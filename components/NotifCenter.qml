import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: ncWindow

    property color bg: "#111318"
    property color fg: "#e1e2e9"
    property color dim: "#5d6172"
    property color primary: "#a3c9ff"
    property color accent: "#2393D7"
    property color red: "#f38ba8"
    property string fontFamily: "JetBrainsMono Nerd Font"

    property bool showing: false
    property bool dndActive: false
    property var notifHistory: ListModel {}

    signal dndToggled()
    signal clearAll()
    signal dismissOne(int idx)

    visible: showing
    anchors { top: true; right: true }
    margins.top: 50; margins.right: 10
    implicitWidth: 400
    implicitHeight: Math.min(ncContent.implicitHeight + 32, 700)
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
        anchors.fill: parent; radius: 18
        color: Qt.rgba(ncWindow.bg.r, ncWindow.bg.g, ncWindow.bg.b, 0.95)
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08)

        Column {
            id: ncContent
            anchors.fill: parent; anchors.margins: 16
            spacing: 12

            // ── Header ──
            Row {
                width: parent.width; spacing: 10

                Text {
                    text: "Notifications"
                    color: ncWindow.fg
                    font { pixelSize: 16; family: ncWindow.fontFamily; bold: true }
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item { width: parent.width - 250; height: 1 }

                // Clear all button
                Rectangle {
                    width: 60; height: 28; radius: 10
                    color: clearMA.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08)
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent; text: "Clear"
                        color: clearMA.containsMouse ? ncWindow.primary : ncWindow.dim
                        font { pixelSize: 11; family: ncWindow.fontFamily }
                    }

                    MouseArea {
                        id: clearMA; anchors.fill: parent; hoverEnabled: true
                        onClicked: ncWindow.clearAll()
                    }
                }
            }

            // ── DnD Toggle ──
            Rectangle {
                width: parent.width; height: 44; radius: 12
                color: Qt.rgba(1, 1, 1, 0.04)
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.06)

                Row {
                    anchors.fill: parent; anchors.margins: 10; spacing: 10

                    Text {
                        text: "Do Not Disturb"
                        color: ncWindow.fg
                        font { pixelSize: 13; family: ncWindow.fontFamily }
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Item { width: parent.width - 190; height: 1 }

                    Rectangle {
                        width: 48; height: 26; radius: 13
                        anchors.verticalCenter: parent.verticalCenter
                        color: ncWindow.dndActive ? ncWindow.primary : Qt.rgba(1, 1, 1, 0.1)
                        Behavior on color { ColorAnimation { duration: 200 } }

                        Rectangle {
                            width: 20; height: 20; radius: 10; color: ncWindow.fg
                            anchors.verticalCenter: parent.verticalCenter
                            x: ncWindow.dndActive ? 24 : 4
                            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        }

                        MouseArea { anchors.fill: parent; onClicked: ncWindow.dndToggled() }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.06) }

            // ── Notification List ──
            Flickable {
                width: parent.width
                height: Math.min(notifCol.implicitHeight, 520)
                contentHeight: notifCol.implicitHeight
                clip: true; boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: notifCol
                    width: parent.width; spacing: 6

                    Repeater {
                        model: ncWindow.notifHistory

                        Rectangle {
                            id: notifCard
                            required property var model
                            required property int index
                            width: parent.width
                            height: notifCardContent.implicitHeight + 20
                            radius: 12
                            color: notifCardMA.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.03)
                            border.width: 1
                            border.color: model.urgency === 2
                                ? Qt.rgba(ncWindow.red.r, ncWindow.red.g, ncWindow.red.b, 0.3)
                                : Qt.rgba(1, 1, 1, 0.06)
                            Behavior on color { ColorAnimation { duration: 150 } }

                            MouseArea { id: notifCardMA; anchors.fill: parent; hoverEnabled: true; z: -1 }

                            Column {
                                id: notifCardContent
                                anchors.fill: parent; anchors.margins: 10
                                spacing: 3

                                // App name + time + close
                                Row {
                                    width: parent.width; spacing: 6

                                    Text {
                                        text: model.appName || ""
                                        color: ncWindow.dim
                                        font { pixelSize: 10; family: ncWindow.fontFamily }
                                        elide: Text.ElideRight
                                        width: parent.width - timeText.implicitWidth - ncCloseBtn.width - 16
                                    }

                                    Text {
                                        id: timeText
                                        text: {
                                            if (!model.time) return "";
                                            var d = model.time;
                                            return Qt.formatDateTime(d, "hh:mm");
                                        }
                                        color: Qt.rgba(ncWindow.fg.r, ncWindow.fg.g, ncWindow.fg.b, 0.5)
                                        font { pixelSize: 10; family: ncWindow.fontFamily }
                                    }

                                    Rectangle {
                                        id: ncCloseBtn
                                        width: 18; height: 18; radius: 9
                                        color: ncCloseBtnMA.containsMouse ? ncWindow.red : Qt.rgba(1, 1, 1, 0.08)
                                        visible: notifCardMA.containsMouse
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        Text {
                                            anchors.centerIn: parent; text: "×"
                                            color: ncCloseBtnMA.containsMouse ? ncWindow.bg : ncWindow.dim
                                            font { pixelSize: 12; family: ncWindow.fontFamily; bold: true }
                                        }
                                        MouseArea {
                                            id: ncCloseBtnMA; anchors.fill: parent; hoverEnabled: true
                                            onClicked: ncWindow.dismissOne(notifCard.index)
                                        }
                                    }
                                }

                                // Summary
                                Text {
                                    text: model.summary || ""
                                    color: ncWindow.fg
                                    font { pixelSize: 13; family: ncWindow.fontFamily; bold: true }
                                    elide: Text.ElideRight; width: parent.width
                                    visible: text !== ""
                                }

                                // Body
                                Text {
                                    text: model.body || ""
                                    color: Qt.rgba(ncWindow.fg.r, ncWindow.fg.g, ncWindow.fg.b, 0.8)
                                    font { pixelSize: 11; family: ncWindow.fontFamily }
                                    wrapMode: Text.WordWrap; width: parent.width
                                    maximumLineCount: 3; elide: Text.ElideRight
                                    visible: text !== ""
                                }
                            }
                        }
                    }
                }
            }

            // ── Empty state ──
            Column {
                visible: ncWindow.notifHistory.count === 0
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                Item { width: 1; height: 20 }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: String.fromCodePoint(0xf009a)
                    color: ncWindow.dim; font { pixelSize: 40; family: ncWindow.fontFamily }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No Notifications"
                    color: ncWindow.dim; font { pixelSize: 14; family: ncWindow.fontFamily }
                }

                Item { width: 1; height: 20 }
            }
        }
    }

    Shortcut { sequence: "Escape"; onActivated: ncWindow.showing = false; enabled: ncWindow.showing }
}
