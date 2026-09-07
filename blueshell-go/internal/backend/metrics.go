package backend

import (
	"context"
	"fmt"
	"os"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/AvengeMedia/dankgo/ipc"
	"github.com/AvengeMedia/dankgo/ipc/params"
	"golang.org/x/sys/unix"
)

const (
	defaultInterval = 3 * time.Second
	minInterval     = 250 * time.Millisecond
	diskPath        = "/"
)

type metricsSampler struct {
	bus *ipc.EventBus

	mu       sync.Mutex
	modules  map[string]bool
	interval time.Duration
	cursor   string
	last     map[string]any

	reconfig chan struct{}
	samples  atomic.Int64
}

func newMetricsSampler(bus *ipc.EventBus) *metricsSampler {
	return &metricsSampler{
		bus:      bus,
		modules:  map[string]bool{"cpu": true, "memory": true},
		interval: defaultInterval,
		reconfig: make(chan struct{}, 1),
	}
}

func (m *metricsSampler) start(ctx context.Context) { go m.loop(ctx) }

func (m *metricsSampler) loop(ctx context.Context) {
	timer := time.NewTimer(m.snapshotConfig().interval)
	defer timer.Stop()

	for {
		select {
		case <-ctx.Done():
			return

		case <-m.reconfig:
			if !timer.Stop() {
				select {
				case <-timer.C:
				default:
				}
			}
			m.publishNow()
			timer.Reset(m.snapshotConfig().interval)

		case <-timer.C:
			m.publishNow()
			timer.Reset(m.snapshotConfig().interval)
		}
	}
}

type metricsConfig struct {
	modules  []string
	interval time.Duration
}

func (m *metricsSampler) snapshotConfig() metricsConfig {
	m.mu.Lock()
	defer m.mu.Unlock()
	mods := make([]string, 0, len(m.modules))
	for name := range m.modules {
		mods = append(mods, name)
	}
	return metricsConfig{modules: mods, interval: m.interval}
}

func (m *metricsSampler) publishNow() {
	if !m.bus.HasSubscriber(TopicMetrics) {
		return
	}

	cfg := m.snapshotConfig()

	m.mu.Lock()
	cursor := m.cursor
	m.mu.Unlock()

	data, next := m.collect(cfg.modules, cursor)

	m.mu.Lock()
	m.cursor = next
	m.last = data
	m.mu.Unlock()

	m.bus.Publish(TopicMetrics, data)
}

func (m *metricsSampler) handle(_ context.Context, w *ipc.ConnWriter, req ipc.Request, _ *ipc.Subscriber) {
	switch req.Method {
	case "metrics.get":
		mods := params.StringSlice(req.Params, "modules")
		if len(mods) == 0 {
			mods = m.snapshotConfig().modules
		}
		cursor := params.StringOpt(req.Params, "cursor", "")
		data, _ := m.collect(mods, cursor)
		ipc.Respond(w, req.ID, data)

	case "metrics.configure":
		mods := params.StringSlice(req.Params, "modules")
		interval := intervalParam(req.Params, "intervalMs", defaultInterval, minInterval)

		m.mu.Lock()
		if len(mods) > 0 {
			set := make(map[string]bool, len(mods))
			for _, name := range mods {
				set[name] = true
			}
			if !set["cpu"] {
				m.cursor = ""
			}
			m.modules = set
		}
		m.interval = interval
		m.mu.Unlock()

		select {
		case m.reconfig <- struct{}{}:
		default:
		}

		ipc.Respond(w, req.ID, map[string]any{"modules": mods, "intervalMs": interval.Milliseconds()})

	default:
		ipc.RespondError(w, req.ID, "unknown method: "+req.Method)
	}
}

func (m *metricsSampler) info() map[string]any {
	cfg := m.snapshotConfig()
	return map[string]any{
		"modules":    cfg.modules,
		"intervalMs": cfg.interval.Milliseconds(),
		"samples":    m.samples.Load(),
		"subscribed": m.bus.HasSubscriber(TopicMetrics),
	}
}

