package backend

import (
	"context"
	"fmt"
	"time"

	"github.com/AvengeMedia/dankgo/ipc"
	"github.com/AvengeMedia/dankgo/ipc/params"
	"github.com/AvengeMedia/dankgo/log"
)

const apiVersion = 1

const (
	TopicMetrics    = "metrics"
	TopicWorkspaces = "workspaces"
	TopicNetwork    = "network"
	TopicClock      = "clock"
	TopicTheme      = "theme"
	TopicLock       = "lock"
	TopicSigil      = "sigil"
	TopicBrightness = "brightness"
	TopicCaffeine   = "caffeine"
)

type Backend struct {
	srv    *ipc.Server
	cancel context.CancelFunc
	done   chan error

	metrics    *metricsSampler
	workspaces *mangoWatcher
	network    *networkWatcher
	clock      *clockTicker
	theme      *themeManager
	power      *powerManager
	lock       *lockManager
	sigil      *sigilManager
	brightness *brightnessManager
	caffeine   *caffeineManager
}

func Boot(ctx context.Context) (*Backend, error) {
	ctx, cancel := context.WithCancel(ctx)

	b := &Backend{
		cancel: cancel,
		done:   make(chan error, 1),
	}

	bus := ipc.NewEventBus()
	b.metrics = newMetricsSampler(bus)
	b.workspaces = newMangoWatcher(bus)
	b.network = newNetworkWatcher(bus)
	b.clock = newClockTicker(bus)
	b.theme = newThemeManager(bus)
	b.lock = newLockManager(bus)
	b.sigil = newSigilManager(bus)
	b.brightness = newBrightnessManager(bus)
	b.caffeine = newCaffeineManager(bus)
	b.power = newPowerManager(b.lock)

	mux := ipc.NewMux()
	mux.Handle("getServerInfo", b.handleServerInfo)
	mux.HandlePrefix("metrics.", b.metrics.handle)
	mux.HandlePrefix("workspaces.", b.workspaces.handle)
	mux.HandlePrefix("network.", b.network.handle)
	mux.HandlePrefix("clock.", b.clock.handle)
	mux.HandlePrefix("theme.", b.theme.handle)
	mux.HandlePrefix("power.", b.power.handle)
	mux.HandlePrefix("lock.", b.lock.handle)
	mux.HandlePrefix("sigil.", b.sigil.handle)
	mux.HandlePrefix("brightness.", b.brightness.handle)
	mux.HandlePrefix("caffeine.", b.caffeine.handle)

	b.srv = ipc.NewServer(ipc.Config{
		AppName:    "blueshell",
		APIVersion: apiVersion,
		Bus:        bus,

		CapabilitiesFunc: b.capabilities,

		DefaultSubscribeTopics: []string{TopicMetrics, TopicWorkspaces, TopicNetwork, TopicClock, TopicTheme, TopicLock, TopicSigil, TopicBrightness, TopicCaffeine},

		OnSubscribe: b.replaySnapshots,
	}, mux.ServeIPC)

	if err := b.srv.Listen(); err != nil {
		cancel()
		return nil, fmt.Errorf("bind ipc socket: %w", err)
	}

	b.metrics.start(ctx)
	b.workspaces.start(ctx)
	b.network.start(ctx)
	b.clock.start(ctx)
	b.theme.start(ctx)
	b.power.start(ctx)
	b.lock.start(ctx)
	b.sigil.start(ctx)
	b.brightness.start(ctx)
	b.caffeine.start(ctx)

	go func() {
		defer func() {
			if r := recover(); r != nil {
				b.done <- fmt.Errorf("backend panic: %v", r)
			}
		}()
		b.done <- b.srv.Serve(ctx)
	}()

	return b, nil
}

func (b *Backend) SocketPath() string { return b.srv.SocketPath() }

func (b *Backend) Done() <-chan error { return b.done }

func (b *Backend) Close() {
	b.cancel()
	_ = b.srv.Close()
}

func (b *Backend) capabilities() []string {
	caps := []string{"metrics", "metrics.cpu", "metrics.memory", "metrics.disk", "metrics.uptime", "clock"}
	if b.workspaces.available() {
		caps = append(caps, "workspaces")
	}
	if b.network.available() {
		caps = append(caps, "network")
	}
	if b.theme.available() {
		caps = append(caps, "theme")
	}
	if b.power.available() {
		caps = append(caps, "power")
	}
	if b.lock.available() {
		caps = append(caps, "lock")
	}
	if b.sigil.available() {
		caps = append(caps, "sigil")
	}
	if b.brightness.available() {
		caps = append(caps, "brightness")
	}
	if b.caffeine.available() {
		caps = append(caps, "caffeine")
	}
	return caps
}

func (b *Backend) replaySnapshots(topics []string, _ *ipc.Subscriber) {
	go func() {
		for _, topic := range topics {
			switch topic {
			case TopicMetrics:
				b.metrics.publishNow()
			case TopicWorkspaces:
				b.workspaces.republish()
			case TopicNetwork:
				b.network.republish()
			case TopicClock:
				b.clock.publishNow()
			case TopicTheme:
				b.theme.republish()
			case TopicLock:
				b.lock.republish()
			case TopicSigil:
				b.sigil.republish()
			case TopicBrightness:
				b.brightness.republish()
			case TopicCaffeine:
				b.caffeine.republish()
			}
		}
	}()
}

func (b *Backend) handleServerInfo(_ context.Context, w *ipc.ConnWriter, req ipc.Request, _ *ipc.Subscriber) {
	ipc.Respond(w, req.ID, map[string]any{
		"apiVersion":   apiVersion,
		"capabilities": b.capabilities(),
		"uptimeSec":    int(time.Since(startedAt).Seconds()),
		"metrics":      b.metrics.info(),
		"compositor":   b.workspaces.info(),
		"network":      b.network.info(),
		"theme":        b.theme.info(),
		"power":        b.power.info(),
		"lock":         b.lock.info(),
		"sigil":        b.sigil.info(),
		"brightness":   b.brightness.info(),
		"caffeine":     b.caffeine.info(),
	})
}

var startedAt = time.Now()

func intervalParam(p map[string]any, key string, def, min time.Duration) time.Duration {
	ms := params.IntOpt(p, key, int(def/time.Millisecond))
	d := time.Duration(ms) * time.Millisecond
	if d < min {
		log.Debugf("clamping %s=%s to %s", key, d, min)
		return min
	}
	return d
}
