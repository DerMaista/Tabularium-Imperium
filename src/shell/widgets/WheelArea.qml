import QtQuick

// A MouseArea that turns wheel input into whole steps. A mouse wheel notch is
// 120 units and steps once; a touchpad streams many small deltas, which are
// summed until they add up to a notch instead of each one counting as a step.
MouseArea {
    id: root

    signal stepped(int direction)

    readonly property int notch: 120

    property int pending: 0

    onWheel: wheel => {
        const dy = wheel.angleDelta.y;
        if (dy === 0)
            return;

        // A change of direction drops whatever the other way had built up.
        if ((dy > 0) !== (root.pending > 0))
            root.pending = 0;
        root.pending += dy;

        while (Math.abs(root.pending) >= root.notch) {
            const direction = root.pending > 0 ? 1 : -1;
            root.pending -= direction * root.notch;
            root.stepped(direction);
        }
    }
}
