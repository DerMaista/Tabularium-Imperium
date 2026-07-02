// BlueprintGrid.qml
import QtQuick

Item {
    id: root
    anchors.fill: parent

    required property int gridSize
    required property color gridColor
    required property real thinWidth
    required property real thickWidth

    Canvas {
        id: gridCanvas
        anchors.fill: parent

        // Tells Qt to redraw the grid whenever the dimensions change
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            // Set global canvas configurations
            ctx.strokeStyle = root.gridColor;

            var centerX = width / 2;
            var centerY = height / 2;

            // 1. DRAW VERTICAL LINES (Radiating Left and Right from Center)
            var currentX = centerX;
            var offsetLinesX = 0;

            // Draw to the right
            while (currentX <= width) {
                ctx.lineWidth = (offsetLinesX % 10 === 0) ? root.thickWidth : root.thinWidth;
                ctx.beginPath();
                ctx.moveTo(currentX, 0);
                ctx.lineTo(currentX, height);
                ctx.stroke();

                currentX += root.gridSize;
                offsetLinesX++;
            }

            // Draw to the left
            currentX = centerX - root.gridSize;
            offsetLinesX = 1;
            while (currentX >= 0) {
                ctx.lineWidth = (offsetLinesX % 10 === 0) ? root.thickWidth : root.thinWidth;
                ctx.beginPath();
                ctx.moveTo(currentX, 0);
                ctx.lineTo(currentX, height);
                ctx.stroke();

                currentX -= root.gridSize;
                offsetLinesX++;
            }

            // 2. DRAW HORIZONTAL LINES (Radiating Up and Down from Center)
            var currentY = centerY;
            var offsetLinesY = 0;

            // Draw down
            while (currentY <= height) {
                ctx.lineWidth = (offsetLinesY % 10 === 0) ? root.thickWidth : root.thinWidth;
                ctx.beginPath();
                ctx.moveTo(0, currentY);
                ctx.lineTo(width, currentY);
                ctx.stroke();

                currentY += root.gridSize;
                offsetLinesY++;
            }

            // Draw up
            currentY = centerY - root.gridSize;
            offsetLinesY = 1;
            while (currentY >= 0) {
                ctx.lineWidth = (offsetLinesY % 10 === 0) ? root.thickWidth : root.thinWidth;
                ctx.beginPath();
                ctx.moveTo(0, currentY);
                ctx.lineTo(width, currentY);
                ctx.stroke();

                currentY -= root.gridSize;
                offsetLinesY++;
            }
        }
    }
}