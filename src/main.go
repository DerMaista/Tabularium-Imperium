package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"os"
	"os/signal"
	"syscall"
	"time"

	"blueshell/internal/backend"

	"github.com/AvengeMedia/dankgo/app"
	"github.com/AvengeMedia/dankgo/ipc"
	"github.com/AvengeMedia/dankgo/log"
	"github.com/AvengeMedia/dankgo/shellapp"
	"github.com/spf13/cobra"
)

var Version = "dev"

const appID = "blueshell"

const qsAppID = "com.tabularium.blueshell"

var shellApp = shellapp.New(shellapp.Config{
	ID:        appID,       // socket + pidfile + XDG identity
	EnvPrefix: "BLUESHELL", // BLUESHELL_SOCKET, BLUESHELL_SHELL_DIR, ...
	QSAppID:   qsAppID,
	Version:   Version,
	Embedded:  embeddedShell{}, // the QML tree, go:embed'd into this binary
	Boot:      bootBackend,
	PreLaunch: ensureDesktopEntry, // so the xdg portal can resolve qsAppID
	ExtraEnv:  extraEnv,
	OnUIExit:  logStartupFailure,
})

func bootBackend(ctx context.Context) (shellapp.Backend, error) {
	return backend.Boot(ctx)
}

func extraEnv(string) []string {
	var env []string

	if self, err := os.Executable(); err == nil {
		env = append(env, "BLUESHELL_EXECUTABLE="+self)
	}

	if os.Getenv("QSG_USE_SIMPLE_ANIMATION_DRIVER") == "" {
		env = append(env, "QSG_USE_SIMPLE_ANIMATION_DRIVER=1")
	}

	return env
}

func logStartupFailure(exitCode int, uptime time.Duration, stderrTail string) {
	if uptime >= 5*time.Second || exitCode == 0 || exitCode > 128 {
		return
	}
	log.Errorf("UI failed to start (exit %d after %s). Last stderr:\n%s",
		exitCode, uptime.Round(time.Millisecond), stderrTail)
}

func main() {
	root := &cobra.Command{
		Use:   appID,
		Short: "The blueshell desktop shell",
		Long: "blueshell runs a Go backend daemon and a quickshell UI as its child.\n" +
			"The backend owns /proc, NetworkManager and the compositor socket;\n" +
			"the UI only draws.",
		SilenceUsage: false,
		RunE: func(cmd *cobra.Command, _ []string) error {
			return cmd.Help()
		},
	}

	root.PersistentFlags().StringVarP(shellApp.CustomConfigVar(), "config", "c", "",
		"Path to the quickshell config dir (overrides the embedded UI)")
	root.PersistentFlags().StringVar(&socketOverride, "socket", "",
		"Backend socket to talk to (default: this Wayland session's instance)")

	root.AddCommand(shellApp.Commands()...)
	root.AddCommand(callCommand())
	root.AddCommand(serveCommand())
	root.AddCommand(themeCommand())
	root.AddCommand(logoutCommand())
	root.AddCommand(notificationsCommand())
	root.AddCommand(lockCommand())
	root.AddCommand(sigilCommand())

	app.New(app.Info{Name: "blueshell", ID: appID, Version: Version}, root).Execute()
}

func logoutCommand() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "logout",
		Short: "Open or close the logout panel",
		Long: "Drives the panel of power actions — lock, sleep, hibernate, exit,\n" +
			"reboot, shutdown — that the running shell draws over the desktop.\n" +
			"The actions themselves go through logind; see `blueshell call power.list`.",
		RunE: func(cmd *cobra.Command, _ []string) error {
			return cmd.Help()
		},
	}

	cmd.AddCommand(logoutPanelCommands()...)

	return cmd
}

func notificationsCommand() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "notifications",
		Short: "Open or close the notification centre",
		Long: "Drives the history panel the running shell draws in the top-right\n" +
			"corner. The notification server itself lives in the UI process, not in\n" +
			"the backend: org.freedesktop.Notifications is event-driven already, so\n" +
			"there is no polling for a Go daemon to remove.",
		RunE: func(cmd *cobra.Command, _ []string) error {
			return cmd.Help()
		},
	}

	cmd.AddCommand(notificationCenterCommands()...)

	return cmd
}

