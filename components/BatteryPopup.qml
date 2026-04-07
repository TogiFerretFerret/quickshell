import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

PanelWindow {
    id: batPopup

    property color bg: "#111318"
    property color fg: "#e1e2e9"
    property color dim: "#5d6172"
    property color primary: "#a3c9ff"
    property color green: "#a6e3a1"
    property string fontFamily: "JetBrainsMono Nerd Font"
    property bool showing: false
    property string battDetail: ""

    visible: showing
    anchors { top: true; left: true }
    margins.top: 56; margins.left: 310
    implicitWidth: Math.max(detailText.implicitWidth + 32, 220)
    implicitHeight: detailCol.implicitHeight + 28
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore

    Process { id: batDetailProc; command: ["sh", "-c",
        "echo '── Power ──' && " +
        "sensors macsmc_battery-isa-0000 2>/dev/null | grep -E 'temp|power|curr|in0' | sed 's/^  *//' && " +
        "echo '' && echo '── Status ──' && " +
        "cat /sys/class/power_supply/macsmc-battery/status 2>/dev/null && " +
        "echo \"Capacity: $(cat /sys/class/power_supply/macsmc-battery/capacity 2>/dev/null)%\" && " +
        "echo \"Health: $(cat /sys/class/power_supply/macsmc-battery/charge_full 2>/dev/null | awk '{printf \"%.0f\", $1/10000}')%\" && " +
        "echo \"Cycles: $(cat /sys/class/power_supply/macsmc-battery/cycle_count 2>/dev/null)\" && " +
        "acpi -b 2>/dev/null | grep -oP '\\d+:\\d+ (remaining|until).*' || true"
    ]; running: true
        stdout: StdioCollector { onStreamFinished: { batPopup.battDetail = text.trim(); } }
    }

    onShowingChanged: if (showing) batDetailProc.running = true

    Rectangle {
        anchors.fill: parent; radius: 14
        color: Qt.rgba(batPopup.bg.r, batPopup.bg.g, batPopup.bg.b, 0.94)
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08)

        Column {
            id: detailCol
            anchors.fill: parent; anchors.margins: 14; spacing: 8

            Text { text: String.fromCodePoint(0xf0079) + "  Battery"
                color: batPopup.green; font { pixelSize: 13; family: batPopup.fontFamily; bold: true } }
            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.06) }
            Text { id: detailText; text: batPopup.battDetail; color: batPopup.fg; lineHeight: 1.4
                font { pixelSize: 12; family: "JetBrainsMono Nerd Font Mono" } }
        }
    }

    Shortcut { sequence: "Escape"; onActivated: batPopup.showing = false; enabled: batPopup.showing }
}
