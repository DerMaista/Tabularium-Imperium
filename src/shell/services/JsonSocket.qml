import QtQuick
import Quickshell.Io

Socket {
    id: root

    signal message(var obj)

    function send(obj) {
        if (!connected) {
            console.warn("JsonSocket.send while disconnected:", JSON.stringify(obj));
            return false;
        }
        write(JSON.stringify(obj) + "\n");
        flush();
        return true;
    }

    parser: SplitParser {
        onRead: line => {
            if (!line || line.length === 0)
                return;

            let obj;
            try {
                obj = JSON.parse(line);
            } catch (e) {
                console.warn("JsonSocket: unparseable line:", line.substring(0, 160));
                return;
            }
            root.message(obj);
        }
    }
}
