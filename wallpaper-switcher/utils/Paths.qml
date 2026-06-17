pragma Singleton

import qs.config
import Quickshell

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string pictures: Quickshell.env("XDG_PICTURES_DIR") || `${home}/Pictures`
    readonly property string videos: Quickshell.env("XDG_VIDEOS_DIR") || `${home}/Videos`

    readonly property string data: `${Quickshell.env("XDG_DATA_HOME") || `${home}/.local/share`}/proper_shell`
    readonly property string state: `${Quickshell.env("XDG_STATE_HOME") || `${home}/.local/state`}/proper_shell`
    readonly property string cache: `${Quickshell.env("XDG_CACHE_HOME") || `${home}/.cache`}/proper_shell`
    readonly property string config: `${Quickshell.env("XDG_CONFIG_HOME") || `${home}/.config`}/proper_shell`

    readonly property string imagecache: `${cache}/imagecache`
    readonly property string notifimagecache: `${imagecache}/notifs`
    readonly property string wallsdir: Quickshell.env("PROPER_SHELL_WALLPAPERS_DIR") || absolutePath(Config.paths.wallpaperDir)
    readonly property string recsdir: Quickshell.env("PROPER_SHELL_RECORDINGS_DIR") || `${videos}/Recordings`
    readonly property string libdir: Quickshell.env("PROPER_SHELL_LIB_DIR") || "/usr/lib/proper_shell"

    function toLocalFile(path: url): string {
        const resolved = Qt.resolvedUrl(path).toString();
        if (!resolved)
            return "";
        return resolved.startsWith("file://") ? resolved.slice("file://".length) : resolved;
    }

    function absolutePath(path: string): string {
        return toLocalFile(path.replace(/~|(\$({?)HOME(}?))+/, home));
    }

    function shortenHome(path: string): string {
        return path.replace(home, "~");
    }
}
