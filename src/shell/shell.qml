//@ pragma Env QSG_RENDER_LOOP=threaded
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import qs.border
import qs.config
import qs.lock
import qs.modals
import qs.notifications
import qs.services
import qs.wallpaper

ShellRoot {
    id: root

    Binding {
        target: MetricsService
        property: "desktopVisible"
        value: WorkspaceService.minActiveClients === 0
    }

    WlSessionLock {
        id: sessionLock

        locked: LockService.shouldLock

        WlSessionLockSurface {
            id: lockSurface

            color: Colors.background

            LockSurface {
                anchors.fill: parent
                screen: lockSurface.screen
            }
        }
    }

    Binding {
        target: LockService
        property: "secure"
        value: sessionLock.secure
    }

    IpcHandler {
        target: "lock"

        function preview(): string {
            if (LockService.shouldLock)
                return "LOCKED";
            const wasOpen = LockService.previewing;
            LockService.requestPreview();
            return wasOpen ? "PREVIEW_CLOSED" : "PREVIEW_OPEN";
        }

        function verify(): string {
            if (LockService.shouldLock)
                return "LOCKED";
            LockService.beginVerify();
            return "VERIFY_OPEN";
        }

        function status(): string {
            if (LockService.shouldLock)
                return LockService.secure ? "LOCKED_SECURE" : "LOCKING";
            if (LockService.previewing)
                return "PREVIEW";
            return "UNLOCKED";
        }
    }

    IpcHandler {
        target: "theme"

        function toggle(): string {
            if (!ThemeService.available)
                return "THEME_UNAVAILABLE";
            ThemeService.togglePicker();
            return ThemeService.pickerOpen ? "THEME_OPEN" : "THEME_CLOSED";
        }

        function show(): string {
            if (!ThemeService.available)
                return "THEME_UNAVAILABLE";
            ThemeService.openPicker();
            return "THEME_OPEN";
        }

        function hide(): string {
            ThemeService.closePicker();
            return "THEME_CLOSED";
        }

        function apply(name: string): string {
            if (!ThemeService.available)
                return "THEME_UNAVAILABLE";
            ThemeService.apply(name);
            return "THEME_APPLYING";
        }

        function status(): string {
            return ThemeService.current;
        }
    }

    IpcHandler {
        target: "sigil"

        function toggle(): string {
            if (!SigilService.available)
                return "SIGIL_UNAVAILABLE";
            SigilService.togglePicker();
            return SigilService.pickerOpen ? "SIGIL_OPEN" : "SIGIL_CLOSED";
        }

        function show(): string {
            if (!SigilService.available)
                return "SIGIL_UNAVAILABLE";
            SigilService.openPicker();
            return "SIGIL_OPEN";
        }

        function hide(): string {
            SigilService.closePicker();
            return "SIGIL_CLOSED";
        }

        function status(): string {
            return SigilService.current;
        }
    }

    IpcHandler {
        target: "logout"

        function toggle(): string {
            if (!PowerService.available)
                return "POWER_UNAVAILABLE";
            PowerService.togglePanel();
            return PowerService.panelOpen ? "PANEL_OPEN" : "PANEL_CLOSED";
        }

        function show(): string {
            if (!PowerService.available)
                return "POWER_UNAVAILABLE";
            PowerService.openPanel();
            return "PANEL_OPEN";
        }

        function hide(): string {
            PowerService.closePanel();
            return "PANEL_CLOSED";
        }
    }

    IpcHandler {
        target: "notifications"

        function toggle(): string {
            NotificationService.toggleCenter();
            return NotificationService.centerOpen ? "CENTER_OPEN" : "CENTER_CLOSED";
        }

        function show(): string {
            NotificationService.openCenter();
            return "CENTER_OPEN";
        }

        function hide(): string {
            NotificationService.closeCenter();
            return "CENTER_CLOSED";
        }

        function clear(): string {
            NotificationService.clearAll();
            return "CLEARED";
        }

        function status(): string {
            return NotificationService.count + (NotificationService.hasCritical ? " CRITICAL" : "");
        }
    }

    Variants {
        model: Quickshell.screens

        Scope {
            id: monitor

            required property var modelData

            Wallpaper {
                id: wallpaper

                screen: monitor.modelData
            }

            Border {
                topheight: wallpaper.topheight
                screen: monitor.modelData
            }

            LazyLoader {
                active: ThemeService.pickerOpen

                component: ThemePicker {
                    screen: monitor.modelData
                }
            }

            LazyLoader {
                active: SigilService.pickerOpen

                component: SigilPicker {
                    screen: monitor.modelData
                }
            }

            LazyLoader {
                active: PowerService.panelOpen

                component: LogoutPanel {
                    screen: monitor.modelData
                }
            }

            LazyLoader {
                active: NotificationService.popups.length > 0 && !NotificationService.centerOpen

                component: NotificationPopups {
                    screen: monitor.modelData
                    topheight: wallpaper.topheight
                }
            }

            LazyLoader {
                active: NotificationService.centerOpen

                component: NotificationCenter {
                    screen: monitor.modelData
                    topheight: wallpaper.topheight
                }
            }

            LazyLoader {
                active: LockService.flyoutActive

                component: FlyoutOverlay {
                    screen: monitor.modelData
                }
            }

            LazyLoader {
                active: LockService.previewing && !LockService.shouldLock

                component: LockPreview {
                    screen: monitor.modelData
                }
            }
        }
    }
}
