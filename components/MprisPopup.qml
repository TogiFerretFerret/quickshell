import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Io
import QtQuick
import "../services" as Services

PanelWindow {
    id: mprisPopup

    property color bg: "#111318"
    property color fg: "#e1e2e9"
    property color dim: "#5d6172"
    property color primary: "#a3c9ff"
    property color secondary: "#bcc7db"
    property string fontFamily: "JetBrainsMono Nerd Font"
    property bool showing: false
    property var player: null
    property real mprisPos: 0
    property real mprisLen: 0

    // Lyrics state
    property string lyricsPrev: ""
    property string lyricsCurrent: ""
    property string lyricsNext: ""
    property bool lyricsAvailable: lyricsCurrent !== ""

    visible: showing && player !== null
    anchors { top: true; right: true }
    margins.top: 58; margins.right: 220
    implicitWidth: 400; implicitHeight: lyricsAvailable ? 250 : 190
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore

    Behavior on implicitHeight { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

    Services.ArtProcessor {
        id: artProc
        sourceUrl: mprisPopup.player ? mprisPopup.player.trackArtUrl : ""
    }

    // Lyrics: try lazyspotify socket first, fall back to lrcsnc
    property var _lyricsHistory: []
    property int _lyricsIdx: -1
    property bool _socketAlive: false

    // Primary: lazyspotify unix socket via socat
    Process {
        id: lyricsProc
        command: ["socat", "-u", "UNIX-CONNECT:/tmp/lazyspotify-lyrics.sock", "STDOUT"]
        running: true
        onExited: (code, status) => {
            mprisPopup._socketAlive = false;
            // Retry socket in 5s in case lazyspotify starts later
            socketRetry.start();
        }
        stdout: SplitParser {
            onRead: data => {
                mprisPopup._socketAlive = true;
                try {
                    var obj = JSON.parse(data);
                    if (!obj.playing) {
                        mprisPopup.lyricsPrev = "";
                        mprisPopup.lyricsCurrent = "";
                        mprisPopup.lyricsNext = "";
                        return;
                    }
                    var line = obj.line_text || "";
                    var idx = obj.line_index || 0;

                    if (idx !== mprisPopup._lyricsIdx) {
                        if (idx === 0) mprisPopup._lyricsHistory = [];
                        while (mprisPopup._lyricsHistory.length <= idx) {
                            mprisPopup._lyricsHistory.push("");
                        }
                        mprisPopup._lyricsHistory[idx] = line;
                        mprisPopup._lyricsIdx = idx;

                        mprisPopup.lyricsPrev = idx > 0 ? (mprisPopup._lyricsHistory[idx - 1] || "") : "";
                        mprisPopup.lyricsCurrent = line;
                        mprisPopup.lyricsNext = "";
                    }
                    if (mprisPopup._lyricsHistory.length > idx + 1) {
                        mprisPopup.lyricsNext = mprisPopup._lyricsHistory[idx + 1] || "";
                    }
                } catch(e) {}
            }
        }
    }

    Timer {
        id: socketRetry; interval: 5000; repeat: false
        onTriggered: { if (!mprisPopup._socketAlive) lyricsProc.running = true; }
    }

    // Fallback: lrcsnc (only runs when socket is dead)
    Process {
        id: lrcsncProc
        command: ["lrcsnc"]
        running: !mprisPopup._socketAlive
        onExited: (code, status) => {
            if (!mprisPopup._socketAlive) lrcsncRetry.start();
        }
        stdout: SplitParser {
            onRead: data => {
                if (mprisPopup._socketAlive) return; // socket took over
                try {
                    var obj = JSON.parse(data);
                    var text = obj.text || "";
                    mprisPopup.lyricsPrev = "";
                    mprisPopup.lyricsCurrent = text;
                    mprisPopup.lyricsNext = "";
                } catch(e) {}
            }
        }
    }

    Timer {
        id: lrcsncRetry; interval: 5000; repeat: false
        onTriggered: { if (!mprisPopup._socketAlive) lrcsncProc.running = true; }
    }

    property real _elapsed: 0
    Timer {
        interval: 16; running: mprisPopup.visible; repeat: true
        onTriggered: mprisPopup._elapsed += 0.016
    }

    // Background with pre-rounded art
    Rectangle {
        id: mainBg
        anchors.fill: parent; radius: 14
        color: Qt.rgba(mprisPopup.bg.r, mprisPopup.bg.g, mprisPopup.bg.b, 0.92)
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08)
        clip: true

        // Rounded bg art from imagemagick
        Image {
            anchors.fill: parent; opacity: 0.25
            source: artProc.bgPath; fillMode: Image.Stretch
            visible: status === Image.Ready
        }

        // Animated GLSL aurora glow
        ShaderEffect {
            anchors.fill: parent
            blending: true

            property real iTime: mprisPopup._elapsed
            property real progress: mprisPopup.mprisLen > 0 ? mprisPopup.mprisPos / mprisPopup.mprisLen : 0
            property real isPlaying: mprisPopup.player && mprisPopup.player.playbackState === MprisPlaybackState.Playing ? 1.0 : 0.0
            property color color1: mprisPopup.primary
            property color color2: "#c084fc"
            property vector4d dims: Qt.vector4d(mainBg.width, mainBg.height, 0, 0)

            fragmentShader: "mpris-glow.frag.qsb"
        }

        Column {
            anchors.fill: parent; anchors.margins: 14; spacing: 10

            Row {
                width: parent.width; height: 140; spacing: 14

                // Rounded album art thumbnail from imagemagick
                Image {
                    id: albumArt
                    width: 140; height: 140
                    source: artProc.roundedPath; fillMode: Image.Stretch
                    visible: status === Image.Ready
                }

                // Fallback
                Rectangle {
                    width: 140; height: 140; radius: 14; visible: !albumArt.visible
                    color: Qt.rgba(1, 1, 1, 0.04)
                    Text { anchors.centerIn: parent; text: String.fromCodePoint(0xf0388)
                        color: mprisPopup.dim; font { pixelSize: 40; family: mprisPopup.fontFamily } }
                }

                // Info + controls
                Column {
                    width: parent.width - 154; spacing: 6
                    anchors.verticalCenter: parent.verticalCenter

                    // Title
                    Text { text: mprisPopup.player ? (mprisPopup.player.trackTitle || "Unknown") : ""
                        color: mprisPopup.fg; font { pixelSize: 14; family: mprisPopup.fontFamily; bold: true }
                        elide: Text.ElideRight; width: parent.width }

                    // Artist
                    Text { text: mprisPopup.player ? (mprisPopup.player.trackArtist || "Unknown") : ""
                        color: mprisPopup.secondary; font { pixelSize: 12; family: mprisPopup.fontFamily }
                        elide: Text.ElideRight; width: parent.width }

                    // Album
                    Text { text: mprisPopup.player ? (mprisPopup.player.trackAlbum || "") : ""
                        color: mprisPopup.dim; font { pixelSize: 11; family: mprisPopup.fontFamily }
                        visible: text !== ""; elide: Text.ElideRight; width: parent.width }

                    Item { width: 1; height: 2 }

                    // Progress bar
                    Rectangle {
                        id: progressBar
                        width: parent.width; height: 4; radius: 2
                        color: Qt.rgba(1, 1, 1, 0.06)
                        Rectangle {
                            width: mprisPopup.mprisLen > 0 ? parent.width * (mprisPopup.mprisPos / mprisPopup.mprisLen) : 0
                            height: parent.height; radius: 2; color: mprisPopup.primary
                            Behavior on width { NumberAnimation { duration: 1000; easing.type: Easing.Linear } }
                        }
                        MouseArea {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width; height: 20
                            anchors.verticalCenter: parent.verticalCenter
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => {
                                if (!mprisPopup.player || mprisPopup.mprisLen <= 0) return;
                                mprisPopup.player.position = (mouse.x / progressBar.width) * mprisPopup.mprisLen;
                            }
                        }
                    }

                    // Controls + Time row
                    Row {
                        width: parent.width; spacing: 8
                        Repeater {
                            model: [
                                { icon: 0xf04ae, action: "previous" },
                                { icon: 0, action: "togglePlaying" },
                                { icon: 0xf04ad, action: "next" }
                            ]
                            Rectangle {
                                required property var modelData
                                required property int index
                                width: 28; height: 28; radius: 14
                                color: ctrlMA.containsMouse ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.04)
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: {
                                        if (parent.modelData.action === "togglePlaying") {
                                            return mprisPopup.player && mprisPopup.player.playbackState === MprisPlaybackState.Playing
                                                ? String.fromCodePoint(0xf03e4) : String.fromCodePoint(0xf040a);
                                        }
                                        return String.fromCodePoint(parent.modelData.icon);
                                    }
                                    color: parent.modelData.action === "togglePlaying" ? mprisPopup.primary : mprisPopup.fg
                                    font { pixelSize: 14; family: mprisPopup.fontFamily }
                                }
                                MouseArea { id: ctrlMA; anchors.fill: parent; hoverEnabled: true
                                    onClicked: { if (!mprisPopup.player) return;
                                        if (parent.modelData.action === "previous") mprisPopup.player.previous();
                                        else if (parent.modelData.action === "next") mprisPopup.player.next();
                                        else mprisPopup.player.togglePlaying(); } }
                            }
                        }
                        Item { height: 1; width: parent.width - 3 * 28 - 4 * 8 - timeLabel.implicitWidth }
                        Text {
                            id: timeLabel
                            function fmt(s) { return Math.floor(s/60) + ":" + ("0" + (Math.floor(s)%60)).slice(-2); }
                            text: mprisPopup.mprisLen > 0 ? fmt(mprisPopup.mprisPos) + " / " + fmt(mprisPopup.mprisLen) : ""
                            color: mprisPopup.dim; font { pixelSize: 10; family: mprisPopup.fontFamily }
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            // ── Lyrics section ──
            Rectangle {
                width: parent.width; height: 56; radius: 10
                visible: mprisPopup.lyricsAvailable
                color: Qt.rgba(0, 0, 0, 0.3)
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.04)

                // Subtle glow behind current line
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.8; height: 20; radius: 10
                    color: mprisPopup.primary; opacity: 0.06
                    Behavior on opacity { NumberAnimation { duration: 400 } }
                }

                Column {
                    anchors.centerIn: parent; spacing: 2; width: parent.width - 20

                    // Previous line
                    Text {
                        id: prevLyricText
                        text: mprisPopup.lyricsPrev
                        color: mprisPopup.dim; opacity: 0.4
                        font { pixelSize: 9; family: mprisPopup.fontFamily }
                        elide: Text.ElideRight; width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        Behavior on text { SequentialAnimation {
                            NumberAnimation { target: prevLyricText; property: "opacity"; to: 0; duration: 100 }
                            PropertyAction { target: prevLyricText; property: "text" }
                            NumberAnimation { target: prevLyricText; property: "opacity"; to: 0.4; duration: 200 }
                        }}
                    }

                    // Current line (highlighted + glow)
                    Text {
                        id: currentLyricText
                        text: mprisPopup.lyricsCurrent
                        color: mprisPopup.primary
                        font { pixelSize: 12; family: mprisPopup.fontFamily; bold: true }
                        elide: Text.ElideRight; width: parent.width
                        horizontalAlignment: Text.AlignHCenter

                        // Glow layer
                        Text {
                            anchors.fill: parent
                            text: parent.text; color: mprisPopup.primary; opacity: 0.3
                            font: parent.font
                            horizontalAlignment: Text.AlignHCenter
                            layer.enabled: true
                            layer.effect: ShaderEffect {
                                fragmentShader: "lyrics-glow.frag.qsb"
                            }
                        }

                        // Fade + scale pulse on line change
                        scale: 1.0
                        transformOrigin: Item.Center
                        Behavior on text { SequentialAnimation {
                            ParallelAnimation {
                                NumberAnimation { target: currentLyricText; property: "opacity"; to: 0; duration: 80 }
                                NumberAnimation { target: currentLyricText; property: "scale"; to: 0.96; duration: 80 }
                            }
                            PropertyAction { target: currentLyricText; property: "text" }
                            ParallelAnimation {
                                NumberAnimation { target: currentLyricText; property: "opacity"; to: 1.0; duration: 250; easing.type: Easing.OutCubic }
                                NumberAnimation { target: currentLyricText; property: "scale"; to: 1.04; duration: 150; easing.type: Easing.OutBack }
                            }
                            NumberAnimation { target: currentLyricText; property: "scale"; to: 1.0; duration: 200; easing.type: Easing.InOutQuad }
                        }}
                    }

                    // Next line
                    Text {
                        id: nextLyricText
                        text: mprisPopup.lyricsNext
                        color: mprisPopup.dim; opacity: 0.3
                        font { pixelSize: 9; family: mprisPopup.fontFamily }
                        elide: Text.ElideRight; width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        Behavior on text { SequentialAnimation {
                            NumberAnimation { target: nextLyricText; property: "opacity"; to: 0; duration: 100 }
                            PropertyAction { target: nextLyricText; property: "text" }
                            NumberAnimation { target: nextLyricText; property: "opacity"; to: 0.3; duration: 200 }
                        }}
                    }
                }
            }

            // Player identity (only when no lyrics)
            Text {
                visible: !mprisPopup.lyricsAvailable
                text: mprisPopup.player ? (mprisPopup.player.identity || "") : ""
                color: mprisPopup.dim; font { pixelSize: 10; family: mprisPopup.fontFamily }
            }
        }
    }

    Shortcut { sequence: "Escape"; onActivated: mprisPopup.showing = false; enabled: mprisPopup.showing }
}
