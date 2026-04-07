import Quickshell
import Quickshell.Wayland
import QtQuick

// Generic info popup - shows monospace text content
PanelWindow {
    id: popup

    property color bg: "#111318"
    property color fg: "#e1e2e9"
    property color dim: "#5d6172"
    property color primary: "#a3c9ff"
    property string fontFamily: "JetBrainsMono Nerd Font"
    property string title: ""
    property string content: ""
    property bool showing: false
    property real popupX: 100

    visible: showing
    anchors { top: true; left: true }
    margins.top: 58
    margins.left: popupX
    implicitWidth: Math.max(contentText.implicitWidth + 32, titleText.implicitWidth + 32, 200)
    implicitHeight: contentCol.implicitHeight + 28
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
        anchors.fill: parent; radius: 14
        color: Qt.rgba(popup.bg.r, popup.bg.g, popup.bg.b, 0.94)
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08)

        Column {
            id: contentCol
            anchors.fill: parent; anchors.margins: 14; spacing: 8

            Text { id: titleText; text: popup.title; color: popup.primary; visible: popup.title !== ""
                font { pixelSize: 13; family: popup.fontFamily; bold: true } }

            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.06); visible: popup.title !== "" }

            Text { id: contentText; text: popup.content; color: popup.fg; lineHeight: 1.4
                font { pixelSize: 12; family: "JetBrainsMono Nerd Font Mono" } }
        }
    }

    Shortcut { sequence: "Escape"; onActivated: popup.showing = false; enabled: popup.showing }
}
