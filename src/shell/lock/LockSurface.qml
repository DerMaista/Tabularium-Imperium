pragma ComponentBehavior: Bound

import QtQuick

import qs.services

Item {
    id: root

    required property var screen

    LockEffects {
        anchors.fill: parent

        screen: root.screen
    }

    MouseArea {
        anchors.fill: parent

        hoverEnabled: true
        acceptedButtons: Qt.NoButton

        onPositionChanged: LockService.wake()
    }

    TextInput {
        id: input

        width: 0
        height: 0
        opacity: 0

        echoMode: TextInput.Password
        enabled: !LockService.authenticating && !LockService.lockedOut

        Keys.onPressed: event => {
            LockService.wake();
            event.accepted = false;
        }

        onTextChanged: {
            if (LockService.password !== text)
                LockService.password = text;
        }

        onAccepted: LockService.submit()

        onEnabledChanged: {
            if (enabled)
                forceActiveFocus();
        }

        Connections {
            target: LockService

            function onPasswordChanged() {
                if (input.text !== LockService.password)
                    input.text = LockService.password;
            }
        }
    }

    Component.onCompleted: {
        input.forceActiveFocus();
        LockService.surfaceReady();
    }
}
