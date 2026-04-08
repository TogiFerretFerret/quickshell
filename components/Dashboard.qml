import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

PanelWindow {
    id: dash

    property color bg: "#111318"
    property color fg: "#e1e2e9"
    property color dim: "#5d6172"
    property color primary: "#a3c9ff"
    property string fontFamily: "JetBrainsMono Nerd Font"

    property bool showing: false

    // Weather data
    property string weatherTemp: "--"
    property string weatherFeels: "--"
    property string weatherDesc: "Loading..."
    property string weatherHumidity: "--"
    property string weatherWind: "--"
    property string weatherIcon: String.fromCodePoint(0xf0590) // cloud

    // Calendar
    property var currentDate: new Date()

    visible: showing
    anchors { top: true; right: true }
    margins.top: 56; margins.right: 10
    implicitWidth: 360; implicitHeight: dashCol.implicitHeight + 32
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore

    onShowingChanged: if (showing) { weatherProc.running = true; currentDate = new Date(); }

    // Fetch weather
    Process { id: weatherProc; command: ["sh", "-c",
        "curl -s 'wttr.in/?format=j1' 2>/dev/null | python3 -c \"" +
        "import json,sys; d=json.load(sys.stdin); c=d['current_condition'][0]; " +
        "print(c['temp_C']); print(c['FeelsLikeC']); print(c['weatherDesc'][0]['value']); " +
        "print(c['humidity']); print(c['windspeedKmph'] + ' ' + c['winddir16Point'])\""]
        stdout: StdioCollector { onStreamFinished: {
            var lines = text.trim().split("\n");
            if (lines.length >= 5) {
                dash.weatherTemp = lines[0];
                dash.weatherFeels = lines[1];
                dash.weatherDesc = lines[2];
                dash.weatherHumidity = lines[3];
                dash.weatherWind = lines[4];
                // Pick icon based on description
                var d = lines[2].toLowerCase();
                if (d.indexOf("sun") >= 0 || d.indexOf("clear") >= 0) dash.weatherIcon = String.fromCodePoint(0xf0599);
                else if (d.indexOf("cloud") >= 0 || d.indexOf("overcast") >= 0) dash.weatherIcon = String.fromCodePoint(0xf0590);
                else if (d.indexOf("rain") >= 0 || d.indexOf("drizzle") >= 0) dash.weatherIcon = String.fromCodePoint(0xf0597);
                else if (d.indexOf("snow") >= 0) dash.weatherIcon = String.fromCodePoint(0xf0598);
                else if (d.indexOf("thunder") >= 0) dash.weatherIcon = String.fromCodePoint(0xf0593);
                else if (d.indexOf("fog") >= 0 || d.indexOf("mist") >= 0) dash.weatherIcon = String.fromCodePoint(0xf0591);
                else dash.weatherIcon = String.fromCodePoint(0xf0590);
            }
        }}
    }

    Rectangle {
        anchors.fill: parent; radius: 18
        color: Qt.rgba(dash.bg.r, dash.bg.g, dash.bg.b, 0.95)
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08)

        Column {
            id: dashCol
            anchors.fill: parent; anchors.margins: 18; spacing: 14

            // ── Weather card ──
            Rectangle {
                width: parent.width; height: 100; radius: 14
                color: Qt.rgba(1, 1, 1, 0.04); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.06)

                Row {
                    anchors.fill: parent; anchors.margins: 14; spacing: 14

                    // Big icon + temp
                    Column {
                        spacing: 2
                        Text { text: dash.weatherIcon; color: dash.primary
                            font { pixelSize: 36; family: dash.fontFamily } }
                        Text { text: dash.weatherTemp + "°C"; color: dash.fg
                            font { pixelSize: 22; family: dash.fontFamily; bold: true } }
                    }

                    // Details
                    Column {
                        spacing: 4; anchors.verticalCenter: parent.verticalCenter
                        Text { text: dash.weatherDesc; color: dash.fg
                            font { pixelSize: 13; family: dash.fontFamily } }
                        Text { text: "Feels like " + dash.weatherFeels + "°C"; color: dash.dim
                            font { pixelSize: 11; family: dash.fontFamily } }
                        Text { text: String.fromCodePoint(0xf0593) + " " + dash.weatherWind + "  " +
                               String.fromCodePoint(0xf058e) + " " + dash.weatherHumidity + "%"
                            color: dash.dim; font { pixelSize: 11; family: dash.fontFamily } }
                    }
                }
            }

            // ── Calendar ──
            Rectangle {
                width: parent.width; height: calCol.implicitHeight + 20; radius: 14
                color: Qt.rgba(1, 1, 1, 0.04); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.06)

                Column {
                    id: calCol; anchors.fill: parent; anchors.margins: 10; spacing: 6

                    // Month nav
                    Row {
                        width: parent.width; spacing: 0
                        Text { text: "<"; color: dash.dim; font { pixelSize: 16; family: dash.fontFamily; bold: true }
                            width: 30; horizontalAlignment: Text.AlignHCenter
                            MouseArea { anchors.fill: parent; onClicked: {
                                var d = dash.currentDate;
                                dash.currentDate = new Date(d.getFullYear(), d.getMonth() - 1, 1); } } }
                        Text { text: Qt.formatDateTime(dash.currentDate, "MMMM yyyy")
                            color: dash.fg; font { pixelSize: 13; family: dash.fontFamily; bold: true }
                            width: parent.width - 60; horizontalAlignment: Text.AlignHCenter }
                        Text { text: ">"; color: dash.dim; font { pixelSize: 16; family: dash.fontFamily; bold: true }
                            width: 30; horizontalAlignment: Text.AlignHCenter
                            MouseArea { anchors.fill: parent; onClicked: {
                                var d = dash.currentDate;
                                dash.currentDate = new Date(d.getFullYear(), d.getMonth() + 1, 1); } } }
                    }

                    // Day headers
                    Row {
                        spacing: 0
                        Repeater { model: ["Mo","Tu","We","Th","Fr","Sa","Su"]
                            Text { width: (calCol.width) / 7; text: modelData; color: dash.dim
                                font { pixelSize: 10; family: dash.fontFamily; bold: true }
                                horizontalAlignment: Text.AlignHCenter } }
                    }

                    // Day grid
                    Grid {
                        columns: 7; spacing: 0
                        Repeater {
                            model: 42
                            Rectangle {
                                required property int index
                                property int dayNum: {
                                    var d = dash.currentDate;
                                    var first = new Date(d.getFullYear(), d.getMonth(), 1);
                                    var off = first.getDay() === 0 ? 6 : first.getDay() - 1;
                                    var last = new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate();
                                    var n = index - off + 1;
                                    return (n >= 1 && n <= last) ? n : 0; }
                                property bool isToday: {
                                    var now = new Date(); var d = dash.currentDate;
                                    return dayNum > 0 && now.getDate() === dayNum &&
                                        now.getMonth() === d.getMonth() && now.getFullYear() === d.getFullYear(); }
                                width: (calCol.width) / 7; height: 28; radius: 8
                                color: isToday ? dash.primary : "transparent"
                                Text { anchors.centerIn: parent
                                    text: parent.dayNum > 0 ? parent.dayNum : ""
                                    color: parent.isToday ? dash.bg : parent.dayNum > 0 ? dash.fg : "transparent"
                                    font { pixelSize: 11; family: dash.fontFamily; bold: parent.isToday } }
                            }
                        }
                    }
                }
            }

            // ── Quick info row ──
            Row {
                width: parent.width; spacing: 8

                // Uptime
                Rectangle {
                    width: (parent.width - 8) / 2; height: 50; radius: 12
                    color: Qt.rgba(1, 1, 1, 0.04); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.06)
                    Column { anchors.centerIn: parent; spacing: 2
                        Text { text: String.fromCodePoint(0xf0954) + " Uptime"; color: dash.dim
                            font { pixelSize: 10; family: dash.fontFamily }
                            anchors.horizontalCenter: parent.horizontalCenter }
                        Text { id: uptimeText; text: "..."; color: dash.fg
                            font { pixelSize: 12; family: dash.fontFamily; bold: true }
                            anchors.horizontalCenter: parent.horizontalCenter }
                    }
                }

                // Packages
                Rectangle {
                    width: (parent.width - 8) / 2; height: 50; radius: 12
                    color: Qt.rgba(1, 1, 1, 0.04); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.06)
                    Column { anchors.centerIn: parent; spacing: 2
                        Text { text: String.fromCodePoint(0xf03d7) + " Packages"; color: dash.dim
                            font { pixelSize: 10; family: dash.fontFamily }
                            anchors.horizontalCenter: parent.horizontalCenter }
                        Text { id: pkgText; text: "..."; color: dash.fg
                            font { pixelSize: 12; family: dash.fontFamily; bold: true }
                            anchors.horizontalCenter: parent.horizontalCenter }
                    }
                }
            }

            // ── Today button ──
            Text { text: "Today"; color: dash.primary; anchors.horizontalCenter: parent.horizontalCenter
                font { pixelSize: 11; family: dash.fontFamily }
                MouseArea { anchors.fill: parent; onClicked: dash.currentDate = new Date() } }
        }
    }

    // Fetch uptime + packages on show
    Process { id: uptimeProc; command: ["sh", "-c", "uptime -p | sed 's/up //'"]
        stdout: SplitParser { onRead: data => { uptimeText.text = data.trim(); } } }
    Process { id: pkgProc; command: ["sh", "-c", "rpm -qa 2>/dev/null | wc -l"]
        stdout: SplitParser { onRead: data => { pkgText.text = data.trim(); } } }

    onVisibleChanged: if (visible) { uptimeProc.running = true; pkgProc.running = true; }

    Shortcut { sequence: "Escape"; onActivated: dash.showing = false; enabled: dash.showing }
}
