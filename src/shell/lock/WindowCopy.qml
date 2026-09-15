pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    required property Item atlas
    required property real atlasW
    required property real atlasH

    required property real homeX
    required property real homeY
    required property real homeW
    required property real homeH
    required property int stagger

    x: root.homeX
    y: root.homeY
    width: root.homeW
    height: root.homeH

    property vector2d seed: Qt.vector2d(0, 0)

    function reseed(): void {
        root.seed = Qt.vector2d(Math.random() * 128, Math.random() * 128);
    }

    ShaderEffect {
        id: shatter

        anchors.fill: parent

        property variant src: root.atlas
        property real progress: 0
        property real aspect: width / Math.max(1, height)
        property vector2d cropOrigin: Qt.vector2d(root.homeX / root.atlasW, root.homeY / root.atlasH)
        property vector2d cropSize: Qt.vector2d(root.homeW / root.atlasW, root.homeH / root.atlasH)
        property vector2d seed: root.seed

        fragmentShader: Qt.resolvedUrl("../shaders/window_shatter.frag.qsb")
    }

    function fadeOut(duration: int): void {
        root.reseed();
        root.runTo(1, duration);
    }

    function fadeIn(duration: int): void {
        root.runTo(0, duration);
    }

    function runTo(target: real, duration: int): void {
        shatterAnim.stop();
        shatterAnim.dur = duration;
        shatterAnim.goal = target;
        shatterAnim.restart();
    }

    SequentialAnimation {
        id: shatterAnim

        property int dur: 650
        property real goal: 1

        PauseAnimation {
            duration: root.stagger
        }

        NumberAnimation {
            target: shatter
            property: "progress"
            to: shatterAnim.goal
            duration: shatterAnim.dur
            easing.type: Easing.InOutQuad
        }
    }

    Component.onCompleted: root.reseed()
}
