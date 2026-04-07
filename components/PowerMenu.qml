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

    // Fetch uptime + current wallpaper on show
    Process { id: uptimeProc; command: ["sh", "-c", "uptime -p | sed 's/up //'"]
        stdout: SplitParser { onRead: data => { pmWindow.uptimeStr = data.trim(); } } }
    Process { id: wpProc; command: ["sh", "-c", "cat ~/.cache/wallpaper-colors/current 2>/dev/null"]
        stdout: SplitParser { onRead: data => { pmWindow.wallpaperPath = "file://" + data.trim(); } } }

    onShowingChanged: if (showing) { uptimeProc.running = true; wpProc.running = true; }

    // Dark backdrop
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.74)
        opacity: pmWindow.showing ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        MouseArea { anchors.fill: parent; onClicked: pmWindow.showing = false }
    }

    // Center card
    Column {
        anchors.centerIn: parent; spacing: 20
        opacity: pmWindow.showing ? 1.0 : 0.0
        scale: pmWindow.showing ? 1.0 : 0.9
        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }

        // User card with wallpaper bg
        Rectangle {
            width: 360; height: 160; radius: 20; clip: true
            color: Qt.rgba(0.08, 0.08, 0.12, 0.9)
            layer.enabled: true

            Image {
                anchors.fill: parent; fillMode: Image.PreserveAspectCrop
                source: pmWindow.wallpaperPath; opacity: 0.3
            }
            Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.4) }

            Column {
                anchors.centerIn: parent; spacing: 8

                // User icon
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: String.fromCodePoint(0xf0004); color: pmWindow.fg
                    font { pixelSize: 32; family: pmWindow.fontFamily }
                }

                // Username
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Quickshell.env("USER") || "user"
                    color: pmWindow.fg
                    font { pixelSize: 18; family: pmWindow.fontFamily; bold: true }
                }

                // Uptime
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter; spacing: 6
                    Text { text: String.fromCodePoint(0xf0954); color: pmWindow.dim
                        font { pixelSize: 13; family: pmWindow.fontFamily } }
                    Text { text: "Uptime: " + pmWindow.uptimeStr; color: pmWindow.dim
                        font { pixelSize: 13; family: pmWindow.fontFamily } }
                }
            }
        }

        // Power buttons row
        Row {
            anchors.horizontalCenter: parent.horizontalCenter; spacing: 14

            // Lock
            Rectangle {
                width: 64; height: 64; radius: 16
                color: lockMA.containsMouse ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.06)
                Behavior on color { ColorAnimation { duration: 150 } }
                Text { anchors.centerIn: parent; text: String.fromCodePoint(0xf033e)
                    color: pmWindow.green; font { pixelSize: 24; family: pmWindow.fontFamily } }
                MouseArea { id: lockMA; anchors.fill: parent; hoverEnabled: true
                    onClicked: { pmWindow.showing = false; lockProc.running = true; } }
            }

            // Logout
            Rectangle {
                width: 64; height: 64; radius: 16
                color: logMA.containsMouse ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.06)
                Behavior on color { ColorAnimation { duration: 150 } }
                Text { anchors.centerIn: parent; text: String.fromCodePoint(0xf0343)
                    color: pmWindow.yellow; font { pixelSize: 24; family: pmWindow.fontFamily } }
                MouseArea { id: logMA; anchors.fill: parent; hoverEnabled: true
                    onClicked: { pmWindow.showing = false; logoutProc.running = true; } }
            }

            // Shutdown
            Rectangle {
                width: 64; height: 64; radius: 16
                color: sdMA.containsMouse ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.06)
                Behavior on color { ColorAnimation { duration: 150 } }
                Text { anchors.centerIn: parent; text: String.fromCodePoint(0xf0425)
                    color: pmWindow.red; font { pixelSize: 24; family: pmWindow.fontFamily } }
                MouseArea { id: sdMA; anchors.fill: parent; hoverEnabled: true
                    onClicked: { pmWindow.showing = false; shutdownProc.running = true; } }
            }
        }

        // Bottom row
        Row {
            anchors.horizontalCenter: parent.horizontalCenter; spacing: 14

            // Reboot
            Rectangle {
                width: 64; height: 64; radius: 16
                color: rbMA.containsMouse ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.06)
                Behavior on color { ColorAnimation { duration: 150 } }
                Text { anchors.centerIn: parent; text: String.fromCodePoint(0xf0709)
                    color: pmWindow.primary; font { pixelSize: 24; family: pmWindow.fontFamily } }
                MouseArea { id: rbMA; anchors.fill: parent; hoverEnabled: true
                    onClicked: { pmWindow.showing = false; rebootProc.running = true; } }
            }

            // Sleep
            Rectangle {
                width: 64; height: 64; radius: 16
                color: slMA.containsMouse ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.06)
                Behavior on color { ColorAnimation { duration: 150 } }
                Text { anchors.centerIn: parent; text: String.fromCodePoint(0xf04b2)
                    color: pmWindow.cyan; font { pixelSize: 24; family: pmWindow.fontFamily } }
                MouseArea { id: slMA; anchors.fill: parent; hoverEnabled: true
                    onClicked: { pmWindow.showing = false; sleepProc.running = true; } }
            }

            // Hibernate
            Rectangle {
                width: 64; height: 64; radius: 16
                color: hibMA.containsMouse ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.06)
                Behavior on color { ColorAnimation { duration: 150 } }
                Text { anchors.centerIn: parent; text: String.fromCodePoint(0xf06c6)
                    color: pmWindow.purple; font { pixelSize: 24; family: pmWindow.fontFamily } }
                MouseArea { id: hibMA; anchors.fill: parent; hoverEnabled: true
                    onClicked: { pmWindow.showing = false; hibProc.running = true; } }
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
