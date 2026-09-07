package main

import (
	"embed"
	"io/fs"

	"github.com/AvengeMedia/dankgo/shellapp/shellfs"
)

//go:embed all:shell
var shellFiles embed.FS

type embeddedShell struct{}

func (embeddedShell) Available() bool {
	_, err := fs.Stat(shellFiles, "shell/shell.qml")
	return err == nil
}

func (embeddedShell) Extract(baseDir string) (string, error) {
	sub, err := fs.Sub(shellFiles, "shell")
	if err != nil {
		return "", err
	}
	return shellfs.Extract(sub, baseDir)
}

func (embeddedShell) Prune(baseDir, keep string) { shellfs.Prune(baseDir, keep) }
