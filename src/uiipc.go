package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/AvengeMedia/dankgo/paths"
	"github.com/spf13/cobra"
)

// Panels and pickers are UI state, not data, so they live behind quickshell's
// own IPC — the `IpcHandler` targets in shell.qml — rather than the backend
// socket. Reaching those needs the config dir of the running instance, and
// blueshell's UI runs the QML extracted from the binary into a runtime dir, so a
// bare `qs ipc call theme toggle` finds no config at all and dies with
// `Could not find "default" config directory`. These subcommands supply the
// path shellapp recorded when it launched the UI, so a compositor keybind is
// just `blueshell theme toggle`, `blueshell logout toggle` or
// `blueshell notifications toggle`.
func themePickerCommands() []*cobra.Command {
	return shellIPCCommands("theme", [][2]string{
		{"toggle", "Open the theme picker in the running shell, or close it"},
		{"show", "Open the theme picker in the running shell"},
		{"hide", "Close the theme picker in the running shell"},
	})
}

func notificationCenterCommands() []*cobra.Command {
	return shellIPCCommands("notifications", [][2]string{
		{"toggle", "Open the notification centre in the running shell, or close it"},
		{"show", "Open the notification centre in the running shell"},
		{"hide", "Close the notification centre in the running shell"},
		{"clear", "Dismiss every notification the running shell is holding"},
		{"status", "Print how many notifications are held, and whether any is critical"},
	})
}

func logoutPanelCommands() []*cobra.Command {
	return shellIPCCommands("logout", [][2]string{
		{"toggle", "Open the logout panel in the running shell, or close it"},
		{"show", "Open the logout panel in the running shell"},
		{"hide", "Close the logout panel in the running shell"},
	})
}

// shellIPCCommands builds one subcommand per {function, description} pair.
func shellIPCCommands(target string, functions [][2]string) []*cobra.Command {
	commands := make([]*cobra.Command, 0, len(functions))
	for _, fn := range functions {
		function := fn[0]
		commands = append(commands, &cobra.Command{
			Use:          function,
			Short:        fn[1],
			SilenceUsage: true,
			Args:         cobra.NoArgs,
			RunE: func(*cobra.Command, []string) error {
				return callShellIPC(target, function)
			},
		})
	}
	return commands
}

// callShellIPC calls a function on one of shell.qml's IpcHandler targets.
// quickshell's wire format is reimplemented nowhere: `qs ipc` is a fork per
// keypress, which is affordable for a key that opens a modal.
func callShellIPC(target, function string) error {
	configPath, err := runningShellConfig()
	if err != nil {
		return err
	}

	cmd := exec.Command("qs", "-p", configPath, "ipc", "call", target, function)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("qs ipc call %s %s: %w", target, function, err)
	}
	return nil
}

// runningShellConfig reads the config dir shellapp records beside the socket
// for the duration of a run. Asking shellApp.ResolveConfig instead would
// extract the embedded QML as a side effect when no UI is up, and then hand
// back a path nothing is listening on.
func runningShellConfig() (string, error) {
	stateFile := filepath.Join(paths.New(appID).SocketDir(), appID+".path")

	data, err := os.ReadFile(stateFile)
	if err != nil {
		return "", fmt.Errorf("no running %s UI: %s is unreadable", appID, stateFile)
	}
	path := strings.TrimSpace(string(data))
	if path == "" {
		return "", fmt.Errorf("no running %s UI: %s is empty", appID, stateFile)
	}
	return path, nil
}
