import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: commandExecutor

    property bool executing: false
    property string activeSymlinkPath: ""

    signal commandStarted(string command)
    signal commandFinished(string command, int exitCode)
    signal allCommandsFinished()

    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'"
    }

    function applyWallpaper(wallpaperPath, symlinkPath) {
        if (executing) {
            console.warn("Already executing commands")
            return
        }

        console.log("Applying wallpaper:", wallpaperPath)
        executing = true


        var commands = []

        commands.push(["notify-send", "Wallpaper changed", wallpaperPath.split("/").pop()])
        commands.push(["sh", "-lc", "nohup switch-wallpaper " + shellQuote(wallpaperPath) + " >/dev/null 2>&1 &"])
        console.log(commands)
        executeCommandSequence(commands, 0)
    }

    function executeCommandSequence(commands, index) {
        if (index >= commands.length) {
            executing = false
            activeSymlinkPath = ""
            allCommandsFinished()
            return
        }

        var cmd = commands[index]
        var cmdString = cmd.join(" ")
        var isSymlinkUpdate = cmd.length >= 3 && cmd[0] === "sh" && cmd[1] === "-lc" && cmd[2].indexOf("ln -sfnT") !== -1
        if (isSymlinkUpdate) {
            console.log("Updating wallpaper symlink:", cmdString)
        }
        commandStarted(cmdString)

        var process = Qt.createQmlObject(`
            import Quickshell.Io
            Process {
                running: false
            }
        `, commandExecutor)

        process.command = cmd

        process.exited.connect(function(code) {
            var normalizedCode = typeof code === "number" ? code : 0
            commandFinished(cmdString, normalizedCode)
            if (isSymlinkUpdate) {
                if (normalizedCode === 0) {
                    console.log("Wallpaper symlink updated successfully")
                    if (activeSymlinkPath.length > 0) {
                        console.log("Symlink check command: readlink -f", activeSymlinkPath)
                    }
                } else {
                    console.error("Wallpaper symlink update failed with exit code", normalizedCode, "for", cmdString)
                }
            }
            process.destroy()

            executeCommandSequence(commands, index + 1)
        })

        process.running = true
    }
}