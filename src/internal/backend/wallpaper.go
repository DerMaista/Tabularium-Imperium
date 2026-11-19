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

// Wallpaper modes: sigil (grid + sigil) or image from the theme's set, falling back to sigil; picks are remembered per theme.
const (
	WallpaperModeSigil = "sigil"
	WallpaperModeImage = "image"
)

var wallpaperExtensions = map[string]bool{
	".jpg": true, ".jpeg": true, ".png": true, ".webp": true, ".bmp": true,
}

type wallpaperSettings struct {
	Mode string `json:"mode"`
	Dir  string `json:"dir"`
}

// wallpaperPick is what a theme shows: the mode, and the image for image mode.
type wallpaperPick struct {
	Mode  string `json:"mode"`
	Image string `json:"image"`
}

type wallpaperEntry struct {
	Name    string
	Path    string
	Default bool
}

type wallpaperManager struct {
	mu    sync.Mutex
	bus   *ipc.EventBus
	theme *themeManager

	mode  string
	image string
	picks map[string]wallpaperPick

	thumbs *thumbCache
}

func newWallpaperManager(bus *ipc.EventBus, theme *themeManager) *wallpaperManager {
	return &wallpaperManager{bus: bus, theme: theme, picks: map[string]wallpaperPick{}, thumbs: newThumbCache()}
}

func (m *wallpaperManager) start(context.Context) {
	mode, image := ReadWallpaperState()
	picks := readWallpaperPicks()

	m.mu.Lock()
	m.mode = mode
	m.image = image
	m.picks = picks
	m.mu.Unlock()

	m.warmThumbs(m.themeWallpapers(m.currentTheme()))
}

// warmThumbs builds missing picker thumbnails in the background; once some are
// ready the UI is told to re-list so it swaps them in.
func (m *wallpaperManager) warmThumbs(entries []wallpaperEntry) {
	srcs := make([]string, 0, len(entries))
	for _, entry := range entries {
		srcs = append(srcs, entry.Path)
	}
	m.thumbs.generate(srcs, func() {
		payload := m.snapshot()
		payload["listChanged"] = true
		m.bus.Publish(TopicWallpaper, payload)
	})
}

func wallpaperConfig() wallpaperSettings {
	settings := wallpaperSettings{Mode: WallpaperModeSigil, Dir: "wallpapers"}

	path := filepath.Join(shellConfigDir(), "config.json")
	data, err := os.ReadFile(path)
	if err != nil {
		return settings
	}

	var file struct {
		Wallpaper wallpaperSettings `json:"wallpaper"`
	}
	if err := json.Unmarshal(data, &file); err != nil {
		log.Debugf("wallpaper: parsing %s: %v", path, err)
		return settings
	}
	if mode, err := ValidWallpaperMode(file.Wallpaper.Mode); err == nil {
		settings.Mode = mode
	}
	if file.Wallpaper.Dir != "" {
		settings.Dir = file.Wallpaper.Dir
	}
	return settings
}

// defaultWallpaperMode is wallpaper.mode from config.json, used until a mode is picked at runtime.
func defaultWallpaperMode() string { return wallpaperConfig().Mode }

// userWallpaperDir holds one folder of images per theme, <dir>/<theme>/.
func userWallpaperDir() string { return expandPath(wallpaperConfig().Dir) }

func ValidWallpaperMode(mode string) (string, error) {
	switch mode {
	case WallpaperModeSigil, WallpaperModeImage:
		return mode, nil
	}
	return "", fmt.Errorf("unknown wallpaper mode %q (want %s or %s)", mode, WallpaperModeSigil, WallpaperModeImage)
}

// NormalizeWallpaperImage expands ~ and $VARS and requires an absolute path; empty means no image.
func NormalizeWallpaperImage(path string) (string, error) {
	path = strings.TrimSpace(path)
	if path == "" {
		return "", nil
	}
	path = strings.TrimPrefix(path, "file://")
	path = os.ExpandEnv(path)
	if path == "~" || strings.HasPrefix(path, "~/") {
		if home, err := os.UserHomeDir(); err == nil {
			path = filepath.Join(home, strings.TrimPrefix(path, "~"))
		}
	}
	if !filepath.IsAbs(path) {
		return "", fmt.Errorf("wallpaper path must be absolute: %q", path)
	}
	return filepath.Clean(path), nil
}

func imageUsable(path string) bool {
	if path == "" {
		return false
	}
	info, err := os.Stat(path)
	return err == nil && info.Mode().IsRegular()
}

func (m *wallpaperManager) currentTheme() string {
	if m.theme == nil {
		return ""
	}
	return m.theme.currentName()
}

