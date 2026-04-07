import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

PanelWindow {
    id: blPopup

    property color bg: "#111318"
    property color fg: "#e1e2e9"
    property color dim: "#5d6172"
    property color primary: "#a3c9ff"
    property color yellow: "#f9e2af"
    property string fontFamily: "JetBrainsMono Nerd Font"
    property bool showing: false
    property int brightness: 0

    visible: showing
    anchors { top: true; right: true }
    margins.top: 56; margins.right: 450
    implicitWidth: 280; implicitHeight: 120
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
        anchors.fill: parent; radius: 14
        color: Qt.rgba(blPopup.bg.r, blPopup.bg.g, blPopup.bg.b, 0.94)
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08)

        Column {
            anchors.fill: parent; anchors.margins: 16; spacing: 12

            Text { text: String.fromCodePoint(0xf00df) + "  Brightness"
                color: blPopup.yellow; font { pixelSize: 14; family: blPopup.fontFamily; bold: true } }

            // Slider bar
            Rectangle {
                width: parent.width; height: 8; radius: 4
                color: Qt.rgba(1, 1, 1, 0.06)

                Rectangle {
                    width: parent.width * (blPopup.brightness / 100); height: parent.height; radius: 4
                    color: blPopup.yellow
                    Behavior on width { NumberAnimation { duration: 100 } }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: mouse => {
                        var pct = Math.round(mouse.x / parent.width * 100);
                        pct = Math.max(1, Math.min(100, pct));
                        blSetProc.command = ["brightnessctl", "s", pct + "%"];
                        blSetProc.running = true;
                    }
                    onPositionChanged: mouse => {
                        if (pressed) {
                            var pct = Math.round(mouse.x / parent.width * 100);
                            pct = Math.max(1, Math.min(100, pct));
                            blPopup.brightness = pct;
                            blSetProc.command = ["brightnessctl", "s", pct + "%"];
                            blSetProc.running = true;
                        }
                    }
                }
            }

            // Value display + input
            Row {
                spacing: 8
                Rectangle {
                    width: 60; height: 30; radius: 8
                    color: Qt.rgba(1, 1, 1, 0.06); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08)
                    TextInput {
                        id: blInput; anchors.centerIn: parent
                        text: blPopup.brightness; color: blPopup.fg
                        font { pixelSize: 14; family: blPopup.fontFamily }
                        horizontalAlignment: TextInput.AlignHCenter
                        maximumLength: 3; inputMethodHints: Qt.ImhDigitsOnly
                        onAccepted: {
                            var v = Math.max(1, Math.min(100, parseInt(text) || 1));
                            blPopup.brightness = v;
                            blSetProc.command = ["brightnessctl", "s", v + "%"];
                            blSetProc.running = true;
                        }
                    }
                }
                Text { text: "%"; color: blPopup.dim; font { pixelSize: 14; family: blPopup.fontFamily }
                    anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }

    Process { id: blSetProc }
    Shortcut { sequence: "Escape"; onActivated: blPopup.showing = false; enabled: blPopup.showing }
}
