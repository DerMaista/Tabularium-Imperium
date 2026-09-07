package main

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/AvengeMedia/dankgo/log"
	"github.com/AvengeMedia/dankgo/paths"
)

// Quickshell passes QS_APP_ID to QGuiApplication::setDesktopFileName, and Qt
// then registers that name with xdg-desktop-portal. The portal resolves it by
// looking up "<app id>.desktop" in the XDG data path and refuses the
// registration — "App info not found for 'com.tabularium.blueshell'" — when
// nothing there matches, which is what happens when the shell runs straight
// out of the Nix store. So blueshell owns that entry: it writes one into
// XDG_DATA_HOME before the UI starts, which is a directory the portal always
// searches no matter how the binary was launched.
//
// Nothing ever runs the entry — no launcher lists a shell, hence NoDisplay —
// it exists purely as the identity the portal (and, via StartupWMClass, the
// compositor) reads back. Exec is only there because the spec requires it for
// Type=Application.
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

// ensureDesktopEntry runs before every UI launch. Failing costs nothing but
// the portal registration, so it warns and lets the shell come up anyway.
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

	// The store path in Exec moves on every rebuild, so compare and rewrite
	// rather than skipping on mere existence.
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
