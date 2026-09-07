package backend

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"os"
	"sync"
	"time"

	"github.com/AvengeMedia/dankgo/ipc"
	"github.com/AvengeMedia/dankgo/ipc/params"
	"github.com/AvengeMedia/dankgo/log"
)

const (
	mangoEnvVar        = "MANGO_INSTANCE_SIGNATURE"
	mangoDialTimeout   = 2 * time.Second
	mangoRetryInterval = 2 * time.Second
)

type mangoTag struct {
	Index       int    `json:"index"`
	IsActive    bool   `json:"is_active"`
	IsUrgent    bool   `json:"is_urgent"`
	Layout      string `json:"layout"`
	ClientCount int    `json:"client_count"`
}

type mangoMonitor struct {
	Monitor string     `json:"monitor"`
	Tags    []mangoTag `json:"tags"`
}

type mangoAllTags struct {
	AllTags []mangoMonitor `json:"all_tags"`
}

type mangoWatcher struct {
	bus *ipc.EventBus

	mu         sync.Mutex
	perMonitor map[string]map[string]any // monitor name -> last published payload
	digests    map[string]string         // monitor name -> digest of that payload
	connected  bool
}

func newMangoWatcher(bus *ipc.EventBus) *mangoWatcher {
	return &mangoWatcher{
		bus:        bus,
		perMonitor: map[string]map[string]any{},
		digests:    map[string]string{},
	}
}

func mangoSocketPath() string { return os.Getenv(mangoEnvVar) }

func (m *mangoWatcher) available() bool {
	path := mangoSocketPath()
	if path == "" {
		return false
	}
	_, err := os.Stat(path)
	return err == nil
}

func (m *mangoWatcher) start(ctx context.Context) {
	if !m.available() {
		log.Warnf("compositor socket unavailable (%s unset or missing); workspaces disabled", mangoEnvVar)
		return
	}
	go m.watchLoop(ctx)
}

func (m *mangoWatcher) watchLoop(ctx context.Context) {
	for {
		if err := m.watch(ctx); err != nil && ctx.Err() == nil {
			log.Warnf("compositor watch ended: %v; retrying in %s", err, mangoRetryInterval)
		}

		m.mu.Lock()
		m.connected = false
		m.mu.Unlock()

		select {
		case <-ctx.Done():
			return
		case <-time.After(mangoRetryInterval):
		}
	}
}

func (m *mangoWatcher) watch(ctx context.Context) error {
	conn, err := net.DialTimeout("unix", mangoSocketPath(), mangoDialTimeout)
	if err != nil {
		return err
	}
	defer conn.Close()

	go func() {
		<-ctx.Done()
		conn.Close()
	}()

	if _, err := fmt.Fprint(conn, "watch all-tags\n"); err != nil {
		return err
	}

	m.mu.Lock()
	m.connected = true
	m.mu.Unlock()
	log.Infof("watching compositor tags on %s", mangoSocketPath())

	scanner := bufio.NewScanner(conn)
	scanner.Buffer(make([]byte, 16*1024), 1024*1024)
	for scanner.Scan() {
		var payload mangoAllTags
		if err := json.Unmarshal(scanner.Bytes(), &payload); err != nil {
			log.Debugf("compositor: unparseable line: %v", err)
			continue
		}
		m.apply(payload)
	}
	if err := scanner.Err(); err != nil {
		return err
	}
	return errors.New("compositor closed the connection")
}

func (m *mangoWatcher) apply(payload mangoAllTags) {
	for _, mon := range payload.AllTags {
		event := monitorEvent(mon)

		digest, err := json.Marshal(event)
		if err != nil {
			continue
		}

		m.mu.Lock()
		unchanged := m.digests[mon.Monitor] == string(digest)
		if !unchanged {
			m.digests[mon.Monitor] = string(digest)
			m.perMonitor[mon.Monitor] = event
		}
		m.mu.Unlock()

		if unchanged {
			continue
		}
		m.bus.Publish(TopicWorkspaces, event)
	}
}

func monitorEvent(mon mangoMonitor) map[string]any {
	tags := make([]map[string]any, 0, len(mon.Tags))
	activeTag := 0
	activeClients := 0

	for _, tag := range mon.Tags {
		if tag.IsActive {
			activeTag = tag.Index
			activeClients += tag.ClientCount
		}
		tags = append(tags, map[string]any{
			"index":   tag.Index,
			"active":  tag.IsActive,
			"urgent":  tag.IsUrgent,
			"clients": tag.ClientCount,
		})
	}

	return map[string]any{
		"monitor":       mon.Monitor,
		"activeTag":     activeTag,
		"activeClients": activeClients,
		"tags":          tags,
	}
}

func (m *mangoWatcher) republish() {
	m.mu.Lock()
	events := make([]map[string]any, 0, len(m.perMonitor))
	for _, ev := range m.perMonitor {
		events = append(events, ev)
	}
	m.mu.Unlock()

	for _, ev := range events {
		m.bus.Publish(TopicWorkspaces, ev)
	}
}

func (m *mangoWatcher) handle(_ context.Context, w *ipc.ConnWriter, req ipc.Request, _ *ipc.Subscriber) {
	switch req.Method {
	case "workspaces.get":
		m.mu.Lock()
		monitors := make([]map[string]any, 0, len(m.perMonitor))
		for _, ev := range m.perMonitor {
			monitors = append(monitors, ev)
		}
		m.mu.Unlock()
		ipc.Respond(w, req.ID, map[string]any{"monitors": monitors})

	case "workspaces.dispatch":
		command, err := params.StringNonEmpty(req.Params, "command")
		if err != nil {
			ipc.RespondError(w, req.ID, err.Error())
			return
		}
		reply, err := m.dispatch(command)
		if err != nil {
			ipc.RespondError(w, req.ID, err.Error())
			return
		}
		ipc.Respond(w, req.ID, reply)

	default:
		ipc.RespondError(w, req.ID, "unknown method: "+req.Method)
	}
}

func (m *mangoWatcher) dispatch(command string) (map[string]any, error) {
	path := mangoSocketPath()
	if path == "" {
		return nil, errors.New("compositor socket unavailable")
	}

	conn, err := net.DialTimeout("unix", path, mangoDialTimeout)
	if err != nil {
		return nil, err
	}
	defer conn.Close()
	_ = conn.SetDeadline(time.Now().Add(mangoDialTimeout))

	if _, err := fmt.Fprintf(conn, "dispatch %s\n", command); err != nil {
		return nil, err
	}

	line, err := bufio.NewReader(conn).ReadBytes('\n')
	if err != nil {
		return nil, err
	}

	var reply map[string]any
	if err := json.Unmarshal(line, &reply); err != nil {
		return nil, fmt.Errorf("compositor reply: %w", err)
	}
	return reply, nil
}

func (m *mangoWatcher) info() map[string]any {
	m.mu.Lock()
	defer m.mu.Unlock()
	return map[string]any{
		"kind":      "mango",
		"socket":    mangoSocketPath(),
		"connected": m.connected,
		"monitors":  len(m.perMonitor),
	}
}
