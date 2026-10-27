package backend

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"
)

const drmClassPath = "/sys/class/drm"

// gpuSampler reads utilisation and VRAM for the primary GPU. amdgpu exposes
// both in sysfs, NVIDIA only through nvidia-smi, and everything else (i915,
// xe, …) is measured from the per-client engine counters in DRM fdinfo.
type gpuSampler struct {
	mu sync.Mutex

	probed bool
	card   string // e.g. /sys/class/drm/card1
	driver string
	pdev   string

	nvidiaSmi string

	prevTime    time.Time
	prevEngines map[string]map[string]uint64 // client id → counter → value
}

func newGPUSampler() *gpuSampler { return &gpuSampler{} }

func (g *gpuSampler) probe() {
	g.probed = true

	cards, _ := filepath.Glob(filepath.Join(drmClassPath, "card[0-9]*"))
	best := -1
	for _, card := range cards {
		if strings.Contains(filepath.Base(card), "-") {
			continue
		}
		link, err := os.Readlink(filepath.Join(card, "device", "driver"))
		if err != nil {
			continue
		}
		driver := filepath.Base(link)

		// Prefer a discrete GPU over an integrated one.
		rank := 0
		switch driver {
		case "nvidia":
			rank = 2
		case "amdgpu":
			if readUint(filepath.Join(card, "device", "mem_info_vram_total")) > 512<<20 {
				rank = 2
			} else {
				rank = 1
			}
		}
		if rank > best {
			best = rank
			g.card = card
			g.driver = driver
			if dev, err := filepath.EvalSymlinks(filepath.Join(card, "device")); err == nil {
				g.pdev = filepath.Base(dev)
			}
		}
	}

	if g.driver == "nvidia" {
		g.nvidiaSmi, _ = exec.LookPath("nvidia-smi")
	}
}

func (g *gpuSampler) read() (map[string]any, error) {
	g.mu.Lock()
	defer g.mu.Unlock()

	if !g.probed {
		g.probe()
	}

	switch {
	case g.card == "":
		return nil, fmt.Errorf("no GPU found")
	case g.driver == "amdgpu":
		return g.readAMD()
	case g.driver == "nvidia":
		return g.readNvidia()
	default:
		return g.readFdinfo()
	}
}

func (g *gpuSampler) readAMD() (map[string]any, error) {
	dev := filepath.Join(g.card, "device")
	data, err := os.ReadFile(filepath.Join(dev, "gpu_busy_percent"))
	if err != nil {
		return nil, err
	}
	busy, err := strconv.ParseFloat(strings.TrimSpace(string(data)), 64)
	if err != nil {
		return nil, err
	}

	out := map[string]any{"percent": busy}
	addVRAM(out,
		readUint(filepath.Join(dev, "mem_info_vram_used"))>>20,
		readUint(filepath.Join(dev, "mem_info_vram_total"))>>20)
	return out, nil
}

