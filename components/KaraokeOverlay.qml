import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Io
import QtQuick
import "../services" as Services

PanelWindow {
    id: karaoke

    property color bg: "#0a0a0f"
    property color fg: "#e1e2e9"
    property color dim: "#5d6172"
    property color primary: "#a3c9ff"
    property color accent2: "#c084fc"
    property color accent3: "#f0abfc"
    property string fontFamily: "JetBrainsMono Nerd Font"

    property bool showing: false
    property var player: null
    property real mprisPos: 0
    property real mprisLen: 0

    // Lyrics (fed from shell.qml via LyricsProvider)
    property string lyricsPrev2: ""
    property string lyricsPrev: ""
    property string lyricsCurrent: ""
    property string lyricsNext: ""
    property string lyricsNext2: ""

    visible: showing && player !== null
    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Services.ArtProcessor {
        id: artProc
        sourceUrl: karaoke.player ? karaoke.player.trackArtUrl : ""
    }

    // ── Dominant color from album art ──
    property color artColor: "#a3c9ff"
    property color artColor2: "#c084fc"
    property color artColor3: "#f0abfc"

    Process {
        id: artColorProc
        property string artUrl: karaoke.player ? (karaoke.player.trackArtUrl || "") : ""
        command: ["sh", "-c",
            "curl -sL '" + artUrl + "' -o /tmp/qs-art/original.png 2>/dev/null && " +
            "matugen image --json hex --prefer saturation /tmp/qs-art/original.png 2>/dev/null | " +
            "python3 -c \"import json,sys; d=json.load(sys.stdin)['colors'];" +
            "print(d['primary']['dark']['color']);" +
            "print(d['secondary']['dark']['color']);" +
            "print(d['tertiary']['dark']['color'])\""]
        stdout: SplitParser {
            property int lineNum: 0
            onRead: data => {
                var hex = data.trim();
                if (hex.length >= 6) {
                    if (hex[0] !== '#') hex = '#' + hex;
                    if (lineNum === 0) karaoke.artColor = hex;
                    else if (lineNum === 1) karaoke.artColor2 = hex;
                    else if (lineNum === 2) karaoke.artColor3 = hex;
                    lineNum++;
                }
            }
        }
        onRunningChanged: { if (running) stdout.lineNum = 0; }
    }

    Connections {
        target: artColorProc
        function onArtUrlChanged() {
            if (artColorProc.artUrl !== "" && karaoke.visible)
                artColorProc.running = true;
        }
    }

    onVisibleChanged: {
        if (visible && artColorProc.artUrl !== "") artColorProc.running = true;
    }

    // ── Cava audio data ──
    property var samples: []
    Process {
        id: cavaProc
        command: ["cava", "-p", "/home/river/.config/hypr/scripts/cava-scope.conf"]
        running: karaoke.showing
        stdout: SplitParser {
            onRead: data => {
                var raw = data.split(";");
                var arr = [];
                for (var i = 0; i < raw.length; i++) {
                    var val = parseInt(raw[i].trim());
                    if (!isNaN(val)) arr.push(val / 100);
                }
                if (arr.length >= 2) karaoke.samples = arr;
            }
        }
    }

    property var normSamples: {
        var s = karaoke.samples;
        var len = Math.min(s.length, 32);
        var peak = 0.0;
        for (var i = 0; i < len; i++) { if (s[i] > peak) peak = s[i]; }
        var norm = peak > 0.01 ? peak : 1.0;
        var out = [];
        for (var i = 0; i < 32; i++) {
            if (i < len) {
                var raw = s[i] / norm;
                out.push(Math.min(Math.pow(raw, 1.6), 0.85));
            } else {
                out.push(0.0);
            }
        }
        return out;
    }

    property real _elapsed: 0
    Timer {
        interval: 16; running: karaoke.visible; repeat: true
        onTriggered: karaoke._elapsed += 0.016
    }

    // ── Full-screen layers ──
    Rectangle {
        anchors.fill: parent
        color: karaoke.bg

        // Album art as shader source
        Image {
            id: artBgImg
            anchors.fill: parent
            source: artProc.bgPath; fillMode: Image.PreserveAspectCrop
            visible: false // hidden, fed into shader
        }

        // ── Art-based animated background ──
        ShaderEffect {
            anchors.fill: parent
            property var src: artBgImg
            property real iTime: karaoke._elapsed
            property real isPlaying: karaoke.player && karaoke.player.playbackState === MprisPlaybackState.Playing ? 1.0 : 0.0
            property real energy: {
                var s = karaoke.samples; var sum = 0;
                for (var i = 0; i < s.length; i++) sum += s[i];
                return s.length > 0 ? sum / s.length : 0;
            }
            property real bass: {
                var s = karaoke.samples;
                return s.length >= 4 ? (s[0] + s[1] + s[2] + s[3]) / 4 : 0;
            }
            property real kick: Math.max(0, bass - 0.5) * 2.0
            fragmentShader: "karaoke-artbg.frag.qsb"
        }

        // ── Cava waveform ──
        Canvas {
            id: cavaCanvas
            anchors.left: parent.left; anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 150

            property var samps: normSamples
            onSampsChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d");
                var w = width, h = height;
                ctx.clearRect(0, 0, w, h);

                var s = samps;
                if (!s || s.length < 2) return;
                var n = Math.min(s.length, 32);

                ctx.beginPath();
                ctx.moveTo(0, h);

                // Smooth curve through sample tops
                for (var i = 0; i < n; i++) {
                    var x = (i + 0.5) * w / n;
                    var y = h - s[i] * h;
                    if (i === 0) {
                        ctx.lineTo(x, y);
                    } else {
                        var px = (i - 0.5) * w / n;
                        var py = h - s[i - 1] * h;
                        var cpx = (px + x) / 2;
                        ctx.bezierCurveTo(cpx, py, cpx, y, x, y);
                    }
                }

                ctx.lineTo(w, h);
                ctx.closePath();

                var col = karaoke.artColor;
                ctx.fillStyle = Qt.rgba(col.r, col.g, col.b, 0.4);
                ctx.fill();

                // Outer bloom
                for (var pass = 0; pass < 3; pass++) {
                    var gw = [12, 6, 2][pass];
                    var ga = [0.06, 0.15, 0.8][pass];
                    ctx.beginPath();
                    for (var i = 0; i < n; i++) {
                        var x = (i + 0.5) * w / n;
                        var y = h - s[i] * h;
                        if (i === 0) {
                            ctx.moveTo(x, y);
                        } else {
                            var px = (i - 0.5) * w / n;
                            var py = h - s[i - 1] * h;
                            var cpx = (px + x) / 2;
                            ctx.bezierCurveTo(cpx, py, cpx, y, x, y);
                        }
                    }
                    ctx.strokeStyle = Qt.rgba(col.r, col.g, col.b, ga);
                    ctx.lineWidth = gw;
                    ctx.stroke();
                }
            }
        }

        // ── Content ──
        Column {
            anchors.centerIn: parent; spacing: 24
            width: parent.width * 0.72

            // Album art + track info
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 30

                // Album art with glow shadow
                Item {
                    width: 220; height: 220

                    // Glow behind art
                    Rectangle {
                        anchors.centerIn: parent
                        width: 230; height: 230; radius: 24
                        color: karaoke.artColor; opacity: 0.08
                    }

                    Rectangle {
                        anchors.fill: parent; radius: 20
                        color: Qt.rgba(1, 1, 1, 0.05)
                        clip: true

                        Image {
                            id: karaokeArt
                            anchors.fill: parent
                            source: artProc.roundedPath; fillMode: Image.Stretch
                            visible: status === Image.Ready
                        }

                        Text {
                            anchors.centerIn: parent; visible: !karaokeArt.visible
                            text: String.fromCodePoint(0xf0388)
                            color: karaoke.dim; font { pixelSize: 60; family: karaoke.fontFamily }
                        }

                        // Spinning vinyl ring when playing
                        Rectangle {
                            anchors.fill: parent; radius: 20
                            color: "transparent"
                            border.width: 2
                            border.color: Qt.rgba(karaoke.artColor.r, karaoke.artColor.g, karaoke.artColor.b, 0.15)
                            rotation: karaoke._elapsed * 20
                            Behavior on rotation { NumberAnimation { duration: 0 } }
                            visible: karaoke.player && karaoke.player.playbackState === MprisPlaybackState.Playing
                        }
                    }
                }

                // Track info
                Column {
                    spacing: 8; anchors.verticalCenter: parent.verticalCenter
                    width: parent.parent.width - 250

                    Text {
                        text: karaoke.player ? (karaoke.player.trackTitle || "") : ""
                        color: karaoke.fg
                        font { pixelSize: 32; family: karaoke.fontFamily; bold: true }
                        elide: Text.ElideRight; width: parent.width
                    }
                    Text {
                        text: karaoke.player ? (karaoke.player.trackArtist || "") : ""
                        color: karaoke.artColor
                        font { pixelSize: 22; family: karaoke.fontFamily }
                        elide: Text.ElideRight; width: parent.width
                    }
                    Text {
                        text: karaoke.player ? (karaoke.player.trackAlbum || "") : ""
                        color: karaoke.dim
                        font { pixelSize: 15; family: karaoke.fontFamily }
                        elide: Text.ElideRight; width: parent.width
                        visible: text !== ""
                    }

                    Item { width: 1; height: 10 }

                    // Progress bar (thicc, glowing)
                    Item {
                        width: parent.width; height: 8
                        Rectangle {
                            anchors.fill: parent; radius: 4
                            color: Qt.rgba(1, 1, 1, 0.06)
                        }
                        Rectangle {
                            width: karaoke.mprisLen > 0 ? parent.width * (karaoke.mprisPos / karaoke.mprisLen) : 0
                            height: parent.height; radius: 4
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: karaoke.artColor }
                                GradientStop { position: 0.5; color: karaoke.artColor2 }
                                GradientStop { position: 1.0; color: karaoke.artColor3 }
                            }
                            Behavior on width { NumberAnimation { duration: 1000; easing.type: Easing.Linear } }
                        }
                        // Glow on progress head
                        Rectangle {
                            x: (karaoke.mprisLen > 0 ? parent.width * (karaoke.mprisPos / karaoke.mprisLen) : 0) - 6
                            y: -4; width: 16; height: 16; radius: 8
                            color: karaoke.artColor; opacity: 0.3
                            Behavior on x { NumberAnimation { duration: 1000; easing.type: Easing.Linear } }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => {
                                if (!karaoke.player || karaoke.mprisLen <= 0) return;
                                karaoke.player.position = (mouse.x / parent.width) * karaoke.mprisLen;
                            }
                        }
                    }

                    // Time + Controls
                    Row {
                        width: parent.width; spacing: 12
                        Text {
                            function fmt(s) { return Math.floor(s/60) + ":" + ("0" + (Math.floor(s)%60)).slice(-2); }
                            text: karaoke.mprisLen > 0 ? fmt(karaoke.mprisPos) : "0:00"
                            color: karaoke.dim; font { pixelSize: 13; family: karaoke.fontFamily }
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Controls
                        Repeater {
                            model: [
                                { icon: 0xf04ae, action: "previous" },
                                { icon: 0, action: "togglePlaying" },
                                { icon: 0xf04ad, action: "next" }
                            ]
                            Rectangle {
                                required property var modelData
                                required property int index
                                width: 40; height: 40; radius: 20
                                color: ctrlMA.containsMouse ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.04)
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: {
                                        if (parent.modelData.action === "togglePlaying") {
                                            return karaoke.player && karaoke.player.playbackState === MprisPlaybackState.Playing
                                                ? String.fromCodePoint(0xf03e4) : String.fromCodePoint(0xf040a);
                                        }
                                        return String.fromCodePoint(parent.modelData.icon);
                                    }
                                    color: parent.modelData.action === "togglePlaying" ? karaoke.artColor : karaoke.fg
                                    font { pixelSize: 20; family: karaoke.fontFamily }
                                }
                                MouseArea { id: ctrlMA; anchors.fill: parent; hoverEnabled: true
                                    onClicked: { if (!karaoke.player) return;
                                        if (parent.modelData.action === "previous") karaoke.player.previous();
                                        else if (parent.modelData.action === "next") karaoke.player.next();
                                        else karaoke.player.togglePlaying(); } }
                            }
                        }

                        Item { width: parent.width - 200; height: 1 }

                        Text {
                            function fmt(s) { return Math.floor(s/60) + ":" + ("0" + (Math.floor(s)%60)).slice(-2); }
                            text: karaoke.mprisLen > 0 ? fmt(karaoke.mprisLen) : "0:00"
                            color: karaoke.dim; font { pixelSize: 13; family: karaoke.fontFamily }
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            // ── Lyrics ──
            Item { width: 1; height: 6 }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width; spacing: 14

                // -2 line
                Text {
                    id: prev2Line
                    text: karaoke.lyricsPrev2; color: karaoke.dim; opacity: 0.15
                    font { pixelSize: 16; family: karaoke.fontFamily }
                    width: parent.width; horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    Behavior on text { SequentialAnimation {
                        NumberAnimation { target: prev2Line; property: "opacity"; to: 0; duration: 80 }
                        PropertyAction { target: prev2Line; property: "text" }
                        NumberAnimation { target: prev2Line; property: "opacity"; to: 0.15; duration: 200 }
                    }}
                }

                // -1 line
                Text {
                    id: prevLine
                    text: karaoke.lyricsPrev; color: karaoke.dim; opacity: 0.4
                    font { pixelSize: 22; family: karaoke.fontFamily }
                    width: parent.width; horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    Behavior on text { SequentialAnimation {
                        NumberAnimation { target: prevLine; property: "opacity"; to: 0; duration: 100 }
                        PropertyAction { target: prevLine; property: "text" }
                        NumberAnimation { target: prevLine; property: "opacity"; to: 0.4; duration: 250 }
                    }}
                }

                // ── Current line ──
                Item {
                    width: parent.width; height: currentLine.height + 20

                    // Glow backdrop
                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(currentLine.contentWidth, currentLine.width) + 50
                        height: currentLine.height + 16
                        radius: 14; color: karaoke.artColor; opacity: 0.05
                        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    }

                    Text {
                        id: currentLine
                        anchors.centerIn: parent
                        text: karaoke.lyricsCurrent || "♪"
                        color: karaoke.lyricsCurrent ? karaoke.artColor : karaoke.dim
                        font { pixelSize: 34; family: karaoke.fontFamily; bold: true }
                        width: parent.width; horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight

                        scale: 1.0; transformOrigin: Item.Center
                        Behavior on text { SequentialAnimation {
                            ParallelAnimation {
                                NumberAnimation { target: currentLine; property: "opacity"; to: 0; duration: 80 }
                                NumberAnimation { target: currentLine; property: "scale"; to: 0.94; duration: 80 }
                            }
                            PropertyAction { target: currentLine; property: "text" }
                            ParallelAnimation {
                                NumberAnimation { target: currentLine; property: "opacity"; to: 1.0; duration: 300; easing.type: Easing.OutCubic }
                                NumberAnimation { target: currentLine; property: "scale"; to: 1.04; duration: 200; easing.type: Easing.OutBack }
                            }
                            NumberAnimation { target: currentLine; property: "scale"; to: 1.0; duration: 300; easing.type: Easing.InOutQuad }
                        }}
                    }
                }

                // +1 line
                Text {
                    id: nextLine
                    text: karaoke.lyricsNext; color: karaoke.dim; opacity: 0.4
                    font { pixelSize: 22; family: karaoke.fontFamily }
                    width: parent.width; horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    Behavior on text { SequentialAnimation {
                        NumberAnimation { target: nextLine; property: "opacity"; to: 0; duration: 100 }
                        PropertyAction { target: nextLine; property: "text" }
                        NumberAnimation { target: nextLine; property: "opacity"; to: 0.4; duration: 250 }
                    }}
                }

                // +2 line
                Text {
                    id: next2Line
                    text: karaoke.lyricsNext2; color: karaoke.dim; opacity: 0.15
                    font { pixelSize: 16; family: karaoke.fontFamily }
                    width: parent.width; horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    Behavior on text { SequentialAnimation {
                        NumberAnimation { target: next2Line; property: "opacity"; to: 0; duration: 80 }
                        PropertyAction { target: next2Line; property: "text" }
                        NumberAnimation { target: next2Line; property: "opacity"; to: 0.15; duration: 200 }
                    }}
                }
            }
        }
    }

    // ESC to close
    Shortcut { sequence: "Escape"; onActivated: karaoke.showing = false; enabled: karaoke.showing }
}
