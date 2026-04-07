import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

PanelWindow {
    id: pmWindow

    property color bg: "#0e1120"
    property color primary: "#a3c9ff"
    property color fg: "#e1e2e9"
    property color dim: "#5d6172"
    property color red: "#f38ba8"
    property color green: "#a6e3a1"
    property color yellow: "#f9e2af"
    property color purple: "#cba6f7"
    property color cyan: "#94e2d5"
    property string fontFamily: "JetBrainsMono Nerd Font"

    property bool showing: false
    property string uptimeStr: ""
    property string wallpaperPath: ""

    visible: showing
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    color: "transparent"

    Process { id: uptimeProc; command: ["sh", "-c", "uptime -p | sed 's/up //'"]
        stdout: SplitParser { onRead: data => { pmWindow.uptimeStr = data.trim(); } } }
    Process { id: wpProc; command: ["sh", "-c", "cat ~/.cache/wallpaper-colors/current 2>/dev/null"]
        stdout: SplitParser { onRead: data => { pmWindow.wallpaperPath = "file://" + data.trim(); } } }

    onShowingChanged: if (showing) { uptimeProc.running = true; wpProc.running = true; }

    // Click outside to dismiss
    MouseArea { anchors.fill: parent; onClicked: pmWindow.showing = false }

    // Main card
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 420; height: 380; radius: 24
        color: pmWindow.bg
        border.width: 2; border.color: Qt.rgba(pmWindow.primary.r, pmWindow.primary.g, pmWindow.primary.b, 0.3)
        opacity: pmWindow.showing ? 1.0 : 0.0
        scale: pmWindow.showing ? 1.0 : 0.9
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

        // Wallpaper banner (top, clipped to top radius)
        Item {
            id: banner
            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
            height: 150; clip: true

            // Rounded top mask
            Rectangle {
                anchors.fill: parent; radius: 24
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: parent.radius; color: parent.color }
                color: pmWindow.bg; clip: true; layer.enabled: true

                Image {
                    anchors.fill: parent; fillMode: Image.PreserveAspectCrop
                    source: pmWindow.wallpaperPath; opacity: 0.6
                }
                Rectangle { anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: pmWindow.bg }
                    }
                }
            }

            // User info overlaid on banner
            Column {
                anchors.centerIn: parent; spacing: 6

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: String.fromCodePoint(0xf0004)
                    color: pmWindow.fg; font { pixelSize: 36; family: pmWindow.fontFamily }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Quickshell.env("USER") || "user"
                    color: pmWindow.fg
                    font { pixelSize: 20; family: pmWindow.fontFamily; bold: true }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter; spacing: 6
                    Text { text: String.fromCodePoint(0xf0954); color: pmWindow.dim
                        font { pixelSize: 13; family: pmWindow.fontFamily } }
                    Text { text: "Uptime: " + pmWindow.uptimeStr; color: pmWindow.dim
                        font { pixelSize: 13; family: pmWindow.fontFamily } }
                }
            }
        }

        // Power buttons - 2 rows of 3
        Column {
            anchors.top: banner.bottom; anchors.topMargin: 16
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 14

            Row {
                anchors.horizontalCenter: parent.horizontalCenter; spacing: 14

                Repeater {
                    model: [
                        { icon: 0xf033e, color: pmWindow.green, label: "Lock", key: "l", proc: "lockProc" },
                        { icon: 0xf0343, color: pmWindow.yellow, label: "Logout", key: "e", proc: "logoutProc" },
                        { icon: 0xf0425, color: pmWindow.red, label: "Shutdown", key: "s", proc: "shutdownProc" }
                    ]

                    Rectangle {
                        required property var modelData
                        width: 110; height: 80; radius: 16
                        color: btnMA.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.03)
                        border.width: 1; border.color: btnMA.containsMouse ? Qt.rgba(modelData.color.r, modelData.color.g, modelData.color.b, 0.4) : Qt.rgba(1,1,1,0.06)
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                        scale: btnMA.containsMouse ? 1.03 : 1.0
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }

                        Column { anchors.centerIn: parent; spacing: 6
                            Text { anchors.horizontalCenter: parent.horizontalCenter
                                text: String.fromCodePoint(parent.parent.modelData.icon)
                                color: parent.parent.modelData.color
                                font { pixelSize: 26; family: pmWindow.fontFamily } }
                            Text { anchors.horizontalCenter: parent.horizontalCenter
                                text: parent.parent.modelData.label; color: pmWindow.dim
                                font { pixelSize: 11; family: pmWindow.fontFamily } }
                        }

                        MouseArea { id: btnMA; anchors.fill: parent; hoverEnabled: true
                            onClicked: { pmWindow.showing = false;
                                var p = parent.modelData.proc;
                                if (p === "lockProc") lockProc.running = true;
                                else if (p === "logoutProc") logoutProc.running = true;
                                else if (p === "shutdownProc") shutdownProc.running = true;
                            }
                        }
                    }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter; spacing: 14

                Repeater {
                    model: [
                        { icon: 0xf0709, color: pmWindow.primary, label: "Reboot", key: "r", proc: "rebootProc" },
                        { icon: 0xf04b2, color: pmWindow.cyan, label: "Sleep", key: "p", proc: "sleepProc" },
                        { icon: 0xf0717, color: pmWindow.purple, label: "Hibernate", key: "h", proc: "hibProc" }
                    ]

                    Rectangle {
                        required property var modelData
                        width: 110; height: 80; radius: 16
                        color: btnMA2.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.03)
                        border.width: 1; border.color: btnMA2.containsMouse ? Qt.rgba(modelData.color.r, modelData.color.g, modelData.color.b, 0.4) : Qt.rgba(1,1,1,0.06)
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                        scale: btnMA2.containsMouse ? 1.03 : 1.0
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }

                        Column { anchors.centerIn: parent; spacing: 6
                            Text { anchors.horizontalCenter: parent.horizontalCenter
                                text: String.fromCodePoint(parent.parent.modelData.icon)
                                color: parent.parent.modelData.color
                                font { pixelSize: 26; family: pmWindow.fontFamily } }
                            Text { anchors.horizontalCenter: parent.horizontalCenter
                                text: parent.parent.modelData.label; color: pmWindow.dim
                                font { pixelSize: 11; family: pmWindow.fontFamily } }
                        }

                        MouseArea { id: btnMA2; anchors.fill: parent; hoverEnabled: true
                            onClicked: { pmWindow.showing = false;
                                var p = parent.modelData.proc;
                                if (p === "rebootProc") rebootProc.running = true;
                                else if (p === "sleepProc") sleepProc.running = true;
                                else if (p === "hibProc") hibProc.running = true;
                            }
                        }
                    }
                }
            }
        }
    }

    // Processes
    Process { id: shutdownProc; command: ["shutdown", "now"] }
    Process { id: rebootProc; command: ["reboot"] }
    Process { id: lockProc; command: ["sh", "-c", "sleep 0.5; hyprlock"] }
    Process { id: logoutProc; command: ["sh", "-c", "sudo systemctl restart sddm; hyprctl dispatch exit 0"] }
    Process { id: sleepProc; command: ["systemctl", "suspend"] }
    Process { id: hibProc; command: ["systemctl", "hibernate"] }

    // Keyboard
    Shortcut { sequence: "Escape"; onActivated: pmWindow.showing = false }
    Shortcut { sequence: "s"; onActivated: { pmWindow.showing = false; shutdownProc.running = true; } }
    Shortcut { sequence: "r"; onActivated: { pmWindow.showing = false; rebootProc.running = true; } }
    Shortcut { sequence: "l"; onActivated: { pmWindow.showing = false; lockProc.running = true; } }
    Shortcut { sequence: "e"; onActivated: { pmWindow.showing = false; logoutProc.running = true; } }
    Shortcut { sequence: "p"; onActivated: { pmWindow.showing = false; sleepProc.running = true; } }
    Shortcut { sequence: "h"; onActivated: { pmWindow.showing = false; hibProc.running = true; } }
}
