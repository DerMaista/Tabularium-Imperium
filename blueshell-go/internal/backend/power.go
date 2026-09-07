package backend

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"syscall"

	"github.com/AvengeMedia/dankgo/ipc"
	"github.com/AvengeMedia/dankgo/ipc/params"
	"github.com/AvengeMedia/dankgo/log"
	"github.com/godbus/dbus/v5"
)

const (
	loginService = "org.freedesktop.login1"
	loginPath    = "/org/freedesktop/login1"
	loginManager = "org.freedesktop.login1.Manager"
	loginSession = "org.freedesktop.login1.Session"

	defaultLockCommand = "swaylock"
)

// powerAction is one button in the logout panel. `can` is the logind method
// that answers whether the machine will honour it — "yes", "no", "na" or
// "challenge" — and `call` is the one that performs it, always with
// interactive=false: there is nobody on this end to answer a polkit prompt.
//
// Two are special. `logout` has no Can… to ask, so it is available exactly
// when a session was resolved to terminate. `lock` is not logind's job at all —
// LockSession only emits a signal for a locker that is already listening, and
// swaylock does not listen — so blueshell spawns the configured locker itself.
//
// Icons, labels and order are the panel's business and live in the QML. All
// the backend says is what the machine is willing to do.
type powerAction struct {
	id   string
	can  string
	call string
}

var powerActions = []powerAction{
	{id: "lock"},
	{id: "logout"},
	{id: "reboot", can: "CanReboot", call: "Reboot"},
	{id: "poweroff", can: "CanPowerOff", call: "PowerOff"},
	{id: "suspend", can: "CanSuspend", call: "Suspend"},
	{id: "hibernate", can: "CanHibernate", call: "Hibernate"},
}

func findPowerAction(id string) (powerAction, bool) {
	for _, action := range powerActions {
		if action.id == id {
			return action, true
		}
	}
	return powerAction{}, false
}

type powerManager struct {
	mu      sync.Mutex
	conn    *dbus.Conn
	session string
}

// newPowerManager takes no event bus: nothing here is a stream. The panel asks
// once when it opens, and the answers only change when the hardware does.
func newPowerManager() *powerManager { return &powerManager{} }

func (p *powerManager) start(ctx context.Context) {
	conn, err := dbus.ConnectSystemBus()
	if err != nil {
		log.Warnf("system bus unavailable: %v; only the locker will work", err)
		return
	}
	if _, err := query(conn, "CanPowerOff"); err != nil {
		log.Warnf("logind not reachable: %v; only the locker will work", err)
		_ = conn.Close()
		return
	}

	session := resolveSession(conn)
	if session == "" {
		log.Warnf("power: no logind session found; logout will be unavailable")
	}

	p.mu.Lock()
	p.conn = conn
	p.session = session
	p.mu.Unlock()

	// No signals to watch, so this goroutine is the whole lifecycle: hold the
	// connection open for as long as the backend runs, then hand it back.
	go func() {
		<-ctx.Done()
		p.mu.Lock()
		p.conn = nil
		p.mu.Unlock()
		_ = conn.Close()
	}()
}

// resolveSession prefers $XDG_SESSION_ID — the backend is started inside the
// session it will later terminate — and asks logind which session owns this
// process only when the environment is silent.
func resolveSession(conn *dbus.Conn) string {
	if id := strings.TrimSpace(os.Getenv("XDG_SESSION_ID")); id != "" {
		return id
	}

	var path dbus.ObjectPath
	call := conn.Object(loginService, dbus.ObjectPath(loginPath)).
		Call(loginManager+".GetSessionByPID", 0, uint32(os.Getpid()))
	if err := call.Store(&path); err != nil {
		log.Debugf("power: no session owns pid %d: %v", os.Getpid(), err)
		return ""
	}

	id, err := getProp[string](conn, loginService, path, loginSession, "Id")
	if err != nil {
		log.Debugf("power: reading session id of %s: %v", path, err)
		return ""
	}
	return id
}

func query(conn *dbus.Conn, method string) (string, error) {
	var answer string
	err := conn.Object(loginService, dbus.ObjectPath(loginPath)).
		Call(loginManager+"."+method, 0).Store(&answer)
	return answer, err
}