// themeWallpapers lists the theme's "wallpaper" and "wallpapers" keys, then every image in <dir>/<theme>/.
func (m *wallpaperManager) themeWallpapers(theme string) []wallpaperEntry {
	if theme == "" {
		return nil
	}

	var out []wallpaperEntry
	seen := map[string]bool{}
	add := func(path string, isDefault bool) {
		path, err := NormalizeWallpaperImage(path)
		if err != nil || path == "" || seen[path] {
			return
		}
		seen[path] = true
		name := strings.TrimSuffix(filepath.Base(path), filepath.Ext(path))
		out = append(out, wallpaperEntry{Name: name, Path: path, Default: isDefault})
	}

	if m.theme != nil {
		if dir, err := m.theme.themesDir(); err == nil {
			data, err := os.ReadFile(filepath.Join(dir, theme+".json"))
			if err == nil {
				var file struct {
					Wallpaper  string   `json:"wallpaper"`
					Wallpapers []string `json:"wallpapers"`
				}
				if err := json.Unmarshal(data, &file); err != nil {
					log.Debugf("wallpaper: theme %q: %v", theme, err)
				}
				add(file.Wallpaper, true)
				for _, path := range file.Wallpapers {
					add(path, false)
				}
			}
		}
	}

	dir := filepath.Join(userWallpaperDir(), theme)
	entries, err := os.ReadDir(dir)
	if err != nil && !os.IsNotExist(err) {
		log.Debugf("wallpaper: reading %s: %v", dir, err)
	}
	var files []string
	for _, entry := range entries {
		if entry.IsDir() || !wallpaperExtensions[strings.ToLower(filepath.Ext(entry.Name()))] {
			continue
		}
		files = append(files, filepath.Join(dir, entry.Name()))
	}
	sort.Slice(files, func(i, j int) bool { return strings.ToLower(files[i]) < strings.ToLower(files[j]) })
	for _, path := range files {
		add(path, false)
	}
	return out
}

// firstWallpaper is what image mode shows for a theme nothing was picked for.
func (m *wallpaperManager) firstWallpaper(theme string) string {
	if list := m.themeWallpapers(theme); len(list) > 0 {
		return list[0].Path
	}
	return ""
}

func (m *wallpaperManager) snapshot() map[string]any {
	m.mu.Lock()
	mode, image := m.mode, m.image
	m.mu.Unlock()

	showing := WallpaperModeSigil
	if mode == WallpaperModeImage && imageUsable(image) {
		showing = WallpaperModeImage
	}
	return map[string]any{
		"mode":    mode,
		"image":   image,
		"showing": showing,
		"theme":   m.currentTheme(),
	}
}

func (m *wallpaperManager) listPayload() map[string]any {
	theme := m.currentTheme()
	entries := m.themeWallpapers(theme)
	list := make([]map[string]any, 0, len(entries))
	for _, entry := range entries {
		list = append(list, map[string]any{
			"name":    entry.Name,
			"path":    entry.Path,
			"thumb":   m.thumbs.lookup(entry.Path),
			"default": entry.Default,
		})
	}
	m.warmThumbs(entries)
	payload := m.snapshot()
	payload["wallpapers"] = list
	if theme != "" {
		payload["dir"] = filepath.Join(userWallpaperDir(), theme)
	}
	return payload
}

// commitLocked stores and broadcasts the state, saving it as the theme's pick if remember; call with m.mu held, it unlocks.
func (m *wallpaperManager) commitLocked(remember bool) {
	mode, image := m.mode, m.image
	theme := m.currentTheme()
	if remember && theme != "" {
		m.picks[theme] = wallpaperPick{Mode: mode, Image: image}
	}
	picks := make(map[string]wallpaperPick, len(m.picks))
	for k, v := range m.picks {
		picks[k] = v
	}
	m.mu.Unlock()

	writeStateFile("wallpaper-mode", mode)
	writeStateFile("wallpaper-image", image)
	writeWallpaperPicks(picks)
	log.Infof("wallpaper: mode %s, image %q (theme %q)", mode, image, theme)
	m.publish()
}

func (m *wallpaperManager) setImage(path string) error {
	path, err := NormalizeWallpaperImage(path)
	if err != nil {
		return err
	}
	if path != "" && !imageUsable(path) {
		log.Warnf("wallpaper: %s is not a readable file, showing the sigil instead", path)
	}

	m.mu.Lock()
	m.image = path
	m.commitLocked(true)
	return nil
}

func (m *wallpaperManager) setMode(mode string) error {
	theme := m.currentTheme()

	m.mu.Lock()
	if mode == "toggle" {
		mode = WallpaperModeImage
		if m.mode == WallpaperModeImage {
			mode = WallpaperModeSigil
		}
	}
	mode, err := ValidWallpaperMode(mode)
	if err != nil {
		m.mu.Unlock()
		return err
	}
	needImage := mode == WallpaperModeImage && m.image == ""
	m.mu.Unlock()

	// Image mode with nothing picked yet starts on the theme's first image.
	var image string
	if needImage {
		image = m.firstWallpaper(theme)
	}

	m.mu.Lock()
	m.mode = mode
	if needImage && m.image == "" {
		m.image = image
	}
	m.commitLocked(true)
	return nil
}

