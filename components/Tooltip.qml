import QtQuick

// Tooltip that appears below the hovered pill
Rectangle {
    id: tooltip

    property string text: ""
    property bool show: false

    visible: show && text !== ""
    opacity: show && text !== "" ? 1.0 : 0.0
    width: tooltipText.implicitWidth + 20
    height: tooltipText.implicitHeight + 14
    radius: 10
    color: Qt.rgba(0.06, 0.06, 0.09, 0.92)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.08)
    z: 100

    Behavior on opacity { NumberAnimation { duration: 150 } }

    Text {
        id: tooltipText
        anchors.centerIn: parent
        text: tooltip.text
        color: "#e1e2e9"
        font { pixelSize: 12; family: "JetBrainsMono Nerd Font" }
        lineHeight: 1.3
    }
}
