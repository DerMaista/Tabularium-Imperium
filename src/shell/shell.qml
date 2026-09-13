//@ pragma Env QSG_RENDER_LOOP=threaded
import QtQuick
import Quickshell
import Quickshell.Io

import qs.border
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
                active: PowerService.panelOpen

                component: LogoutPanel {
                    screen: monitor.modelData
                }
            }

            // Only up while there is something in it, so an idle
            // desktop carries no notification surface at all.
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
        }
    }
}
