package backend

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/AvengeMedia/dankgo/ipc"
	"github.com/AvengeMedia/dankgo/ipc/params"
	"github.com/AvengeMedia/dankgo/log"
	"github.com/AvengeMedia/dankgo/paths"
	"github.com/godbus/dbus/v5"
)

const (
	lockSleepGrace = 3 * time.Second

	defaultLockIdleTimeout = 300
)

type lockManager struct {
	mu      sync.Mutex
	bus     *ipc.EventBus
	conn    *dbus.Conn
	session dbus.ObjectPath

	locked bool
	secure bool
	since  time.Time

	secureWait chan struct{}

	inhibitor *os.File
}

func newLockManager(bus *ipc.EventBus) *lockManager {
	return &lockManager{bus: bus}
}

func (l *lockManager) start(ctx context.Context) {
	if readLockedState() {
		l.mu.Lock()
		l.locked = true
		l.since = time.Now()
		l.mu.Unlock()
		log.Infof("lock: restoring locked session from saved state")
	}

	conn, err := dbus.ConnectSystemBus()
	if err != nil {
		log.Warnf("lock: system bus unavailable: %v; loginctl and sleep integration are off", err)
		return
	}

	session := resolveSessionPath(conn)
	if session == "" {
		log.Warnf("lock: no logind session; loginctl and sleep integration are off")
		_ = conn.Close()
		return
	}

	l.mu.Lock()
	l.conn = conn
	l.session = session
	l.mu.Unlock()

	l.watchSignals(ctx, conn, session)
	l.takeInhibitor()
	l.publishLockedHint()

	go func() {
		<-ctx.Done()
		l.releaseInhibitor()
		l.mu.Lock()
		l.conn = nil
		l.mu.Unlock()
		_ = conn.Close()
	}()
}

func resolveSessionPath(conn *dbus.Conn) dbus.ObjectPath {
	manager := conn.Object(loginService, dbus.ObjectPath(loginPath))

	if id := resolveSession(conn); id != "" {
		var path dbus.ObjectPath
		if err := manager.Call(loginManager+".GetSession", 0, id).Store(&path); err == nil {
			return path
		}
	}

	var path dbus.ObjectPath
	call := manager.Call(loginManager+".GetSessionByPID", 0, uint32(os.Getpid()))
	if err := call.Store(&path); err != nil {
		log.Debugf("lock: no session owns pid %d: %v", os.Getpid(), err)
		return ""
	}
	return path
}

func (l *lockManager) watchSignals(ctx context.Context, conn *dbus.Conn, session dbus.ObjectPath) {
	if err := conn.AddMatchSignal(
		dbus.WithMatchObjectPath(session),
		dbus.WithMatchInterface(loginSession),
	); err != nil {
		log.Warnf("lock: cannot watch session signals: %v", err)
	}
	if err := conn.AddMatchSignal(
		dbus.WithMatchObjectPath(dbus.ObjectPath(loginPath)),
		dbus.WithMatchInterface(loginManager),
		dbus.WithMatchMember("PrepareForSleep"),
	); err != nil {
		log.Warnf("lock: cannot watch PrepareForSleep: %v", err)
	}

	signals := make(chan *dbus.Signal, 8)
	conn.Signal(signals)

	go func() {
		for {
			select {
			case <-ctx.Done():
				return
			case sig, ok := <-signals:
				if !ok {
					return
				}
				l.onSignal(sig)
			}
		}
	}()
}

func (l *lockManager) onSignal(sig *dbus.Signal) {
	switch sig.Name {
	case loginSession + ".Lock":
		log.Infof("lock: logind asked us to lock")
		l.setLocked(true, lockSourceLogind)

	case loginSession + ".Unlock":
		log.Infof("lock: ignoring logind Unlock; only PAM can unlock this session")

	case loginManager + ".PrepareForSleep":
		if len(sig.Body) != 1 {
			return
		}
		sleeping, _ := sig.Body[0].(bool)
		if sleeping {
			l.onSleep()
			return
		}
		l.takeInhibitor()
	}
}

func (l *lockManager) onSleep() {
	log.Infof("lock: locking before sleep")
	l.setLocked(true, lockSourceSleep)

	if !l.waitForSecure(lockSleepGrace) {
		log.Warnf("lock: lock surface not confirmed within %s; sleeping anyway", lockSleepGrace)
	}
	l.releaseInhibitor()
}

func (l *lockManager) takeInhibitor() {
	l.mu.Lock()
	conn := l.conn
	held := l.inhibitor != nil
	l.mu.Unlock()

	if conn == nil || held {
		return
	}

	var fd dbus.UnixFD
	call := conn.Object(loginService, dbus.ObjectPath(loginPath)).
		Call(loginManager+".Inhibit", 0, "sleep", "blueshell", "Locking the session before sleep", "delay")
	if err := call.Store(&fd); err != nil {
		log.Warnf("lock: cannot inhibit sleep: %v", err)
		return
	}

	l.mu.Lock()
	l.inhibitor = os.NewFile(uintptr(fd), "blueshell-sleep-inhibitor")
	l.mu.Unlock()
}

func (l *lockManager) releaseInhibitor() {
	l.mu.Lock()
	file := l.inhibitor
	l.inhibitor = nil
	l.mu.Unlock()

	if file != nil {
		_ = file.Close()
	}
}

