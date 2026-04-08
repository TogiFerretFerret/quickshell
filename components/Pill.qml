import QtQuick

Item {
    id: pill

    // Public API
    property string label: ""
    property color labelColor: "#e1e2e9"
    property string tooltipText: ""
    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontSize: 15
    property int minWidth: 0
    property bool interactive: true
    property real hoverScale: 1.034
    property int animDuration: 250
    property bool fixedWidth: false

    // Pill appearance (set by parent)
    property color pillBg: "#111318"
    property color pillBorder: "#333"
    property int pillHeight: 42
    property int pillRadius: 21
    property int pillPadding: 28

    // Signals
    signal clicked(var mouse)
    signal wheel(var wheel)
    signal tooltipShow(real globalX, string text)
    signal tooltipHide()

    // Expose hover state
    readonly property bool hovered: ma.containsMouse

    implicitHeight: pillHeight
    implicitWidth: Math.max(labelText.implicitWidth + pillPadding, minWidth, pillHeight)

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: pill.pillRadius
        color: pill.pillBg
        border.width: 1
        border.color: pill.pillBorder
        scale: pill.interactive && ma.containsMouse ? pill.hoverScale : 1.0
        smooth: true

        Behavior on color { ColorAnimation { duration: pill.animDuration } }
        Behavior on border.color { ColorAnimation { duration: pill.animDuration } }
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

        Text {
            id: labelText
            anchors.centerIn: parent
            text: pill.label
            color: pill.labelColor
            textFormat: pill.label.indexOf("<") >= 0 ? Text.RichText : Text.PlainText
            font { pixelSize: pill.fontSize; family: pill.fontFamily }
            Behavior on color { ColorAnimation { duration: pill.animDuration } }
        }
    }

    Behavior on implicitWidth { enabled: !pill.fixedWidth; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => pill.clicked(mouse)
        onWheel: wheel => pill.wheel(wheel)
        onContainsMouseChanged: {
            if (containsMouse && pill.tooltipText) {
                var mapped = pill.mapToItem(null, pill.width / 2, 0);
                pill.tooltipShow(mapped.x, pill.tooltipText);
            } else {
                pill.tooltipHide();
            }
        }
    }
}
