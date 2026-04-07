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

    visible: showing && player !== null
    anchors { top: true; right: true }
    margins.top: 58; margins.right: 280
    implicitWidth: 340; implicitHeight: 200
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore

    Services.ArtProcessor {
        id: artProc
        sourceUrl: mprisPopup.player ? mprisPopup.player.trackArtUrl : ""
    }

    // Background with pre-rounded art
    Rectangle {
        id: mainBg
        anchors.fill: parent; radius: 14
        color: Qt.rgba(mprisPopup.bg.r, mprisPopup.bg.g, mprisPopup.bg.b, 0.92)
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08)

        // Rounded bg art from imagemagick
        Image {
            anchors.fill: parent; opacity: 0.25
            source: artProc.bgPath; fillMode: Image.Stretch
            visible: status === Image.Ready
        }

        Row {
            anchors.fill: parent; anchors.margins: 14; spacing: 14

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
                width: parent.width - 168; spacing: 6

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

                Item { width: 1; height: 4 }

                // Progress bar
                Rectangle {
                    width: parent.width; height: 4; radius: 2
                    color: Qt.rgba(1, 1, 1, 0.06)
                    Rectangle {
                        width: { var l = mprisPopup.player ? mprisPopup.player.length : 0;
                            var p = mprisPopup.player ? mprisPopup.player.position : 0;
                            return l > 0 ? parent.width * (p / l) : 0; }
                        height: parent.height; radius: 2; color: mprisPopup.primary
                    }
                }

                // Time
                Text {
                    property int pos: mprisPopup.player ? Math.floor(mprisPopup.player.position || 0) : 0
                    property int len: mprisPopup.player ? Math.floor(mprisPopup.player.length || 0) : 0
                    function fmt(s) { return Math.floor(s/60) + ":" + ("0" + (s%60)).slice(-2); }
                    text: len > 0 ? fmt(pos) + " / " + fmt(len) : ""
                    color: mprisPopup.dim; font { pixelSize: 10; family: mprisPopup.fontFamily } }

                // Controls
                Row {
                    spacing: 12
                    Repeater {
                        model: [
                            { icon: 0xf04ae, action: "previous" },
                            { icon: 0, action: "togglePlaying" },
                            { icon: 0xf04ad, action: "next" }
                        ]
                        Rectangle {
                            required property var modelData
                            required property int index
                            width: 36; height: 36; radius: 18
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
                                font { pixelSize: 18; family: mprisPopup.fontFamily }
                            }
                            MouseArea { id: ctrlMA; anchors.fill: parent; hoverEnabled: true
                                onClicked: { if (!mprisPopup.player) return;
                                    if (parent.modelData.action === "previous") mprisPopup.player.previous();
                                    else if (parent.modelData.action === "next") mprisPopup.player.next();
                                    else mprisPopup.player.togglePlaying(); } }
                        }
                    }
                }

                // Player name
                Text { text: mprisPopup.player ? (mprisPopup.player.identity || "") : ""
                    color: mprisPopup.dim; font { pixelSize: 10; family: mprisPopup.fontFamily } }
            }
        }
    }

    Shortcut { sequence: "Escape"; onActivated: mprisPopup.showing = false; enabled: mprisPopup.showing }
}