// unavailableReason is empty when the action can run, and otherwise says why
// not in words the panel can put on screen.
func (p *powerManager) unavailableReason(action powerAction) string {
	if action.id == "lock" {
		locker := p.lockCommand()[0]
		if _, err := exec.LookPath(locker); err != nil {
			return locker + " is not in $PATH"
		}
		return ""
	}

	p.mu.Lock()
	conn, session := p.conn, p.session
	p.mu.Unlock()

	if conn == nil {
		return "logind is not reachable"
	}
	if action.id == "logout" {
		if session == "" {
			return "no logind session to terminate"
		}
		return ""
	}

	answer, err := query(conn, action.can)
	switch {
	case err != nil:
		return err.Error()
	case answer == "yes":
		return ""
	case answer == "na":
		return "not supported by this system"
	case answer == "challenge":
		return "requires authentication"
	default:
		return "logind says " + answer
	}
}

func (p *powerManager) list() []map[string]any {
	actions := make([]map[string]any, 0, len(powerActions))
	for _, action := range powerActions {
		reason := p.unavailableReason(action)
		actions = append(actions, map[string]any{
			"id":        action.id,
			"available": reason == "",
			"reason":    reason,
		})
	}
	return actions
}

// available gates the capability, and with it the chip in the corner: it goes
// away only when there is nothing at all this machine will let us do.
func (p *powerManager) available() bool {
	for _, action := range powerActions {
		if p.unavailableReason(action) == "" {
			return true
		}
	}
	return false
}

func (p *powerManager) invoke(id string) error {
	action, ok := findPowerAction(id)
	if !ok {
		return fmt.Errorf("unknown power action %q", id)
	}
	if reason := p.unavailableReason(action); reason != "" {
		return fmt.Errorf("%s is unavailable: %s", id, reason)
	}

	// Logged before the call, because for four of the six this is the last
	// line the log will ever get.
	log.Infof("power: %s", id)

	if action.id == "lock" {
		return p.lock()
	}

	p.mu.Lock()
	conn, session := p.conn, p.session
	p.mu.Unlock()

	manager := conn.Object(loginService, dbus.ObjectPath(loginPath))
	if action.id == "logout" {
		return manager.Call(loginManager+".TerminateSession", 0, session).Err
	}
	return manager.Call(loginManager+"."+action.call, 0, false).Err
}

// lock starts the locker in its own session, so that restarting the shell — or
// the backend dying — cannot take the lock screen down with it and leave the
// desktop bare.
func (p *powerManager) lock() error {
	command := p.lockCommand()

	cmd := exec.Command(command[0], command[1:]...)
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	if err := cmd.Start(); err != nil {
		return fmt.Errorf("%s: %w", command[0], err)
	}

	go func() {
		if err := cmd.Wait(); err != nil {
			log.Debugf("power: %s exited: %v", command[0], err)
		}
	}()
	return nil
}

type powerSettings struct {
	LockCommand string `json:"lockCommand"`
}

// lockCommand splits the configured command on spaces rather than handing it to
// a shell. The panel this replaces pasted its commands into a `bash -c` string
// built by QML; none of that is needed to run a locker.
func (p *powerManager) lockCommand() []string {
	fields := strings.Fields(p.settings().LockCommand)
	if len(fields) == 0 {
		return []string{defaultLockCommand}
	}
	return fields
}

func (p *powerManager) settings() powerSettings {
	settings := powerSettings{LockCommand: defaultLockCommand}

	path := filepath.Join(shellConfigDir(), "config.json")
	data, err := os.ReadFile(path)
	if err != nil {
		return settings
	}

	var file struct {
		Power powerSettings `json:"power"`
	}
	if err := json.Unmarshal(data, &file); err != nil {
		log.Debugf("power: parsing %s: %v", path, err)
		return settings
	}
	return settings.merge(file.Power)
}

func (s powerSettings) merge(other powerSettings) powerSettings {
	if other.LockCommand != "" {
		s.LockCommand = other.LockCommand
	}
	return s
}

func (p *powerManager) info() map[string]any {
	p.mu.Lock()
	reachable := p.conn != nil
	session := p.session
	p.mu.Unlock()

	return map[string]any{
		"logind":      reachable,
		"session":     session,
		"lockCommand": strings.Join(p.lockCommand(), " "),
	}
}

func (p *powerManager) handle(_ context.Context, w *ipc.ConnWriter, req ipc.Request, _ *ipc.Subscriber) {
	switch req.Method {
	case "power.list":
		ipc.Respond(w, req.ID, map[string]any{"actions": p.list()})

	case "power.invoke":
		id, err := params.StringNonEmpty(req.Params, "action")
		if err != nil {
			ipc.RespondError(w, req.ID, err.Error())
			return
		}
		if err := p.invoke(id); err != nil {
			ipc.RespondError(w, req.ID, err.Error())
			return
		}
		ipc.Respond(w, req.ID, map[string]any{"action": id})

	default:
		ipc.RespondError(w, req.ID, "unknown method: "+req.Method)
	}
}
