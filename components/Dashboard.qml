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

    // Weather
    property string weatherTemp: "--"
    property string weatherFeels: "--"
    property string weatherDesc: "Loading..."
    property string weatherHumidity: "--"
    property string weatherWind: "--"
    property string weatherIcon: String.fromCodePoint(0xf0590)
    property real weatherCode: 1.0
    property var hourlyForecast: []
    property var dailyForecast: []
    property var allHourly: ({})  // { "2026-05-10": [{time, temp, desc}, ...], ... }
    property int selectedDay: -1  // -1 = today (default), 0-6 = index into dailyForecast
    property int selectedHour: -1 // -1 = no specific hour selected
    property var displayedHourly: {
        if (selectedDay < 0 || dailyForecast.length === 0) return hourlyForecast;
        var d = dailyForecast[selectedDay];
        if (!d || !d.date) return hourlyForecast;
        return allHourly[d.date] || [];
    }
    property real displayedWeatherCode: {
        // If a specific hour is selected, use that hour's weather
        if (selectedHour >= 0 && selectedHour < displayedHourly.length)
            return weatherCodeFor(displayedHourly[selectedHour].desc);
        // Today with no hour selected = current actual weather
        if (selectedDay < 0 || dailyForecast.length === 0) return weatherCode;
        // Other day with no hour = that day's overall weather
        var d = dailyForecast[selectedDay];
        return d ? weatherCodeFor(d.desc) : weatherCode;
    }

    onSelectedDayChanged: {
        selectedHour = -1; // reset hour selection when switching days
    }

    // Pomodoro
    property int pomoDur: 25 * 60
    property int pomoRem: 25 * 60
    property bool pomoRun: false
    property string pomoMode: "focus"

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

    // Calendar
    property var currentDate: new Date()

    // Animation
    property real _elapsed: 0
    Timer { interval: 16; running: dash.visible; repeat: true; onTriggered: dash._elapsed += 0.016 }

    visible: showing
    anchors { top: true; right: true }
    margins.top: 50; margins.right: 10
    implicitWidth: 920; implicitHeight: 680
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore

    onShowingChanged: if (showing) {
        weatherProc.running = true;
        uptimeProc.running = true; pkgProc.running = true;
        netProc.running = true; loadNotes.running = true;
        calLoading = true; calProc.running = true;
        currentDate = new Date(); selectedDay = -1;
    }

    function weatherIconFor(desc) {
        var d = (desc || "").toLowerCase();
        if (d.indexOf("sun") >= 0 || d.indexOf("clear") >= 0) return String.fromCodePoint(0xf0599);
        if (d.indexOf("rain") >= 0 || d.indexOf("drizzle") >= 0 || d.indexOf("shower") >= 0) return String.fromCodePoint(0xf0597);
        if (d.indexOf("snow") >= 0) return String.fromCodePoint(0xf0598);
        if (d.toLowerCase().indexOf("thunder") >= 0) return String.fromCodePoint(0xf0593);
        if (d.indexOf("fog") >= 0 || d.indexOf("mist") >= 0) return String.fromCodePoint(0xf0591);
        return String.fromCodePoint(0xf0590);
    }

    function weatherCodeFor(desc) {
        var d = (desc || "").toLowerCase();
        if (d.indexOf("sun") >= 0 || d.indexOf("clear") >= 0) return 0.0;
        if (d.indexOf("rain") >= 0 || d.indexOf("drizzle") >= 0 || d.indexOf("shower") >= 0) return 2.0;
        if (d.indexOf("snow") >= 0) return 3.0;
        if (d.toLowerCase().indexOf("thunder") >= 0) return 4.0;
        return 1.0;
    }

    // ── Data fetchers ──
    Process { id: weatherProc; command: ["python3", Quickshell.env("HOME") + "/.config/hypr/scripts/weather.py"]
        stdout: StdioCollector { onStreamFinished: {
            var lines = text.trim().split("\n");
            if (lines.length < 5) return;
            dash.weatherTemp = lines[0]; dash.weatherFeels = lines[1];
            dash.weatherDesc = lines[2]; dash.weatherHumidity = lines[3]; dash.weatherWind = lines[4];
            dash.weatherIcon = dash.weatherIconFor(lines[2]);
            dash.weatherCode = dash.weatherCodeFor(lines[2]);
            var hrs = []; var daily = []; var allH = {}; var section = "hourly";
            for (var i = 5; i < lines.length; i++) {
                if (lines[i] === "---DAILY---") { section = "daily"; continue; }
                if (lines[i] === "---HOURLY-ALL---") { section = "hourlyall"; continue; }
                var parts = lines[i].split("|");
                if (section === "hourly" && parts.length >= 3)
                    hrs.push({ time: parts[0], temp: parts[1], desc: parts[2] });
                else if (section === "daily" && parts.length >= 5)
                    daily.push({ day: parts[0], high: parts[1], low: parts[2], desc: parts[3], date: parts[4] });
                else if (section === "hourlyall" && parts.length >= 4) {
                    var dt = parts[0];
                    if (!allH[dt]) allH[dt] = [];
                    allH[dt].push({ time: parts[1], temp: parts[2], desc: parts[3] });
                }
            }
            dash.hourlyForecast = hrs; dash.dailyForecast = daily; dash.allHourly = allH;
        }}
    }

    Process { id: netProc; command: ["sh", "-c",
        "nmcli -t -f active,ssid,signal dev wifi | grep '^yes' | head -1; echo '---'; ip -4 addr show | grep 'inet ' | grep -v '127.0.0' | head -1 | awk '{print $2}'"]
        stdout: StdioCollector { onStreamFinished: {
            var lines = text.trim().split("\n");
            for (var i = 0; i < lines.length; i++) {
                if (lines[i].indexOf("yes:") === 0) { var parts = lines[i].split(":"); dash.netSSID = parts[1] || "--"; dash.netSignal = (parts[2] || "--") + "%"; }
                if (lines[i].indexOf("/") > 0 && lines[i].indexOf("---") < 0) dash.netIP = lines[i].split("/")[0];
            }
        }}
    }

    Process { id: calProc; command: ["python3", Quickshell.env("HOME") + "/.config/hypr/scripts/gcal-events.py"]
        stdout: StdioCollector { onStreamFinished: {
            var lines = text.trim().split("\n"); var evts = [];
            for (var i = 0; i < lines.length; i++) {
                var parts = lines[i].split("|");
                if (parts.length >= 2) evts.push({ time: parts[0], title: parts.slice(1).join("|") });
            }
            dash.calEvents = evts; dash.calLoading = false;
        }}
    }

    Process { id: loadNotes; command: ["sh", "-c", "cat '" + dash.notesFile + "' 2>/dev/null || echo ''"]
        stdout: StdioCollector { onStreamFinished: { dash.notesText = text; } } }
    function saveNotesNow() {
        saveNotes.command = ["sh", "-c", "echo '" + dash.notesText.replace(/'/g, "'\\''") + "' > '" + dash.notesFile + "'"];
        saveNotes.running = true;
    }
    Process { id: saveNotes }
    Timer { id: saveDebounce; interval: 1000; onTriggered: dash.saveNotesNow() }

    Timer {
        interval: 1000; repeat: true; running: dash.pomoRun
        onTriggered: {
            if (dash.pomoRem > 0) dash.pomoRem--;
            else {
                dash.pomoRun = false; pomoNotify.running = true;
                if (dash.pomoMode === "focus") { dash.pomoMode = "break"; dash.pomoDur = 5 * 60; }
                else { dash.pomoMode = "focus"; dash.pomoDur = 25 * 60; }
                dash.pomoRem = dash.pomoDur;
            }
        }
    }
    Process { id: pomoNotify; command: ["notify-send", "-u", "critical",
        dash.pomoMode === "focus" ? "Focus done! Take a break." : "Break over! Time to focus."] }

    Process { id: uptimeProc; command: ["sh", "-c", "uptime -p | sed 's/up //'"]
        stdout: SplitParser { onRead: data => { uptimeText.text = String.fromCodePoint(0xf0954) + " " + data.trim(); } } }
    Process { id: pkgProc; command: ["sh", "-c", "rpm -qa 2>/dev/null | wc -l"]
        stdout: SplitParser { onRead: data => { pkgText.text = String.fromCodePoint(0xf03d7) + " " + data.trim() + " pkgs"; } } }

    // ═══════════════════════════════════════
    // UI
    // ═══════════════════════════════════════
    Rectangle {
        id: mainBg
        anchors.fill: parent; radius: 18
        color: Qt.rgba(dash.bg.r, dash.bg.g, dash.bg.b, 0.95)
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08)
        clip: true

        ShaderEffect {
            anchors.fill: parent; blending: true
            property real iTime: dash._elapsed
            property real weatherCode: dash.displayedWeatherCode
            property color accent: dash.primary
            property vector4d dims: Qt.vector4d(mainBg.width, mainBg.height, 0, 0)
            fragmentShader: "dashboard-weather.frag.qsb"
            Behavior on weatherCode { NumberAnimation { duration: 500 } }
        }

        Column {
            anchors.fill: parent; anchors.margins: 16; spacing: 10

            // ══════════ WEATHER HERO + 7-DAY ══════════
            Row {
                width: parent.width; spacing: 12

                // Current weather
                Rectangle {
                    width: parent.width * 0.35; height: 130; radius: 16
                    color: Qt.rgba(1, 1, 1, 0.05); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08)
                    Row {
                        anchors.fill: parent; anchors.margins: 16; spacing: 16
                        Text {
                            text: dash.weatherIcon; color: dash.primary
                            font { pixelSize: 48; family: dash.fontFamily }
                            anchors.verticalCenter: parent.verticalCenter
                            y: Math.sin(dash._elapsed * 1.5) * 3
                            MouseArea {
                                anchors.fill: parent; acceptedButtons: Qt.RightButton
                                onClicked: {
                                    var modes = [0, 1, 2, 3, 4];
                                    var names = ["Clear", "Cloudy", "Rain", "Snow", "Thunder"];
                                    var idx = modes.indexOf(Math.round(dash.weatherCode));
                                    idx = (idx + 1) % modes.length;
                                    dash.weatherCode = modes[idx]; dash.selectedDay = -1;
                                    dash.weatherIcon = [String.fromCodePoint(0xf0599), String.fromCodePoint(0xf0590),
                                        String.fromCodePoint(0xf0597), String.fromCodePoint(0xf0598), String.fromCodePoint(0xf0593)][idx];
                                    dash.weatherDesc = names[idx] + " (preview)";
                                }
                            }
                        }
                        Column {
                            spacing: 2; anchors.verticalCenter: parent.verticalCenter
                            Text { text: dash.weatherTemp + "°F"; color: dash.fg
                                font { pixelSize: 32; family: dash.fontFamily; bold: true } }
                            Text { text: dash.weatherDesc; color: dash.fg
                                font { pixelSize: 13; family: dash.fontFamily } }
                            Text { text: "Feels " + dash.weatherFeels + "°F"; color: dash.dim
                                font { pixelSize: 10; family: dash.fontFamily } }
                            Row {
                                spacing: 10
                                Text { text: String.fromCodePoint(0xf059d) + " " + dash.weatherWind; color: dash.dim
                                    font { pixelSize: 9; family: dash.fontFamily } }
                                Text { text: String.fromCodePoint(0xf058e) + " " + dash.weatherHumidity + "%"; color: dash.dim
                                    font { pixelSize: 9; family: dash.fontFamily } }
                            }
                        }
                    }
                }

                // 7-day cards — clickable
                Row {
                    spacing: 5; anchors.verticalCenter: parent.verticalCenter
                    Repeater {
                        model: dash.dailyForecast
                        Rectangle {
                            required property var modelData
                            required property int index
                            width: (dash.width - 32 - dash.width * 0.35 - 12 - 5 * 6) / 7
                            height: 130; radius: 12
                            color: dash.selectedDay === index
                                ? Qt.rgba(dash.primary.r, dash.primary.g, dash.primary.b, 0.18)
                                : modelData.day === "Today" && dash.selectedDay < 0
                                ? Qt.rgba(dash.primary.r, dash.primary.g, dash.primary.b, 0.1)
                                : Qt.rgba(1, 1, 1, 0.04)
                            border.width: 1
                            border.color: dash.selectedDay === index
                                ? Qt.rgba(dash.primary.r, dash.primary.g, dash.primary.b, 0.4)
                                : modelData.day === "Today" && dash.selectedDay < 0
                                ? Qt.rgba(dash.primary.r, dash.primary.g, dash.primary.b, 0.2)
                                : Qt.rgba(1, 1, 1, 0.06)
                            Behavior on color { ColorAnimation { duration: 200 } }
                            Behavior on border.color { ColorAnimation { duration: 200 } }

                            opacity: 0; y: 15
                            Component.onCompleted: { opacity = 1; y = 0; }
                            Behavior on opacity { NumberAnimation { duration: 300 + index * 80; easing.type: Easing.OutCubic } }
                            Behavior on y { NumberAnimation { duration: 300 + index * 80; easing.type: Easing.OutCubic } }

                            scale: dayCardMA.containsMouse ? 1.03 : 1.0
                            z: dayCardMA.containsMouse ? 10 : 0
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                            MouseArea {
                                id: dayCardMA; anchors.fill: parent; hoverEnabled: true
                                onClicked: {
                                    if (dash.selectedDay === parent.index || parent.modelData.day === "Today") {
                                        dash.selectedDay = -1; // back to current real-time weather
                                    } else {
                                        dash.selectedDay = parent.index;
                                    }
                                    // Reset auto-scroll for new day
                                    hourlyStrip.autoScroll = true;
                                    hourlyFlick.contentX = 0;
                                }
                            }

                            Column {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top; anchors.topMargin: 12
                                spacing: 5

                                Text {
                                    text: modelData.day
                                    color: (dash.selectedDay === index || (modelData.day === "Today" && dash.selectedDay < 0)) ? dash.primary : dash.dim
                                    font { pixelSize: 10; family: dash.fontFamily; bold: dash.selectedDay === index }
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                Item {
                                    width: 24; height: 26; anchors.horizontalCenter: parent.horizontalCenter
                                    Text {
                                        anchors.centerIn: parent
                                        anchors.verticalCenterOffset: Math.sin(dash._elapsed * 1.2 + index * 0.8) * 2
                                        text: dash.weatherIconFor(modelData.desc); color: dash.primary
                                        font { pixelSize: 20; family: dash.fontFamily }
                                    }
                                }
                                Text { text: modelData.high + "°"; color: dash.fg; anchors.horizontalCenter: parent.horizontalCenter
                                    font { pixelSize: 13; family: dash.fontFamily; bold: true } }
                                Rectangle { width: 20; height: 2; radius: 1; anchors.horizontalCenter: parent.horizontalCenter
                                    color: Qt.rgba(dash.primary.r, dash.primary.g, dash.primary.b, 0.3) }
                                Text { text: modelData.low + "°"; color: dash.dim; anchors.horizontalCenter: parent.horizontalCenter
                                    font { pixelSize: 10; family: dash.fontFamily } }
                            }
                        }
                    }
                }
            }

            // ── Hourly strip — scrollable, clickable ──
            Rectangle {
                id: hourlyStrip
                width: parent.width; height: 54; radius: 14
                visible: dash.displayedHourly.length > 0
                color: Qt.rgba(1, 1, 1, 0.04); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.06)
                clip: true

                // Auto-scroll animation
                property bool autoScroll: true
                Timer {
                    interval: 30; running: hourlyStrip.autoScroll && hourlyFlick.contentWidth > hourlyFlick.width && dash.visible
                    repeat: true
                    onTriggered: {
                        hourlyFlick.contentX = Math.min(hourlyFlick.contentX + 0.3, hourlyFlick.contentWidth - hourlyFlick.width);
                        if (hourlyFlick.contentX >= hourlyFlick.contentWidth - hourlyFlick.width)
                            hourlyFlick.contentX = 0;
                    }
                }

                Flickable {
                    id: hourlyFlick
                    anchors.fill: parent; anchors.margins: 6
                    contentWidth: hourlyRow.implicitWidth
                    contentHeight: height
                    flickableDirection: Flickable.HorizontalFlick
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    // Stop auto-scroll on interaction
                    onMovementStarted: hourlyStrip.autoScroll = false
                    onFlickStarted: hourlyStrip.autoScroll = false

                    Row {
                        id: hourlyRow; spacing: 2; height: parent.height

                        Repeater {
                            model: dash.displayedHourly

                            Rectangle {
                                required property var modelData
                                required property int index
                                width: 62; height: parent.height; radius: 8
                                color: dash.selectedHour === index
                                    ? Qt.rgba(dash.primary.r, dash.primary.g, dash.primary.b, 0.15)
                                    : hrMA.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                                border.width: dash.selectedHour === index ? 1 : 0
                                border.color: Qt.rgba(dash.primary.r, dash.primary.g, dash.primary.b, 0.3)
                                Behavior on color { ColorAnimation { duration: 120 } }

                                MouseArea {
                                    id: hrMA; anchors.fill: parent; hoverEnabled: true
                                    onClicked: {
                                        if (dash.selectedHour === parent.index) {
                                            dash.selectedHour = -1; // deselect
                                        } else {
                                            dash.selectedHour = parent.index;
                                            hourlyStrip.autoScroll = false;
                                        }
                                    }
                                }

                                Column {
                                    anchors.centerIn: parent; spacing: 1
                                    Text {
                                        text: modelData.time; anchors.horizontalCenter: parent.horizontalCenter
                                        color: dash.selectedHour === index ? dash.primary : dash.dim
                                        font { pixelSize: 9; family: dash.fontFamily;  bold: dash.selectedHour === index }
                                    }
                                    Text {
                                        text: dash.weatherIconFor(modelData.desc); anchors.horizontalCenter: parent.horizontalCenter
                                        color: dash.primary
                                        font { pixelSize: 14; family: dash.fontFamily }
                                    }
                                    Text {
                                        text: modelData.temp + "°"; anchors.horizontalCenter: parent.horizontalCenter
                                        color: dash.selectedHour === index ? dash.primary : dash.fg
                                        font { pixelSize: 10; family: dash.fontFamily; bold: true }
                                    }
                                }
                            }
                        }
                    }
                }

                // Fade edges
                Rectangle {
                    anchors.left: parent.left; width: 20; height: parent.height; radius: 14
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Qt.rgba(dash.bg.r, dash.bg.g, dash.bg.b, 0.9) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }
                Rectangle {
                    anchors.right: parent.right; width: 20; height: parent.height; radius: 14
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.rgba(dash.bg.r, dash.bg.g, dash.bg.b, 0.9) }
                    }
                }
            }

            // ══════════ BOTTOM ROW ══════════
            Row {
                width: parent.width; spacing: 10
                height: parent.height - 130 - 50 - 30

                // Events
                Rectangle {
                    width: parent.width * 0.30; height: parent.height; radius: 14
                    color: Qt.rgba(1, 1, 1, 0.04); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.06)
                    Flickable {
                        anchors.fill: parent; anchors.margins: 10
                        contentHeight: eventsCol.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds
                        Column {
                            id: eventsCol; width: parent.width; spacing: 5
                            Text { text: String.fromCodePoint(0xf00ed) + " Upcoming"; color: dash.dim
                                font { pixelSize: 10; family: dash.fontFamily; bold: true; letterSpacing: 0.5 } }
                            Text { text: "Loading..."; color: dash.dim; visible: dash.calLoading && dash.calEvents.length === 0
                                font { pixelSize: 10; family: dash.fontFamily; italic: true } }
                            Text { text: "No events"; color: dash.dim; visible: !dash.calLoading && dash.calEvents.length === 0
                                font { pixelSize: 10; family: dash.fontFamily; italic: true } }
                            Repeater {
                                model: dash.calEvents
                                Rectangle {
                                    required property var modelData; required property int index
                                    width: parent.width; height: evtC.implicitHeight + 10; radius: 6
                                    color: evtMA2.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    MouseArea { id: evtMA2; anchors.fill: parent; hoverEnabled: true }
                                    opacity: 0; x: -8
                                    Component.onCompleted: { opacity = 1; x = 0; }
                                    Behavior on opacity { NumberAnimation { duration: 200 + index * 50; easing.type: Easing.OutCubic } }
                                    Behavior on x { NumberAnimation { duration: 200 + index * 50; easing.type: Easing.OutCubic } }
                                    Column {
                                        id: evtC; anchors.fill: parent; anchors.margins: 5; spacing: 1
                                        Text { text: modelData.time; color: dash.primary; font { pixelSize: 9; family: dash.fontFamily } }
                                        Text { text: modelData.title; color: dash.fg; font { pixelSize: 11; family: dash.fontFamily }
                                            width: parent.width; wrapMode: Text.WordWrap }
                                    }
                                }
                            }
                        }
                    }
                }

                // Pomodoro
                Rectangle {
                    width: parent.width * 0.22 - 5; height: parent.height; radius: 14
                    color: Qt.rgba(1, 1, 1, 0.04); border.width: 1
                    border.color: dash.pomoRun
                        ? Qt.rgba(dash.pomoMode === "focus" ? dash.primary.r : 0.65,
                                  dash.pomoMode === "focus" ? dash.primary.g : 0.89,
                                  dash.pomoMode === "focus" ? dash.primary.b : 0.63, 0.3)
                        : Qt.rgba(1, 1, 1, 0.06)
                    Behavior on border.color { ColorAnimation { duration: 300 } }
                    Column {
                        anchors.fill: parent; anchors.margins: 10; spacing: 6
                        Text { text: dash.pomoMode === "focus" ? "FOCUS" : "BREAK"
                            color: dash.pomoMode === "focus" ? dash.primary : "#a6e3a1"
                            font { pixelSize: 9; family: dash.fontFamily; bold: true; letterSpacing: 1 }
                            Behavior on color { ColorAnimation { duration: 200 } } }
                        Item {
                            width: 100; height: 100; anchors.horizontalCenter: parent.horizontalCenter
                            Canvas {
                                anchors.fill: parent
                                property real progress: dash.pomoDur > 0 ? 1.0 - (dash.pomoRem / dash.pomoDur) : 0
                                onProgressChanged: requestPaint()
                                onPaint: {
                                    var ctx = getContext("2d"); var w = width, h = height, cx = w/2, cy = h/2, r = 42;
                                    ctx.clearRect(0, 0, w, h);
                                    ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2);
                                    ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.06); ctx.lineWidth = 3; ctx.stroke();
                                    if (progress > 0) {
                                        ctx.beginPath(); ctx.arc(cx, cy, r, -Math.PI/2, -Math.PI/2 + Math.PI * 2 * progress);
                                        ctx.strokeStyle = dash.pomoMode === "focus" ? dash.primary : Qt.rgba(0.65, 0.89, 0.63, 1);
                                        ctx.lineWidth = 3; ctx.lineCap = "round"; ctx.stroke();
                                    }
                                }
                            }
                            Column {
                                anchors.centerIn: parent; spacing: 1
                                Text { anchors.horizontalCenter: parent.horizontalCenter
                                    text: Math.floor(dash.pomoRem / 60).toString().padStart(2, '0') + ":" + (dash.pomoRem % 60).toString().padStart(2, '0')
                                    color: dash.fg; font { pixelSize: 20; family: dash.fontFamily; bold: true } }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: dash.pomoMode
                                    color: dash.dim; font { pixelSize: 8; family: dash.fontFamily } }
                            }
                        }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter; spacing: 4
                            Repeater {
                                model: [{ mode: "focus", label: "F", dur: 25 }, { mode: "break", label: "B", dur: 5 }]
                                Rectangle {
                                    required property var modelData; width: 32; height: 22; radius: 6
                                    color: dash.pomoMode === modelData.mode ? Qt.rgba(dash.primary.r, dash.primary.g, dash.primary.b, 0.15) : Qt.rgba(1, 1, 1, 0.04)
                                    border.width: 1; border.color: dash.pomoMode === modelData.mode ? Qt.rgba(dash.primary.r, dash.primary.g, dash.primary.b, 0.3) : Qt.rgba(1, 1, 1, 0.06)
                                    Text { anchors.centerIn: parent; text: modelData.label; color: dash.pomoMode === modelData.mode ? dash.primary : dash.dim
                                        font { pixelSize: 10; family: dash.fontFamily } }
                                    MouseArea { anchors.fill: parent; onClicked: { dash.pomoMode = modelData.mode; dash.pomoDur = modelData.dur * 60; dash.pomoRem = dash.pomoDur; dash.pomoRun = false; } }
                                }
                            }
                        }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter; spacing: 6
                            Repeater {
                                model: ["play", "reset"]
                                Rectangle {
                                    required property var modelData; width: 28; height: 28; radius: 14
                                    color: pMA.containsMouse ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.06)
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    scale: pMA.containsMouse ? 1.1 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
                                    Text { anchors.centerIn: parent
                                        text: modelData === "play" ? (dash.pomoRun ? String.fromCodePoint(0xf03e4) : String.fromCodePoint(0xf040a)) : String.fromCodePoint(0xf0453)
                                        color: modelData === "play" ? dash.primary : dash.dim; font { pixelSize: 12; family: dash.fontFamily } }
                                    MouseArea { id: pMA; anchors.fill: parent; hoverEnabled: true
                                        onClicked: { if (modelData === "play") dash.pomoRun = !dash.pomoRun; else { dash.pomoRun = false; dash.pomoRem = dash.pomoDur; } } }
                                }
                            }
                        }
                        Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.06) }
                        Column {
                            width: parent.width; spacing: 1
                            Text { id: uptimeText; text: String.fromCodePoint(0xf0954) + " ..."; color: dash.dim; font { pixelSize: 9; family: dash.fontFamily } }
                            Text { id: pkgText; text: String.fromCodePoint(0xf03d7) + " ..."; color: dash.dim; font { pixelSize: 9; family: dash.fontFamily } }
                        }
                    }
                }

                // Notes + Calendar + Network
                Column {
                    width: parent.width * 0.48 - 5; spacing: 8; height: parent.height

                    // Notes (shorter)
                    Rectangle {
                        width: parent.width; height: 120; radius: 14
                        color: Qt.rgba(1, 1, 1, 0.04); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.06)
                        Column {
                            anchors.fill: parent; anchors.margins: 10; spacing: 4
                            Text { text: String.fromCodePoint(0xf09a8) + " Notes"; color: dash.dim
                                font { pixelSize: 9; family: dash.fontFamily; bold: true; letterSpacing: 0.5 } }
                            Flickable {
                                width: parent.width; height: parent.height - 16
                                contentHeight: notesEdit.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds
                                TextEdit {
                                    id: notesEdit; width: parent.width; text: dash.notesText
                                    color: dash.fg; selectionColor: dash.primary
                                    font { pixelSize: 11; family: dash.fontFamily }
                                    wrapMode: TextEdit.Wrap
                                    onTextChanged: { dash.notesText = text; saveDebounce.restart(); }
                                }
                            }
                        }
                    }

                    // Calendar
                    Rectangle {
                        width: parent.width; height: parent.height - 120 - 44 - 16; radius: 14
                        color: Qt.rgba(1, 1, 1, 0.04); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.06)
                        Column {
                            id: calCol; anchors.fill: parent; anchors.margins: 10; spacing: 4
                            Row {
                                width: parent.width
                                Rectangle {
                                    width: 24; height: 22; radius: 6; color: cpMA.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
                                    Text { anchors.centerIn: parent; text: "<"; color: cpMA.containsMouse ? dash.primary : dash.dim
                                        font { pixelSize: 12; family: dash.fontFamily; bold: true } }
                                    MouseArea { id: cpMA; anchors.fill: parent; hoverEnabled: true
                                        onClicked: { var d = dash.currentDate; dash.currentDate = new Date(d.getFullYear(), d.getMonth() - 1, 1); } }
                                }
                                Item {
                                    width: parent.width - 48; height: 22
                                    Text { anchors.centerIn: parent; text: Qt.formatDateTime(dash.currentDate, "MMMM yyyy")
                                        color: dash.fg; font { pixelSize: 11; family: dash.fontFamily; bold: true } }
                                    MouseArea { anchors.fill: parent; onDoubleClicked: dash.currentDate = new Date() }
                                }
                                Rectangle {
                                    width: 24; height: 22; radius: 6; color: cnMA.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
                                    Text { anchors.centerIn: parent; text: ">"; color: cnMA.containsMouse ? dash.primary : dash.dim
                                        font { pixelSize: 12; family: dash.fontFamily; bold: true } }
                                    MouseArea { id: cnMA; anchors.fill: parent; hoverEnabled: true
                                        onClicked: { var d = dash.currentDate; dash.currentDate = new Date(d.getFullYear(), d.getMonth() + 1, 1); } }
                                }
                            }
                            Row {
                                spacing: 0
                                Repeater { model: ["Mo","Tu","We","Th","Fr","Sa","Su"]
                                    Text { width: calCol.width / 7; text: modelData; color: dash.dim
                                        font { pixelSize: 8; family: dash.fontFamily; bold: true }
                                        horizontalAlignment: Text.AlignHCenter } }
                            }
                            Grid {
                                columns: 7; spacing: 0
                                Repeater {
                                    model: 42
                                    Rectangle {
                                        required property int index
                                        property int dayNum: {
                                            var d = dash.currentDate; var first = new Date(d.getFullYear(), d.getMonth(), 1);
                                            var off = first.getDay() === 0 ? 6 : first.getDay() - 1;
                                            var last = new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate();
                                            var n = index - off + 1; return (n >= 1 && n <= last) ? n : 0; }
                                        property bool isToday: {
                                            var now = new Date(); var d = dash.currentDate;
                                            return dayNum > 0 && now.getDate() === dayNum && now.getMonth() === d.getMonth() && now.getFullYear() === d.getFullYear(); }
                                        width: calCol.width / 7; height: 22; radius: 6
                                        color: isToday ? dash.primary : cdMA.containsMouse && dayNum > 0 ? Qt.rgba(1,1,1,0.08) : "transparent"
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                        Text { anchors.centerIn: parent; text: parent.dayNum > 0 ? parent.dayNum : ""
                                            color: parent.isToday ? dash.bg : parent.dayNum > 0 ? (cdMA.containsMouse ? dash.primary : dash.fg) : "transparent"
                                            font { pixelSize: 10; family: dash.fontFamily; bold: parent.isToday } }
                                        MouseArea { id: cdMA; anchors.fill: parent; hoverEnabled: true }
                                    }
                                }
                            }
                        }
                    }

                    // Network
                    Rectangle {
                        width: parent.width; height: 36; radius: 10
                        color: Qt.rgba(1, 1, 1, 0.04); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.06)
                        Row {
                            anchors.centerIn: parent; spacing: 8
                            Text { text: String.fromCodePoint(0xf05a9); color: dash.primary; font { pixelSize: 12; family: dash.fontFamily } }
                            Text { text: dash.netSSID; color: dash.fg; font { pixelSize: 10; family: dash.fontFamily; bold: true } }
                            Text { text: "·"; color: dash.dim; font { pixelSize: 10 } }
                            Text { text: dash.netIP; color: dash.dim; font { pixelSize: 9; family: dash.fontFamily } }
                        }
                    }
                }
            }
        }
    }

    Shortcut { sequence: "Escape"; onActivated: dash.showing = false; enabled: dash.showing }
}