func lockCommand() *cobra.Command {
	var wait bool
	var timeout time.Duration

	cmd := &cobra.Command{
		Use:          "lock",
		SilenceUsage: true,
		Short:        "Lock the session",
		Long: "Raises the lock screen the running shell draws over every output.\n" +
			"Unlocking needs your password: there is no unlock subcommand, because\n" +
			"anything that could call one could also be a process that is not you.\n\n" +
			"Suspend does not need this — the backend holds a logind sleep inhibitor\n" +
			"and locks on its own before the machine goes down.",
		Args: cobra.NoArgs,
		RunE: func(_ *cobra.Command, _ []string) error {
			return withBackend(func(client *ipc.Client) error {
				if _, err := callBackend(client, "lock.lock", nil); err != nil {
					return err
				}
				if !wait {
					return nil
				}

				deadline := time.Now().Add(timeout)
				for time.Now().Before(deadline) {
					status, err := callBackend(client, "lock.status", nil)
					if err != nil {
						return err
					}
					if secure, _ := status["secure"].(bool); secure {
						return nil
					}
					time.Sleep(100 * time.Millisecond)
				}
				return fmt.Errorf("lock screen not confirmed within %s", timeout)
			})
		},
	}

	cmd.Flags().BoolVar(&wait, "wait", false, "Block until the lock screen is confirmed up")
	cmd.Flags().DurationVar(&timeout, "timeout", 5*time.Second, "How long --wait waits")

	cmd.AddCommand(lockScreenCommands()...)

	return cmd
}

func sigilCommand() *cobra.Command {
	cmd := &cobra.Command{
		Use:          "sigil [name]",
		SilenceUsage: true,
		Short:        "List the SVGs the wallpaper can show, or pick one",
		Long: "The emblem in the middle of the wallpaper. Built-in SVGs ship inside\n" +
			"the binary; drop your own into ~/.config/tabularium-imperium/svgs and\n" +
			"they appear alongside them, overriding a built-in of the same name.\n\n" +
			"toggle, show and hide drive the GUI picker in the running shell.",
		Args: cobra.MaximumNArgs(1),
		RunE: func(_ *cobra.Command, args []string) error {
			if len(args) == 0 {
				return withBackend(func(client *ipc.Client) error {
					result, err := callBackend(client, "sigil.list", nil)
					if err != nil {
						return err
					}
					current, _ := result["current"].(string)
					sigils, _ := result["sigils"].([]any)
					if len(sigils) == 0 {
						fmt.Printf("no svgs found — put one in %v\n", result["userDir"])
						return nil
					}
					for _, entry := range sigils {
						sigil, ok := entry.(map[string]any)
						if !ok {
							continue
						}
						name, _ := sigil["name"].(string)
						marker := " "
						if name == current {
							marker = "*"
						}
						origin := "user"
						if builtin, _ := sigil["builtin"].(bool); builtin {
							origin = "built-in"
						}
						fmt.Printf("%s %-32s %s\n", marker, name, origin)
					}
					return nil
				})
			}

			return withBackend(func(client *ipc.Client) error {
				result, err := callBackend(client, "sigil.apply", map[string]any{"name": args[0]})
				if err != nil {
					return err
				}
				fmt.Printf("%v\n", result["current"])
				return nil
			})
		},
	}

	cmd.AddCommand(sigilPickerCommands()...)

	return cmd
}

func themeCommand() *cobra.Command {
	cmd := &cobra.Command{
		Use:          "theme [name]",
		SilenceUsage: true,
		Short:        "List Chromarium themes, or apply one",
		Long: "With no argument, lists the themes blueshell can see and marks the\n" +
			"active one. With a name, runs Chromarium to apply it; the shell\n" +
			"cross-fades to the new palette without restarting.\n\n" +
			"toggle, show and hide drive the GUI picker in the running shell.",
		Args: cobra.MaximumNArgs(1),
		RunE: func(_ *cobra.Command, args []string) error {
			if len(args) == 0 {
				return withBackend(func(client *ipc.Client) error {
					result, err := callBackend(client, "theme.list", nil)
					if err != nil {
						return err
					}
					current, _ := result["current"].(string)
					themes, _ := result["themes"].([]any)
					if reason, _ := result["reason"].(string); reason != "" {
						fmt.Fprintf(os.Stderr, "warning: cannot apply themes — %s\n", reason)
					}
					if len(themes) == 0 {
						fmt.Println("no themes found")
						return nil
					}
					for _, entry := range themes {
						theme, ok := entry.(map[string]any)
						if !ok {
							continue
						}
						name, _ := theme["name"].(string)
						marker := " "
						if name == current {
							marker = "*"
						}
						fmt.Printf("%s %-16s %s %s %s\n", marker, name,
							theme["background"], theme["primary"], theme["accent"])
					}
					return nil
				})
			}

			return withBackend(func(client *ipc.Client) error {
				_, err := callBackend(client, "theme.apply", map[string]any{"name": args[0]})
				if err != nil {
					return err
				}
				fmt.Printf("applied %s\n", args[0])
				return nil
			})
		},
	}

	cmd.AddCommand(themePickerCommands()...)

	return cmd
}

