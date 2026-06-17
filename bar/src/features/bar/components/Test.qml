import Quickshell
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

Item {
    id: root;
    required property Component elided;
    property bool alwaysShift: false;
    property real shiftTempo: 0.1;
    property int shiftPauseDuration: 250;
    property int shiftReturnDuration: 300;

    readonly property int baseXShift: 0;
    property int xShift: baseXShift;
    readonly property bool canShift: xShiftMaximum !== baseXShift
    readonly property bool shouldShift: canShift && (alwaysShift || hoverHandler.hovered)
    readonly property real contentWidth: elidedLoader.item
        ? ((elidedLoader.item.implicitWidth > 0) ? elidedLoader.item.implicitWidth : elidedLoader.item.width)
        : elidedLoader.implicitWidth
    property int xShiftMaximum: Math.min(0, root.width - contentWidth)
    property int shiftTravelDuration: Math.max(1, constantTempo(baseXShift, xShiftMaximum, shiftTempo))

    implicitWidth: elidedLoader.implicitWidth;
    implicitHeight: elidedLoader.implicitHeight;
    clip: true;

    function constantTempo(from, to, tempo) {
        // tempo - units per ms
        const range = Math.abs(to - from);
        return (range / tempo)
    }

    function refreshShiftState() {
        if (!shouldShift)
            returnToBaseAnimation.restart();
    }

    // The animation when resumed will have the same duration as if it started from zero
    // This fn should be implemented in such a way that it moves "the same speed", that is
    // the animation's duration is shorter when it restarts while being closer to target.
    // function animationProgressDuration(from, to, current, duration) {
    //     const range = Math.abs(to - from);
    //     return (1 - (Math.abs(current) / range)) * duration;
    // }

    Loader {
        id: elidedLoader;
        sourceComponent: elided;

        transform: Translate { x: root.xShift }
    }

    HoverHandler {
        id: hoverHandler
        enabled: canShift
        onHoveredChanged: () => root.refreshShiftState()
    }

    onAlwaysShiftChanged: refreshShiftState()
    onCanShiftChanged: refreshShiftState()
    onShouldShiftChanged: refreshShiftState()
    Component.onCompleted: refreshShiftState()

    NumberAnimation {
        id: returnToBaseAnimation
        target: root
        property: "xShift"
        to: root.baseXShift
        duration: root.shiftReturnDuration
        running: !root.shouldShift && root.xShift !== root.baseXShift
    }

    SequentialAnimation {
        id: shiftLoopAnimation
        running: root.shouldShift
        loops: Animation.Infinite

        NumberAnimation {
            target: root
            property: "xShift"
            to: root.xShiftMaximum
            duration: root.shiftTravelDuration
        }
        PauseAnimation { duration: root.shiftPauseDuration }
        NumberAnimation {
            target: root
            property: "xShift"
            to: root.baseXShift
            duration: root.shiftTravelDuration
        }
        PauseAnimation { duration: root.shiftPauseDuration }
    }
}
