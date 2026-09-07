package backend

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/AvengeMedia/dankgo/ipc"
	"github.com/AvengeMedia/dankgo/ipc/params"
	"github.com/AvengeMedia/dankgo/log"
	"github.com/AvengeMedia/dankgo/paths"
)

const (
	shellConfigDirName = "tabularium-imperium"
	themeAppDirName    = "blueshell"
	themeSpawnTimeout  = 10 * time.Second
	themeWaitDelay     = 500 * time.Millisecond
)

type themeSettings struct {
	Command      string `json:"command"`
	ConfigFile   string `json:"configFile"`
	TemplateFile string `json:"templateFile"`
	TemplatesDir string `json:"templatesDir"`
}

func shellConfigDir() string {
	return filepath.Join(paths.XDGConfigHome(), shellConfigDirName)
}

func themeAppDir() string {
	return filepath.Join(paths.XDGConfigHome(), themeAppDirName)
}

func defaultThemeSettings() themeSettings {
	dir := themeAppDir()
	return themeSettings{
		Command:      "chromarium-mechanicus",
		ConfigFile:   filepath.Join(dir, "config.json"),
		TemplateFile: filepath.Join(dir, "template.json"),
		TemplatesDir: dir,
	}
}

func (s themeSettings) merge(other themeSettings) themeSettings {
	if other.Command != "" {
		s.Command = other.Command
	}
	if other.ConfigFile != "" {
		s.ConfigFile = other.ConfigFile
	}
	if other.TemplateFile != "" {
		s.TemplateFile = other.TemplateFile
	}
	if other.TemplatesDir != "" {
		s.TemplatesDir = other.TemplatesDir
	}
	return s
}

type chromaTheme struct {
	Mode      string `json:"mode"`
	Wallpaper string `json:"wallpaper"`
	Colors    struct {
		Background   string `json:"background"`
		BackgroundOn string `json:"background_on"`
		Primary      string `json:"primary"`
	} `json:"colors"`
}

type themeManager struct {
	bus *ipc.EventBus

	mu      sync.Mutex
	current string
	busy    bool
}

func newThemeManager(bus *ipc.EventBus) *themeManager {
	return &themeManager{bus: bus}
}

func (t *themeManager) start(context.Context) {
	if err := t.ensureConfig(); err != nil {
		log.Warnf("theme setup: %v", err)
	}
	t.mu.Lock()
	t.current = readCurrentTheme()
	t.mu.Unlock()
}

func (t *themeManager) settings() themeSettings {
	settings := defaultThemeSettings()

	path := filepath.Join(shellConfigDir(), "config.json")
	data, err := os.ReadFile(path)
	if err != nil {
		return settings
	}

	var file struct {
		Theme themeSettings `json:"theme"`
	}
	if err := json.Unmarshal(data, &file); err != nil {
		log.Debugf("theme: parsing %s: %v", path, err)
		return settings
	}
	return settings.merge(file.Theme)
}

func (t *themeManager) available() bool {
	settings := t.settings()
	if _, err := exec.LookPath(settings.Command); err != nil {
		return false
	}
	dir, err := t.themesDir()
	if err != nil {
		return false
	}
	info, err := os.Stat(dir)
	return err == nil && info.IsDir()
}

func (t *themeManager) unavailableReason() string {
	settings := t.settings()
	if _, err := exec.LookPath(settings.Command); err != nil {
		return settings.Command + " is not in $PATH"
	}
	dir, err := t.themesDir()
	if err != nil {
		return err.Error()
	}
	if info, err := os.Stat(dir); err != nil || !info.IsDir() {
		return "no themes directory at " + dir
	}
	return ""
}

func (t *themeManager) ensureConfig() error {
	settings := t.settings()

	if _, err := os.Stat(settings.ConfigFile); err == nil {
		return nil
	}

	themes := filepath.Join(themeAppDir(), "themes")
	if err := os.MkdirAll(themes, 0o755); err != nil {
		return fmt.Errorf("create %s: %w", themes, err)
	}
	if err := os.MkdirAll(filepath.Dir(settings.ConfigFile), 0o755); err != nil {
		return fmt.Errorf("create %s: %w", filepath.Dir(settings.ConfigFile), err)
	}

	data, err := json.MarshalIndent(map[string]string{"themesDir": themes}, "", "    ")
	if err != nil {
		return err
	}
	if err := os.WriteFile(settings.ConfigFile, append(data, '\n'), 0o644); err != nil {
		return fmt.Errorf("write %s: %w", settings.ConfigFile, err)
	}

	log.Infof("wrote %s (themesDir=%s)", settings.ConfigFile, themes)
	return nil
}

