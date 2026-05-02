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
    property string weatherIcon: String.fromCodePoint(0xf0590)
    property var hourlyForecast: []

    // Calendar
    property var currentDate: new Date()

    // Pomodoro - Long (focus)
    property int pomoLongDur: 25 * 60
    property int pomoLongRem: 25 * 60
    property bool pomoLongRun: false
    // Pomodoro - Short (break)
    property int pomoShortDur: 5 * 60
    property int pomoShortRem: 5 * 60
    property bool pomoShortRun: false

    // Notes
    property string notesText: ""
    property string notesFile: Quickshell.env("HOME") + "/.cache/dashboard-notes.txt"

    // Calendar events
    property var calEvents: []
    property bool calLoading: false

    // Network
    property string netSSID: "--"
    property string netIP: "--"
    property string netSignal: "--"

    visible: showing
    anchors { top: true; right: true }
    margins.top: 50; margins.right: 10
    implicitWidth: 820; implicitHeight: dashRoot.implicitHeight + 32
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore

    onShowingChanged: if (showing) {
        weatherProc.running = true; currentDate = new Date();
        uptimeProc.running = true; pkgProc.running = true;
        netProc.running = true; loadNotes.running = true;
        calLoading = true; calProc.running = true;
    }

    // ── Fetch weather + hourly ──
    Process { id: weatherProc; command: ["python3", Quickshell.env("HOME") + "/.config/hypr/scripts/weather.py"]
        stdout: StdioCollector { onStreamFinished: {
            var lines = text.trim().split("\n");
            if (lines.length >= 5) {
                dash.weatherTemp = lines[0];
                dash.weatherFeels = lines[1];
                dash.weatherDesc = lines[2];
                dash.weatherHumidity = lines[3];
                dash.weatherWind = lines[4];
                var d = lines[2].toLowerCase();
                if (d.indexOf("sun") >= 0 || d.indexOf("clear") >= 0) dash.weatherIcon = String.fromCodePoint(0xf0599);
                else if (d.indexOf("cloud") >= 0 || d.indexOf("overcast") >= 0) dash.weatherIcon = String.fromCodePoint(0xf0590);
                else if (d.indexOf("rain") >= 0 || d.indexOf("drizzle") >= 0) dash.weatherIcon = String.fromCodePoint(0xf0597);
                else if (d.indexOf("snow") >= 0) dash.weatherIcon = String.fromCodePoint(0xf0598);
                else if (d.indexOf("thunder") >= 0) dash.weatherIcon = String.fromCodePoint(0xf0593);
                else if (d.indexOf("fog") >= 0 || d.indexOf("mist") >= 0) dash.weatherIcon = String.fromCodePoint(0xf0591);
                else dash.weatherIcon = String.fromCodePoint(0xf0590);
                // Parse hourly
                var hrs = [];
                for (var i = 5; i < lines.length; i++) {
                    var parts = lines[i].split("|");
                    if (parts.length >= 3) hrs.push({ time: parts[0], temp: parts[1], desc: parts[2] });
                }
                dash.hourlyForecast = hrs;
            }
        }}
    }

    // ── Network info ──
    Process { id: netProc; command: ["sh", "-c",
        "nmcli -t -f active,ssid,signal dev wifi | grep '^yes' | head -1; echo '---'; ip -4 addr show | grep 'inet ' | grep -v '127.0.0' | head -1 | awk '{print $2}'"]
        stdout: StdioCollector { onStreamFinished: {
            var lines = text.trim().split("\n");
            for (var i = 0; i < lines.length; i++) {
                if (lines[i].indexOf("yes:") === 0) {
                    var parts = lines[i].split(":");
                    dash.netSSID = parts[1] || "--";
                    dash.netSignal = (parts[2] || "--") + "%";
                }
                if (lines[i].indexOf("/") > 0 && lines[i].indexOf("---") < 0) {
                    dash.netIP = lines[i].split("/")[0];
                }
            }
        }}
    }

    // ── Google Calendar ──
    Process { id: calProc; command: ["python3", Quickshell.env("HOME") + "/.config/hypr/scripts/gcal-events.py"]
        stdout: StdioCollector { onStreamFinished: {
            var lines = text.trim().split("\n");
            var evts = [];
            for (var i = 0; i < lines.length; i++) {
                var parts = lines[i].split("|");
                if (parts.length >= 2) evts.push({ time: parts[0], title: parts.slice(1).join("|") });
            }
            dash.calEvents = evts;
            dash.calLoading = false;
        }}
    }

    // ── Notes persistence ──
    Process { id: loadNotes; command: ["sh", "-c", "cat '" + dash.notesFile + "' 2>/dev/null || echo ''"]
        stdout: StdioCollector { onStreamFinished: { dash.notesText = text; } }
    }
    Process { id: saveNotes; command: ["sh", "-c", "cat > '" + dash.notesFile + "'"]
        property bool needsSave: false
    }

    function saveNotesNow() {
        saveNotes.command = ["sh", "-c", "echo '" + dash.notesText.replace(/'/g, "'\\''") + "' > '" + dash.notesFile + "'"];
        saveNotes.running = true;
    }

    // ── Pomodoro timers ──
    Timer {
        id: pomoLongTimer; interval: 1000; repeat: true; running: dash.pomoLongRun
        onTriggered: {
            if (dash.pomoLongRem > 0) dash.pomoLongRem--;
            else { dash.pomoLongRun = false; pomoLongNotify.running = true; }
        }
    }
    Timer {
        id: pomoShortTimer; interval: 1000; repeat: true; running: dash.pomoShortRun
        onTriggered: {
            if (dash.pomoShortRem > 0) dash.pomoShortRem--;
            else { dash.pomoShortRun = false; pomoShortNotify.running = true; }
        }
    }
    Process { id: pomoLongNotify; command: ["notify-send", "-u", "critical", "Focus session done! Take a break."] }
    Process { id: pomoShortNotify; command: ["notify-send", "-u", "critical", "Break over! Time to focus."] }

    Rectangle {
        anchors.fill: parent; radius: 18
        color: Qt.rgba(dash.bg.r, dash.bg.g, dash.bg.b, 0.97)
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08)

        Row {
            id: dashRoot
            anchors.fill: parent; anchors.margins: 16; spacing: 12

            // ══════════ LEFT COLUMN ══════════
            Column {
                width: (parent.width - 24) * 0.28; spacing: 10

                // Network
                Rectangle {
                    width: parent.width; height: 70; radius: 14
                    color: Qt.rgba(1, 1, 1, 0.04); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.06)
                    Column {
                        anchors.fill: parent; anchors.margins: 12; spacing: 4
                        Row {
                            spacing: 8
                            Text { text: String.fromCodePoint(0xf05a9); color: dash.primary
                                font { pixelSize: 16; family: dash.fontFamily } }
                            Text { text: dash.netSSID; color: dash.fg
                                font { pixelSize: 11; family: dash.fontFamily; bold: true } }
                        }
                        Text { text: dash.netIP; color: dash.dim
                            font { pixelSize: 10; family: dash.fontFamily } }
                        Text { text: dash.netSignal + " signal"; color: dash.dim
                            font { pixelSize: 10; family: dash.fontFamily } }
                    }
                }

                // Notes
                Rectangle {
                    width: parent.width; height: 180; radius: 14
                    color: Qt.rgba(1, 1, 1, 0.04); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.06)
                    Column {
                        anchors.fill: parent; anchors.margins: 10; spacing: 4
                        Text { text: String.fromCodePoint(0xf09a8) + " Notes"; color: dash.dim
                            font { pixelSize: 10; family: dash.fontFamily; bold: true } }
                        Flickable {
                            width: parent.width; height: parent.height - 18
                            contentHeight: notesEdit.implicitHeight
                            clip: true; boundsBehavior: Flickable.StopAtBounds
                            TextEdit {
                                id: notesEdit
                                width: parent.width
                                text: dash.notesText
                                color: dash.fg; selectionColor: dash.primary
                                font { pixelSize: 11; family: dash.fontFamily }
                                wrapMode: TextEdit.Wrap
                                onTextChanged: {
                                    dash.notesText = text;
                                    saveDebounce.restart();
                                }
                            }
                        }
                    }
                }

                // Uptime + Packages (compact)
                Rectangle {
                    width: parent.width; height: 40; radius: 12
                    color: Qt.rgba(1, 1, 1, 0.04); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.06)
                    MouseArea { id: upMA; anchors.fill: parent; hoverEnabled: true }
                    MouseArea { id: pkgMA; anchors.fill: parent; hoverEnabled: true; visible: false }
                    Column {
                        anchors.centerIn: parent; spacing: 2
                        Text { id: uptimeText; text: String.fromCodePoint(0xf0954) + " ..."; color: dash.fg
                            font { pixelSize: 10; family: dash.fontFamily }
                            anchors.horizontalCenter: parent.horizontalCenter }
                        Text { id: pkgText; text: String.fromCodePoint(0xf03d7) + " ..."; color: dash.dim
                            font { pixelSize: 10; family: dash.fontFamily }
                            anchors.horizontalCenter: parent.horizontalCenter }
                    }
                }

                // Focus timer
                Rectangle {
                    width: parent.width; height: 80; radius: 14
                        color: Qt.rgba(1, 1, 1, 0.04); border.width: 1
                        border.color: dash.pomoLongRun ? Qt.rgba(dash.primary.r, dash.primary.g, dash.primary.b, 0.3) : Qt.rgba(1, 1, 1, 0.06)
                        Behavior on border.color { ColorAnimation { duration: 200 } }
                        Column {
                            anchors.fill: parent; anchors.margins: 8; spacing: 2
                            Text { text: "FOCUS"; color: dash.primary
                                font { pixelSize: 8; family: dash.fontFamily; bold: true } }
                            Text {
                                text: Math.floor(dash.pomoLongRem / 60).toString().padStart(2, '0') + ":" +
                                      (dash.pomoLongRem % 60).toString().padStart(2, '0')
                                color: dash.fg
                                font { pixelSize: 20; family: dash.fontFamily; bold: true } }
                            Row {
                                spacing: 4
                                Rectangle {
                                    width: 22; height: 22; radius: 11
                                    color: plMA.containsMouse ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.06)
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Text { anchors.centerIn: parent
                                        text: dash.pomoLongRun ? String.fromCodePoint(0xf03e4) : String.fromCodePoint(0xf040a)
                                        color: dash.primary; font { pixelSize: 10; family: dash.fontFamily } }
                                    MouseArea { id: plMA; anchors.fill: parent; hoverEnabled: true
                                        onClicked: dash.pomoLongRun = !dash.pomoLongRun }
                                }
                                Rectangle {
                                    width: 22; height: 22; radius: 11
                                    color: rlMA.containsMouse ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.06)
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Text { anchors.centerIn: parent; text: String.fromCodePoint(0xf0453)
                                        color: dash.dim; font { pixelSize: 10; family: dash.fontFamily } }
                                    MouseArea { id: rlMA; anchors.fill: parent; hoverEnabled: true
                                        onClicked: { dash.pomoLongRun = false; dash.pomoLongRem = dash.pomoLongDur; } }
                                }
                                Text { text: "-"; color: mlMA.containsMouse ? dash.primary : dash.dim; anchors.verticalCenter: parent.verticalCenter
                                    font { pixelSize: 11; family: dash.fontFamily; bold: true }
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    MouseArea { id: mlMA; anchors.fill: parent; hoverEnabled: true
                                        onClicked: { if (!dash.pomoLongRun && dash.pomoLongDur > 300) { dash.pomoLongDur -= 300; dash.pomoLongRem = dash.pomoLongDur; } } } }
                                Text { text: Math.floor(dash.pomoLongDur / 60) + "m"; color: dash.dim
                                    font { pixelSize: 8; family: dash.fontFamily }
                                    anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "+"; color: alMA.containsMouse ? dash.primary : dash.dim; anchors.verticalCenter: parent.verticalCenter
                                    font { pixelSize: 11; family: dash.fontFamily; bold: true }
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    MouseArea { id: alMA; anchors.fill: parent; hoverEnabled: true
                                        onClicked: { if (!dash.pomoLongRun && dash.pomoLongDur < 3600) { dash.pomoLongDur += 300; dash.pomoLongRem = dash.pomoLongDur; } } } }
                            }
                        }
                    }
            }

            // ══════════ CENTER COLUMN (Events) ══════════
            Column {
                width: (parent.width - 24) * 0.30; spacing: 10

                Rectangle {
                    width: parent.width
                    height: eventsCol.implicitHeight + 16; radius: 14
                    color: Qt.rgba(1, 1, 1, 0.04); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.06)
                    Column {
                        id: eventsCol; anchors.fill: parent; anchors.margins: 10; spacing: 6
                        Text { text: String.fromCodePoint(0xf00ed) + " Upcoming"; color: dash.dim
                            font { pixelSize: 10; family: dash.fontFamily; bold: true } }
                        Text { text: "Loading..."; color: dash.dim; visible: dash.calLoading && dash.calEvents.length === 0
                            font { pixelSize: 10; family: dash.fontFamily; italic: true } }
                        Text { text: "No upcoming events"; color: dash.dim; visible: !dash.calLoading && dash.calEvents.length === 0
                            font { pixelSize: 10; family: dash.fontFamily; italic: true } }
                        Repeater {
                            model: dash.calEvents
                            Column {
                                width: parent.width; spacing: 1
                                Text { text: modelData.time; color: dash.primary
                                    font { pixelSize: 9; family: dash.fontFamily } }
                                Text { text: modelData.title; color: dash.fg
                                    font { pixelSize: 10; family: dash.fontFamily }
                                    width: parent.width; elide: Text.ElideRight }
                                Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.04); visible: index < dash.calEvents.length - 1 }
                            }
                        }
                    }
                }

                // Break timer
                Rectangle {
                    width: parent.width; height: 80; radius: 14
                    color: Qt.rgba(1, 1, 1, 0.04); border.width: 1
                    border.color: dash.pomoShortRun ? Qt.rgba(0.65, 0.89, 0.63, 0.3) : Qt.rgba(1, 1, 1, 0.06)
                    Behavior on border.color { ColorAnimation { duration: 200 } }
                    Column {
                        anchors.fill: parent; anchors.margins: 8; spacing: 2
                        Text { text: "BREAK"; color: "#a6e3a1"
                            font { pixelSize: 8; family: dash.fontFamily; bold: true } }
                        Text {
                            text: Math.floor(dash.pomoShortRem / 60).toString().padStart(2, '0') + ":" +
                                  (dash.pomoShortRem % 60).toString().padStart(2, '0')
                            color: dash.fg
                            font { pixelSize: 20; family: dash.fontFamily; bold: true } }
                        Row {
                            spacing: 4
                            Rectangle {
                                width: 22; height: 22; radius: 11
                                color: psMA.containsMouse ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.06)
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Text { anchors.centerIn: parent
                                    text: dash.pomoShortRun ? String.fromCodePoint(0xf03e4) : String.fromCodePoint(0xf040a)
                                    color: "#a6e3a1"; font { pixelSize: 10; family: dash.fontFamily } }
                                MouseArea { id: psMA; anchors.fill: parent; hoverEnabled: true
                                    onClicked: dash.pomoShortRun = !dash.pomoShortRun }
                            }
                            Rectangle {
                                width: 22; height: 22; radius: 11
                                color: rsMA.containsMouse ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.06)
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Text { anchors.centerIn: parent; text: String.fromCodePoint(0xf0453)
                                    color: dash.dim; font { pixelSize: 10; family: dash.fontFamily } }
                                MouseArea { id: rsMA; anchors.fill: parent; hoverEnabled: true
                                    onClicked: { dash.pomoShortRun = false; dash.pomoShortRem = dash.pomoShortDur; } }
                            }
                            Text { text: "-"; color: msMA.containsMouse ? dash.primary : dash.dim
                                anchors.verticalCenter: parent.verticalCenter
                                font { pixelSize: 11; family: dash.fontFamily; bold: true }
                                Behavior on color { ColorAnimation { duration: 150 } }
                                MouseArea { id: msMA; anchors.fill: parent; hoverEnabled: true
                                    onClicked: { if (!dash.pomoShortRun && dash.pomoShortDur > 60) { dash.pomoShortDur -= 60; dash.pomoShortRem = dash.pomoShortDur; } } } }
                            Text { text: Math.floor(dash.pomoShortDur / 60) + "m"; color: dash.dim
                                font { pixelSize: 8; family: dash.fontFamily }
                                anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "+"; color: asMA.containsMouse ? dash.primary : dash.dim
                                anchors.verticalCenter: parent.verticalCenter
                                font { pixelSize: 11; family: dash.fontFamily; bold: true }
                                Behavior on color { ColorAnimation { duration: 150 } }
                                MouseArea { id: asMA; anchors.fill: parent; hoverEnabled: true
                                    onClicked: { if (!dash.pomoShortRun && dash.pomoShortDur < 1800) { dash.pomoShortDur += 60; dash.pomoShortRem = dash.pomoShortDur; } } } }
                        }
                    }
                }
            }

            // ══════════ RIGHT COLUMN ══════════
            Column {
                width: (parent.width - 24) * 0.42; spacing: 10

                // Weather
                Rectangle {
                    width: parent.width; height: 90; radius: 14
                    color: Qt.rgba(1, 1, 1, 0.04); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.06)
                    Row {
                        anchors.fill: parent; anchors.margins: 12; spacing: 14
                        Column {
                            spacing: 2
                            Text { text: dash.weatherIcon; color: dash.primary
                                font { pixelSize: 32; family: dash.fontFamily } }
                            Text { text: dash.weatherTemp + "°F"; color: dash.fg
                                font { pixelSize: 20; family: dash.fontFamily; bold: true } }
                        }
                        Column {
                            spacing: 3; anchors.verticalCenter: parent.verticalCenter
                            Text { text: dash.weatherDesc; color: dash.fg
                                font { pixelSize: 12; family: dash.fontFamily } }
                            Text { text: "Feels like " + dash.weatherFeels + "°F"; color: dash.dim
                                font { pixelSize: 10; family: dash.fontFamily } }
                            Text { text: String.fromCodePoint(0xf0593) + " " + dash.weatherWind + "  " +
                                   String.fromCodePoint(0xf058e) + " " + dash.weatherHumidity + "%"
                                color: dash.dim
                                font { pixelSize: 10; family: dash.fontFamily } }
                        }
                    }
                }

                // Hourly forecast
                Rectangle {
                    width: parent.width; height: 60; radius: 14; visible: dash.hourlyForecast.length > 0
                    color: Qt.rgba(1, 1, 1, 0.04); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.06)
                    Row {
                        anchors.centerIn: parent; spacing: 0
                        Repeater {
                            model: dash.hourlyForecast
                            Column {
                                width: (parent.parent.width - 24) / Math.max(dash.hourlyForecast.length, 1)
                                spacing: 2
                                Text { text: modelData.time; color: dash.dim; anchors.horizontalCenter: parent.horizontalCenter
                                    font { pixelSize: 9; family: dash.fontFamily } }
                                Text {
                                    property string d: modelData.desc ? modelData.desc.toLowerCase() : ""
                                    text: d.indexOf("sun") >= 0 || d.indexOf("clear") >= 0 ? String.fromCodePoint(0xf0599) :
                                          d.indexOf("rain") >= 0 ? String.fromCodePoint(0xf0597) :
                                          d.indexOf("cloud") >= 0 ? String.fromCodePoint(0xf0590) : String.fromCodePoint(0xf0590)
                                    color: dash.primary; anchors.horizontalCenter: parent.horizontalCenter
                                    font { pixelSize: 14; family: dash.fontFamily } }
                                Text { text: modelData.temp + "°"; color: dash.fg; anchors.horizontalCenter: parent.horizontalCenter
                                    font { pixelSize: 10; family: dash.fontFamily; bold: true } }
                            }
                        }
                    }
                }

                // Calendar
                Rectangle {
                    width: parent.width; height: calCol.implicitHeight + 20; radius: 14
                    color: Qt.rgba(1, 1, 1, 0.04); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.06)
                    Column {
                        id: calCol; anchors.fill: parent; anchors.margins: 10; spacing: 6
                        Row {
                            width: parent.width; spacing: 0
                            Rectangle { width: 30; height: 26; radius: 8; color: prevMA.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Text { anchors.centerIn: parent; text: "<"; color: prevMA.containsMouse ? dash.primary : dash.dim
                                    font { pixelSize: 14; family: dash.fontFamily; bold: true }
                                    Behavior on color { ColorAnimation { duration: 150 } } }
                                MouseArea { id: prevMA; anchors.fill: parent; hoverEnabled: true; onClicked: {
                                    var d = dash.currentDate;
                                    dash.currentDate = new Date(d.getFullYear(), d.getMonth() - 1, 1); } } }
                            Item {
                                width: parent.width - 60; height: 26
                                Text { anchors.centerIn: parent; text: Qt.formatDateTime(dash.currentDate, "MMMM yyyy")
                                    color: dash.fg; font { pixelSize: 12; family: dash.fontFamily; bold: true } }
                                MouseArea { id: todayMA; anchors.fill: parent; onDoubleClicked: dash.currentDate = new Date() }
                            }
                            Rectangle { width: 30; height: 26; radius: 8; color: nextMA.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Text { anchors.centerIn: parent; text: ">"; color: nextMA.containsMouse ? dash.primary : dash.dim
                                    font { pixelSize: 14; family: dash.fontFamily; bold: true }
                                    Behavior on color { ColorAnimation { duration: 150 } } }
                                MouseArea { id: nextMA; anchors.fill: parent; hoverEnabled: true; onClicked: {
                                    var d = dash.currentDate;
                                    dash.currentDate = new Date(d.getFullYear(), d.getMonth() + 1, 1); } } }
                        }
                        Row {
                            spacing: 0
                            Repeater { model: ["Mo","Tu","We","Th","Fr","Sa","Su"]
                                Text { width: (calCol.width) / 7; text: modelData; color: dash.dim
                                    font { pixelSize: 9; family: dash.fontFamily; bold: true }
                                    horizontalAlignment: Text.AlignHCenter } }
                        }
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
                                    width: (calCol.width) / 7; height: 26; radius: 8
                                    color: isToday ? dash.primary : dayMA.containsMouse && dayNum > 0 ? Qt.rgba(1,1,1,0.08) : "transparent"
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                    Text { anchors.centerIn: parent
                                        text: parent.dayNum > 0 ? parent.dayNum : ""
                                        color: parent.isToday ? dash.bg : parent.dayNum > 0 ? (dayMA.containsMouse ? dash.primary : dash.fg) : "transparent"
                                        font { pixelSize: 10; family: dash.fontFamily; bold: parent.isToday }
                                        Behavior on color { ColorAnimation { duration: 120 } } }
                                    MouseArea { id: dayMA; anchors.fill: parent; hoverEnabled: true }
                                }
                            }
                        }
                    }
                }

            }
        }
    }

    // Save notes with debounce
    Timer { id: saveDebounce; interval: 1000; onTriggered: dash.saveNotesNow() }

    // Fetch uptime + packages on show
    Process { id: uptimeProc; command: ["sh", "-c", "uptime -p | sed 's/up //'"]
        stdout: SplitParser { onRead: data => { uptimeText.text = String.fromCodePoint(0xf0954) + " " + data.trim(); } } }
    Process { id: pkgProc; command: ["sh", "-c", "rpm -qa 2>/dev/null | wc -l"]
        stdout: SplitParser { onRead: data => { pkgText.text = String.fromCodePoint(0xf03d7) + " " + data.trim() + " pkgs"; } } }

    onVisibleChanged: if (visible) { uptimeProc.running = true; pkgProc.running = true; }

    Shortcut { sequence: "Escape"; onActivated: dash.showing = false; enabled: dash.showing }
}