func (m *metricsSampler) collect(modules []string, cursor string) (map[string]any, string) {
	m.samples.Add(1)

	want := make(map[string]bool, len(modules))
	for _, name := range modules {
		want[name] = true
	}

	out := map[string]any{}
	next := cursor

	if want["cpu"] {
		if cur, err := readCPU(); err == nil {
			next = cur.encode()
			if prev, ok := decodeCPUCursor(cursor); ok && cur.total > prev.total {
				dTotal := cur.total - prev.total
				dIdle := cur.idle - prev.idle
				out["cpu"] = map[string]any{"percent": float64(dTotal-dIdle) / float64(dTotal) * 100}
			}
		}
	}

	if want["memory"] {
		if mem, err := readMemory(); err == nil {
			out["memory"] = mem
		}
	}

	if want["disk"] {
		if disk, err := readDisk(diskPath); err == nil {
			out["disk"] = disk
		}
	}

	if want["uptime"] {
		if up, err := readUptime(); err == nil {
			out["uptime"] = up
		}
	}

	return out, next
}

type cpuSample struct{ total, idle uint64 }

func (c cpuSample) encode() string {
	return strconv.FormatUint(c.total, 10) + "," + strconv.FormatUint(c.idle, 10)
}

func decodeCPUCursor(s string) (cpuSample, bool) {
	total, idle, ok := strings.Cut(s, ",")
	if !ok {
		return cpuSample{}, false
	}
	t, err1 := strconv.ParseUint(total, 10, 64)
	i, err2 := strconv.ParseUint(idle, 10, 64)
	if err1 != nil || err2 != nil {
		return cpuSample{}, false
	}
	return cpuSample{total: t, idle: i}, true
}

func readCPU() (cpuSample, error) {
	data, err := os.ReadFile("/proc/stat")
	if err != nil {
		return cpuSample{}, err
	}
	line, _, _ := strings.Cut(string(data), "\n")
	fields := strings.Fields(line)
	if len(fields) < 5 || fields[0] != "cpu" {
		return cpuSample{}, fmt.Errorf("unexpected /proc/stat format")
	}

	var s cpuSample
	for i, f := range fields[1:] {
		v, err := strconv.ParseUint(f, 10, 64)
		if err != nil {
			continue
		}
		s.total += v
		if i == 3 || i == 4 {
			s.idle += v
		}
	}
	return s, nil
}

func readMemory() (map[string]any, error) {
	data, err := os.ReadFile("/proc/meminfo")
	if err != nil {
		return nil, err
	}

	vals := map[string]uint64{}
	for line := range strings.SplitSeq(string(data), "\n") {
		key, rest, ok := strings.Cut(line, ":")
		if !ok {
			continue
		}
		fields := strings.Fields(rest)
		if len(fields) == 0 {
			continue
		}
		if v, err := strconv.ParseUint(fields[0], 10, 64); err == nil {
			vals[key] = v
		}
	}

	total := vals["MemTotal"]
	if total == 0 {
		return nil, fmt.Errorf("MemTotal missing from /proc/meminfo")
	}
	used := total - vals["MemAvailable"]

	return map[string]any{
		"totalMB": total / 1024,
		"usedMB":  used / 1024,
		"percent": float64(used) / float64(total) * 100,
	}, nil
}

func readDisk(path string) (map[string]any, error) {
	var st unix.Statfs_t
	if err := unix.Statfs(path, &st); err != nil {
		return nil, err
	}

	total := st.Blocks * uint64(st.Bsize)
	free := st.Bavail * uint64(st.Bsize)
	used := total - free
	if total == 0 {
		return nil, fmt.Errorf("statfs %s reported zero blocks", path)
	}

	percent := float64(used) / float64(total) * 100
	return map[string]any{
		"path":      path,
		"totalGB":   float64(total) / (1 << 30),
		"usedGB":    float64(used) / (1 << 30),
		"percent":   percent,
		"formatted": fmt.Sprintf("%.0f%%", percent),
	}, nil
}

func readUptime() (map[string]any, error) {
	data, err := os.ReadFile("/proc/uptime")
	if err != nil {
		return nil, err
	}
	field, _, _ := strings.Cut(strings.TrimSpace(string(data)), " ")
	secs, err := strconv.ParseFloat(field, 64)
	if err != nil {
		return nil, err
	}

	d := time.Duration(secs) * time.Second
	return map[string]any{
		"seconds":   int64(secs),
		"formatted": formatUptime(d),
	}, nil
}

func formatUptime(d time.Duration) string {
	days := int(d.Hours()) / 24
	hours := int(d.Hours()) % 24
	mins := int(d.Minutes()) % 60

	switch {
	case days > 0:
		return fmt.Sprintf("%dd %dh", days, hours)
	case hours > 0:
		return fmt.Sprintf("%dh %02dm", hours, mins)
	default:
		return fmt.Sprintf("%dm", mins)
	}
}