func (t *themeManager) themesDir() (string, error) {
	settings := t.settings()

	data, err := os.ReadFile(settings.ConfigFile)
	if err != nil {
		return "", fmt.Errorf("read %s: %w", settings.ConfigFile, err)
	}

	var cfg struct {
		ThemesDir string `json:"themesDir"`
	}
	if err := json.Unmarshal(data, &cfg); err != nil {
		return "", fmt.Errorf("parse %s: %w", settings.ConfigFile, err)
	}
	if cfg.ThemesDir == "" {
		return "", fmt.Errorf("themesDir is empty in %s", settings.ConfigFile)
	}
	return cfg.ThemesDir, nil
}

func (t *themeManager) ensureTemplates() error {
	settings := t.settings()

	if _, err := os.Stat(settings.TemplateFile); err == nil {
		return nil
	}

	templateRel := filepath.Join("templates", "blueshell-colors.json")
	templatePath := filepath.Join(settings.TemplatesDir, templateRel)

	if err := os.MkdirAll(filepath.Dir(templatePath), 0o755); err != nil {
		return fmt.Errorf("create templates dir: %w", err)
	}
	if _, err := os.Stat(templatePath); err != nil {
		if err := os.WriteFile(templatePath, []byte(defaultColorTemplate), 0o644); err != nil {
			return fmt.Errorf("write %s: %w", templatePath, err)
		}
		log.Infof("wrote %s", templatePath)
	}

	colorsOut := filepath.Join(shellConfigDir(), "colors.json")
	body := defaultTemplateSet(colorsOut, "./"+templateRel)
	if err := os.WriteFile(settings.TemplateFile, []byte(body), 0o644); err != nil {
		return fmt.Errorf("write %s: %w", settings.TemplateFile, err)
	}
	log.Infof("wrote %s", settings.TemplateFile)
	return nil
}

const defaultColorTemplate = `{
    "background": "{{.Colors.Background}}",
    "primary": "{{.Colors.BackgroundOn}}",
    "accent": "{{.Colors.Primary}}"
}
`

func defaultTemplateSet(colorsOut, templateRel string) string {
	set := map[string]any{
		"wallpaper_cmd": "true",
		"templates": []map[string]string{{
			"source_file": templateRel,
			"output_file": colorsOut,
			"pre_hook":    "",
			"post_hook":   "",
		}},
	}
	data, _ := json.MarshalIndent(set, "", "    ")
	return string(data) + "\n"
}

func (t *themeManager) list() ([]map[string]any, error) {
	dir, err := t.themesDir()
	if err != nil {
		return nil, err
	}

	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, fmt.Errorf("no themes directory at %s — create it and drop <name>.json theme files in", dir)
	}

	themes := make([]map[string]any, 0, len(entries))
	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".json") {
			continue
		}
		name := strings.TrimSuffix(entry.Name(), ".json")

		data, err := os.ReadFile(filepath.Join(dir, entry.Name()))
		if err != nil {
			log.Warnf("theme %q unreadable: %v", name, err)
			continue
		}
		var parsed chromaTheme
		if err := json.Unmarshal(data, &parsed); err != nil {
			log.Warnf("theme %q is not valid JSON: %v", name, err)
			continue
		}

		themes = append(themes, map[string]any{
			"name":       name,
			"mode":       parsed.Mode,
			"background": parsed.Colors.Background,
			"primary":    parsed.Colors.BackgroundOn,
			"accent":     parsed.Colors.Primary,
			"wallpaper":  parsed.Wallpaper,
		})
	}

	sort.Slice(themes, func(i, j int) bool {
		return themes[i]["name"].(string) < themes[j]["name"].(string)
	})
	return themes, nil
}

