package backend

import (
	"context"
	"fmt"
	"sync"

	"github.com/AvengeMedia/dankgo/ipc"
	"github.com/AvengeMedia/dankgo/ipc/params"
	"github.com/AvengeMedia/dankgo/log"
	"github.com/godbus/dbus/v5"
)

const (
	gammaService = "rs.wl-gammarelay"
	gammaPath    = dbus.ObjectPath("/")
	gammaIface   = "rs.wl.gammarelay"

	brightnessFloor = 0.1

	dbusService = "org.freedesktop.DBus"
	dbusPath    = dbus.ObjectPath("/org/freedesktop/DBus")
)

type brightnessManager struct {
	bus *ipc.EventBus

	mu      sync.Mutex
	conn    *dbus.Conn
	present bool
	value   float64
}

func newBrightnessManager(bus *ipc.EventBus) *brightnessManager {
	return &brightnessManager{bus: bus, value: 1}
}

func (b *brightnessManager) start(ctx context.Context) {
	conn, err := dbus.ConnectSessionBus()
	if err != nil {
		log.Warnf("brightness: session bus unavailable: %v; brightness control is off", err)
		return
	}

	b.mu.Lock()
	b.conn = conn
	b.mu.Unlock()

	b.watch(ctx, conn)
	b.refresh()

	go func() {
		<-ctx.Done()
		b.mu.Lock()
		b.conn = nil
		b.mu.Unlock()
		_ = conn.Close()
	}()
}

func (b *brightnessManager) watch(ctx context.Context, conn *dbus.Conn) {
	if err := conn.AddMatchSignal(
		dbus.WithMatchSender(gammaService),
		dbus.WithMatchObjectPath(gammaPath),
		dbus.WithMatchInterface(propsIface),
		dbus.WithMatchMember("PropertiesChanged"),
	); err != nil {
		log.Warnf("brightness: cannot watch %s properties: %v", gammaService, err)
	}

	if err := conn.AddMatchSignal(
		dbus.WithMatchSender(dbusService),
		dbus.WithMatchObjectPath(dbusPath),
		dbus.WithMatchInterface(dbusService),
		dbus.WithMatchMember("NameOwnerChanged"),
		dbus.WithMatchArg(0, gammaService),
	); err != nil {
		log.Warnf("brightness: cannot watch %s ownership: %v", gammaService, err)
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
				b.onSignal(sig)
			}
		}
	}()
}

func (b *brightnessManager) onSignal(sig *dbus.Signal) {
	switch sig.Name {
	case propsIface + ".PropertiesChanged":
		if sig.Path != gammaPath || len(sig.Body) < 2 {
			return
		}
		iface, _ := sig.Body[0].(string)
		if iface != gammaIface {
			return
		}
		changed, ok := sig.Body[1].(map[string]dbus.Variant)
		if !ok {
			return
		}
		variant, ok := changed["Brightness"]
		if !ok {
			return
		}
		value, ok := variant.Value().(float64)
		if !ok {
			return
		}
		b.note(value, true)

	case dbusService + ".NameOwnerChanged":
		if len(sig.Body) < 3 {
			return
		}
		name, _ := sig.Body[0].(string)
		if name != gammaService {
			return
		}
		owner, _ := sig.Body[2].(string)
		if owner == "" {
			log.Infof("brightness: %s left the bus", gammaService)
			b.note(0, false)
			return
		}
		log.Infof("brightness: %s appeared on the bus", gammaService)
		b.refresh()
	}
}

func (b *brightnessManager) note(value float64, present bool) {
	b.mu.Lock()
	changed := b.present != present || (present && b.value != value)
	b.present = present
	if present {
		b.value = value
	}
	b.mu.Unlock()

	if changed {
		b.publish()
	}
}

func (b *brightnessManager) refresh() {
	b.mu.Lock()
	conn := b.conn
	b.mu.Unlock()

	if conn == nil {
		b.note(0, false)
		return
	}

	value, err := getProp[float64](conn, gammaService, gammaPath, gammaIface, "Brightness")
	if err != nil {
		log.Debugf("brightness: %s is not answering: %v", gammaService, err)
		b.note(0, false)
		return
	}
	b.note(value, true)
}

func (b *brightnessManager) set(value float64) error {
	b.mu.Lock()
	conn, present := b.conn, b.present
	b.mu.Unlock()

	if conn == nil {
		return fmt.Errorf("no session bus")
	}
	if !present {
		return fmt.Errorf("%s is not running", gammaService)
	}

	value = clampBrightness(value)
	if err := conn.Object(gammaService, gammaPath).
		SetProperty(gammaIface+".Brightness", dbus.MakeVariant(value)); err != nil {
		return fmt.Errorf("set brightness: %w", err)
	}

	b.note(value, true)
	return nil
}

func clampBrightness(value float64) float64 {
	switch {
	case value < brightnessFloor:
		return brightnessFloor
	case value > 1:
		return 1
	default:
		return value
	}
}

func (b *brightnessManager) current() float64 {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.value
}

func (b *brightnessManager) available() bool {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.present
}

func (b *brightnessManager) snapshot() map[string]any {
	b.mu.Lock()
	defer b.mu.Unlock()

	return map[string]any{
		"available": b.present,
		"value":     b.value,
	}
}

func (b *brightnessManager) publish() {
	b.bus.Publish(TopicBrightness, b.snapshot())
}

func (b *brightnessManager) republish() { b.publish() }

func (b *brightnessManager) info() map[string]any {
	b.mu.Lock()
	reachable := b.conn != nil
	b.mu.Unlock()

	info := b.snapshot()
	info["sessionBus"] = reachable
	info["service"] = gammaService
	info["floor"] = brightnessFloor
	return info
}

func (b *brightnessManager) handle(_ context.Context, w *ipc.ConnWriter, req ipc.Request, _ *ipc.Subscriber) {
	switch req.Method {
	case "brightness.get":
		b.refresh()
		ipc.Respond(w, req.ID, b.snapshot())

	case "brightness.set":
		value, err := params.Float(req.Params, "value")
		if err != nil {
			ipc.RespondError(w, req.ID, err.Error())
			return
		}
		if err := b.set(value); err != nil {
			ipc.RespondError(w, req.ID, err.Error())
			return
		}
		ipc.Respond(w, req.ID, b.snapshot())

	case "brightness.adjust":
		delta, err := params.Float(req.Params, "delta")
		if err != nil {
			ipc.RespondError(w, req.ID, err.Error())
			return
		}
		if err := b.set(b.current() + delta); err != nil {
			ipc.RespondError(w, req.ID, err.Error())
			return
		}
		ipc.Respond(w, req.ID, b.snapshot())

	default:
		ipc.RespondError(w, req.ID, "unknown method: "+req.Method)
	}
}
