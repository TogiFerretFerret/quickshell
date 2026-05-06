import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: lyricsProvider

    // Public API — bind from anywhere
    property string prev2: ""
    property string prev: ""
    property string current: ""
    property string next: ""
    property string next2: ""
    property bool available: current !== ""

    // Internal
    property bool _socketAlive: false
    property int _lastIdx: -1

    // Primary: lazyspotify unix socket
    Process {
        id: socketProc
        command: ["socat", "-u", "UNIX-CONNECT:/tmp/lazyspotify-lyrics.sock", "STDOUT"]
        running: true
        onRunningChanged: {
            if (!running) {
                lyricsProvider._socketAlive = false;
                socketRetry.start();
            }
        }
        stdout: SplitParser {
            onRead: data => {
                lyricsProvider._socketAlive = true;
                try {
                    var obj = JSON.parse(data);
                    if (!obj.playing) {
                        lyricsProvider.prev2 = ""; lyricsProvider.prev = "";
                        lyricsProvider.current = "";
                        lyricsProvider.next = ""; lyricsProvider.next2 = "";
                        lyricsProvider._lastIdx = -1;
                        return;
                    }
                    var idx = obj.line_index !== undefined ? obj.line_index : -1;
                    if (idx === lyricsProvider._lastIdx) return;
                    lyricsProvider._lastIdx = idx;

                    lyricsProvider.prev = obj.prior || "";
                    lyricsProvider.current = obj.line_text || "";
                    lyricsProvider.next = obj.next || "";
                    // prev2/next2 not available from socket — clear them
                    lyricsProvider.prev2 = "";
                    lyricsProvider.next2 = "";
                } catch(e) {}
            }
        }
    }

    Timer {
        id: socketRetry; interval: 5000; repeat: false
        onTriggered: { if (!lyricsProvider._socketAlive) socketProc.running = true; }
    }

    // Fallback: lrcsnc (only when socket is dead)
    Process {
        id: lrcsncProc
        command: ["lrcsnc", "--no-log"]
        running: !lyricsProvider._socketAlive
        onRunningChanged: {
            if (!running && !lyricsProvider._socketAlive) lrcsncRetry.start();
        }
        stdout: SplitParser {
            onRead: data => {
                if (lyricsProvider._socketAlive) return;
                try {
                    var obj = JSON.parse(data);
                    lyricsProvider.prev = obj.prior || "";
                    lyricsProvider.current = obj.text || "";
                    lyricsProvider.next = obj.next || "";
                    lyricsProvider.prev2 = "";
                    lyricsProvider.next2 = "";
                } catch(e) {}
            }
        }
    }

    Timer {
        id: lrcsncRetry; interval: 5000; repeat: false
        onTriggered: { if (!lyricsProvider._socketAlive) lrcsncProc.running = true; }
    }
}
