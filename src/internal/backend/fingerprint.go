package backend

import (
	"context"
	"sync"

	"github.com/AvengeMedia/dankgo/ipc"
	"github.com/AvengeMedia/dankgo/log"
	"github.com/godbus/dbus/v5"
)

const (
	fprintService  = "net.reactivated.Fprint"
	fprintDevice   = fprintService + ".Device"
	fprintDevices  = dbus.ObjectPath("/net/reactivated/Fprint/Device")
	fprintPresent  = "finger-present"
	dbusProperties = "org.freedesktop.DBus.Properties"
	dbusDaemon     = "org.freedesktop.DBus"
	dbusDaemonPath = dbus.ObjectPath("/org/freedesktop/DBus")
)

// fingerprintWatcher follows fprintd's finger-present property so the lock
// dial can tell "reader is waiting" apart from "a finger is being read". PAM
// still does the verifying; this only listens. fprintd is bus-activated and
// exits when idle, so the watcher never calls it and only reacts to signals.
type fingerprintWatcher struct {
	mu   sync.Mutex
	bus  *ipc.EventBus
	conn *dbus.Conn

	present bool
	device  dbus.ObjectPath
}

func newFingerprintWatcher(bus *ipc.EventBus) *fingerprintWatcher {
	return &fingerprintWatcher{bus: bus}
}

func (f *fingerprintWatcher) start(ctx context.Context) {
	conn, err := dbus.ConnectSystemBus()
	if err != nil {
		log.Warnf("fingerprint: system bus unavailable: %v; the dial cannot see a finger on the reader", err)
		return
	}

	if err := conn.AddMatchSignal(
		dbus.WithMatchSender(fprintService),
		dbus.WithMatchPathNamespace(fprintDevices),
		dbus.WithMatchInterface(dbusProperties),
		dbus.WithMatchMember("PropertiesChanged"),
		dbus.WithMatchArg(0, fprintDevice),
	); err != nil {
		log.Warnf("fingerprint: cannot watch fprintd: %v", err)
		_ = conn.Close()
		return
	}
	if err := conn.AddMatchSignal(
		dbus.WithMatchSender(dbusDaemon),
		dbus.WithMatchObjectPath(dbusDaemonPath),
		dbus.WithMatchInterface(dbusDaemon),
		dbus.WithMatchMember("NameOwnerChanged"),
		dbus.WithMatchArg(0, fprintService),
	); err != nil {
		log.Debugf("fingerprint: cannot watch fprintd's bus name: %v", err)
	}

	f.mu.Lock()
	f.conn = conn
	f.mu.Unlock()

	signals := make(chan *dbus.Signal, 8)
	conn.Signal(signals)

	go func() {
		defer func() {
			f.mu.Lock()
			f.conn = nil
			f.mu.Unlock()
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
				f.onSignal(sig)
			}
		}
	}()
}

func (f *fingerprintWatcher) onSignal(sig *dbus.Signal) {
	switch sig.Name {
	case dbusProperties + ".PropertiesChanged":
		if len(sig.Body) < 2 {
			return
		}
		changed, ok := sig.Body[1].(map[string]dbus.Variant)
		if !ok {
			return
		}
		value, ok := changed[fprintPresent]
		if !ok {
			return
		}
		present, ok := value.Value().(bool)
		if !ok {
			return
		}
		f.setPresent(present, sig.Path)

	case dbusDaemon + ".NameOwnerChanged":
		if len(sig.Body) != 3 {
			return
		}
		// fprintd went away mid-touch: the finger is no longer being read
		if owner, _ := sig.Body[2].(string); owner == "" {
			f.setPresent(false, "")
		}
	}
}

func (f *fingerprintWatcher) setPresent(present bool, device dbus.ObjectPath) {
	f.mu.Lock()
	if f.present == present {
		f.mu.Unlock()
		return
	}
	f.present = present
	if device != "" {
		f.device = device
	}
	f.mu.Unlock()

	log.Debugf("fingerprint: finger present=%v on %s", present, device)
	f.publish()
}

func (f *fingerprintWatcher) snapshot() map[string]any {
	f.mu.Lock()
	defer f.mu.Unlock()

	return map[string]any{
		"present": f.present,
	}
}

func (f *fingerprintWatcher) publish() { f.bus.Publish(TopicFingerprint, f.snapshot()) }

func (f *fingerprintWatcher) republish() { f.publish() }

func (f *fingerprintWatcher) available() bool {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.conn != nil
}

func (f *fingerprintWatcher) info() map[string]any {
	info := f.snapshot()
	f.mu.Lock()
	info["watching"] = f.conn != nil
	info["device"] = string(f.device)
	f.mu.Unlock()
	return info
}
