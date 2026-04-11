//@ pragma UseQApplication
//@ pragma ShellId river-bar

import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.SystemTray
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import Quickshell.Bluetooth
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts
import "services" as Services
import "components" as C

Scope {
    id: root

    // ══════════════════════════════════════
    // Theme (loaded from pywal/matugen colors.json)
    // ══════════════════════════════════════
    property color bg:        "#0e1120"
    property color fg:        "#c2c3c7"
    property color surface:   "#0e1120"
    property color dim:       "#5d6172"
    property color primary:   "#1376C6"
    property color secondary: "#5E90B2"
    property color accent:    "#2393D7"
    property color cRed:      "#f38ba8"
    property color cGreen:    "#a6e3a1"
    property color cYellow:   "#f9e2af"
    property color cMaroon:   "#eba0ac"
    property color cPink:     "#f5c2e7"
    property color pillBg:    Qt.rgba(bg.r, bg.g, bg.b, 0.85)
    property color pillBorder: Qt.rgba(0.08, 0.42, 0.78, 0.5)
    property string ff:       "JetBrainsMono Nerd Font"
    property int fs:          13
    property int pillH:       34
    property int pillR:       17
    property int pillPad:     20

    onBgChanged: pillBg = Qt.rgba(bg.r, bg.g, bg.b, 0.85)

    FileView {
        id: walFile
        path: Qt.resolvedUrl("file://" + Quickshell.env("HOME") + "/.cache/wal/colors.json")
        watchChanges: true
        onFileChanged: walFile.reload()
        function apply() {
            try {
                var o = JSON.parse(walFile.text());
                if (o.special) { root.bg = o.special.background; root.fg = o.special.foreground; }
                if (o.colors) {
                    root.surface = o.colors.color0; root.primary = o.colors.color4;
                    root.secondary = o.colors.color5; root.accent = o.colors.color6;
                    root.dim = o.colors.color8;
                    var pR = parseInt(o.colors.color4.substr(1,2),16)/255;
                    var pG = parseInt(o.colors.color4.substr(3,2),16)/255;
                    var pB = parseInt(o.colors.color4.substr(5,2),16)/255;
                    root.pillBorder = Qt.rgba(pR, pG, pB, 0.5);
                }
            } catch(e) {}
        }
        Component.onCompleted: apply()
        onLoaded: apply()
    }

    // ══════════════════════════════════════
    // Nerd font icons
    // ══════════════════════════════════════
    readonly property string iCpu:    String.fromCodePoint(0xf2db)
    readonly property string iMem:    String.fromCodePoint(0xefc5)
    readonly property string iTemp:   String.fromCodePoint(0xf050f)
    readonly property string iVolOn:  String.fromCodePoint(0xf057e)
    readonly property string iVolMute:String.fromCodePoint(0xf075f)
    readonly property string iMicOn:  String.fromCodePoint(0xf036c)
    readonly property string iMicOff: String.fromCodePoint(0xf036d)
    readonly property string iBright: String.fromCodePoint(0xf00df)
    readonly property string iNotif:  String.fromCodePoint(0xf009a)
    readonly property string iNotifOff: String.fromCodePoint(0xf009b) // bell-off
    readonly property string iPlay:   String.fromCodePoint(0xf040a)
    readonly property string iPause:  String.fromCodePoint(0xf03e4)
    readonly property string iCoffee: String.fromCodePoint(0xf0176)
    readonly property string iSleep:  String.fromCodePoint(0xf04b2)

    // ══════════════════════════════════════
    // Services
    // ══════════════════════════════════════
    Services.SysInfo { id: sys }

    property bool clockShowDate: false
    property string clockTime: clockShowDate
        ? Qt.formatDateTime(sysClock.date, "yyyy-MM-dd")
        : Qt.formatDateTime(sysClock.date, "hh:mm AP")
    property string calendarText: {
        var d = sysClock.date;
        var month = Qt.formatDateTime(d, "MMMM yyyy");
        var today = d.getDate();
        var first = new Date(d.getFullYear(), d.getMonth(), 1);
        var lastDay = new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate();
        var startDay = first.getDay();
        var cal = month + "\nMo Tu We Th Fr Sa Su\n";
        var line = "   ".repeat(startDay === 0 ? 6 : startDay - 1);
        for (var i = 1; i <= lastDay; i++) {
            var ds = i < 10 ? " " + i : "" + i;
            if (i === today) ds = "[" + i + "]";
            line += (ds.length < 3 ? ds + " " : ds);
            var dow = new Date(d.getFullYear(), d.getMonth(), i).getDay();
            if (dow === 0) { cal += line.replace(/\s+$/, "") + "\n"; line = ""; }
        }
        if (line.trim()) cal += line.replace(/\s+$/, "");
        return cal;
    }
    SystemClock { id: sysClock; precision: SystemClock.Seconds }

    property var activePlayer: {
        var pl = Mpris.players.values;
        if (!pl || pl.length === 0) return null;
        for (var i = 0; i < pl.length; i++)
            if (pl[i].playbackState === MprisPlaybackState.Playing) return pl[i];
        return pl[0];
    }

    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }

    property bool idleInhibited: false
    property bool battShowTime: false
    property bool dndActive: false
    property int notifCount: 0

    // Launcher processes
    Process { id: idleInhibitOn; command: ["sh", "-c", "systemd-inhibit --what=idle --who=quickshell --why='User requested' --mode=block sleep infinity &"] }
    Process { id: idleInhibitOff; command: ["sh", "-c", "pkill -f 'systemd-inhibit.*quickshell'"] }
    Process { id: openBtop; command: ["ghostty", "-e", "btop"] }
    Process { id: openDiskUsage; command: ["baobab"] }
    Process { id: openPavucontrol; command: ["pavucontrol"] }
    Process { id: blUp; command: ["brightnessctl", "s", "+5%"] }
    Process { id: blDown; command: ["brightnessctl", "s", "5%-"] }
    Process { id: swayncToggle; command: ["swaync-client", "-t", "-sw"] }
    Process { id: swayncDnd; command: ["swaync-client", "-d", "-sw"]
        onRunningChanged: if (!running) root.dndActive = !root.dndActive }
    // Subscribe to swaync status changes (long-running, fires on every state change)
    Process { id: dndWatch; command: ["swaync-client", "-swb"]; running: true
        stdout: SplitParser { onRead: data => {
            try { var j = JSON.parse(data); root.dndActive = (j.alt || "").indexOf("dnd") >= 0; root.notifCount = parseInt(j.text) || 0; } catch(e) {}
        }}
    }
    // Popup management
    function closePopups() { calendarPopup.showing = false; btPopup.showing = false;
        cpuPopup.showing = false; memPopup.showing = false; tempPopup.showing = false;
        blPopup.showing = false; wifiPopup.showing = false; mprisPopup.showing = false;
        batPopup.showing = false; }
    function togglePopup(popup) { var was = popup.showing; closePopups(); popup.showing = !was; }

    // Popups
    C.Dashboard {
        id: calendarPopup
        bg: root.bg; fg: root.fg; dim: root.dim; primary: root.primary
    }

    C.BluetoothPopup {
        id: btPopup
        bg: root.bg; fg: root.fg; dim: root.dim; primary: root.primary
        red: root.cRed; green: root.cGreen
    }

    C.InfoPopup { id: cpuPopup; bg: root.bg; fg: root.fg; dim: root.dim; primary: root.primary
        title: "CPU"; content: sys.cpuDetail; popupX: 10 }

    C.InfoPopup { id: memPopup; bg: root.bg; fg: root.fg; dim: root.dim; primary: root.primary
        title: "Memory & Disk"; content: sys.memDetail; popupX: 100 }

    C.InfoPopup { id: tempPopup; bg: root.bg; fg: root.fg; dim: root.dim; primary: root.primary
        title: "Thermals"; content: sys.tempDetail; popupX: 85 }

    C.BatteryPopup { id: batPopup; bg: root.bg; fg: root.fg; dim: root.dim; primary: root.primary
        green: root.cGreen }

    C.BrightnessPopup { id: blPopup; bg: root.bg; fg: root.fg; dim: root.dim; primary: root.primary
        yellow: root.cYellow; brightness: sys.brightness }

    C.WifiPopup { id: wifiPopup; bg: root.bg; fg: root.fg; dim: root.dim; primary: root.primary
        green: root.cGreen }

    C.MprisPopup { id: mprisPopup; bg: root.bg; fg: root.fg; dim: root.dim; primary: root.primary
        secondary: root.secondary; player: root.activePlayer }

    // Wallpaper picker
    C.WallpaperPicker {
        id: wallpaperPicker
        bg: root.bg; fg: root.fg; dim: root.dim; primary: root.primary
        green: root.cGreen; yellow: root.cYellow
    }

    FileView {
        path: "file:///tmp/qs-wallpaper-picker"
        watchChanges: true
        onFileChanged: {
            if (wallpaperPicker.showing) wallpaperPicker.showing = false;
            else wallpaperPicker.showing = true;
        }
    }

    // Power menu overlay
    C.PowerMenu {
        id: powerMenu
        bg: root.bg; primary: root.primary; fg: root.fg; dim: root.dim
        red: root.cRed; green: root.cGreen; yellow: root.cYellow
    }

    // ══════════════════════════════════════
    // Shared tooltip state
    // ══════════════════════════════════════
    property string ttText: ""
    property real ttX: 0
    property bool ttVisible: false

    // ══════════════════════════════════════
    // Bar
    // ══════════════════════════════════════
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar
            required property var modelData
            screen: modelData

            anchors { top: true; left: true; right: true }
            margins.top: 5
            implicitHeight: 40
            color: "transparent"

            // Tooltip rendered at bar level (not clipped by Row)
            Rectangle {
                id: barTooltip
                visible: root.ttVisible && root.ttText !== ""
                x: Math.max(4, Math.min(root.ttX - width/2, bar.width - width - 4))
                y: bar.implicitHeight + 2
                width: ttLabel.implicitWidth + 24
                height: ttLabel.implicitHeight + 16
                radius: 10
                color: Qt.rgba(0.05, 0.05, 0.08, 0.94)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.1)
                z: 999

                opacity: root.ttVisible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 120 } }
                Behavior on x { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }

                Text {
                    id: ttLabel
                    anchors.centerIn: parent
                    text: root.ttText
                    color: "#e1e2e9"
                    font { pixelSize: 12; family: root.ff }
                    lineHeight: 1.4
                }
            }

            // ── LEFT ──
            Row {
                anchors.left: parent.left; anchors.leftMargin: 10
                anchors.bottom: parent.bottom; anchors.bottomMargin: 2
                spacing: 18

                C.Pill {
                    function zpad(n) { return n >= 100 ? "100" : n < 10 ? "0" + n : "" + n; }
                    label: root.iCpu + " " + zpad(sys.cpuUsage) + "%"
                    labelColor: root.primary; pillBg: root.pillBg; pillBorder: root.pillBorder
                    pillHeight: root.pillH; pillRadius: root.pillR; pillPadding: root.pillPad
                    fontFamily: root.ff; fontSize: root.fs
                    tooltipText: sys.cpuDetail
                    onClicked: mouse => { if (mouse.button === Qt.RightButton) openBtop.running = true; else root.togglePopup(cpuPopup); }
                    onTooltipShow: (gx, t) => { root.ttText = t; root.ttX = gx; root.ttVisible = true; }
                    onTooltipHide: root.ttVisible = false
                }

                C.Pill {
                    function zpad(n) { return n >= 100 ? "100" : n < 10 ? "0" + n : "" + n; }
                    label: root.iMem + " " + zpad(sys.memUsage) + "%"
                    labelColor: root.accent; pillBg: root.pillBg; pillBorder: root.pillBorder
                    pillHeight: root.pillH; pillRadius: root.pillR; pillPadding: root.pillPad
                    fontFamily: root.ff; fontSize: root.fs
                    tooltipText: sys.memDetail
                    onClicked: mouse => { if (mouse.button === Qt.RightButton) openDiskUsage.running = true; else root.togglePopup(memPopup); }
                    onTooltipShow: (gx, t) => { root.ttText = t; root.ttX = gx; root.ttVisible = true; }
                    onTooltipHide: root.ttVisible = false
                }

                C.Pill {
                    label: root.iTemp + " " + sys.temperature + "°C"
                    labelColor: sys.temperature >= 80 ? root.cRed : root.secondary
                    pillBg: root.pillBg; pillBorder: root.pillBorder
                    pillHeight: root.pillH; pillRadius: root.pillR; pillPadding: root.pillPad
                    fontFamily: root.ff; fontSize: root.fs
                    tooltipText: sys.tempDetail
                    onClicked: root.togglePopup(tempPopup)
                    onTooltipShow: (gx, t) => { root.ttText = t; root.ttX = gx; root.ttVisible = true; }
                    onTooltipHide: root.ttVisible = false
                }

                C.Pill {
                    label: { if (root.battShowTime && sys.battTimeRemaining) return sys.battIcon + " " + sys.battTimeRemaining;
                        return sys.battIcon + " " + sys.battLevel + "%"; }
                    labelColor: sys.battCharging ? root.cGreen : sys.battLevel <= 20 ? root.cRed : sys.battLevel <= 30 ? root.cYellow : root.cGreen
                    pillBg: root.pillBg; pillBorder: root.pillBorder
                    pillHeight: root.pillH; pillRadius: root.pillR; pillPadding: root.pillPad
                    fontFamily: root.ff; fontSize: root.fs
                    onClicked: mouse => { if (mouse.button === Qt.RightButton) root.battShowTime = !root.battShowTime; else root.togglePopup(batPopup); }
                    onTooltipShow: (gx, t) => { root.ttText = t; root.ttX = gx; root.ttVisible = true; }
                    onTooltipHide: root.ttVisible = false
                }

                // Cava
                Rectangle {
                    height: root.pillH; width: 150; radius: root.pillR
                    color: root.pillBg; border.width: 1; border.color: root.pillBorder
                    visible: sys.cavaOutput !== ""; clip: true
                    Behavior on color { ColorAnimation { duration: 250 } }
                    Behavior on border.color { ColorAnimation { duration: 250 } }
                    Text { anchors.centerIn: parent; text: sys.cavaOutput
                        color: root.cPink; font { pixelSize: 14; family: "JetBrainsMono Nerd Font Mono"; letterSpacing: 0 } }
                }

                // Window title
                Rectangle {
                    id: winPill
                    height: root.pillH
                    width: winT.text !== "" ? Math.min(winT.implicitWidth + root.pillPad, 300) : 0
                    radius: root.pillR; color: root.pillBg; border.width: 1; border.color: root.pillBorder
                    clip: true; visible: width > 0
                    Behavior on color { ColorAnimation { duration: 250 } }
                    Behavior on border.color { ColorAnimation { duration: 250 } }
                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    Text { id: winT; anchors.centerIn: parent
                        width: Math.max(0, parent.width - root.pillPad)
                        property string raw: Hyprland.activeToplevel ? (Hyprland.activeToplevel.title || "") : ""
                        text: raw
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        color: root.dim; font { pixelSize: root.fs; family: root.ff } }
                }
            }

            // ── CENTER ──
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom; anchors.bottomMargin: 2
                spacing: 18

                Rectangle {
                    height: root.pillH; width: wsRow.implicitWidth + 20; radius: root.pillR
                    color: root.pillBg; border.width: 1; border.color: root.pillBorder
                    Behavior on color { ColorAnimation { duration: 250 } }
                    Behavior on border.color { ColorAnimation { duration: 250 } }
                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Row {
                        id: wsRow; anchors.centerIn: parent; spacing: 4
                        Repeater {
                            model: 10
                            Rectangle {
                                required property int index
                                property int wsId: index + 1
                                property bool active: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === wsId
                                property bool occupied: {
                                    var ws = Hyprland.workspaces.values;
                                    if (!ws) return false;
                                    for (var i = 0; i < ws.length; i++) if (ws[i].id === wsId) return true;
                                    return false; }
                                visible: occupied || active
                                width: active ? 36 : 28; height: 32; radius: 16
                                color: active ? root.primary : "transparent"
                                scale: wsH.containsMouse ? 1.1 : 1.0
                                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                Behavior on color { ColorAnimation { duration: 200 } }
                                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
                                Text { anchors.centerIn: parent; text: parent.wsId
                                    color: parent.active ? root.bg : root.dim
                                    font { pixelSize: root.fs; bold: parent.active; family: root.ff }
                                    Behavior on color { ColorAnimation { duration: 200 } } }
                                MouseArea { id: wsH; anchors.fill: parent; hoverEnabled: true
                                    onClicked: Hyprland.dispatch("workspace " + parent.wsId) }
                            }
                        }
                    }
                }
            }

            // ── RIGHT ──
            Row {
                anchors.right: parent.right; anchors.rightMargin: 10
                anchors.bottom: parent.bottom; anchors.bottomMargin: 2
                spacing: 18

                // Idle Inhibitor
                C.Pill {
                    label: root.idleInhibited ? root.iCoffee : root.iSleep
                    labelColor: root.idleInhibited ? root.accent : root.dim
                    pillBg: root.pillBg; pillBorder: root.pillBorder
                    pillHeight: root.pillH; pillRadius: root.pillR; pillPadding: 20
                    fontFamily: root.ff; fontSize: root.fs + 2; minWidth: root.pillH
                    tooltipText: root.idleInhibited ? "Idle inhibitor ON" : "Idle inhibitor OFF"
                    onClicked: { root.idleInhibited = !root.idleInhibited;
                        if (root.idleInhibited) idleInhibitOn.running = true;
                        else idleInhibitOff.running = true; }
                    onTooltipShow: (gx, t) => { root.ttText = t; root.ttX = gx; root.ttVisible = true; }
                    onTooltipHide: root.ttVisible = false
                }

                // Volume + Mic
                C.Pill {
                    label: {
                        var sink = Pipewire.defaultAudioSink;
                        var src = Pipewire.defaultAudioSource;
                        var vol = "";
                        if (!sink || !sink.audio) vol = root.iVolOn + " --";
                        else if (sink.audio.muted) vol = root.iVolMute;
                        else vol = root.iVolOn + " " + Math.round(sink.audio.volume * 100) + "%";
                        if (src && src.audio && src.audio.muted) vol += " " + root.iMicOff;
                        else if (src && src.audio) vol += " " + root.iMicOn;
                        return vol;
                    }
                    labelColor: { var s = Pipewire.defaultAudioSink;
                        return (s && s.audio && s.audio.muted) ? root.dim : root.primary; }
                    pillBg: root.pillBg; pillBorder: root.pillBorder
                    pillHeight: root.pillH; pillRadius: root.pillR; pillPadding: 22
                    fontFamily: root.ff; fontSize: root.fs
                    tooltipText: {
                        var sink = Pipewire.defaultAudioSink;
                        var src = Pipewire.defaultAudioSource;
                        var t = "";
                        if (sink) { t += (sink.name || "Output");
                            if (sink.audio) t += ": " + Math.round(sink.audio.volume * 100) + "%" + (sink.audio.muted ? " (muted)" : ""); }
                        if (src) { t += "\n" + (src.name || "Input");
                            if (src.audio) t += ": " + Math.round(src.audio.volume * 100) + "%" + (src.audio.muted ? " (muted)" : ""); }
                        return t;
                    }
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton) { openPavucontrol.running = true; return; }
                        var s = Pipewire.defaultAudioSink; if (s && s.audio) s.audio.muted = !s.audio.muted;
                    }
                    onWheel: wheel => { var s = Pipewire.defaultAudioSink; if (!s || !s.audio) return;
                        s.audio.volume = Math.max(0, Math.min(1.5, s.audio.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))); }
                    onTooltipShow: (gx, t) => { root.ttText = t; root.ttX = gx; root.ttVisible = true; }
                    onTooltipHide: root.ttVisible = false
                }

                // Backlight
                C.Pill {
                    label: root.iBright + " " + sys.brightness + "%"
                    labelColor: root.cYellow; pillBg: root.pillBg; pillBorder: root.pillBorder
                    pillHeight: root.pillH; pillRadius: root.pillR; pillPadding: 22
                    fontFamily: root.ff; fontSize: root.fs
                    onClicked: root.togglePopup(blPopup)
                    onWheel: wheel => {
                        if (wheel.angleDelta.y > 0) blUp.running = true; else blDown.running = true;
                        sys.brightness = Math.max(0, Math.min(100, sys.brightness + (wheel.angleDelta.y > 0 ? 5 : -5)));
                    }
                    onTooltipShow: (gx, t) => { root.ttText = t; root.ttX = gx; root.ttVisible = true; }
                    onTooltipHide: root.ttVisible = false
                }

                // MPRIS
                C.Pill {
                    label: { if (!root.activePlayer) return root.iPause + " No media";
                        var icon = root.activePlayer.playbackState === MprisPlaybackState.Playing ? root.iPlay : root.iPause;
                        var a = root.activePlayer.trackArtist || ""; var t = root.activePlayer.trackTitle || "";
                        var info = t ? (a ? t + " - " + a : t) : a;
                        // CJK chars count as 2 toward limit; limit scales with workspace count
                        var wsCount = 0; var wsv = Hyprland.workspaces.values;
                        if (wsv) for (var w = 0; w < wsv.length; w++) if (wsv[w].id >= 1 && wsv[w].id <= 10) wsCount++;
                        var limit = wsCount <= 6 ? 23 : wsCount === 7 ? 19 : wsCount === 8 ? 16 : wsCount === 9 ? 13 : 11; var count = 0; var cut = info.length;
                        for (var i = 0; i < info.length; i++) {
                            count += info.charCodeAt(i) > 0x2E80 ? 2 : 1;
                            if (count > limit) { cut = i; break; }
                        }
                        return icon + " " + (cut < info.length ? info.substring(0, cut) + "…" : info); }
                    labelColor: root.secondary; pillBg: root.pillBg; pillBorder: root.pillBorder
                    pillHeight: root.pillH; pillRadius: root.pillR; pillPadding: 22
                    fontFamily: root.ff; fontSize: root.fs
                    tooltipText: {
                        if (!root.activePlayer) return "";
                        var t = root.activePlayer.trackTitle || "Unknown";
                        var a = root.activePlayer.trackArtist || "Unknown";
                        var alb = root.activePlayer.trackAlbum || "";
                        var pos = Math.floor(root.activePlayer.position || 0);
                        var len = Math.floor(root.activePlayer.length || 0);
                        var fmt = function(s) { return Math.floor(s/60) + ":" + ("0" + (s%60)).slice(-2); };
                        var info = t + "\n" + a;
                        if (alb) info += "\n" + alb;
                        if (len > 0) info += "\n" + fmt(pos) + " / " + fmt(len);
                        info += "\n" + (root.activePlayer.identity || "");
                        return info;
                    }
                    onClicked: root.togglePopup(mprisPopup)
                    onTooltipShow: (gx, t) => { root.ttText = t; root.ttX = gx; root.ttVisible = true; }
                    onTooltipHide: root.ttVisible = false
                }

                // System Tray
                Rectangle {
                    height: root.pillH; width: trayRow.implicitWidth + 16; radius: root.pillR
                    color: root.pillBg; border.width: 1; border.color: root.pillBorder
                    visible: trayRepeater.count > 0
                    Behavior on color { ColorAnimation { duration: 250 } }
                    Behavior on border.color { ColorAnimation { duration: 250 } }
                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Row { id: trayRow; anchors.centerIn: parent; spacing: 6

                        // Tray items
                        Repeater { id: trayRepeater; model: SystemTray.items
                            MouseArea { id: trayItem; required property SystemTrayItem modelData
                                width: 22; height: 22
                                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                onClicked: mouse => {
                                    if (mouse.button === Qt.LeftButton) trayItem.modelData.activate();
                                    else if (mouse.button === Qt.RightButton && trayItem.modelData.hasMenu) trayMenu.open();
                                    else if (mouse.button === Qt.MiddleButton) trayItem.modelData.secondaryActivate(); }
                                IconImage { anchors.centerIn: parent; source: trayItem.modelData.icon; implicitSize: 20 }
                                QsMenuAnchor { id: trayMenu; menu: trayItem.modelData.menu; anchor.window: bar
                                    anchor.adjustment: PopupAdjustment.Flip
                                    anchor.onAnchoring: { var rect = bar.contentItem.mapFromItem(trayItem, 0, trayItem.height, trayItem.width, trayItem.height); trayMenu.anchor.rect = rect; } }
                            }
                        }

                        // WiFi icon
                        MouseArea {
                            property var wifiDev: {
                                var devs = Networking.devices ? Networking.devices.values : [];
                                for (var i = 0; i < devs.length; i++)
                                    if (devs[i].type === DeviceType.Wifi) return devs[i];
                                return null; }
                            property bool connected: {
                                if (!wifiDev || !wifiDev.networks) return false;
                                var nets = wifiDev.networks.values;
                                for (var i = 0; i < nets.length; i++) if (nets[i].connected) return true;
                                return false; }
                            width: 22; height: 22
                            onClicked: root.togglePopup(wifiPopup)
                            Text { anchors.centerIn: parent
                                text: Networking.wifiEnabled ? String.fromCodePoint(0xf05a9) : String.fromCodePoint(0xf05aa)
                                color: root.dim
                                font { pixelSize: 16; family: root.ff } }
                        }

                        // Bluetooth icon
                        MouseArea {
                            property int btCount: {
                                if (!Bluetooth.devices) return 0;
                                var devs = Bluetooth.devices.values; var n = 0;
                                for (var i = 0; i < devs.length; i++) if (devs[i].connected) n++;
                                return n; }
                            width: 22; height: 22
                            onClicked: root.togglePopup(btPopup)
                            Text { anchors.centerIn: parent
                                text: parent.btCount > 0 ? String.fromCodePoint(0xf00b1) : String.fromCodePoint(0xf00af)
                                color: root.dim
                                font { pixelSize: 16; family: root.ff } }
                        }
                    }
                }

                // SwayNC
                C.Pill {
                    label: (root.dndActive ? root.iNotifOff : root.iNotif) + (root.notifCount > 0 ? " " + root.notifCount : "")
                    labelColor: root.dndActive ? root.dim : root.accent
                    pillBg: root.pillBg; pillBorder: root.pillBorder
                    pillHeight: root.pillH; pillRadius: root.pillR; pillPadding: 20
                    fontFamily: root.ff; fontSize: root.fs; minWidth: root.pillH
                    onClicked: mouse => {
                        if (mouse.button === Qt.LeftButton) swayncToggle.running = true;
                        else swayncDnd.running = true; }
                    onTooltipShow: (gx, t) => { root.ttText = t; root.ttX = gx; root.ttVisible = true; }
                    onTooltipHide: root.ttVisible = false
                }

                // Clock
                C.Pill {
                    label: root.clockTime; labelColor: root.fg
                    pillBg: root.pillBg; pillBorder: root.pillBorder
                    pillHeight: root.pillH; pillRadius: root.pillR; pillPadding: 22
                    fontFamily: root.ff; fontSize: root.fs
                    tooltipText: root.calendarText
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton) root.clockShowDate = !root.clockShowDate;
                        else root.togglePopup(calendarPopup);
                    }
                    onTooltipShow: (gx, t) => { root.ttText = t; root.ttX = gx; root.ttVisible = true; }
                    onTooltipHide: root.ttVisible = false
                }

                // Power
                C.Pill {
                    label: "⏻"; labelColor: root.cMaroon
                    pillBg: root.pillBg; pillBorder: root.pillBorder
                    pillHeight: root.pillH; pillRadius: root.pillR; pillPadding: 20
                    fontFamily: root.ff; fontSize: root.fs + 2; minWidth: root.pillH
                    onClicked: powerMenu.showing = !powerMenu.showing
                    onTooltipShow: (gx, t) => { root.ttText = t; root.ttX = gx; root.ttVisible = true; }
                    onTooltipHide: root.ttVisible = false
                }
            }
        }
    }
}