func (g *gpuSampler) readNvidia() (map[string]any, error) {
	if g.nvidiaSmi == "" {
		return nil, fmt.Errorf("nvidia-smi not found")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	raw, err := exec.CommandContext(ctx, g.nvidiaSmi,
		"--query-gpu=utilization.gpu,memory.used,memory.total",
		"--format=csv,noheader,nounits").Output()
	if err != nil {
		return nil, err
	}

	line, _, _ := strings.Cut(strings.TrimSpace(string(raw)), "\n")
	fields := strings.Split(line, ",")
	if len(fields) != 3 {
		return nil, fmt.Errorf("unexpected nvidia-smi output %q", line)
	}
	var vals [3]float64
	for i, f := range fields {
		if vals[i], err = strconv.ParseFloat(strings.TrimSpace(f), 64); err != nil {
			return nil, err
		}
	}

	out := map[string]any{"percent": vals[0]}
	addVRAM(out, uint64(vals[1]), uint64(vals[2]))
	return out, nil
}

// readFdinfo sums the drm-engine-* busy counters of every DRM client on our
// device and reports the busiest engine class over the last interval. The
// first call only primes the counters.
func (g *gpuSampler) readFdinfo() (map[string]any, error) {
	now := time.Now()
	cur := map[string]map[string]uint64{}
	capacity := map[string]uint64{}

	pids, _ := os.ReadDir("/proc")
	for _, p := range pids {
		if p.Name()[0] < '0' || p.Name()[0] > '9' {
			continue
		}
		fdDir := filepath.Join("/proc", p.Name(), "fd")
		fds, err := os.ReadDir(fdDir)
		if err != nil {
			continue
		}
		for _, fd := range fds {
			target, err := os.Readlink(filepath.Join(fdDir, fd.Name()))
			if err != nil || !strings.HasPrefix(target, "/dev/dri/") {
				continue
			}
			data, err := os.ReadFile(filepath.Join("/proc", p.Name(), "fdinfo", fd.Name()))
			if err != nil {
				continue
			}
			parseDRMFdinfo(string(data), g.pdev, cur, capacity)
		}
	}

	prev, prevTime := g.prevEngines, g.prevTime
	g.prevEngines, g.prevTime = cur, now

	if prev == nil {
		return map[string]any{}, nil
	}
	wall := now.Sub(prevTime).Nanoseconds()
	if wall <= 0 {
		return map[string]any{}, nil
	}

	// i915 and most drivers report busy ns per engine ("ns:<engine>"); xe
	// reports busy cycles against a GPU timestamp ("cycles:" / "total:").
	busy := map[string]uint64{}
	period := map[string]uint64{}
	for id, engines := range cur {
		old, ok := prev[id]
		if !ok {
			continue // new client: its lifetime total is not this interval's work
		}
		for key, v := range engines {
			if v <= old[key] {
				continue
			}
			d := v - old[key]
			if engine, ok := strings.CutPrefix(key, "total:"); ok {
				period[engine] = max(period[engine], d)
			} else {
				busy[key] += d
			}
		}
	}

	var percent float64
	for key, d := range busy {
		kind, engine, _ := strings.Cut(key, ":")
		denom := uint64(wall)
		if kind == "cycles" {
			if denom = period[engine]; denom == 0 {
				continue
			}
		}
		c := max(capacity[engine], 1)
		percent = max(percent, float64(d)/float64(denom*c)*100)
	}
	return map[string]any{"percent": min(percent, 100)}, nil
}

func parseDRMFdinfo(data, pdev string, clients map[string]map[string]uint64, capacity map[string]uint64) {
	var id, dev string
	engines := map[string]uint64{}

	for line := range strings.SplitSeq(data, "\n") {
		key, val, ok := strings.Cut(line, ":")
		if !ok {
			continue
		}
		val = strings.TrimSpace(val)
		switch {
		case key == "drm-client-id":
			id = val
		case key == "drm-pdev":
			dev = val
		case strings.HasPrefix(key, "drm-engine-capacity-"):
			if n, err := strconv.ParseUint(val, 10, 64); err == nil {
				capacity[strings.TrimPrefix(key, "drm-engine-capacity-")] = n
			}
		case strings.HasPrefix(key, "drm-engine-"):
			num, _, _ := strings.Cut(val, " ")
			if n, err := strconv.ParseUint(num, 10, 64); err == nil {
				engines["ns:"+strings.TrimPrefix(key, "drm-engine-")] = n
			}
		case strings.HasPrefix(key, "drm-total-cycles-"):
			if n, err := strconv.ParseUint(val, 10, 64); err == nil {
				engines["total:"+strings.TrimPrefix(key, "drm-total-cycles-")] = n
			}
		case strings.HasPrefix(key, "drm-cycles-"):
			if n, err := strconv.ParseUint(val, 10, 64); err == nil {
				engines["cycles:"+strings.TrimPrefix(key, "drm-cycles-")] = n
			}
		}
	}

	// Several fds (and dup'd ones in other processes) can share one client.
	if id == "" || (pdev != "" && dev != pdev) {
		return
	}
	clients[id] = engines
}

func addVRAM(out map[string]any, usedMB, totalMB uint64) {
	if totalMB == 0 {
		return
	}
	out["vramUsedMB"] = usedMB
	out["vramTotalMB"] = totalMB
	out["vramPercent"] = float64(usedMB) / float64(totalMB) * 100
}

func readUint(path string) uint64 {
	data, err := os.ReadFile(path)
	if err != nil {
		return 0
	}
	v, _ := strconv.ParseUint(strings.TrimSpace(string(data)), 10, 64)
	return v
}
