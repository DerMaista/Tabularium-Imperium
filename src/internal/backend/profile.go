package backend

import (
	"context"
	"fmt"
	"slices"
	"sync"

	"github.com/AvengeMedia/dankgo/ipc"
	"github.com/AvengeMedia/dankgo/ipc/params"
	"github.com/AvengeMedia/dankgo/log"
	"github.com/godbus/dbus/v5"
)

const (
	profileService = "net.hadess.PowerProfiles"
	profilePath    = "/net/hadess/PowerProfiles"
	profileIface   = "net.hadess.PowerProfiles"
)

var profileOrder = []string{"power-saver", "balanced", "performance"}

type profileManager struct {
	mu   sync.Mutex
	bus  *ipc.EventBus
	conn *dbus.Conn

	active   string
	profiles []string
	degraded string
}

func newProfileManager(bus *ipc.EventBus) *profileManager { return &profileManager{bus: bus} }

func (p *profileManager) start(ctx context.Context) {
	conn, err := dbus.ConnectSystemBus()
	if err != nil {
		log.Warnf("profile: system bus unavailable: %v; power profiles will be unavailable", err)
		return
	}
	if err := p.read(conn); err != nil {
		log.Warnf("profile: %s not reachable: %v; power profiles will be unavailable", profileService, err)
		_ = conn.Close()
		return
	}

	if err := conn.AddMatchSignal(
		dbus.WithMatchObjectPath(profilePath),
		dbus.WithMatchInterface(propsIface),
		dbus.WithMatchMember("PropertiesChanged"),
	); err != nil {
		log.Warnf("profile: subscribing to %s signals: %v", profileService, err)
	}

	signals := make(chan *dbus.Signal, 16)
	conn.Signal(signals)

	p.mu.Lock()
	p.conn = conn
	p.mu.Unlock()

	go func() {
		defer func() {
			p.mu.Lock()
			p.conn = nil
			p.mu.Unlock()
			_ = conn.Close()
		}()

		for {
			select {
			case <-ctx.Done():
				return
			case sig, ok := <-signals:
				if !ok {
					return
				}
				if len(sig.Body) == 0 || sig.Body[0] != profileIface {
					continue
				}
				if err := p.read(conn); err != nil {
					log.Debugf("profile: rereading after change: %v", err)
					continue
				}
				p.publish()
			}
		}
	}()
}

func (p *profileManager) read(conn *dbus.Conn) error {
	var props map[string]dbus.Variant
	err := conn.Object(profileService, profilePath).
		Call(propsIface+".GetAll", 0, profileIface).Store(&props)
	if err != nil {
		return err
	}

	active, _ := props["ActiveProfile"].Value().(string)
	degraded, _ := props["PerformanceDegraded"].Value().(string)

	var offered []string
	entries, _ := props["Profiles"].Value().([]map[string]dbus.Variant)
	for _, entry := range entries {
		if name, ok := entry["Profile"].Value().(string); ok {
			offered = append(offered, name)
		}
	}
	// Keep the cycle order no matter how the daemon lists them.
	profiles := make([]string, 0, len(offered))
	for _, name := range profileOrder {
		if slices.Contains(offered, name) {
			profiles = append(profiles, name)
		}
	}

	p.mu.Lock()
	p.active = active
	p.profiles = profiles
	p.degraded = degraded
	p.mu.Unlock()
	return nil
}

func (p *profileManager) set(name string) error {
	p.mu.Lock()
	conn, known := p.conn, slices.Contains(p.profiles, name)
	p.mu.Unlock()

	if conn == nil {
		return fmt.Errorf("%s is not reachable", profileService)
	}
	if !known {
		return fmt.Errorf("unknown power profile %q", name)
	}

	log.Infof("profile: %s", name)
	if err := conn.Object(profileService, profilePath).
		SetProperty(profileIface+".ActiveProfile", dbus.MakeVariant(name)); err != nil {
		return err
	}

	// Record it now so the response and a quick follow-up cycle see the new
	// profile without waiting for the PropertiesChanged signal.
	p.mu.Lock()
	p.active = name
	p.mu.Unlock()
	return nil
}

func (p *profileManager) cycle() error {
	p.mu.Lock()
	profiles, active := p.profiles, p.active
	p.mu.Unlock()

	if len(profiles) == 0 {
		return fmt.Errorf("no power profiles offered")
	}
	next := (slices.Index(profiles, active) + 1) % len(profiles)
	return p.set(profiles[next])
}

func (p *profileManager) snapshot() map[string]any {
	p.mu.Lock()
	defer p.mu.Unlock()

	return map[string]any{
		"active":   p.active,
		"profiles": slices.Clone(p.profiles),
		"degraded": p.degraded,
	}
}

func (p *profileManager) publish() { p.bus.Publish(TopicProfile, p.snapshot()) }

func (p *profileManager) republish() {
	if p.available() {
		p.publish()
	}
}

func (p *profileManager) available() bool {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.conn != nil
}

func (p *profileManager) info() map[string]any {
	info := p.snapshot()
	info["daemon"] = p.available()
	return info
}

func (p *profileManager) handle(_ context.Context, w *ipc.ConnWriter, req ipc.Request, _ *ipc.Subscriber) {
	var err error
	switch req.Method {
	case "profile.status":
	case "profile.set":
		var name string
		if name, err = params.StringNonEmpty(req.Params, "profile"); err == nil {
			err = p.set(name)
		}
	case "profile.cycle":
		err = p.cycle()
	default:
		ipc.RespondError(w, req.ID, "unknown method: "+req.Method)
		return
	}

	if err != nil {
		ipc.RespondError(w, req.ID, err.Error())
		return
	}
	ipc.Respond(w, req.ID, p.snapshot())
}
