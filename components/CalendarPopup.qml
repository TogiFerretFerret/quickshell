import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: calPopup

    property color bg: "#111318"
    property color fg: "#e1e2e9"
    property color dim: "#5d6172"
    property color primary: "#a3c9ff"
    property string fontFamily: "JetBrainsMono Nerd Font"

    property bool showing: false
    property var currentDate: new Date()

    visible: showing
    anchors { top: true; right: true }
    margins.top: 58
    margins.right: 10
    implicitWidth: 320
    implicitHeight: 340
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore

    // Background
    Rectangle {
        anchors.fill: parent
        radius: 16
        color: Qt.rgba(calPopup.bg.r, calPopup.bg.g, calPopup.bg.b, 0.92)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.08)

        // Month/Year header
        Row {
            id: header
            anchors.top: parent.top; anchors.topMargin: 16
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 20

            Text {
                text: "<"; color: calPopup.dim; font { pixelSize: 18; family: calPopup.fontFamily; bold: true }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var d = calPopup.currentDate;
                        calPopup.currentDate = new Date(d.getFullYear(), d.getMonth() - 1, 1);
                    }
                }
            }

            Text {
                text: Qt.formatDateTime(calPopup.currentDate, "MMMM yyyy")
                color: calPopup.fg; font { pixelSize: 16; family: calPopup.fontFamily; bold: true }
                width: 180; horizontalAlignment: Text.AlignHCenter
            }

            Text {
                text: ">"; color: calPopup.dim; font { pixelSize: 18; family: calPopup.fontFamily; bold: true }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var d = calPopup.currentDate;
                        calPopup.currentDate = new Date(d.getFullYear(), d.getMonth() + 1, 1);
                    }
                }
            }
        }

        // Day of week headers
        Row {
            id: dowHeader
            anchors.top: header.bottom; anchors.topMargin: 16
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 0
            Repeater {
                model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                Text {
                    width: 40; horizontalAlignment: Text.AlignHCenter
                    text: modelData; color: calPopup.dim
                    font { pixelSize: 12; family: calPopup.fontFamily; bold: true }
                }
            }
        }

        // Day grid
        Grid {
            id: dayGrid
            anchors.top: dowHeader.bottom; anchors.topMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            columns: 7; spacing: 0

            Repeater {
                model: 42
                Rectangle {
                    required property int index
                    property int dayNum: {
                        var d = calPopup.currentDate;
                        var first = new Date(d.getFullYear(), d.getMonth(), 1);
                        var startOff = first.getDay() === 0 ? 6 : first.getDay() - 1; // Monday start
                        var lastDay = new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate();
                        var num = index - startOff + 1;
                        return (num >= 1 && num <= lastDay) ? num : 0;
                    }
                    property bool isToday: {
                        var now = new Date();
                        var d = calPopup.currentDate;
                        return dayNum > 0 && now.getDate() === dayNum &&
                               now.getMonth() === d.getMonth() && now.getFullYear() === d.getFullYear();
                    }

                    width: 40; height: 36; radius: 10
                    color: isToday ? calPopup.primary : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: parent.dayNum > 0 ? parent.dayNum : ""
                        color: parent.isToday ? calPopup.bg : parent.dayNum > 0 ? calPopup.fg : "transparent"
                        font { pixelSize: 13; family: calPopup.fontFamily; bold: parent.isToday }
                    }
                }
            }
        }

        // Today button
        Text {
            anchors.bottom: parent.bottom; anchors.bottomMargin: 12
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Today"; color: calPopup.primary
            font { pixelSize: 12; family: calPopup.fontFamily }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: calPopup.currentDate = new Date() }
        }
    }

    // Click outside to close
    MouseArea {
        anchors.fill: parent
        onClicked: calPopup.showing = false
        z: -1
    }
}
