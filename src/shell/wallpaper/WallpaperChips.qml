pragma ComponentBehavior: Bound

import QtQuick

import qs.widgets

Item {
    id: root

    required property var screen

    readonly property real screenw: root.screen ? root.screen.width : root.width
    readonly property real screenh: root.screen ? root.screen.height : root.height
    readonly property real uniformMargin: Math.max(Math.min(root.screenw, root.screenh) * 0.01, 15)
    readonly property real strokeWidth: root.uniformMargin / 6

    readonly property real topheight: topContent.childrenRect.height + root.uniformMargin / 2

    Item {
        id: topContent

        anchors.fill: parent

        Clock {
            id: clock
            screen: root.screen
            anchors {
                horizontalCenter: parent.horizontalCenter
                verticalCenter: parent.top
                verticalCenterOffset: root.strokeWidth / 2
            }
        }

        Workspaces {
            id: workspaces
            screen: root.screen
            anchors {
                left: parent.left
                verticalCenter: parent.top
                verticalCenterOffset: root.strokeWidth / 2
                margins: root.uniformMargin
            }
        }

        Notifications {
            id: notifications

            screen: root.screen
            anchors {
                left: workspaces.right
                verticalCenter: parent.top
                verticalCenterOffset: root.strokeWidth / 2
                margins: root.uniformMargin
            }
        }

        Logout {
            id: logout

            screen: root.screen
            anchors {
                right: parent.right
                verticalCenter: parent.top
                verticalCenterOffset: root.strokeWidth / 2
                margins: root.uniformMargin
            }
        }

        

        SysMonitor {
            id: sysmon

            screen: root.screen
            anchors {
                right: logout.left
                verticalCenter: parent.top
                verticalCenterOffset: root.strokeWidth / 2
                margins: root.uniformMargin
            }
        }

        Storage {
            id: storage

            screen: root.screen
            anchors {
                right: sysmon.left
                verticalCenter: parent.top
                verticalCenterOffset: root.strokeWidth / 2
                margins: root.uniformMargin
            }
        }

        Battery {
            screen: root.screen
            anchors {
                right: storage.left
                verticalCenter: parent.top
                verticalCenterOffset: root.strokeWidth / 2
                margins: root.uniformMargin
            }
        }
    }
    Item {
        id: bottomContent

        anchors.fill: parent

        Network {
            id: network

            screen: root.screen
            anchors {
                left: parent.left
                verticalCenter: parent.bottom
                verticalCenterOffset: -root.strokeWidth / 2
                margins: root.uniformMargin
            }
        }

        Uptime {
            screen: root.screen
            anchors {
                left: network.right
                verticalCenter: parent.bottom
                verticalCenterOffset: -root.strokeWidth / 2
                margins: root.uniformMargin
            }
        }

        MprisMedia {
            screen: root.screen
            anchors {
                horizontalCenter: parent.horizontalCenter
                verticalCenter: parent.bottom
                verticalCenterOffset: -root.strokeWidth / 2
                margins: root.uniformMargin
            }
        }

        Volume {
            id: volume

            screen: root.screen
            anchors {
                right: parent.right
                verticalCenter: parent.bottom
                verticalCenterOffset: -root.strokeWidth / 2
                margins: root.uniformMargin
            }
        }

        Brightness {
            screen: root.screen
            anchors {
                right: volume.left
                verticalCenter: parent.bottom
                verticalCenterOffset: -root.strokeWidth / 2
                margins: root.uniformMargin
            }
        }
    }
}
