import Quickshell
import Quickshell.Wayland
import Quickshell.Networking
import QtQuick

PanelWindow {
    id: wifiPopup

    property color bg: "#111318"
    property color fg: "#e1e2e9"
    property color dim: "#5d6172"
    property color primary: "#a3c9ff"
    property color green: "#a6e3a1"
    property string fontFamily: "JetBrainsMono Nerd Font"
    property bool showing: false

    // Find wifi device
    property var wifiDev: {
        var devs = Networking.devices ? Networking.devices.values : [];
        for (var i = 0; i < devs.length; i++)
            if (devs[i].type === DeviceType.Wifi) return devs[i];
        return null;
    }

    visible: showing
    anchors { top: true; right: true }
    margins.top: 58; margins.right: 10
    implicitWidth: 320; implicitHeight: wifiContent.implicitHeight + 32
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore

    onShowingChanged: { if (showing && wifiDev) wifiDev.scannerEnabled = true; }

    Rectangle {
        anchors.fill: parent; radius: 14
        color: Qt.rgba(wifiPopup.bg.r, wifiPopup.bg.g, wifiPopup.bg.b, 0.94)
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08)

        Column {
            id: wifiContent
            anchors.fill: parent; anchors.margins: 16; spacing: 10

            // Header with toggle
            Row {
                width: parent.width; spacing: 10
                Text { text: String.fromCodePoint(0xf05a9) + "  WiFi"
                    color: wifiPopup.fg; font { pixelSize: 16; family: wifiPopup.fontFamily; bold: true } }
                Item { width: parent.width - 160; height: 1 }
                Rectangle {
                    width: 48; height: 26; radius: 13
                    color: Networking.wifiEnabled ? wifiPopup.primary : Qt.rgba(1,1,1,0.1)
                    Behavior on color { ColorAnimation { duration: 200 } }
                    Rectangle {
                        width: 20; height: 20; radius: 10; color: wifiPopup.fg
                        x: Networking.wifiEnabled ? 24 : 4
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    }
                    MouseArea { anchors.fill: parent; onClicked: Networking.wifiEnabled = !Networking.wifiEnabled }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.06) }

            // Network list
            Column {
                width: parent.width; spacing: 4
                visible: wifiPopup.wifiDev !== null

                Repeater {
                    model: wifiPopup.wifiDev ? wifiPopup.wifiDev.networks : []

                    Rectangle {
                        required property var modelData
                        width: parent.width; height: 40; radius: 10
                        color: netMA.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.03)
                        visible: modelData.name !== ""
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Row {
                            anchors.fill: parent; anchors.margins: 10; spacing: 8

                            // Signal icon
                            Text {
                                text: {
                                    var s = modelData.signalStrength;
                                    if (s > 0.75) return String.fromCodePoint(0xf05a9);
                                    if (s > 0.5) return String.fromCodePoint(0xf05a9);
                                    if (s > 0.25) return String.fromCodePoint(0xf05a9);
                                    return String.fromCodePoint(0xf05a9);
                                }
                                color: modelData.connected ? wifiPopup.green : wifiPopup.dim
                                font { pixelSize: 14; family: wifiPopup.fontFamily }
                            }

                            Column {
                                Text { text: modelData.name; color: wifiPopup.fg
                                    font { pixelSize: 13; family: wifiPopup.fontFamily } }
                                Text {
                                    text: modelData.connected ? "Connected" : Math.round(modelData.signalStrength * 100) + "%"
                                    color: modelData.connected ? wifiPopup.green : wifiPopup.dim
                                    font { pixelSize: 10; family: wifiPopup.fontFamily } }
                            }
                        }

                        MouseArea { id: netMA; anchors.fill: parent; hoverEnabled: true }
                    }
                }
            }

            Text { visible: !wifiPopup.wifiDev || !Networking.wifiEnabled
                text: "WiFi is off"; color: wifiPopup.dim
                font { pixelSize: 13; family: wifiPopup.fontFamily } }
        }
    }

    Shortcut { sequence: "Escape"; onActivated: wifiPopup.showing = false; enabled: wifiPopup.showing }
}
