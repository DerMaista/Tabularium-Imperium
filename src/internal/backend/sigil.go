package backend

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"

	"github.com/AvengeMedia/dankgo/ipc"
	"github.com/AvengeMedia/dankgo/ipc/params"
	"github.com/AvengeMedia/dankgo/log"
	"github.com/AvengeMedia/dankgo/paths"
)

const defaultSigil = "NixOS"

type sigilManager struct {
	mu      sync.Mutex
	bus     *ipc.EventBus
	current string
}

func newSigilManager(bus *ipc.EventBus) *sigilManager {
	return &sigilManager{bus: bus}
}

func (s *sigilManager) start(context.Context) {
	name := readCurrentSigil()
	if name == "" {
		name = defaultSigil
	}

	s.mu.Lock()
	s.current = name
	s.mu.Unlock()
}

type sigilSettings struct {
	Dir string `json:"dir"`
}

func defaultSigilSettings() sigilSettings {
	return sigilSettings{Dir: filepath.Join(shellConfigDir(), "svgs")}
}

func (s *sigilManager) settings() sigilSettings {
	settings := defaultSigilSettings()

	path := filepath.Join(shellConfigDir(), "config.json")
	data, err := os.ReadFile(path)
	if err != nil {
		return settings
	}

	var file struct {
		Sigil sigilSettings `json:"sigil"`
	}
	if err := json.Unmarshal(data, &file); err != nil {
		log.Debugf("sigil: parsing %s: %v", path, err)
		return settings
	}
	return settings.merge(file.Sigil)
}

func (s sigilSettings) merge(other sigilSettings) sigilSettings {
	if other.Dir != "" {
		s.Dir = other.Dir
	}
	return s
}

func (s *sigilManager) userSigilDir() string { return expandPath(s.settings().Dir) }

func expandPath(path string) string {
	if path == "" {
		return ""
	}

	path = os.ExpandEnv(path)

	if path == "~" || strings.HasPrefix(path, "~/") {
		if home, err := os.UserHomeDir(); err == nil {
			path = filepath.Join(home, strings.TrimPrefix(path, "~"))
		}
	}

	if !filepath.IsAbs(path) {
		return filepath.Join(shellConfigDir(), path)
	}
	return filepath.Clean(path)
}

func builtinSigilDir() string {
	data, err := os.ReadFile(filepath.Join(paths.New("blueshell").SocketDir(), "blueshell.path"))
	if err != nil {
		log.Debugf("sigil: no running UI to take built-ins from: %v", err)
		return ""
	}

	shell := strings.TrimSpace(string(data))
	if shell == "" {
		return ""
	}
	return filepath.Join(shell, "svgs")
}

type sigilEntry struct {
	Name    string
	Path    string
	Builtin bool
}

func (s *sigilManager) list() []sigilEntry {
	found := map[string]sigilEntry{}

	for _, source := range []struct {
		dir     string
		builtin bool
	}{
		{builtinSigilDir(), true},
		{s.userSigilDir(), false},
	} {
		if source.dir == "" {
			continue
		}
		entries, err := os.ReadDir(source.dir)
		if err != nil {
			if !os.IsNotExist(err) {
				log.Debugf("sigil: reading %s: %v", source.dir, err)
			}
			continue
		}

		for _, entry := range entries {
			if entry.IsDir() || !strings.HasSuffix(strings.ToLower(entry.Name()), ".svg") {
				continue
			}
			name := strings.TrimSuffix(entry.Name(), filepath.Ext(entry.Name()))
			found[name] = sigilEntry{
				Name:    name,
				Path:    filepath.Join(source.dir, entry.Name()),
				Builtin: source.builtin,
			}
		}
	}

	out := make([]sigilEntry, 0, len(found))
	for _, entry := range found {
		out = append(out, entry)
	}
	sort.Slice(out, func(i, j int) bool {
		return strings.ToLower(out[i].Name) < strings.ToLower(out[j].Name)
	})
	return out
}

func (s *sigilManager) listPayload() []map[string]any {
	entries := s.list()
	out := make([]map[string]any, 0, len(entries))
	for _, entry := range entries {
		out = append(out, map[string]any{
			"name":    entry.Name,
			"path":    entry.Path,
			"builtin": entry.Builtin,
		})
	}
	return out
}

func (s *sigilManager) currentName() string {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.current
}

func (s *sigilManager) resolve() (string, string) {
	entries := s.list()
	if len(entries) == 0 {
		return s.currentName(), ""
	}

	for _, want := range []string{s.currentName(), defaultSigil} {
		for _, entry := range entries {
			if entry.Name == want {
				return entry.Name, entry.Path
			}
		}
	}
	return entries[0].Name, entries[0].Path
}

func (s *sigilManager) apply(name string) error {
	for _, entry := range s.list() {
		if entry.Name != name {
			continue
		}

		s.mu.Lock()
		s.current = name
		s.mu.Unlock()

		writeCurrentSigil(name)
		log.Infof("sigil: %s", name)
		s.publish()
		return nil
	}
	return fmt.Errorf("no sigil named %q — put %s.svg in %s", name, name, s.userSigilDir())
}

func (s *sigilManager) snapshot() map[string]any {
	name, path := s.resolve()
	return map[string]any{
		"current": name,
		"path":    path,
	}
}

func (s *sigilManager) publish() { s.bus.Publish(TopicSigil, s.snapshot()) }

func (s *sigilManager) republish() { s.publish() }

func (s *sigilManager) available() bool { return true }

func (s *sigilManager) info() map[string]any {
	info := s.snapshot()
	info["count"] = len(s.list())
	info["userDir"] = s.userSigilDir()
	return info
}

func currentSigilStatePath() string {
	dir, err := paths.New("blueshell").StateDir()
	if err != nil {
		return ""
	}
	return filepath.Join(dir, "current-sigil")
}

func readCurrentSigil() string {
	path := currentSigilStatePath()
	if path == "" {
		return ""
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(data))
}

func writeCurrentSigil(name string) {
	path := currentSigilStatePath()
	if path == "" {
		return
	}
	if err := os.WriteFile(path, []byte(name+"\n"), 0o644); err != nil {
		log.Debugf("sigil: recording current sigil: %v", err)
	}
}

func (s *sigilManager) handle(_ context.Context, w *ipc.ConnWriter, req ipc.Request, _ *ipc.Subscriber) {
	switch req.Method {
	case "sigil.list":
		name, path := s.resolve()
		ipc.Respond(w, req.ID, map[string]any{
			"sigils":  s.listPayload(),
			"current": name,
			"path":    path,
			"userDir": s.userSigilDir(),
		})

	case "sigil.apply":
		name, err := params.StringNonEmpty(req.Params, "name")
		if err != nil {
			ipc.RespondError(w, req.ID, err.Error())
			return
		}
		if err := s.apply(name); err != nil {
			ipc.RespondError(w, req.ID, err.Error())
			return
		}
		ipc.Respond(w, req.ID, s.snapshot())

	case "sigil.current":
		ipc.Respond(w, req.ID, s.snapshot())

	default:
		ipc.RespondError(w, req.ID, "unknown method: "+req.Method)
	}
}
