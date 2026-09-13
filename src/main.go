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

// Version is overridden at build time: -ldflags "-X main.Version=$(git describe)".
var Version = "dev"

const appID = "blueshell"

// qsAppID is the identity quickshell gives the UI process: the Wayland app id
// and the desktop entry name the xdg portal resolves. It must match the entry
// ensureDesktopEntry writes.
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

	app.New(app.Info{Name: "blueshell", ID: appID, Version: Version}, root).Execute()
}

// logoutCommand deliberately does nothing on its own: `blueshell logout`
// prints help rather than logging anyone out. The verb has to be typed.
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

// notificationsCommand, like logoutCommand, needs its verb typed: bare
// `blueshell notifications` prints help rather than clearing anything.
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
