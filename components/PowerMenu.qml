import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

// Fullscreen power menu overlay
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

    visible: showing
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    color: "transparent"

    // Dark backdrop
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.65)
        opacity: pmWindow.showing ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        MouseArea {
            anchors.fill: parent
            onClicked: pmWindow.showing = false
        }
    }

    // Title
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.2
        text: "Power Menu"
        color: pmWindow.fg
        font { pixelSize: 28; family: pmWindow.fontFamily; bold: true }
        opacity: pmWindow.showing ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 300 } }
    }

    // Button grid
    Row {
        anchors.centerIn: parent
        spacing: 30
        opacity: pmWindow.showing ? 1.0 : 0.0
        scale: pmWindow.showing ? 1.0 : 0.85
        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }

        // Shutdown
        Rectangle {
            width: 140; height: 160; radius: 24
            color: shutdownMA.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.04)
            border.width: 2; border.color: shutdownMA.containsMouse ? pmWindow.red : Qt.rgba(1, 1, 1, 0.08)
            scale: shutdownMA.containsMouse ? 1.05 : 1.0
            Behavior on color { ColorAnimation { duration: 200 } }
            Behavior on border.color { ColorAnimation { duration: 200 } }
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
            Column { anchors.centerIn: parent; spacing: 12
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: String.fromCodePoint(0xf0425)
                    color: pmWindow.red; font { pixelSize: 42; family: pmWindow.fontFamily } }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Shutdown"
                    color: pmWindow.fg; font { pixelSize: 14; family: pmWindow.fontFamily } }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "S"
                    color: pmWindow.dim; font { pixelSize: 11; family: pmWindow.fontFamily } }
            }
            MouseArea { id: shutdownMA; anchors.fill: parent; hoverEnabled: true
                onClicked: { pmWindow.showing = false; shutdownProc.running = true; } }
            Process { id: shutdownProc; command: ["shutdown", "now"] }
        }

        // Reboot
        Rectangle {
            width: 140; height: 160; radius: 24
            color: rebootMA.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.04)
            border.width: 2; border.color: rebootMA.containsMouse ? pmWindow.primary : Qt.rgba(1, 1, 1, 0.08)
            scale: rebootMA.containsMouse ? 1.05 : 1.0
            Behavior on color { ColorAnimation { duration: 200 } }
            Behavior on border.color { ColorAnimation { duration: 200 } }
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
            Column { anchors.centerIn: parent; spacing: 12
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: String.fromCodePoint(0xf0709)
                    color: pmWindow.primary; font { pixelSize: 42; family: pmWindow.fontFamily } }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Reboot"
                    color: pmWindow.fg; font { pixelSize: 14; family: pmWindow.fontFamily } }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "R"
                    color: pmWindow.dim; font { pixelSize: 11; family: pmWindow.fontFamily } }
            }
            MouseArea { id: rebootMA; anchors.fill: parent; hoverEnabled: true
                onClicked: { pmWindow.showing = false; rebootProc.running = true; } }
            Process { id: rebootProc; command: ["reboot"] }
        }

        // Lock
        Rectangle {
            width: 140; height: 160; radius: 24
            color: lockMA.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.04)
            border.width: 2; border.color: lockMA.containsMouse ? pmWindow.green : Qt.rgba(1, 1, 1, 0.08)
            scale: lockMA.containsMouse ? 1.05 : 1.0
            Behavior on color { ColorAnimation { duration: 200 } }
            Behavior on border.color { ColorAnimation { duration: 200 } }
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
            Column { anchors.centerIn: parent; spacing: 12
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: String.fromCodePoint(0xf033e)
                    color: pmWindow.green; font { pixelSize: 42; family: pmWindow.fontFamily } }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Lock"
                    color: pmWindow.fg; font { pixelSize: 14; family: pmWindow.fontFamily } }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "L"
                    color: pmWindow.dim; font { pixelSize: 11; family: pmWindow.fontFamily } }
            }
            MouseArea { id: lockMA; anchors.fill: parent; hoverEnabled: true
                onClicked: { pmWindow.showing = false; lockProc.running = true; } }
            Process { id: lockProc; command: ["sh", "-c", "sleep 0.5; hyprlock"] }
        }

        // Logout
        Rectangle {
            width: 140; height: 160; radius: 24
            color: logoutMA.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.04)
            border.width: 2; border.color: logoutMA.containsMouse ? pmWindow.yellow : Qt.rgba(1, 1, 1, 0.08)
            scale: logoutMA.containsMouse ? 1.05 : 1.0
            Behavior on color { ColorAnimation { duration: 200 } }
            Behavior on border.color { ColorAnimation { duration: 200 } }
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
            Column { anchors.centerIn: parent; spacing: 12
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: String.fromCodePoint(0xf0343)
                    color: pmWindow.yellow; font { pixelSize: 42; family: pmWindow.fontFamily } }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Logout"
                    color: pmWindow.fg; font { pixelSize: 14; family: pmWindow.fontFamily } }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "E"
                    color: pmWindow.dim; font { pixelSize: 11; family: pmWindow.fontFamily } }
            }
            MouseArea { id: logoutMA; anchors.fill: parent; hoverEnabled: true
                onClicked: { pmWindow.showing = false; logoutProc.running = true; } }
            Process { id: logoutProc; command: ["sh", "-c", "sudo systemctl restart sddm; hyprctl dispatch exit 0"] }
        }

        // Sleep
        Rectangle {
            width: 140; height: 160; radius: 24
            color: sleepMA.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.04)
            border.width: 2; border.color: sleepMA.containsMouse ? pmWindow.cyan : Qt.rgba(1, 1, 1, 0.08)
            scale: sleepMA.containsMouse ? 1.05 : 1.0
            Behavior on color { ColorAnimation { duration: 200 } }
            Behavior on border.color { ColorAnimation { duration: 200 } }
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
            Column { anchors.centerIn: parent; spacing: 12
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: String.fromCodePoint(0xf04b2)
                    color: pmWindow.cyan; font { pixelSize: 42; family: pmWindow.fontFamily } }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Sleep"
                    color: pmWindow.fg; font { pixelSize: 14; family: pmWindow.fontFamily } }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "P"
                    color: pmWindow.dim; font { pixelSize: 11; family: pmWindow.fontFamily } }
            }
            MouseArea { id: sleepMA; anchors.fill: parent; hoverEnabled: true
                onClicked: { pmWindow.showing = false; sleepProc.running = true; } }
            Process { id: sleepProc; command: ["systemctl", "suspend"] }
        }

        // Hibernate
        Rectangle {
            width: 140; height: 160; radius: 24
            color: hibMA.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.04)
            border.width: 2; border.color: hibMA.containsMouse ? pmWindow.purple : Qt.rgba(1, 1, 1, 0.08)
            scale: hibMA.containsMouse ? 1.05 : 1.0
            Behavior on color { ColorAnimation { duration: 200 } }
            Behavior on border.color { ColorAnimation { duration: 200 } }
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
            Column { anchors.centerIn: parent; spacing: 12
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: String.fromCodePoint(0xf06c6)
                    color: pmWindow.purple; font { pixelSize: 42; family: pmWindow.fontFamily } }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Hibernate"
                    color: pmWindow.fg; font { pixelSize: 14; family: pmWindow.fontFamily } }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "H"
                    color: pmWindow.dim; font { pixelSize: 11; family: pmWindow.fontFamily } }
            }
            MouseArea { id: hibMA; anchors.fill: parent; hoverEnabled: true
                onClicked: { pmWindow.showing = false; hibProc.running = true; } }
            Process { id: hibProc; command: ["systemctl", "hibernate"] }
        }
    }


    // Keyboard handling
    Shortcut { sequence: "Escape"; onActivated: pmWindow.showing = false }
    Shortcut { sequence: "s"; onActivated: { pmWindow.showing = false; shutdownProc.running = true; } }
    Shortcut { sequence: "r"; onActivated: { pmWindow.showing = false; rebootProc.running = true; } }
    Shortcut { sequence: "l"; onActivated: { pmWindow.showing = false; lockProc.running = true; } }
    Shortcut { sequence: "e"; onActivated: { pmWindow.showing = false; logoutProc.running = true; } }
    Shortcut { sequence: "p"; onActivated: { pmWindow.showing = false; sleepProc.running = true; } }
    Shortcut { sequence: "h"; onActivated: { pmWindow.showing = false; hibProc.running = true; } }
}