func (t *themeManager) apply(ctx context.Context, name string) (string, error) {
	if err := validThemeName(name); err != nil {
		return "", err
	}

	dir, err := t.themesDir()
	if err != nil {
		return "", err
	}
	themeFile := filepath.Join(dir, name+".json")
	if _, err := os.Stat(themeFile); err != nil {
		return "", fmt.Errorf("unknown theme %q (no %s)", name, themeFile)
	}

	settings := t.settings()

	t.mu.Lock()
	if t.busy {
		t.mu.Unlock()
		return "", fmt.Errorf("a theme change is already in progress")
	}
	t.busy = true
	t.mu.Unlock()

	defer func() {
		t.mu.Lock()
		t.busy = false
		t.mu.Unlock()
	}()

	if err := t.ensureConfig(); err != nil {
		return "", err
	}
	if err := t.ensureTemplates(); err != nil {
		return "", err
	}

	ctx, cancel := context.WithTimeout(ctx, themeSpawnTimeout)
	defer cancel()

	cmd := exec.CommandContext(ctx, settings.Command,
		"-c", settings.ConfigFile,
		"-t", settings.TemplateFile,
		"--templatesDir", settings.TemplatesDir,
		name,
	)
	cmd.WaitDelay = themeWaitDelay

	out, err := cmd.CombinedOutput()
	output := strings.TrimSpace(string(out))
	if err != nil {
		return output, fmt.Errorf("%s: %w", settings.Command, err)
	}

	if line, failed := firstErrorLine(output); failed {
		return output, fmt.Errorf("%s reported an error: %s", settings.Command, line)
	}

	t.mu.Lock()
	t.current = name
	t.mu.Unlock()
	writeCurrentTheme(name)

	log.Infof("applied theme %q", name)
	t.bus.Publish(TopicTheme, map[string]any{"current": name})

	return output, nil
}

func firstErrorLine(output string) (string, bool) {
	for line := range strings.SplitSeq(output, "\n") {
		if strings.Contains(line, "level=ERROR") {
			if _, msg, ok := strings.Cut(line, "msg="); ok {
				return strings.Trim(strings.TrimSpace(msg), `"`), true
			}
			return strings.TrimSpace(line), true
		}
	}
	return "", false
}

func validThemeName(name string) error {
	switch {
	case name == "":
		return fmt.Errorf("theme name is required")
	case strings.ContainsAny(name, `/\`):
		return fmt.Errorf("theme name must not contain a path separator")
	case name == "." || name == ".." || strings.HasPrefix(name, "-"):
		return fmt.Errorf("invalid theme name %q", name)
	}
	return nil
}

func currentThemeStatePath() string {
	dir, err := paths.New("blueshell").StateDir()
	if err != nil {
		return ""
	}
	return filepath.Join(dir, "current-theme")
}

func readCurrentTheme() string {
	path := currentThemeStatePath()
	if path == "" {
		return ""
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(data))
}

func writeCurrentTheme(name string) {
	path := currentThemeStatePath()
	if path == "" {
		return
	}
	if err := os.WriteFile(path, []byte(name+"\n"), 0o644); err != nil {
		log.Debugf("theme: recording current theme: %v", err)
	}
}

func (t *themeManager) currentName() string {
	t.mu.Lock()
	defer t.mu.Unlock()
	return t.current
}

func (t *themeManager) republish() {
	t.bus.Publish(TopicTheme, map[string]any{"current": t.currentName()})
}

func (t *themeManager) handle(ctx context.Context, w *ipc.ConnWriter, req ipc.Request, _ *ipc.Subscriber) {
	switch req.Method {
	case "theme.list":
		themes, err := t.list()
		if err != nil {
			ipc.RespondError(w, req.ID, err.Error())
			return
		}
		ipc.Respond(w, req.ID, map[string]any{
			"themes":  themes,
			"current": t.currentName(),
			"reason":  t.unavailableReason(),
		})

	case "theme.apply":
		name, err := params.StringNonEmpty(req.Params, "name")
		if err != nil {
			ipc.RespondError(w, req.ID, err.Error())
			return
		}
		output, err := t.apply(ctx, name)
		if err != nil {
			if output != "" {
				ipc.RespondError(w, req.ID, err.Error()+": "+output)
				return
			}
			ipc.RespondError(w, req.ID, err.Error())
			return
		}
		ipc.Respond(w, req.ID, map[string]any{"current": name, "output": output})

	case "theme.current":
		ipc.Respond(w, req.ID, map[string]any{"current": t.currentName()})

	default:
		ipc.RespondError(w, req.ID, "unknown method: "+req.Method)
	}
}

func (t *themeManager) info() map[string]any {
	settings := t.settings()
	dir, dirErr := t.themesDir()

	info := map[string]any{
		"available":    t.available(),
		"reason":       t.unavailableReason(),
		"command":      settings.Command,
		"configFile":   settings.ConfigFile,
		"templateFile": settings.TemplateFile,
		"templatesDir": settings.TemplatesDir,
		"current":      t.currentName(),
		"themesDir":    dir,
	}
	if dirErr != nil {
		info["themesDirError"] = dirErr.Error()
	}
	return info
}
