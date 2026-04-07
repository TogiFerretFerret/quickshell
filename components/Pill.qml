import QtQuick

Rectangle {
    id: pill

    // Public API
    property string label: ""
    property color labelColor: "#e1e2e9"
    property string tooltipText: ""
    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontSize: 15
    property int minWidth: 0
    property bool interactive: true
    property real hoverScale: 1.04
    property int animDuration: 250

    // Pill appearance (set by parent)
    property color pillBg: "#111318"
    property color pillBorder: "#333"
    property int pillHeight: 42
    property int pillRadius: 21
    property int pillPadding: 28

    // Signals
    signal clicked(var mouse)
    signal wheel(var wheel)

    // Expose hover state
    readonly property bool hovered: ma.containsMouse

    height: pillHeight
    width: Math.max(labelText.implicitWidth + pillPadding, minWidth, pillHeight)
    radius: pillRadius
    color: pillBg
    border.width: 2
    border.color: pillBorder
    scale: interactive && ma.containsMouse ? hoverScale : 1.0
    smooth: true

    Behavior on color { ColorAnimation { duration: animDuration } }
    Behavior on border.color { ColorAnimation { duration: animDuration } }
    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

    Text {
        id: labelText
        anchors.centerIn: parent
        text: pill.label
        color: pill.labelColor
        font { pixelSize: pill.fontSize; family: pill.fontFamily }
        Behavior on color { ColorAnimation { duration: pill.animDuration } }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => pill.clicked(mouse)
        onWheel: wheel => pill.wheel(wheel)
    }

    // Tooltip positioned below pill
    Tooltip {
        id: tt
        text: pill.tooltipText
        show: ma.containsMouse && pill.tooltipText !== ""
        anchors.top: pill.bottom
        anchors.topMargin: 4
        anchors.horizontalCenter: pill.horizontalCenter
    }
}
