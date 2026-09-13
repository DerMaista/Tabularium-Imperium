package backend

import (
	"context"
	"sync"
	"time"

	"github.com/AvengeMedia/dankgo/ipc"
)

const (
	timeLayout = "15:04"
	dateLayout = "Mon, 02 Jan"
)

type clockTicker struct {
	bus *ipc.EventBus

	mu   sync.Mutex
	last map[string]any
}

func newClockTicker(bus *ipc.EventBus) *clockTicker {
	return &clockTicker{bus: bus}
}

func (c *clockTicker) start(ctx context.Context) { go c.loop(ctx) }

func (c *clockTicker) loop(ctx context.Context) {
	c.publishNow()

	for {
		timer := time.NewTimer(untilNextMinute(time.Now()))
		select {
		case <-ctx.Done():
			timer.Stop()
			return
		case <-timer.C:
			c.publishNow()
		}
	}
}

func untilNextMinute(now time.Time) time.Duration {
	next := now.Truncate(time.Minute).Add(time.Minute)
	d := next.Sub(now)
	if d <= 0 {
		return time.Minute
	}
	return d
}

func (c *clockTicker) publishNow() {
	state := clockState(time.Now())

	c.mu.Lock()
	c.last = state
	c.mu.Unlock()

	if !c.bus.HasSubscriber(TopicClock) {
		return
	}
	c.bus.Publish(TopicClock, state)
}

func clockState(now time.Time) map[string]any {
	return map[string]any{
		"time":    now.Format(timeLayout),
		"date":    now.Format(dateLayout),
		"epochMs": now.UnixMilli(),
	}
}

func (c *clockTicker) handle(_ context.Context, w *ipc.ConnWriter, req ipc.Request, _ *ipc.Subscriber) {
	switch req.Method {
	case "clock.get":
		ipc.Respond(w, req.ID, clockState(time.Now()))
	default:
		ipc.RespondError(w, req.ID, "unknown method: "+req.Method)
	}
}
