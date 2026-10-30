# blueshell

The source of the shell: a Go backend daemon and the Quickshell UI it
launches. The daemon is built on
[dankgo](https://github.com/AvengeMedia/dankgo), which provides process
supervision (`shellapp`), the socket server and event bus (`ipc`), and logging.

## Building and running

```bash
go build -o blueshell .
./blueshell run -c ./shell   # use the QML from this tree, with hot reload
./blueshell run              # use the QML embedded in the binary
./blueshell serve            # backend only, no UI
```

Only one instance runs per `$WAYLAND_DISPLAY`. Use `blueshell restart` or
`blueshell kill` instead of starting a second one.

## Layout

```
main.go              CLI entry point
uiipc.go             subcommands forwarded to the UI via `qs ipc`
shellembed.go        embeds shell/ and extracts it at startup
desktopentry.go      writes the desktop entry for the xdg portal
internal/backend/
  backend.go         server wiring, capabilities, snapshot replay
  metrics.go         CPU, memory, disk and uptime sampling
  gpu.go             GPU and VRAM usage via sysfs, DRM fdinfo or nvidia-smi
  mango.go           compositor socket: tags, dispatch, window rects
  network.go         NetworkManager over D-Bus
  clock.go           minute-aligned clock
  theme.go           theme listing, Chromarium invocation
  power.go           power actions: compositor quit, logind for the rest
  profile.go         power-profiles-daemon
  lock.go            lock state, logind Lock, sleep inhibitor
  fingerprint.go     fprintd finger-present watch
  caffeine.go        idle inhibitor
  brightness.go      brightness topic, gamma fallback via wl-gammarelay-rs
  backlight.go       /sys/class/backlight access via logind
  sigil.go           sigil listing and selection
shell/
  shell.qml          entry point, per-screen Variants, IpcHandlers
  services/          BackendService (socket transport) and one service per topic
  widgets/           bar widgets
  modals/            theme picker, sigil picker, logout panel
  notifications/     toasts, notification centre
  osd/               volume and brightness OSD
  tray/              status notifier items and their menus
  lock/              lock surface, preview, flyout
  wallpaper/         wallpaper, grid, chips
  border/            screen border
  config/            Colors.qml, Config.qml and reference JSON files
  shaders/           fragment shaders and their compiled .qsb files
  svgs/              built-in sigils (empty by default)
```

## Protocol

The daemon binds `$XDG_RUNTIME_DIR/blueshell-<pid>.sock` before starting the UI
and passes the path in `$BLUESHELL_SOCKET`. Messages are newline-delimited JSON.
Each connection starts with a banner listing the API version and capabilities;
widgets check capabilities, so a machine without NetworkManager simply hides
the network widget.

The UI opens two connections, one for requests and one for subscriptions, so
pushed events never delay a reply.

Requests are `{"id":1,"method":"...","params":{...}}`. Events are
`{"event":"<topic>","data":{...}}`. `getServerInfo` returns the current method
and topic list. Because it is plain JSON, the backend can be exercised without
the UI:

```bash
./blueshell call metrics.get '{"modules":["cpu","memory"]}'
./blueshell call workspaces.get

S=$(ls $XDG_RUNTIME_DIR/blueshell-*.sock | head -1)
printf '{"id":1,"method":"subscribe","params":{"topics":["metrics"]}}\n' \
  | socat - UNIX-CONNECT:$S
```

Metrics are reference counted: each widget declares the modules it needs with a
`Ref`, and the backend samples only those. The sample interval is 3s while the
desktop is visible, 15s while every monitor's active tag has windows, and 60s
with no consumers.

## Configuration

`${XDG_CONFIG_HOME:-~/.config}/tabularium-imperium/` holds `config.json` and
`colors.json`. Both are watched and applied without a restart; palette changes
cross-fade according to `animation`. Every key has a default, see
`shell/config/config.json` for the full list.

`animation.colorEasing` accepts any QML `Easing` name, and
`animation.colorBezier` takes `[x1, y1, x2, y2]` as in CSS `cubic-bezier()` and
overrides the easing. A `colorDuration` of `0` disables the fade.

Themes live in `~/.config/blueshell/themes/` and are rendered into
`colors.json` by `chromarium-mechanicus` when applied with `blueshell theme
<name>`.

Sigils are SVG files. User files come from `sigil.dir` (default
`<configDir>/svgs`) and override built-ins of the same name. Only the name is
stored, in `~/.local/state/blueshell/current-sigil`.

## Lock screen

The lock uses `ext-session-lock-v1` and PAM. Unlocking happens only on PAM
success in the UI; the backend has no unlock method, and logind `Unlock` signals
are ignored. The backend holds a delay inhibitor on sleep and waits up to 3s
for the UI to confirm the screen is covered before allowing suspend.

The PAM service is `blueshell`, falling back to `swaylock` and then `login` if
it is missing. With fprintd enabled, the NixOS module also defines
`blueshell-fingerprint`, which runs alongside the password prompt.

Two commands exercise the lock without engaging it:

```bash
blueshell lock preview   # play the animation and show the surface
blueshell lock verify    # run the PAM stack, unlock nothing
```

If the lock is ever stranded with no UI, from a TTY:

```bash
blueshell call lock.state '{"locked":false}'
blueshell restart
```

The flyout uses the layer namespace `qs-lock-flyout`. Add this to the mango
config so the compositor does not animate or blur it:

```
layerrule = noanim:1,noblur:1,layer_name:qs-lock-flyout
```

## Runtime dependencies

The package wraps `quickshell`, `chromarium-mechanicus` and `wl-gammarelay-rs`
onto `PATH`. NetworkManager, UPower, logind, power-profiles-daemon and fprintd
are used over D-Bus when present, and the corresponding widgets hide when they
are not.

## Known limitations

- The compositor client only supports mango.
- Notifications are not grouped per application, and inline replies are not
  supported.
- `wallpaper_switcher` settings are not read by the shell.