// pick shows an image in image mode, or the sigil for an empty path; used by the picker.
func (m *wallpaperManager) pick(path string) error {
	path, err := NormalizeWallpaperImage(path)
	if err != nil {
		return err
	}

	m.mu.Lock()
	if path == "" {
		m.mode = WallpaperModeSigil
	} else {
		m.mode = WallpaperModeImage
		m.image = path
	}
	m.commitLocked(true)
	return nil
}

// themeChanged restores the theme's pick or default wallpaper; without a pick the mode is kept.
func (m *wallpaperManager) themeChanged(theme string) {
	m.mu.Lock()
	pick, ok := m.picks[theme]
	m.mu.Unlock()

	entries := m.themeWallpapers(theme)
	m.warmThumbs(entries)

	if !ok && len(entries) > 0 {
		pick.Image = entries[0].Path
	}

	m.mu.Lock()
	if ok {
		m.mode = pick.Mode
	}
	m.image = pick.Image
	m.commitLocked(ok)
}

func (m *wallpaperManager) publish() { m.bus.Publish(TopicWallpaper, m.snapshot()) }

func (m *wallpaperManager) republish() { m.publish() }

func (m *wallpaperManager) available() bool { return true }

func (m *wallpaperManager) info() map[string]any {
	info := m.snapshot()
	info["userDir"] = userWallpaperDir()
	return info
}

func (m *wallpaperManager) handle(_ context.Context, w *ipc.ConnWriter, req ipc.Request, _ *ipc.Subscriber) {
	respond := func(err error) {
		if err != nil {
			ipc.RespondError(w, req.ID, err.Error())
			return
		}
		ipc.Respond(w, req.ID, m.snapshot())
	}

	switch req.Method {
	case "wallpaper.current":
		ipc.Respond(w, req.ID, m.snapshot())

	case "wallpaper.list":
		ipc.Respond(w, req.ID, m.listPayload())

	case "wallpaper.set":
		path, err := params.String(req.Params, "path")
		if err != nil {
			respond(err)
			return
		}
		respond(m.setImage(path))

	case "wallpaper.pick":
		path, err := params.String(req.Params, "path")
		if err != nil {
			respond(err)
			return
		}
		respond(m.pick(path))

	case "wallpaper.mode":
		mode, err := params.StringNonEmpty(req.Params, "mode")
		if err != nil {
			respond(err)
			return
		}
		respond(m.setMode(mode))

	default:
		ipc.RespondError(w, req.ID, "unknown method: "+req.Method)
	}
}

// State lives in files so the CLI can record changes while no shell is running.

func stateFilePath(name string) string {
	dir, err := paths.New("blueshell").StateDir()
	if err != nil {
		return ""
	}
	return filepath.Join(dir, name)
}

func readStateFile(name string) (string, bool) {
	path := stateFilePath(name)
	if path == "" {
		return "", false
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return "", false
	}
	return strings.TrimSpace(string(data)), true
}

func writeStateFile(name, value string) {
	path := stateFilePath(name)
	if path == "" {
		return
	}
	if err := os.WriteFile(path, []byte(value+"\n"), 0o644); err != nil {
		log.Debugf("recording %s: %v", name, err)
	}
}

func readWallpaperPicks() map[string]wallpaperPick {
	picks := map[string]wallpaperPick{}
	data, ok := readStateFile("wallpaper-picks.json")
	if !ok {
		return picks
	}
	if err := json.Unmarshal([]byte(data), &picks); err != nil {
		log.Debugf("wallpaper: reading picks: %v", err)
		return map[string]wallpaperPick{}
	}
	for theme, pick := range picks {
		if _, err := ValidWallpaperMode(pick.Mode); err != nil {
			delete(picks, theme)
		}
	}
	return picks
}

func writeWallpaperPicks(picks map[string]wallpaperPick) {
	data, err := json.MarshalIndent(picks, "", "  ")
	if err != nil {
		return
	}
	writeStateFile("wallpaper-picks.json", string(data))
}

// ReadWallpaperState returns the stored mode (or configured default) and image path.
func ReadWallpaperState() (string, string) {
	mode := defaultWallpaperMode()
	if stored, ok := readStateFile("wallpaper-mode"); ok {
		if valid, err := ValidWallpaperMode(stored); err == nil {
			mode = valid
		}
	}
	image, _ := readStateFile("wallpaper-image")
	return mode, image
}

// WriteWallpaperImage and WriteWallpaperMode record a change directly when no backend is running.
func WriteWallpaperImage(path string) error {
	path, err := NormalizeWallpaperImage(path)
	if err != nil {
		return err
	}
	writeStateFile("wallpaper-image", path)
	return nil
}

func WriteWallpaperMode(mode string) (string, error) {
	if mode == "toggle" {
		current, _ := ReadWallpaperState()
		mode = WallpaperModeImage
		if current == WallpaperModeImage {
			mode = WallpaperModeSigil
		}
	}
	mode, err := ValidWallpaperMode(mode)
	if err != nil {
		return "", err
	}
	writeStateFile("wallpaper-mode", mode)
	return mode, nil
}
