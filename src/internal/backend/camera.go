package backend

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
	"unsafe"

	"github.com/AvengeMedia/dankgo/ipc"
	"github.com/AvengeMedia/dankgo/log"
	"golang.org/x/sys/unix"
)

const (
	cameraDevDir   = "/dev"
	cameraPrefix   = "video"
	cameraDebounce = 250 * time.Millisecond
)

// PipeWire and WirePlumber open cameras on behalf of their clients; the UI
// sees those clients through PipeWire links, so here they would only hide
// the real application behind the daemon's name.
var cameraIgnoredComms = map[string]bool{
	"pipewire":    true,
	"wireplumber": true,
	"v4l_id":      true,
}

// cameraWatcher reports which processes hold a /dev/video* node open. It
// never polls: inotify raises IN_OPEN and IN_CLOSE on the device nodes
// themselves, and only then are the open file descriptors in /proc scanned.
type cameraWatcher struct {
	bus *ipc.EventBus

	mu      sync.Mutex
	started bool
	apps    []string
	timer   *time.Timer
	fd      int
	watched map[string]bool
}

func newCameraWatcher(bus *ipc.EventBus) *cameraWatcher {
	return &cameraWatcher{bus: bus, fd: -1, watched: map[string]bool{}}
}

func (c *cameraWatcher) available() bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.started
}

func (c *cameraWatcher) start(ctx context.Context) {
	fd, err := unix.InotifyInit1(unix.IN_CLOEXEC | unix.IN_NONBLOCK)
	if err != nil {
		log.Warnf("camera: inotify unavailable: %v; camera indicator disabled", err)
		return
	}
	if _, err := unix.InotifyAddWatch(fd, cameraDevDir, unix.IN_CREATE|unix.IN_DELETE); err != nil {
		_ = unix.Close(fd)
		log.Warnf("camera: cannot watch %s: %v; camera indicator disabled", cameraDevDir, err)
		return
	}
	file := os.NewFile(uintptr(fd), "inotify")

	c.mu.Lock()
	c.fd = fd
	c.started = true
	c.mu.Unlock()

	c.watchDevices()
	c.rescan()

	go func() {
		<-ctx.Done()
		c.mu.Lock()
		if c.timer != nil {
			c.timer.Stop()
		}
		c.mu.Unlock()
		_ = file.Close()
	}()

	go c.readLoop(file)
}

func (c *cameraWatcher) readLoop(file *os.File) {
	buf := make([]byte, 64*1024)
	for {
		n, err := file.Read(buf)
		if err != nil {
			if !errors.Is(err, os.ErrClosed) {
				log.Warnf("camera: watch stopped: %v", err)
			}
			return
		}

		hotplug := false
		for off := 0; off+unix.SizeofInotifyEvent <= n; {
			ev := (*unix.InotifyEvent)(unsafe.Pointer(&buf[off]))
			nameLen := int(ev.Len)
			if ev.Mask&(unix.IN_CREATE|unix.IN_DELETE) != 0 && nameLen > 0 {
				name := strings.TrimRight(string(buf[off+unix.SizeofInotifyEvent:off+unix.SizeofInotifyEvent+nameLen]), "\x00")
				if strings.HasPrefix(name, cameraPrefix) {
					hotplug = true
				}
			}
			off += unix.SizeofInotifyEvent + nameLen
		}

		if hotplug {
			c.watchDevices()
		}
		c.scheduleRescan()
	}
}

// watchDevices adds an open/close watch to every camera node not yet
// watched. Watches on removed nodes are dropped by the kernel.
func (c *cameraWatcher) watchDevices() {
	nodes, _ := filepath.Glob(filepath.Join(cameraDevDir, cameraPrefix+"*"))

	c.mu.Lock()
	defer c.mu.Unlock()

	present := map[string]bool{}
	for _, node := range nodes {
		present[node] = true
		if c.watched[node] {
			continue
		}
		mask := uint32(unix.IN_OPEN | unix.IN_CLOSE_WRITE | unix.IN_CLOSE_NOWRITE)
		if _, err := unix.InotifyAddWatch(c.fd, node, mask); err != nil {
			log.Debugf("camera: cannot watch %s: %v", node, err)
			continue
		}
		c.watched[node] = true
	}
	for node := range c.watched {
		if !present[node] {
			delete(c.watched, node)
		}
	}
}

// Opening a camera produces a burst of open/close events (format probing,
// udev's v4l_id), so the /proc scan waits for the burst to settle.
func (c *cameraWatcher) scheduleRescan() {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.timer != nil {
		c.timer.Reset(cameraDebounce)
		return
	}
	c.timer = time.AfterFunc(cameraDebounce, c.rescan)
}

func (c *cameraWatcher) rescan() {
	apps := cameraUsers()

	c.mu.Lock()
	changed := strings.Join(apps, "\x00") != strings.Join(c.apps, "\x00")
	c.apps = apps
	c.mu.Unlock()

	if changed {
		log.Debugf("camera: in use by %v", apps)
		c.publish()
	}
}

// cameraUsers lists the command names of processes holding a camera node
// open. Only processes of the same user are visible, which covers every
// application in the session.
func cameraUsers() []string {
	procs, err := os.ReadDir("/proc")
	if err != nil {
		return nil
	}

	seen := map[string]bool{}
	self := strconv.Itoa(os.Getpid())
	for _, p := range procs {
		pid := p.Name()
		if pid[0] < '0' || pid[0] > '9' || pid == self {
			continue
		}
		fdDir := filepath.Join("/proc", pid, "fd")
		fds, err := os.ReadDir(fdDir)
		if err != nil {
			continue
		}
		for _, fd := range fds {
			target, err := os.Readlink(filepath.Join(fdDir, fd.Name()))
			if err != nil || !strings.HasPrefix(target, cameraDevDir+"/"+cameraPrefix) {
				continue
			}
			comm, err := os.ReadFile(filepath.Join("/proc", pid, "comm"))
			if err != nil {
				break
			}
			name := strings.TrimSpace(string(comm))
			if !cameraIgnoredComms[name] {
				seen[name] = true
			}
			break
		}
	}

	apps := make([]string, 0, len(seen))
	for name := range seen {
		apps = append(apps, name)
	}
	sort.Strings(apps)
	return apps
}

func (c *cameraWatcher) event() map[string]any {
	c.mu.Lock()
	defer c.mu.Unlock()
	apps := append([]string{}, c.apps...)
	return map[string]any{"active": len(apps) > 0, "apps": apps}
}

func (c *cameraWatcher) publish() { c.bus.Publish(TopicCamera, c.event()) }

func (c *cameraWatcher) republish() {
	if c.available() {
		c.publish()
	}
}

func (c *cameraWatcher) handle(_ context.Context, w *ipc.ConnWriter, req ipc.Request, _ *ipc.Subscriber) {
	switch req.Method {
	case "camera.get":
		ipc.Respond(w, req.ID, c.event())
	default:
		ipc.RespondError(w, req.ID, "unknown method: "+req.Method)
	}
}

func (c *cameraWatcher) info() map[string]any {
	ev := c.event()
	c.mu.Lock()
	ev["devices"] = len(c.watched)
	c.mu.Unlock()
	return ev
}
