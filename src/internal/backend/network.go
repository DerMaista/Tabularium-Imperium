package backend

import (
	"context"
	"encoding/json"
	"sync"
	"time"

	"github.com/AvengeMedia/dankgo/ipc"
	"github.com/AvengeMedia/dankgo/log"
	"github.com/godbus/dbus/v5"
)

const (
	nmService   = "org.freedesktop.NetworkManager"
	nmPath      = "/org/freedesktop/NetworkManager"
	nmIface     = "org.freedesktop.NetworkManager"
	nmActive    = "org.freedesktop.NetworkManager.Connection.Active"
	nmWireless  = "org.freedesktop.NetworkManager.Device.Wireless"
	nmAccessPt  = "org.freedesktop.NetworkManager.AccessPoint"
	propsIface  = "org.freedesktop.DBus.Properties"
	nmConnected = 70
	nmDebounce  = 250 * time.Millisecond
)

type networkWatcher struct {
	bus  *ipc.EventBus
	conn *dbus.Conn

	mu     sync.Mutex
	last   map[string]any
	digest string
	ok     bool
}

func newNetworkWatcher(bus *ipc.EventBus) *networkWatcher {
	return &networkWatcher{bus: bus, last: map[string]any{"available": false}}
}

func (n *networkWatcher) available() bool {
	n.mu.Lock()
	defer n.mu.Unlock()
	return n.ok
}

func (n *networkWatcher) start(ctx context.Context) {
	conn, err := dbus.ConnectSystemBus()
	if err != nil {
		log.Warnf("system bus unavailable: %v; network widget disabled", err)
		return
	}

	if _, err := getProp[uint32](conn, nmService, dbus.ObjectPath(nmPath), nmIface, "State"); err != nil {
		log.Warnf("NetworkManager not reachable: %v; network widget disabled", err)
		_ = conn.Close()
		return
	}

	n.mu.Lock()
	n.conn = conn
	n.ok = true
	n.mu.Unlock()

	if err := conn.AddMatchSignal(
		dbus.WithMatchSender(nmService),
		dbus.WithMatchInterface(propsIface),
		dbus.WithMatchMember("PropertiesChanged"),
	); err != nil {
		log.Warnf("subscribing to NetworkManager signals: %v", err)
	}

	signals := make(chan *dbus.Signal, 64)
	conn.Signal(signals)

	go n.loop(ctx, conn, signals)
}

func (n *networkWatcher) loop(ctx context.Context, conn *dbus.Conn, signals chan *dbus.Signal) {
	defer conn.Close()

	debounce := time.NewTimer(0)
	if !debounce.Stop() {
		<-debounce.C
	}
	pending := false

	n.publish(n.resolve())

	for {
		select {
		case <-ctx.Done():
			return

		case _, ok := <-signals:
			if !ok {
				return
			}
			if !pending {
				pending = true
				debounce.Reset(nmDebounce)
			}

		case <-debounce.C:
			pending = false
			n.publish(n.resolve())
		}
	}
}

func (n *networkWatcher) publish(state map[string]any) {
	digest, err := json.Marshal(state)
	if err != nil {
		return
	}

	n.mu.Lock()
	unchanged := n.digest == string(digest)
	n.digest = string(digest)
	n.last = state
	n.mu.Unlock()

	if unchanged {
		return
	}
	n.bus.Publish(TopicNetwork, state)
}

func (n *networkWatcher) republish() {
	n.mu.Lock()
	last := n.last
	n.mu.Unlock()
	n.bus.Publish(TopicNetwork, last)
}

func (n *networkWatcher) resolve() map[string]any {
	n.mu.Lock()
	conn := n.conn
	n.mu.Unlock()

	if conn == nil {
		return map[string]any{"available": false, "connected": false, "name": "OFFLINE"}
	}

	state := map[string]any{
		"available": true,
		"connected": false,
		"type":      "none",
		"name":      "OFFLINE",
		"strength":  0,
	}

	nmState, err := getProp[uint32](conn, nmService, dbus.ObjectPath(nmPath), nmIface, "State")
	if err != nil {
		return state
	}
	state["nmState"] = nmState

	primary, err := getProp[dbus.ObjectPath](conn, nmService, dbus.ObjectPath(nmPath), nmIface, "PrimaryConnection")
	if err != nil || primary == "" || primary == "/" {
		return state
	}

	connType, _ := getProp[string](conn, nmService, primary, nmActive, "Type")
	connID, _ := getProp[string](conn, nmService, primary, nmActive, "Id")

	state["connected"] = nmState >= nmConnected
	state["type"] = shortConnType(connType)
	if connID != "" {
		state["name"] = connID
	}

	if connType != "802-11-wireless" {
		return state
	}

	devices, err := getProp[[]dbus.ObjectPath](conn, nmService, primary, nmActive, "Devices")
	if err != nil || len(devices) == 0 {
		return state
	}

	ap, err := getProp[dbus.ObjectPath](conn, nmService, devices[0], nmWireless, "ActiveAccessPoint")
	if err != nil || ap == "" || ap == "/" {
		return state
	}

	if ssid, err := getProp[[]byte](conn, nmService, ap, nmAccessPt, "Ssid"); err == nil && len(ssid) > 0 {
		state["name"] = string(ssid)
	}
	if strength, err := getProp[byte](conn, nmService, ap, nmAccessPt, "Strength"); err == nil {
		state["strength"] = int(strength)
	}

	return state
}

func shortConnType(t string) string {
	switch t {
	case "802-11-wireless":
		return "wifi"
	case "802-3-ethernet":
		return "ethernet"
	case "":
		return "none"
	default:
		return t
	}
}

func (n *networkWatcher) handle(_ context.Context, w *ipc.ConnWriter, req ipc.Request, _ *ipc.Subscriber) {
	switch req.Method {
	case "network.get":
		if !n.available() {
			ipc.Respond(w, req.ID, map[string]any{"available": false, "connected": false, "name": "OFFLINE"})
			return
		}
		ipc.Respond(w, req.ID, n.resolve())
	default:
		ipc.RespondError(w, req.ID, "unknown method: "+req.Method)
	}
}

func (n *networkWatcher) info() map[string]any {
	n.mu.Lock()
	defer n.mu.Unlock()
	return map[string]any{"available": n.ok, "state": n.last}
}

func getProp[T any](conn *dbus.Conn, service string, path dbus.ObjectPath, iface, name string) (T, error) {
	var zero T
	variant, err := conn.Object(service, path).GetProperty(iface + "." + name)
	if err != nil {
		return zero, err
	}
	value, ok := variant.Value().(T)
	if !ok {
		return zero, dbus.MakeFailedError(errWrongType{iface + "." + name})
	}
	return value, nil
}

type errWrongType struct{ prop string }

func (e errWrongType) Error() string { return "unexpected type for " + e.prop }