var socketOverride string

func resolveSocket() (string, error) {
	if socketOverride != "" {
		return socketOverride, nil
	}
	if path, ok := shellApp.SessionSocketPath(); ok && socketAlive(path) {
		return path, nil
	}
	path, err := ipc.FindRunningSocket(appID)
	if err != nil {
		return "", fmt.Errorf("no running blueshell backend: %w", err)
	}
	return path, nil
}

func socketAlive(path string) bool {
	conn, err := net.DialTimeout("unix", path, 500*time.Millisecond)
	if err != nil {
		return false
	}
	_ = conn.Close()
	return true
}

func withBackend(fn func(*ipc.Client) error) error {
	socketPath, err := resolveSocket()
	if err != nil {
		return err
	}
	client, err := ipc.Dial(socketPath)
	if err != nil {
		return err
	}
	defer client.Close()
	return fn(client)
}

func callBackend(client *ipc.Client, method string, params map[string]any) (map[string]any, error) {
	resp, err := client.Call(ipc.Request{ID: 1, Method: method, Params: params})
	if err != nil {
		return nil, err
	}
	if resp.Error != "" {
		return nil, fmt.Errorf("%s", resp.Error)
	}
	if resp.Result == nil {
		return map[string]any{}, nil
	}
	result, ok := (*resp.Result).(map[string]any)
	if !ok {
		return nil, fmt.Errorf("unexpected result shape from %s", method)
	}
	return result, nil
}

func serveCommand() *cobra.Command {
	return &cobra.Command{
		Use:          "serve",
		SilenceUsage: true,
		Short:        "Run the backend only, without launching the UI",
		Long: "Runs the daemon in the foreground and prints its socket path.\n" +
			"Useful for developing backend methods before there is any QML for them:\n\n" +
			"  printf '{\"id\":1,\"method\":\"getServerInfo\"}\\n' | socat - UNIX-CONNECT:$SOCKET",
		RunE: func(cmd *cobra.Command, _ []string) error {
			ctx, stop := signal.NotifyContext(cmd.Context(), os.Interrupt, syscall.SIGTERM)
			defer stop()

			b, err := backend.Boot(ctx)
			if err != nil {
				return err
			}
			defer b.Close()

			log.Infof("backend ready, no UI attached (socket=%s)", b.SocketPath())

			select {
			case <-ctx.Done():
				log.Infof("shutting down")
				return nil
			case err := <-b.Done():
				return err
			}
		},
	}
}

func callCommand() *cobra.Command {
	cmd := &cobra.Command{
		Use:          "call <method> [json-params]",
		SilenceUsage: true,
		Short:        "Call a backend method on the running instance",
		Example: "  blueshell call getServerInfo\n" +
			`  blueshell call metrics.get '{"modules":["cpu","memory"]}'` + "\n" +
			`  blueshell call workspaces.dispatch '{"command":"view,3,0"}'`,
		Args: cobra.RangeArgs(1, 2),
		RunE: func(_ *cobra.Command, args []string) error {
			params := map[string]any{}
			if len(args) == 2 {
				if err := json.Unmarshal([]byte(args[1]), &params); err != nil {
					return fmt.Errorf("params must be a JSON object: %w", err)
				}
			}

			socketPath, err := resolveSocket()
			if err != nil {
				return err
			}
			client, err := ipc.Dial(socketPath)
			if err != nil {
				return err
			}
			defer client.Close()

			resp, err := client.Call(ipc.Request{ID: 1, Method: args[0], Params: params})
			if err != nil {
				return err
			}
			if resp.Error != "" {
				return fmt.Errorf("%s", resp.Error)
			}

			out, err := json.MarshalIndent(resp.Result, "", "  ")
			if err != nil {
				return err
			}
			fmt.Println(string(out))
			return nil
		},
	}
	return cmd
}
