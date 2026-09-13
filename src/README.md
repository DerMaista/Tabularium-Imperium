# blueshell, ported to the two-process model

Your `~/repos/Tabularium-Imperium/blueshell` config, rebuilt around a Go backend
daemon the way DMS is built. Same look, same widgets, same compositor. What
changed is where the work happens.

The framework is [`github.com/AvengeMedia/dankgo`](https://github.com/AvengeMedia/dankgo)
— the same one DMS uses. `shellapp` is the launcher and process supervisor,
`ipc` is the socket server with its event bus, `paths` and `log` are the
plumbing. DMS's `core/cmd/dms/shellapp.go` and this repo's `main.go` are the
same object with different callbacks.

## The headline

The old shell had **six `Timer`s**, four of them re-running a shell pipeline on
every tick. All six are gone.

| Widget | Was | Now |
|---|---|---|
| `SysMonitor` | `Timer 3s` → `top -bn1 \| grep 'Cpu(s)' \| awk`, `free -m \| awk` | Go reads `/proc/stat` + `/proc/meminfo`, pushes over a socket |
| `Storage` | `df -h / \| awk` through a shell | Go `statfs(2)` |
| `Uptime` | `Timer 30s` → `uptime -p \| sed 's/…'` | Go reads `/proc/uptime`, formats it there |
| `Network` | `Timer 5s` → `nmcli … \| awk` | Go holds a NetworkManager D-Bus connection, pushes on `PropertiesChanged` |
| `MprisMedia` | `Timer 2s` → `playerctl metadata` | `Quickshell.Services.Mpris` (native D-Bus, no Go) |
| `Volume` | `wpctl get-volume \| awk`, plus a `wpctl set-volume` fork **per scroll notch** | `Quickshell.Services.Pipewire` (native, no Go) |
| `Clock` | two `Timer 60s`, each rebuilding a `Date` | Go ticks on the wall-clock minute boundary |
| `Workspaces` | `Process` running `mmsg watch all-tags`, `JSON.parse` + full `ListModel` rebuild per line | Go dials the compositor socket directly, diffs, and only speaks when a monitor actually changed |
| `Battery` | `Quickshell.Services.UPower` | unchanged — it was already right |

Counting only the timed ones — 20/min from `SysMonitor`, 30 from `MprisMedia`,
12 from `Network`, 2 from `Uptime` — that is **64 process spawns a minute**,
forever, each one a `fork(2)` of a process with Qt and a GPU context mapped,
on the thread with a 16.6 ms frame budget. Now zero.

Three of those did not need Go at all. MPRIS, PipeWire and UPower already have
native Quickshell bindings that are event-driven; the rule that mattered was
"stop polling", not "move everything to Go".

## Try it

```bash
go build -o blueshell .
./blueshell run -c ./shell        # dev: hot-reloads QML edits, backend survives them
./blueshell run                   # uses the QML embedded in the binary
```

The backend alone, with no UI anywhere:

```bash
./blueshell serve &
./blueshell call getServerInfo
./blueshell call metrics.get '{"modules":["cpu","memory","disk","uptime"]}'
./blueshell call network.get
./blueshell call workspaces.get
```

It is newline-delimited JSON, so `socat` is a complete client — including the
push stream:

```bash
S=$(ls $XDG_RUNTIME_DIR/blueshell-*.sock | head -1)
{ printf '{"id":1,"method":"subscribe","params":{"topics":["metrics","workspaces"]}}\n'
  sleep 5; } | socat - UNIX-CONNECT:$S
```

Being able to exercise every backend feature before any QML exists for it is
one of the underrated wins of the split.

## Layout

```
main.go              CLI: run / restart / kill / serve / call / theme / logout / notifications
uiipc.go             `theme`, `logout`, `notifications`: qs ipc into the running UI
shellembed.go        go:embed of shell/, extracted read-only at startup
desktopentry.go      writes the XDG desktop entry the xdg portal resolves QS_APP_ID against
blueshell.nix        replaces packages/blueshell.nix
theming/             Chromarium template, themes, and the integration guide
internal/backend/
  backend.go         ipc.Server + Mux wiring, capabilities, snapshot replay
  metrics.go         /proc/stat, /proc/meminfo, statfs, /proc/uptime + the sampler
  mango.go           compositor socket: tag watch (deduped) and dispatch
  network.go         NetworkManager over D-Bus, debounced
  clock.go           minute-aligned tick
  theme.go           theme enumeration + the Chromarium spawn
  power.go           logind: what the machine can do, and doing it
shell/
  shell.qml          entry point: pragmas, screen Variants, Binding, IpcHandler
  services/          BackendService (transport) + one thin service per topic,
                     plus NotificationService, which talks to no backend at all
  modals/            ThemePicker.qml, LogoutPanel.qml — the two overlays
  notifications/     the toast stack, the centre, and the card they share
  widgets/           Chip, ChipText, and the widgets
  wallpaper/         Wallpaper.qml; BlueprintGrid.qml (now a shader)
  border/            Border.qml (verbatim from the original)
  config/            Colors.qml, Config.qml (XDG-based, defaults, palette fade)
                     colors.json + config.json reference copies
  shaders/           color_swap.frag (unchanged) + blueprint_grid.frag (new)
  svgs/              unchanged
```

## How the two halves talk

One unix socket, `$XDG_RUNTIME_DIR/blueshell-<pid>.sock`, line-delimited JSON.
The UI learns its path from `$BLUESHELL_SOCKET`, which `shellapp` sets when it
forks quickshell. That environment variable is the entire handshake.

The socket is **bound synchronously** before the UI is forked, so the QML side
can never race an unbound path.

`BackendService.qml` opens that path **twice**:

- `requestSocket` — correlated request/response
- `subscribeSocket` — pushed events only

If they shared a stream, a burst of pushed events could sit in front of a reply
the UI is waiting on, and latency would start depending on how chatty the
compositor happens to be. `subscribeSocket` only connects once `requestSocket`
reports up.

**Banner.** The first line on every connection, before the client says anything:

```json
{"apiVersion":1,"capabilities":["metrics","metrics.cpu",…,"workspaces","network"]}
```

Widgets gate on the capability strings, not on the version number, so a machine
with no NetworkManager gets a widget that collapses to nothing rather than one
stuck on `DISCONNECTED`. The version check exists only to say something useful
out loud when the halves are genuinely mismatched.

**Methods.** `getServerInfo`, `metrics.get`, `metrics.configure`,
`workspaces.get`, `workspaces.dispatch`, `network.get`, `clock.get`,
`theme.list`, `theme.apply`, `theme.current`, `power.list`, `power.invoke`,
`ping`, `subscribe`, `unsubscribe`.

**Events.** `{"event":"<topic>","data":{…}}` on `metrics`, `workspaces`,
`network`, `clock`, `theme`. The QML side fans them out to per-topic Qt signals, so one
socket read updates exactly the widgets that care and nothing parses the same
JSON twice.

## The mechanisms worth knowing about

**Refcounting decides what gets read.** Each widget holds a `Ref`:

```qml
Ref { service: MetricsService; module: "disk" }
```

`MetricsService` collects the live module names, sorts them, and sends
`metrics.configure`. The backend reads only those. Delete `Storage.qml` and
`statfs(2)` stops being called — no other change anywhere. Verified live: with
the shell up, `getServerInfo` reports exactly `["cpu","disk","memory","uptime"]`,
which is precisely what the nine widgets between them ask for.

The `Ref` is destroyed with its widget, including when the widget dies because
a monitor was unplugged, which is exactly where hand-written
`addRef`/`removeRef` pairs leak.

**The sample rate follows what you can actually see.** The compositor already
tells us how many windows are on each monitor's active tag. If every monitor's
active tag has windows on it, these widgets are behind those windows:

```qml
readonly property int updateInterval: {
    if (refCount === 0) return 60000;
    return desktopVisible ? 3000 : 15000;
}
```

A 20× range from one ternary. Note 3s, not 1s — a desktop CPU readout does not
need 1 Hz, and 1 Hz is what everyone reaches for reflexively. Changing the
interval triggers an immediate sample, so uncovering the desktop shows fresh
numbers rather than a 15-second-old reading.

`shell.qml` wires this with a `Binding` rather than an import, so
`MetricsService` never has to know the compositor exists:

```qml
Binding {
    target: MetricsService
    property: "desktopVisible"
    value: WorkspaceService.minActiveClients === 0
}
```

**The compositor stream is deduped in Go.** `mmsg watch all-tags` re-emits the
full state of every monitor on almost any activity — measured at three
identical lines in under two seconds while nothing changed. The backend diffs
per monitor and publishes only real changes, so QML does no parsing and no
model work on the noise. It also emits one event *per monitor*, so a tag switch
on DP-1 costs DP-2 nothing.

**The model is updated in place.** The old widget did `wsModel.clear()` then
re-appended every tag, which destroys and recreates all nine delegates. That is
why the `Behavior on color` and `Behavior on opacity` in the original never
actually animated: a brand-new `Text` has nothing to animate from. Now a tag
switch touches two rows and the transitions work.

**Derivatives are computed where the samples live.** CPU percentage needs two
`/proc/stat` samples. Rather than keeping the previous one in JS, the backend
hands out an opaque cursor string and does the subtraction itself. QML holds a
string and does no arithmetic. The first sample returns a cursor but no
percentage, which is why the widget shows `--` for one tick.

**Value-comparable keys, not `var`.** QML compares `var` properties by
reference, so binding to the module *array* would make every `addModule()` look
like a change. `MetricsService` binds to `enabledModulesKey`, a sorted JSON
string — an unchanged set compares equal and nothing fires. The `.sort()` is
load-bearing: without it, the same modules in a different order look different.

**Everything degrades rather than breaks.** A disconnected socket still invokes
your callback, with `{error: …}`, so every caller has one code path.
`failPendingRequests()` flushes every in-flight callback on disconnect, so a
backend restart cannot leave the UI waiting forever. Kill the backend while the
UI runs and the widgets fall back to `--`; start it again and a 2-second
reconnect timer picks it back up without restarting quickshell.

## Hot-swapping the palette

Editing `~/.config/tabularium-imperium/colors.json` cross-fades the entire
shell in place. Nothing is torn down: no surface is destroyed and recreated,
the process is not restarted, the widgets do not blink, and the backend never
even notices. `FileView` watches with inotify, the `JsonAdapter` properties
change, and every binding that reads `Colors.*` re-evaluates — which is all of
them, including the `ShaderEffect` recolouring the Metatron's cube.

Editors that save by writing a temp file and renaming over the target — vim,
helix, `sed -i` — swap the inode, which is where naive inotify watches break.
Verified: an `mv` over `colors.json` is picked up.

The same applies to `config.json`: change `fontsize` and the chips resize
around the new text immediately.

### The transition, and configuring it

```json
"animation": {
    "colorDuration": 400,
    "colorEasing": "OutCubic",
    "colorBezier": []
}
```

- **`colorDuration`** — milliseconds. **`0` disables the transition** and
  colours snap, which is the old behaviour.
- **`colorEasing`** — any name from QML's `Easing` enum: `Linear`,
  `InOutQuad`, `OutCubic`, `OutExpo`, `OutBack`, `OutElastic`, and the rest.
  Resolved by lookup rather than a hand-written table, so the whole enum is
  available and there is nothing to keep in sync. An unknown name logs a
  warning and falls back to `OutCubic` instead of breaking the shell.
- **`colorBezier`** — `[x1, y1, x2, y2]`, exactly the four numbers you would
  write in CSS's `cubic-bezier()`. When present it wins over `colorEasing`.
  QML wants the trailing `(1,1)` end point; `Config.qml` appends it for you.

All three are hot-reloaded like everything else — you can tune the curve with
the shell running and see the next change use it.

The animation lives in **one place**, `Colors.qml`, as three `Behavior`s on the
palette properties themselves. Every consumer is an ordinary binding onto those
three, so all ten sites cross-fade in step without a single `Behavior` of their
own. The `Behavior`s are disabled until the file has been read once, so
startup does not visibly fade from the built-in defaults to your palette.

### Driving it from a theme manager

`theming/` wires up Chromarium-Mechanicus (`~/repos/Chromarium-Mechanicus`) — it
renders blueshell's `colors.json` from a theme file, blueshell's inotify watch
picks it up, and the cross-fade above does the rest.
See [`theming/README.md`](theming/README.md).

Themes live in `~/.config/blueshell/themes/`, alongside the Chromarium config
and template the daemon seeds there and drives with `-c` / `-t` /
`--templatesDir`. Drop a `<name>.json` in and it appears:

```bash
blueshell theme                   # list, with * on the active one
blueshell theme toggle            # open the GUI picker, or close it
blueshell theme nord              # whole shell fades to Nord
blueshell theme blueprint         # and back
```

There is also a GUI picker — a layer-shell overlay with a card per theme,
painted in that theme's own colours. Bind a key to `blueshell theme toggle`, or
drive it from the CLI with `blueshell theme` / `blueshell theme <name>`.

### Two bugs found while building this

**The grid never recoloured at all.** `BlueprintGrid` drew into a `Canvas`, and
a Canvas only repaints when explicitly asked — the original only asked on
resize. So editing `colors.json` recoloured everything *except* the grid, which
kept the old accent until something resized it. Screenshotted: chips, cube and
background went purple while the grid stayed blue. This bug is in the original
blueshell too; it was invisible there only because the palette path pointed at
a checkout you were not editing live.

Repainting the Canvas on colour change fixes it and makes the animation
*ruinous*. Measured on this machine, CPU time of the quickshell process:

| | 3s idle | 2s palette animation |
|---|---|---|
| Canvas grid, repainting per frame | 0 ticks | **205 ticks** (2.05 CPU-s — a saturated core) |
| Canvas grid fed the un-animated colour | 0 ticks | 16 ticks |
| **Grid as a fragment shader** | 0 ticks | **0 ticks** |

The grid was **92%** of the cost: ~200 stroked lines rasterised in software
into a 1920×1080 surface and uploaded as an 8 MB texture, sixty times a second,
for the cheapest-looking element on screen.

So `BlueprintGrid` is now a fragment shader (`shaders/blueprint_grid.frag`,
built with the same `qsb` invocation as your existing `color_swap.frag`). The
colour is a uniform: recolouring is a uniform write, animating it is sixty
uniform writes, and neither touches the CPU. There is also no repaint left to
forget. Verified visually against the Canvas output at the same palette —
4.25% RMSE over a grid-only region, which is antialiasing, and indistinguishable
side by side.

Worth noting the idle column: **0 ticks**. The ported shell uses no measurable
CPU when nothing is happening.

**`Array.isArray()` is false for a JSON array.** `colorBezier` arrives from
`JsonAdapter` as a `QVariantList`, which is array-*like* in JS but is not a
genuine `Array` — so `Array.isArray(points)` returned false and the custom
curve silently never applied, falling back to `colorEasing` with no error
anywhere. `Config.qml` duck-types on `length` instead. This one only showed up
because the measured curve shape did not match the requested one.

## The logout panel

The power glyph in the top-right corner — or `blueshell logout toggle` from a
compositor keybind — opens a layer-shell overlay with six buttons: LOCK, SLEEP,
HIBERNATE, EXIT, REBOOT, SHUTDOWN. Escape or a click outside closes it, ←/→
move, Enter confirms, and the chip inverts while the panel is up. It is the
`bar/` `LogoutPanel.qml`, same six actions, with three things done differently.

**The actions go through logind, not a shell.** The old panel built a QML
object per click — `Qt.createQmlObject('… Process { command: ["bash","-c","' +
cmd + '"] }')` — around `systemctl reboot`, `systemctl poweroff` and
`loginctl kill-session $XDG_SESSION_ID`. `internal/backend/power.go` calls
`org.freedesktop.login1.Manager.{Reboot,PowerOff,Suspend,Hibernate,TerminateSession}`
on the system bus instead. No `bash`, no command string pasted together in QML,
no dependency on `systemctl` being on `PATH` — and the request is carried out by
logind rather than by a process that is about to be killed by what it just asked
for.

`lock` is the exception, because logind's `LockSession` only emits a signal for
a locker that is already listening and swaylock does not listen. So blueshell
starts the locker itself: `power.lockCommand` in `config.json`, `swaylock` by
default, split on spaces rather than handed to a shell, and started with its own
session id so that restarting the shell cannot take the lock screen down with
it.

**Buttons the machine will refuse are dimmed, and say why.** `power.list` asks
logind `CanReboot` / `CanPowerOff` / `CanSuspend` / `CanHibernate`, each of which
answers `yes`, `no`, `na` or `challenge`. Anything but `yes` is drawn at 35%,
declines the click, is skipped by the keyboard walk, and names its reason under
the row. On this machine that is HIBERNATE — `not supported by this system` —
which the old panel offered anyway, silently doing nothing when pressed.

**Nothing is preselected.** `selectedIndex` starts at `-1`, so a Return that
arrives at a panel which just took keyboard focus powers nothing off. The first
→ lands on LOCK, which is where the row begins because the six are ordered by
what it costs to get one wrong.

## Notifications

`notification-daemon/` at the repo root was a second quickshell process with its
own `Colors.qml` and `Config.qml`: a toast stack in the top-right corner, and a
history panel behind `ipc call notifications toggle`. It is now part of the
shell — `services/NotificationService.qml` and three files under
`notifications/` — driven by `blueshell notifications toggle` or the bell chip
next to the power glyph.

**It stayed in QML, and that is the point.** Everything that moved to Go moved
because it was polling. `Quickshell.Services.Notifications` is a D-Bus service
in the UI process: it is woken by the sending application and idle otherwise, so
there is no timer to delete and no `fork(2)` per tick to remove. Reimplementing
`org.freedesktop.Notifications` in Go would have bought nothing but a
hand-written path for `image-data` hints — raw pixel arrays — over a JSON
socket. The rule that decided MPRIS, PipeWire and UPower decides this too: stop
polling, don't move everything to Go. So the backend gains no capability string,
no method and no topic, and `blueshell serve` is unchanged.

**What the service is for is that there is exactly one of it.** `shell.qml`
instantiates its `Variants` delegate once per monitor, and a
`NotificationServer` inside that delegate would mean two servers racing for the
bus name on a two-monitor machine. The singleton owns the server; the
per-monitor surfaces are views onto its state.

**One timer for the whole shell.** The original put a `Timer` inside each toast
delegate. A Timer in a delegate restarts whenever the model around it changes,
so every visible toast's countdown began again each time a new notification
arrived — and dropping that into the per-monitor `Variants` would have
multiplied it by the number of screens. The service instead keeps absolute
deadlines in a map and arms a single non-repeating `Timer` for the nearest one.
Any number of notifications on any number of monitors cost one timer, and it
fires only when it has something to do.

**The surfaces exist only while they have something to show.** `shell.qml`
gates both behind a `LazyLoader`, so an idle desktop carries no notification
surface at all. The original kept a 380×1 layer surface up permanently, because
its toast window had no `visible` binding and simply collapsed to nothing.

**Toast visibility is not the same thing as being tracked.** A toast that times
out leaves the corner, not the history. The original got that by keeping a
parallel `ListModel` of *copies* of each notification, which is also why its
images and actions were dead in the centre — the copy holds a URL into an
object that has been freed. Here the tracked list is the only list: history is
derived from it newest-first, a toast is an id in a set, and closing a
notification for real is what removes it from both. Notifications stay tracked,
so their images and action buttons still work an hour later, and
`historyLimit` (default 100) evicts oldest-first so that cannot grow without
bound.

### Five things the original got wrong

- **The per-row close button never worked.** The centre's `x` called
  `history.remove(card.modelData.index)`, but `index` is a delegate context
  property, not a role on a `ListModel`'s `modelData` — so the argument was
  always `undefined`. Deriving history from the tracked list removes the
  question: the button closes the notification it is attached to.
- **`actionsSupported: true` was a claim, not a feature.** The server
  advertised action support over D-Bus and then never rendered a single action,
  so an application's buttons silently did nothing. The cards draw them now,
  and the notification is closed afterwards unless it is `resident`.
- **`expireTimeout` was ignored.** Every notification got the one configured
  timeout, so an application asking to stay up until dismissed — `0`, which the
  spec reserves for exactly that — was thrown away after five seconds anyway.
  Critical notifications are still sticky regardless of what the sender asks
  for.
- **The centre and the toasts overlapped.** Both were anchored to the same
  corner with the same margins, so opening the centre while a toast was up drew
  one on top of the other. The toasts are now suppressed while the centre is
  open, which is also why the centre is placed where they were: it reads as the
  stack unfolding.
- **The offset was hardcoded.** The daemon positioned itself at
  `12 + Config.barHeight`, a static `35` from `config.json`. The port takes
  `topheight` — the measurement `Border` already gets from `Wallpaper` — so the
  stack clears the real chip row at any `fontsize`. `barHeight` is now read by
  nothing.

### The palette, and what critical looks like

The daemon read a 48-role Material palette from
`~/.local/state/quickshell/user/generated/colors.json`; blueshell has three
colours in `~/.config/tabularium-imperium/colors.json`. There is no `error`
role to give a critical notification, and inventing a fourth would mean editing
every theme. So urgency is drawn the way the rest of the shell draws emphasis
instead — a doubled stroke, and the accent as a fill rather than as a line, the
same language the logout panel uses for the selected cell. The cards
cross-fade with everything else when the palette changes, for free, because
they are ordinary bindings onto `Colors.*`.

Bodies are rendered as `Text.PlainText` and `bodyMarkupSupported` is left
false, so an application that sends markup anyway gets it shown rather than
interpreted, and no `<img>` tag can pull in a remote resource.

### Configuration and keys

```json
"notifications": {
    "timeout": 5000,
    "historyLimit": 100,
    "popupLimit": 5
}
```

`timeout` is the fallback for a sender that did not ask for one.
`popupLimit` caps how many toasts are on screen at once — the rest wait in the
history and the stack says `+N MORE`. Both are hot-reloaded like the rest of
`config.json`.

```bash
blueshell notifications toggle    # the centre, for a compositor keybind
blueshell notifications clear     # dismiss everything
blueshell notifications status    # how many, and whether any is critical
```

Clicking a toast puts it away and leaves it in the centre; clicking an action
runs it. In the centre, `✕` on a row dismisses that one, `CLEAR ALL` empties
the list, and Escape or a click outside closes the panel.

**The standalone daemon has to go.** Two processes cannot both own
`org.freedesktop.Notifications` — whichever starts second gets nothing and the
shell shows no notifications at all. `packages/notification-daemon.nix` and the
`quickshell-notification-daemon` output in `flake.nix` are still there and are
now redundant; drop them, and drop `my-notification-daemon` from whatever
starts it, before running this.

## Things that changed behaviour (deliberately)

- **`colors.json` and `config.json` moved to XDG.** `Colors.qml` used to
  hardcode `/home/christoph/repos/Tabularium-Imperium/blueshell/config/colors.json`
  (with your own `TODO` next to it). Both files now live in
  `${XDG_CONFIG_HOME:-~/.config}/tabularium-imperium/`, and every property
  carries a default, so a missing file gives you the blueprint palette instead
  of black-on-black. Copy the shipped one across:
  ```bash
  mkdir -p ~/.config/tabularium-imperium
  cp shell/config/colors.json ~/.config/tabularium-imperium/
  ```
- **`Volume` gained click-to-mute** and reads `MUTE` when muted, because with
  the PipeWire binding that is one line and the state was already there.
- **`Network` shows signal strength** on Wi-Fi — it was already sitting on the
  access-point object next to the SSID.
- **`Network` and `Battery` collapse to zero width** when unavailable rather
  than merely hiding, because the widgets beside them are anchored to their
  edges.
- **`Chip` and `ChipText`** replace fifteen lines of identical margin maths,
  border and font setup that were copy-pasted into all nine widgets.

## Runtime dependencies

The old derivation put `playerctl`, `upower`, `networkmanager` and `procps` on
`PATH`. None of them are needed now: `playerctl` and `procps` are gone
entirely, and NetworkManager and UPower are spoken to over D-Bus. `mmsg` is no
longer used either: the daemon dials the compositor's socket itself. Three
binaries are still exec'd, none of them on a timer: `quickshell`, which is the
UI; `chromarium-mechanicus`, only when you change a theme and only if it is
installed; and the locker, only when you press LOCK. `systemctl` and `loginctl`
are not among them — the logout panel talks to logind directly, so the shell
works on a machine that ships neither.

## Not done

- **Channel (B) is now used, minimally.** `shell.qml` exposes three `IpcHandler`
  targets — `theme`, `logout` and `notifications` — so a keybind can open any of
  the three overlays. There is still no Go client for quickshell's binary
  protocol — `blueshell theme toggle` forks
  `qs -p <config> ipc call`, which is fast enough for a key that opens a modal,
  and reimplementing the wire format only pays off on keys you hold to repeat.
  The wrapper exists because `qs` cannot find a config on its own: the UI runs
  the QML extracted into `$XDG_RUNTIME_DIR`, not `~/.config/quickshell`.
- **`Config.barHeight` is now read by nothing.** The notification daemon was its
  only consumer, and the port measures the real chip row instead. It is left in
  `Config.qml` because removing a key from a config file people already have on
  disk buys nothing.
- **No do-not-disturb, no inline replies, no grouping.** The server declines
  `inlineReplySupported` rather than claiming it, which is the mistake the
  original made with actions. Notifications from one application stack as
  separate cards; DMS groups them, and that is the next thing worth taking.
- **`Config.wallpaperDir` / `wallpaperCmd`** are still unread, exactly as
  before — the wallpaper-switcher is a separate package in your repo.
- **The compositor client is mango-specific.** DMS abstracts behind a
  `CompositorService` with a backend per compositor; that is worth doing the
  day you run something other than mango, and not before.
- Only `metrics` has adaptive rate. `workspaces`, `network` and `clock` are
  purely event-driven, so there is no rate to adapt.

## Verified on this machine

`go vet` clean, `nix build` clean (from source and from the embedded UI), and
the shell was run against the live mango session and screenshotted on DP-2:

- Tag numerals I–IX, with I bright as the active tag and the rest dimmed.
- `09:54 Sat, 22 Aug` · `SDD 10%` · `CPU 1% • RAM 18%` on the top row.
- `NET LKW6@M.T17R.DE 66%` · `UP 38m` · `NO MEDIA ACTIVE` · `VOL 40%` on the
  bottom row.
- `Battery` correctly collapsed to nothing — this is a desktop.
- `getServerInfo` while the UI was up: `subscribed: true`, `intervalMs: 3000`,
  `modules: [cpu, disk, memory, uptime]` — derived purely from which widgets
  exist, with nothing hardcoded.
- The compositor watcher published two events (one per monitor) on subscribe
  and then stayed silent for the rest of the run, while raw `mmsg watch
  all-tags` was emitting three identical lines every two seconds.
- No QML warnings or errors. (Quickshell logs one benign
  `Failed to register with host portal` warning because there is no `.desktop`
  file for the app ID.)

- Palette hot-swap screenshotted across four colour schemes, including an
  inode-replacing `mv` edit, with no reload and no surface teardown.
- The cross-fade sampled frame by frame under `Linear` (even steps) and under
  a custom `cubic-bezier(0.68, -0.55, 0.27, 1.55)` (near-flat start, steep
  middle) — visibly different curves, so the config really is driving it.
- An invalid `colorEasing` logs `unknown easing curve "…", falling back to
  OutCubic` and keeps running.
- `0 ticks` of CPU both idle and mid-animation, with the shader grid.

Not visually checked: the second output's surfaces, and the `desktopVisible`
15s fallback, which needs a window on every monitor's active tag at once.

One thing worth knowing from testing: `shellapp` refuses to start a second
instance for the same `$WAYLAND_DISPLAY` (`already running for this session`).
Use `blueshell kill` or `blueshell restart` rather than launching again.
