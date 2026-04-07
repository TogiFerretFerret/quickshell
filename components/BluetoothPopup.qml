import Quickshell
import Quickshell.Wayland
import Quickshell.Bluetooth
import QtQuick

PanelWindow {
    id: btPopup

    property color bg: "#111318"
    property color fg: "#e1e2e9"
    property color dim: "#5d6172"
    property color primary: "#a3c9ff"
    property color red: "#f38ba8"
    property color green: "#a6e3a1"
    property string fontFamily: "JetBrainsMono Nerd Font"

    property bool showing: false

    visible: showing
    anchors { top: true; right: true }
    margins.top: 58
    margins.right: 80
    implicitWidth: 320
    implicitHeight: btContent.implicitHeight + 32
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: Qt.rgba(btPopup.bg.r, btPopup.bg.g, btPopup.bg.b, 0.92)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.08)

        Column {
            id: btContent
            anchors.fill: parent; anchors.margins: 16
            spacing: 12

            // Header with toggle
            Row {
                width: parent.width; spacing: 10

                Text {
                    text: String.fromCodePoint(0xf00af) + "  Bluetooth"
                    color: btPopup.fg; font { pixelSize: 16; family: btPopup.fontFamily; bold: true }
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item { width: parent.width - 200; height: 1 }

                // Power toggle
                Rectangle {
                    width: 48; height: 26; radius: 13
                    anchors.verticalCenter: parent.verticalCenter
                    color: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled
                        ? btPopup.primary : Qt.rgba(1,1,1,0.1)
                    Behavior on color { ColorAnimation { duration: 200 } }

                    Rectangle {
                        width: 20; height: 20; radius: 10
                        anchors.verticalCenter: parent.verticalCenter
                        x: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled ? 24 : 4
                        color: btPopup.fg
                        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    }

                    MouseArea { anchors.fill: parent; onClicked: {
                        if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled;
                    }}
                }
            }

            // Separator
            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.06) }

            // Device list
            Text {
                text: "Devices"
                color: btPopup.dim; font { pixelSize: 12; family: btPopup.fontFamily }
                visible: deviceRepeater.count > 0
            }

            Column {
                width: parent.width; spacing: 6

                Repeater {
                    id: deviceRepeater
                    model: Bluetooth.devices

                    Rectangle {
                        required property var modelData
                        width: parent.width; height: 44; radius: 10
                        color: devMA.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.03)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Row {
                            anchors.fill: parent; anchors.margins: 10; spacing: 10
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                text: parent.parent.modelData.connected ? String.fromCodePoint(0xf00b1) : String.fromCodePoint(0xf00af)
                                color: parent.parent.modelData.connected ? btPopup.primary : btPopup.dim
                                font { pixelSize: 16; family: btPopup.fontFamily }
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    text: parent.parent.parent.modelData.name || "Unknown"
                                    color: btPopup.fg; font { pixelSize: 13; family: btPopup.fontFamily }
                                }
                                Text {
                                    text: parent.parent.parent.modelData.connected ? "Connected" + (parent.parent.parent.modelData.battery >= 0 ? " · " + parent.parent.parent.modelData.battery + "%" : "") : "Disconnected"
                                    color: btPopup.dim; font { pixelSize: 10; family: btPopup.fontFamily }
                                }
                            }
                        }

                        MouseArea {
                            id: devMA; anchors.fill: parent; hoverEnabled: true
                            onClicked: parent.modelData.connected = !parent.modelData.connected
                        }
                    }
                }
            }

            // Empty state
            Text {
                visible: deviceRepeater.count === 0
                text: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled ? "No devices paired" : "Bluetooth is off"
                color: btPopup.dim; font { pixelSize: 13; family: btPopup.fontFamily }
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // Scan button
            Rectangle {
                visible: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled
                width: parent.width; height: 36; radius: 10
                color: scanMA.containsMouse ? Qt.rgba(1,1,1,0.1) : Qt.rgba(1,1,1,0.04)
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.discovering ? "Scanning..." : "Scan for devices"
                    color: btPopup.primary; font { pixelSize: 12; family: btPopup.fontFamily }
                }

                MouseArea { id: scanMA; anchors.fill: parent; hoverEnabled: true
                    onClicked: { if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.discovering = !Bluetooth.defaultAdapter.discovering; }
                }
            }
        }
    }
}
