package backend

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"os"
	"sort"
	"strings"
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
	keymode    string

	// onMonitors hears the set of monitor names whenever it changes.
	onMonitors func([]string)
	monitors   string
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
	go m.watchLoop(ctx, "all-tags", m.applyTagsLine, m.setConnected)
	go m.watchLoop(ctx, "keymode", m.applyKeymodeLine, nil)
}

func (m *mangoWatcher) setConnected(up bool) {
	m.mu.Lock()
	m.connected = up
	m.mu.Unlock()
}

// watchLoop holds one `watch <stream>` connection open, hands every line to
// apply, and redials whenever the compositor drops it.
func (m *mangoWatcher) watchLoop(ctx context.Context, stream string, apply func([]byte), onLink func(bool)) {
	for {
		if err := m.watch(ctx, stream, apply, onLink); err != nil && ctx.Err() == nil {
			log.Warnf("compositor %s watch ended: %v; retrying in %s", stream, err, mangoRetryInterval)
		}

		if onLink != nil {
			onLink(false)
		}

		select {
		case <-ctx.Done():
			return
		case <-time.After(mangoRetryInterval):
		}
	}
}

func (m *mangoWatcher) watch(ctx context.Context, stream string, apply func([]byte), onLink func(bool)) error {
	conn, err := net.DialTimeout("unix", mangoSocketPath(), mangoDialTimeout)
	if err != nil {
		return err
	}
	defer conn.Close()

	go func() {
		<-ctx.Done()
		conn.Close()
	}()

	if _, err := fmt.Fprintf(conn, "watch %s\n", stream); err != nil {
		return err
	}

	if onLink != nil {
		onLink(true)
	}
	log.Infof("watching compositor %s on %s", stream, mangoSocketPath())

	scanner := bufio.NewScanner(conn)
	scanner.Buffer(make([]byte, 16*1024), 1024*1024)
	for scanner.Scan() {
		apply(scanner.Bytes())
	}
	if err := scanner.Err(); err != nil {
		return err
	}
	return errors.New("compositor closed the connection")
}

func (m *mangoWatcher) applyTagsLine(line []byte) {
	var payload mangoAllTags
	if err := json.Unmarshal(line, &payload); err != nil {
		log.Debugf("compositor: unparseable tags line: %v", err)
		return
	}
	m.apply(payload)
}

func (m *mangoWatcher) applyKeymodeLine(line []byte) {
	var payload struct {
		Keymode string `json:"keymode"`
	}
	if err := json.Unmarshal(line, &payload); err != nil {
		log.Debugf("compositor: unparseable keymode line: %v", err)
		return
	}

	m.mu.Lock()
	changed := payload.Keymode != m.keymode
	m.keymode = payload.Keymode
	m.mu.Unlock()

	if changed {
		m.publishKeymode()
	}
}

func (m *mangoWatcher) keymodeEvent() map[string]any {
	m.mu.Lock()
	defer m.mu.Unlock()
	return map[string]any{"keymode": m.keymode}
}

func (m *mangoWatcher) publishKeymode() { m.bus.Publish(TopicKeymode, m.keymodeEvent()) }

func (m *mangoWatcher) republishKeymode() {
	m.mu.Lock()
	known := m.keymode != ""
	m.mu.Unlock()

	if known {
		m.publishKeymode()
	}
}

func (m *mangoWatcher) apply(payload mangoAllTags) {
	m.noteMonitors(payload)

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
	layout := ""

	for _, tag := range mon.Tags {
		if tag.IsActive {
			activeTag = tag.Index
			activeClients += tag.ClientCount
			if layout == "" {
				layout = tag.Layout
			}
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
		"layout":        layout,
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

	case "workspaces.keymode":
		ipc.Respond(w, req.ID, m.keymodeEvent())

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

	case "workspaces.clients":
		clients, err := m.clients()
		if err != nil {
			ipc.RespondError(w, req.ID, err.Error())
			return
		}
		ipc.Respond(w, req.ID, map[string]any{"clients": clients})

	default:
		ipc.RespondError(w, req.ID, "unknown method: "+req.Method)
	}
}

func (m *mangoWatcher) converse(request string) ([]byte, error) {
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

	if _, err := fmt.Fprintf(conn, "%s\n", request); err != nil {
		return nil, err
	}

	return bufio.NewReader(conn).ReadBytes('\n')
}

func (m *mangoWatcher) dispatch(command string) (map[string]any, error) {
	line, err := m.converse("dispatch " + command)
	if err != nil {
		return nil, err
	}

	var reply map[string]any
	if err := json.Unmarshal(line, &reply); err != nil {
		return nil, fmt.Errorf("compositor reply: %w", err)
	}
	return reply, nil
}

type mangoClient struct {
	X           int    `json:"x"`
	Y           int    `json:"y"`
	Width       int    `json:"width"`
	Height      int    `json:"height"`
	Monitor     string `json:"monitor"`
	IsVisible   bool   `json:"is_visible"`
	IsMinimized bool   `json:"is_minimized"`
}

func (m *mangoWatcher) clients() ([]map[string]any, error) {
	line, err := m.converse("get all-clients")
	if err != nil {
		return nil, err
	}

	var reply struct {
		Clients []mangoClient `json:"clients"`
	}
	if err := json.Unmarshal(line, &reply); err != nil {
		return nil, fmt.Errorf("compositor reply: %w", err)
	}

	out := make([]map[string]any, 0, len(reply.Clients))
	for _, c := range reply.Clients {
		if !c.IsVisible || c.IsMinimized {
			continue
		}
		out = append(out, map[string]any{
			"x":       c.X,
			"y":       c.Y,
			"width":   c.Width,
			"height":  c.Height,
			"monitor": c.Monitor,
		})
	}
	return out, nil
}

func (m *mangoWatcher) info() map[string]any {
	m.mu.Lock()
	defer m.mu.Unlock()
	return map[string]any{
		"kind":      "mango",
		"socket":    mangoSocketPath(),
		"connected": m.connected,
		"monitors":  len(m.perMonitor),
		"keymode":   m.keymode,
	}
}

func (m *mangoWatcher) noteMonitors(payload mangoAllTags) {
	names := make([]string, 0, len(payload.AllTags))
	for _, mon := range payload.AllTags {
		names = append(names, mon.Monitor)
	}
	sort.Strings(names)
	key := strings.Join(names, "\x00")

	m.mu.Lock()
	changed := key != m.monitors
	m.monitors = key
	m.mu.Unlock()

	if changed && m.onMonitors != nil {
		m.onMonitors(names)
	}
}
