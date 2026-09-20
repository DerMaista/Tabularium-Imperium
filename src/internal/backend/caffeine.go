package backend

import (
	"context"
	"fmt"
	"os"
	"sync"
	"time"

	"github.com/AvengeMedia/dankgo/ipc"
	"github.com/AvengeMedia/dankgo/ipc/params"
	"github.com/AvengeMedia/dankgo/log"
	"github.com/godbus/dbus/v5"
)

const caffeineWhat = "idle"

const caffeineReason = "caffeine: keeping the session awake"

type caffeineManager struct {
	mu   sync.Mutex
	bus  *ipc.EventBus
	conn *dbus.Conn

	active bool
	since  time.Time

	inhibitor *os.File
}

func newCaffeineManager(bus *ipc.EventBus) *caffeineManager { return &caffeineManager{bus: bus} }

func (c *caffeineManager) start(ctx context.Context) {
	conn, err := dbus.ConnectSystemBus()
	if err != nil {
		log.Warnf("caffeine: system bus unavailable: %v; logind's idle timer cannot be held off", err)
		return
	}

	c.mu.Lock()
	c.conn = conn
	c.mu.Unlock()

	go func() {
		<-ctx.Done()
		c.releaseInhibitor()
		c.mu.Lock()
		c.conn = nil
		c.mu.Unlock()
		_ = conn.Close()
	}()
}

func (c *caffeineManager) setActive(active bool) {
	c.mu.Lock()
	if c.active == active {
		c.mu.Unlock()
		return
	}
	c.active = active
	c.since = time.Now()
	c.mu.Unlock()

	if active {
		if err := c.takeInhibitor(); err != nil {
			log.Warnf("caffeine: %v; only the shell's own idle lock is held off", err)
		} else {
			log.Infof("caffeine: on, holding logind's %s inhibitor", caffeineWhat)
		}
	} else {
		c.releaseInhibitor()
		log.Infof("caffeine: off")
	}

	c.publish()
}

func (c *caffeineManager) takeInhibitor() error {
	c.mu.Lock()
	conn, held := c.conn, c.inhibitor != nil
	c.mu.Unlock()

	if held {
		return nil
	}
	if conn == nil {
		return fmt.Errorf("no system bus")
	}

	var fd dbus.UnixFD
	call := conn.Object(loginService, dbus.ObjectPath(loginPath)).
		Call(loginManager+".Inhibit", 0, caffeineWhat, "blueshell", caffeineReason, "block")
	if err := call.Store(&fd); err != nil {
		return fmt.Errorf("cannot inhibit %s: %w", caffeineWhat, err)
	}

	c.mu.Lock()
	c.inhibitor = os.NewFile(uintptr(fd), "blueshell-idle-inhibitor")
	c.mu.Unlock()
	return nil
}

func (c *caffeineManager) releaseInhibitor() {
	c.mu.Lock()
	file := c.inhibitor
	c.inhibitor = nil
	c.mu.Unlock()

	if file != nil {
		_ = file.Close()
	}
}

func (c *caffeineManager) snapshot() map[string]any {
	c.mu.Lock()
	defer c.mu.Unlock()

	since := int64(0)
	if !c.since.IsZero() {
		since = c.since.Unix()
	}

	return map[string]any{
		"active":    c.active,
		"inhibited": c.inhibitor != nil,
		"since":     since,
	}
}

func (c *caffeineManager) publish() { c.bus.Publish(TopicCaffeine, c.snapshot()) }

func (c *caffeineManager) republish() { c.publish() }

func (c *caffeineManager) available() bool { return true }

func (c *caffeineManager) info() map[string]any {
	c.mu.Lock()
	reachable := c.conn != nil
	c.mu.Unlock()

	info := c.snapshot()
	info["logind"] = reachable
	info["what"] = caffeineWhat
	return info
}

func (c *caffeineManager) handle(_ context.Context, w *ipc.ConnWriter, req ipc.Request, _ *ipc.Subscriber) {
	switch req.Method {
	case "caffeine.status":
		ipc.Respond(w, req.ID, c.snapshot())

	case "caffeine.set":
		active, err := params.Bool(req.Params, "active")
		if err != nil {
			ipc.RespondError(w, req.ID, err.Error())
			return
		}
		c.setActive(active)
		ipc.Respond(w, req.ID, c.snapshot())

	case "caffeine.toggle":
		c.mu.Lock()
		active := c.active
		c.mu.Unlock()
		c.setActive(!active)
		ipc.Respond(w, req.ID, c.snapshot())

	default:
		ipc.RespondError(w, req.ID, "unknown method: "+req.Method)
	}
}
