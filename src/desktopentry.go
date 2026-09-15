package main

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/AvengeMedia/dankgo/log"
	"github.com/AvengeMedia/dankgo/paths"
)

const desktopEntryTemplate = `[Desktop Entry]
Type=Application
Name=blueshell
Comment=The blueshell desktop shell
Exec=%s run
Terminal=false
NoDisplay=true
Categories=Utility;
StartupWMClass=%s
`
func ensureDesktopEntry() {
	if err := writeDesktopEntry(); err != nil {
		log.Warnf("desktop entry: %v — xdg-desktop-portal will not recognise %s", err, qsAppID)
	}
}

func writeDesktopEntry() error {
	self, err := os.Executable()
	if err != nil {
		return err
	}

	dir := filepath.Join(paths.XDGDataHome(), "applications")
	path := filepath.Join(dir, qsAppID+".desktop")
	want := fmt.Sprintf(desktopEntryTemplate, self, qsAppID)

	if current, err := os.ReadFile(path); err == nil && string(current) == want {
		return nil
	}
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}
	if err := os.WriteFile(path, []byte(want), 0o644); err != nil {
		return err
	}

	log.Infof("wrote desktop entry %s", path)
	return nil
}
