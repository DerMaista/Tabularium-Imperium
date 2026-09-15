package backend

import (
	"context"
	"fmt"
	"os"
	"strings"
	"sync"

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
)

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

	lock *lockManager
}

func newPowerManager(lock *lockManager) *powerManager { return &powerManager{lock: lock} }

func (p *powerManager) start(ctx context.Context) {
	conn, err := dbus.ConnectSystemBus()
	if err != nil {
		log.Warnf("system bus unavailable: %v; power actions will be unavailable", err)
		return
	}
	if _, err := query(conn, "CanPowerOff"); err != nil {
		log.Warnf("logind not reachable: %v; power actions will be unavailable", err)
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

	go func() {
		<-ctx.Done()
		p.mu.Lock()
		p.conn = nil
		p.mu.Unlock()
		_ = conn.Close()
	}()
}

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

func (p *powerManager) unavailableReason(action powerAction) string {
	if action.id == "lock" {
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

	log.Infof("power: %s", id)

	if action.id == "lock" {
		p.lock.setLocked(true, lockSourceUser)
		return nil
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

func (p *powerManager) info() map[string]any {
	p.mu.Lock()
	reachable := p.conn != nil
	session := p.session
	p.mu.Unlock()

	return map[string]any{
		"logind":  reachable,
		"session": session,
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
