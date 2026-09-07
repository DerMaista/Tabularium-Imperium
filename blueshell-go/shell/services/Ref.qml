import QtQuick

QtObject {
    id: root

    required property var service

    property string module: ""

    Component.onCompleted: {
        root.service.refCount++;
        if (root.module.length > 0)
            root.service.addModule(root.module);
    }

    Component.onDestruction: {
        if (root.module.length > 0)
            root.service.removeModule(root.module);
        root.service.refCount--;
    }
}
