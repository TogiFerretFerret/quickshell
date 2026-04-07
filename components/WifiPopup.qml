import Quickshell
import Quickshell.Wayland
import Quickshell.Networking
import Quickshell.Io
import QtQuick

PanelWindow {
    id: wifiPopup

    property color bg: "#111318"
    property color fg: "#e1e2e9"
    property color dim: "#5d6172"
    property color primary: "#a3c9ff"
    property color green: "#a6e3a1"
    property color red: "#f38ba8"
    property string fontFamily: "JetBrainsMono Nerd Font"
    property bool showing: false

    property var wifiDev: {
        var devs = Networking.devices ? Networking.devices.values : [];
        for (var i = 0; i < devs.length; i++)
            if (devs[i].type === DeviceType.Wifi) return devs[i];
        return null;
    }

    visible: showing
    anchors { top: true; right: true }
    margins.top: 56; margins.right: 10
    implicitWidth: 320; implicitHeight: wifiContent.implicitHeight + 32
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore

    onShowingChanged: { if (showing && wifiDev) wifiDev.scannerEnabled = true; }

    Process { id: nmConnect; property string ssid: ""
        command: ["nmcli", "device", "wifi", "connect", ssid] }
    Process { id: nmDisconnect
        command: ["nmcli", "device", "disconnect", wifiDev ? wifiDev.name : "wlan0"] }

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
                        width: parent.width; height: 44; radius: 10
                        color: netMA.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.03)
                        visible: modelData.name !== ""
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Row {
                            anchors.fill: parent; anchors.margins: 10; spacing: 8

                            // Signal strength bars
                            Text {
                                text: {
                                    var s = modelData.signalStrength;
                                    if (s > 0.75) return String.fromCodePoint(0xf0928);
                                    if (s > 0.5) return String.fromCodePoint(0xf0925);
                                    if (s > 0.25) return String.fromCodePoint(0xf0922);
                                    return String.fromCodePoint(0xf091f);
                                }
                                color: modelData.connected ? wifiPopup.green : wifiPopup.dim
                                font { pixelSize: 16; family: wifiPopup.fontFamily }
                            }

                            Column {
                                width: parent.width - 80
                                Text { text: modelData.name; color: wifiPopup.fg; elide: Text.ElideRight; width: parent.width
                                    font { pixelSize: 13; family: wifiPopup.fontFamily } }
                                Text {
                                    text: {
                                        if (modelData.stateChanging) return "Connecting...";
                                        if (modelData.connected) return "Connected · " + Math.round(modelData.signalStrength * 100) + "%";
                                        var sec = modelData.security;
                                        var secStr = sec === WifiSecurityType.Open ? "Open" : "Secured";
                                        return secStr + " · " + Math.round(modelData.signalStrength * 100) + "%";
                                    }
                                    color: modelData.connected ? wifiPopup.green : wifiPopup.dim
                                    font { pixelSize: 10; family: wifiPopup.fontFamily } }
                            }

                            // Connect/Disconnect button
                            Rectangle {
                                width: 24; height: 24; radius: 12
                                anchors.verticalCenter: parent.verticalCenter
                                color: netMA2.containsMouse ? Qt.rgba(1,1,1,0.15) : Qt.rgba(1,1,1,0.05)
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Text { anchors.centerIn: parent
                                    text: modelData.connected ? String.fromCodePoint(0xf0159) : String.fromCodePoint(0xf0156)
                                    color: modelData.connected ? wifiPopup.red : wifiPopup.green
                                    font { pixelSize: 12; family: wifiPopup.fontFamily } }
                                MouseArea { id: netMA2; anchors.fill: parent; hoverEnabled: true
                                    onClicked: {
                                        if (modelData.connected) { nmDisconnect.running = true; }
                                        else { nmConnect.ssid = modelData.name; nmConnect.running = true; }
                                    }
                                }
                            }
                        }

                        MouseArea { id: netMA; anchors.fill: parent; hoverEnabled: true; z: -1
                            onClicked: {
                                if (modelData.connected) { nmDisconnect.running = true; }
                                else { nmConnect.ssid = modelData.name; nmConnect.running = true; }
                            }
                        }
                    }
                }
            }

            Text { visible: !wifiPopup.wifiDev || !Networking.wifiEnabled
                text: "WiFi is off"; color: wifiPopup.dim
                font { pixelSize: 13; family: wifiPopup.fontFamily } }

            // Scan button
            Rectangle {
                visible: Networking.wifiEnabled && wifiPopup.wifiDev
                width: parent.width; height: 34; radius: 10
                color: scanMA.containsMouse ? Qt.rgba(1,1,1,0.1) : Qt.rgba(1,1,1,0.04)
                Behavior on color { ColorAnimation { duration: 150 } }
                Text { anchors.centerIn: parent
                    text: wifiPopup.wifiDev && wifiPopup.wifiDev.scannerEnabled ? "Scanning..." : "Scan"
                    color: wifiPopup.primary; font { pixelSize: 12; family: wifiPopup.fontFamily } }
                MouseArea { id: scanMA; anchors.fill: parent; hoverEnabled: true
                    onClicked: { if (wifiPopup.wifiDev) wifiPopup.wifiDev.scannerEnabled = !wifiPopup.wifiDev.scannerEnabled; } }
            }
        }
    }

    Shortcut { sequence: "Escape"; onActivated: wifiPopup.showing = false; enabled: wifiPopup.showing }
}
