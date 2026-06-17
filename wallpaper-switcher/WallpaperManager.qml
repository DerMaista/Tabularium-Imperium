import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: wallpaperManager
    
    property string wallpapersDir: "/home/christoph/.dotfiles/modules/style/wallpapers"
    property string symlinkPath: "/home/christoph/.dotfiles/modules/style/wallpapers/current-wallpaper"
    property var wallpapers: []
    property string currentWallpaper: ""
    property int currentIndex: -1
    property bool scanning: false
    
    signal wallpapersLoaded()
    signal scanError(string error)

    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'"
    }

    function finalizeWallpaperScan(rawOutput, rawError, exitCode) {
        var output = (rawOutput || "")
        var errorOutput = (rawError || "").trim()
        var lines = output.length > 0 ? output.split('\n') : []
        var files = []

        for (var i = 0; i < lines.length; i++) {
            var candidate = String(lines[i]).trim()
            if (candidate.length === 0) continue
            if (candidate[0] !== "/") continue
            files.push(candidate)
        }

        console.log("Wallpaper scan raw output length:", output.length)
        if (errorOutput.length > 0) {
            console.log("Wallpaper scan stderr:", errorOutput)
        }

        var failed = typeof exitCode === "number" && exitCode !== 0
        if (failed || (files.length === 0 && errorOutput.length > 0)) {
            var details = errorOutput.length > 0 ? errorOutput : ("exit code " + String(exitCode))
            scanError("Failed to scan wallpapers directory: " + wallpapersDir + " (" + details + ")")
            wallpapers = []
            currentIndex = -1
            currentWallpaper = ""
            scanning = false
            wallpapersLoaded()
            return
        }

        console.log("Found", files.length, "wallpapers via find command")
        if (files.length > 0) {
            console.log("First wallpaper:", files[0])
        }

        wallpapers = files
        loadCurrentWallpaper()
        scanning = false
        wallpapersLoaded()
    }

    function finalizeCurrentWallpaperLookup(rawOutput, rawError, exitCode) {
        var resolved = (rawOutput || "").trim()
        var errorOutput = (rawError || "").trim()

        if (resolved.length > 0) {
            currentWallpaper = resolved
            currentIndex = wallpapers.indexOf(currentWallpaper)
            if (currentIndex === -1) {
                currentIndex = 0
                currentWallpaper = wallpapers[0]
            }
        } else {
            if (errorOutput.length > 0) {
                console.log("readlink stderr:", errorOutput)
            }
            currentIndex = 0
            currentWallpaper = wallpapers[0]
        }
    }

    function scanWallpapers() {
        if (scanning) return

        var normalizedWallpapersDir = wallpapersDir.replace("~", Quickshell.env("HOME"))
        console.log("Scanning wallpapers in:", normalizedWallpapersDir)
        scanning = true
        wallpapers = []

        var process = Qt.createQmlObject(`
            import Quickshell.Io
            Process {
                running: false
                stdout: StdioCollector {}
                stderr: StdioCollector {}
            }
        `, wallpaperManager)

        process.exited.connect(function(code) {
            wallpaperManager.finalizeWallpaperScan(
                (process.stdout && process.stdout.text) || "",
                (process.stderr && process.stderr.text) || "",
                typeof code === "number" ? code : -1
            )
            process.destroy()
        })

        var findScript = "if [ ! -d " + shellQuote(normalizedWallpapersDir) + " ]; then "
            + "echo 'Scan path is not a directory: " + normalizedWallpapersDir + "' >&2; exit 1; fi; "
            + "find -L " + shellQuote(normalizedWallpapersDir)
            + " -type f \\( -iname '*.jpg' -o -iname '*.png' -o -iname '*.jpeg' -o -iname '*.gif' \\) -print"
        process.command = ["sh", "-lc", findScript]

        process.running = true
    }

    function loadCurrentWallpaper() {
        if (wallpapers.length === 0) {
            currentIndex = -1
            currentWallpaper = ""
            return
        }

        try {
            var normalizedSymlink = symlinkPath.replace("~", Quickshell.env("HOME"))

            var process = Qt.createQmlObject(`
                import Quickshell.Io
                Process {
                    running: false
                    stdout: StdioCollector {}
                    stderr: StdioCollector {}
                }
            `, wallpaperManager)

            process.exited.connect(function(code) {
                wallpaperManager.finalizeCurrentWallpaperLookup(
                    (process.stdout && process.stdout.text) || "",
                    (process.stderr && process.stderr.text) || "",
                    typeof code === "number" ? code : -1
                )
                process.destroy()
            })

            process.command = ["readlink", "-f", normalizedSymlink]
            process.running = true
            return
        } catch (e) {
            console.error("Error loading current wallpaper:", e)
        }

        currentIndex = 0
        currentWallpaper = wallpapers[0]
    }
    
    function setWallpaper(index) {
        if (index < 0 || index >= wallpapers.length) return false
        
        currentIndex = index
        currentWallpaper = wallpapers[index]
        return true
    }
    
    function getWallpaperName(index) {
        if (index < 0 || index >= wallpapers.length) return "No wallpaper"
        var path = wallpapers[index]
        return path.split("/").pop() || "Unknown"
    }
}