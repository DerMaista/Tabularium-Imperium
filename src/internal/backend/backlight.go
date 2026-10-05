package backend

import (
	"context"
	"errors"
	"fmt"
	"math"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"

	"github.com/AvengeMedia/dankgo/log"
	"github.com/godbus/dbus/v5"
	"golang.org/x/sys/unix"
)

// backlightRoot is a var so a fake sysfs tree can stand in for it.
var backlightRoot = "/sys/class/backlight"

// Logind resolves "auto" to the caller's session, or — for a systemd user
// service, which sits in no session — to the user's graphical one.
const loginAutoSession = dbus.ObjectPath("/org/freedesktop/login1/session/auto")

// The same order gnome-settings-daemon and systemd-backlight use: firmware
// interfaces know about the panel, raw ones only about the PWM register.
var backlightTypeRank = map[string]int{"firmware": 0, "platform": 1, "raw": 2}

type backlight struct {
	name string
	dir  string
	max  int
}

func findBacklight() *backlight {
	entries, err := os.ReadDir(backlightRoot)
	if err != nil {
		return nil
	}

	var found []*backlight
	rank := map[string]int{}
	for _, entry := range entries {
		dir := filepath.Join(backlightRoot, entry.Name())
		max, err := readInt(filepath.Join(dir, "max_brightness"))
		if err != nil || max <= 0 {
			continue
		}
		kind, _ := os.ReadFile(filepath.Join(dir, "type"))
		r, ok := backlightTypeRank[strings.TrimSpace(string(kind))]
		if !ok {
			r = len(backlightTypeRank)
		}
		d := &backlight{name: entry.Name(), dir: dir, max: max}
		rank[d.name] = r
		found = append(found, d)
	}
	if len(found) == 0 {
		return nil
	}

	sort.Slice(found, func(i, j int) bool {
		if rank[found[i].name] != rank[found[j].name] {
			return rank[found[i].name] < rank[found[j].name]
		}
		return found[i].name < found[j].name
	})
	return found[0]
}

// minLevel keeps the panel lit: 0 switches some backlights off entirely.
func (d *backlight) minLevel() int {
	return max(1, int(math.Round(float64(d.max)*0.01)))
}

func (d *backlight) clampLevel(level int) int {
	return min(max(level, d.minLevel()), d.max)
}

func (d *backlight) level(value float64) int {
	return d.clampLevel(int(math.Round(value * float64(d.max))))
}

func (d *backlight) fraction(level int) float64 {
	return float64(level) / float64(d.max)
}

// read uses brightness rather than actual_brightness: some drivers (amdgpu)
// report the latter on a different scale, and brightness is what was asked for.
func (d *backlight) read() (int, error) {
	return readInt(filepath.Join(d.dir, "brightness"))
}

// write goes straight to sysfs when a udev rule has made that possible, and
// otherwise asks logind, which lets the session's own user do it unprivileged.
func (d *backlight) write(sys *dbus.Conn, level int) error {
	path := filepath.Join(d.dir, "brightness")
	if unix.Access(path, unix.W_OK) == nil {
		return os.WriteFile(path, []byte(strconv.Itoa(level)), 0)
	}
	if sys == nil {
		return fmt.Errorf("%s is not writable and the system bus is unavailable", path)
	}
	return sys.Object(loginService, loginAutoSession).
		Call(loginSession+".SetBrightness", 0, "backlight", d.name, uint32(level)).Err
}

// watch reports every change, whoever made it. Writes to brightness raise
// IN_MODIFY through the VFS; the kernel's own changes (firmware hotkeys)
// arrive as a sysfs_notify on actual_brightness.
func (d *backlight) watch(ctx context.Context, onChange func()) error {
	fd, err := unix.InotifyInit1(unix.IN_CLOEXEC | unix.IN_NONBLOCK)
	if err != nil {
		return err
	}
	file := os.NewFile(uintptr(fd), "inotify")

	watched := 0
	for _, name := range []string{"brightness", "actual_brightness"} {
		if _, err := unix.InotifyAddWatch(fd, filepath.Join(d.dir, name), unix.IN_MODIFY); err == nil {
			watched++
		}
	}
	if watched == 0 {
		_ = file.Close()
		return fmt.Errorf("cannot watch %s", d.dir)
	}

	go func() {
		<-ctx.Done()
		_ = file.Close()
	}()

	go func() {
		buf := make([]byte, 4096)
		for {
			if _, err := file.Read(buf); err != nil {
				if !errors.Is(err, os.ErrClosed) {
					log.Warnf("brightness: watching %s stopped: %v", d.name, err)
				}
				return
			}
			onChange()
		}
	}()
	return nil
}

func readInt(path string) (int, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return 0, err
	}
	return strconv.Atoi(strings.TrimSpace(string(raw)))
}