func (l *lockManager) waitForSecure(timeout time.Duration) bool {
	l.mu.Lock()
	if l.secure {
		l.mu.Unlock()
		return true
	}
	if l.secureWait == nil {
		l.secureWait = make(chan struct{})
	}
	wait := l.secureWait
	l.mu.Unlock()

	select {
	case <-wait:
		return true
	case <-time.After(timeout):
		return false
	}
}

const (
	lockSourceUser   = "user"
	lockSourceLogind = "logind"
	lockSourceSleep  = "sleep"
	lockSourceUI     = "ui"
)

func (l *lockManager) setLocked(locked bool, source string) {
	l.mu.Lock()
	if l.locked == locked {
		l.mu.Unlock()
		return
	}
	l.locked = locked
	l.since = time.Now()
	if !locked {
		l.secure = false
	}
	l.mu.Unlock()

	writeLockedState(locked)
	l.publish(source)
	l.publishLockedHint()
}

func (l *lockManager) reportState(locked, secure bool) {
	l.mu.Lock()
	changed := l.locked != locked || l.secure != secure
	l.locked = locked
	l.secure = secure
	if changed {
		l.since = time.Now()
	}
	if secure && l.secureWait != nil {
		close(l.secureWait)
		l.secureWait = nil
	}
	l.mu.Unlock()

	if !changed {
		return
	}
	writeLockedState(locked)
	l.publish(lockSourceUI)
	l.publishLockedHint()
}

func (l *lockManager) publishLockedHint() {
	l.mu.Lock()
	conn, session, locked := l.conn, l.session, l.locked
	l.mu.Unlock()

	if conn == nil || session == "" {
		return
	}
	call := conn.Object(loginService, session).Call(loginSession+".SetLockedHint", 0, locked)
	if call.Err != nil {
		log.Debugf("lock: SetLockedHint(%v): %v", locked, call.Err)
	}
}

func (l *lockManager) snapshot() map[string]any {
	l.mu.Lock()
	defer l.mu.Unlock()

	since := int64(0)
	if !l.since.IsZero() {
		since = l.since.Unix()
	}

	return map[string]any{
		"locked": l.locked,
		"secure": l.secure,
		"since":  since,
	}
}

func (l *lockManager) publish(source string) {
	event := l.snapshot()
	event["source"] = source
	l.bus.Publish(TopicLock, event)
}

func (l *lockManager) republish() { l.publish(lockSourceUI) }

func (l *lockManager) available() bool { return true }

func (l *lockManager) info() map[string]any {
	l.mu.Lock()
	reachable := l.conn != nil
	session := string(l.session)
	inhibited := l.inhibitor != nil
	l.mu.Unlock()

	info := l.snapshot()
	info["logind"] = reachable
	info["session"] = session
	info["sleepInhibited"] = inhibited
	info["idleTimeout"] = l.settings().IdleTimeout
	return info
}

type lockSettings struct {
	IdleTimeout int `json:"idleTimeout"`
}

func (l *lockManager) settings() lockSettings {
	settings := lockSettings{IdleTimeout: defaultLockIdleTimeout}

	path := filepath.Join(shellConfigDir(), "config.json")
	data, err := os.ReadFile(path)
	if err != nil {
		return settings
	}

	var file struct {
		Lock lockSettings `json:"lock"`
	}
	if err := json.Unmarshal(data, &file); err != nil {
		log.Debugf("lock: parsing %s: %v", path, err)
		return settings
	}
	return settings.merge(file.Lock)
}

func (s lockSettings) merge(other lockSettings) lockSettings {
	if other.IdleTimeout != 0 {
		s.IdleTimeout = other.IdleTimeout
	}
	return s
}

func lockStatePath() string {
	dir, err := paths.New("blueshell").StateDir()
	if err != nil {
		return ""
	}
	return filepath.Join(dir, "locked")
}

func readLockedState() bool {
	path := lockStatePath()
	if path == "" {
		return false
	}
	_, err := os.Stat(path)
	return err == nil
}

func writeLockedState(locked bool) {
	path := lockStatePath()
	if path == "" {
		return
	}
	if !locked {
		if err := os.Remove(path); err != nil && !os.IsNotExist(err) {
			log.Debugf("lock: clearing %s: %v", path, err)
		}
		return
	}
	if err := os.WriteFile(path, []byte("1\n"), 0o600); err != nil {
		log.Debugf("lock: recording locked state: %v", err)
	}
}

func (l *lockManager) handle(_ context.Context, w *ipc.ConnWriter, req ipc.Request, _ *ipc.Subscriber) {
	switch req.Method {
	case "lock.status":
		ipc.Respond(w, req.ID, l.snapshot())

	case "lock.lock":
		l.setLocked(true, lockSourceUser)
		ipc.Respond(w, req.ID, l.snapshot())

	case "lock.state":
		locked, err := params.Bool(req.Params, "locked")
		if err != nil {
			ipc.RespondError(w, req.ID, err.Error())
			return
		}
		l.reportState(locked, params.BoolOpt(req.Params, "secure", false))
		ipc.Respond(w, req.ID, l.snapshot())

	default:
		ipc.RespondError(w, req.ID, "unknown method: "+req.Method)
	}
}
