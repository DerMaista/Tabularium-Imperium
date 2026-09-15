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

func sigilPickerCommands() []*cobra.Command {
	return shellIPCCommands("sigil", [][2]string{
		{"toggle", "Open the sigil picker in the running shell, or close it"},
		{"show", "Open the sigil picker in the running shell"},
		{"hide", "Close the sigil picker in the running shell"},
	})
}

func themePickerCommands() []*cobra.Command {
	return shellIPCCommands("theme", [][2]string{
		{"toggle", "Open the theme picker in the running shell, or close it"},
		{"show", "Open the theme picker in the running shell"},
		{"hide", "Close the theme picker in the running shell"},
	})
}

func lockScreenCommands() []*cobra.Command {
	return shellIPCCommands("lock", [][2]string{
		{"preview", "Play the lock animation and draw the screen without locking"},
		{"verify", "Test the PAM stack by asking for your password, without locking"},
		{"status", "Print what the lock screen in the running shell is doing"},
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
