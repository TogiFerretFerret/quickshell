import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Controls

PanelWindow {
    id: clipPopup

    property color bg: "#111318"
    property color fg: "#e1e2e9"
    property color dim: "#5d6172"
    property color primary: "#0ed2f7"
    property color pink: "#f4569d"
    property string fontFamily: "JetBrainsMono Nerd Font"
    property bool showing: false
    property var clipItems: []
    property string searchText: ""

    visible: showing
    // Fullscreen overlay — content centered via inner container
    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    // Fetch clipboard history with image detection
    Process {
        id: clipListProc
        command: ["python3", "-c", `
import sqlite3, os, json

db = sqlite3.connect(os.path.expanduser("~/.local/share/clipvault.db"))
rows = db.execute("SELECT id, content, length(content) FROM clipboard ORDER BY id DESC LIMIT 50").fetchall()
items = []
tmp = os.path.expanduser("~/.cache/clipvault-thumbs")
os.makedirs(tmp, exist_ok=True)

for rid, content, size in rows:
    is_img = content[:4] == b'\\x89PNG' or content[:3] == b'\\xff\\xd8\\xff'
    entry = {"id": str(rid), "isImage": is_img, "content": "", "thumb": ""}
    if is_img:
        ext = "png" if content[:4] == b'\\x89PNG' else "jpg"
        thumb_path = os.path.join(tmp, f"{rid}.{ext}")
        if not os.path.exists(thumb_path):
            with open(thumb_path, "wb") as f:
                f.write(content)
        entry["thumb"] = thumb_path
        entry["content"] = f"[Image {size//1024}KB]"
    else:
        try:
            entry["content"] = content.decode("utf-8", errors="replace")[:200]
        except:
            entry["content"] = f"[Binary {size}B]"
    items.append(entry)

print(json.dumps(items))
`]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    clipPopup.clipItems = JSON.parse(text.trim());
                } catch(e) {
                    clipPopup.clipItems = [];
                }
            }
        }
    }

    // Paste selected item
    Process {
        id: clipGetProc
        property string clipId: ""
        command: ["sh", "-c", "clipvault get " + clipId + " | wl-copy"]
        running: false
    }

    property int selectedIndex: 0
    property var filteredItems: {
        if (!searchText) return clipItems;
        var s = searchText.toLowerCase();
        return clipItems.filter(function(item) {
            return item.content.toLowerCase().indexOf(s) >= 0;
        });
    }

    onShowingChanged: {
        if (showing) {
            searchText = "";
            searchInput.text = "";
            selectedIndex = 0;
            clipListProc.running = true;
            searchInput.forceActiveFocus();
        }
    }

    // Click outside to close
    MouseArea {
        anchors.fill: parent
        onClicked: clipPopup.showing = false
    }

    // Keyboard handling
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            clipPopup.showing = false;
            event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            if (clipPopup.selectedIndex < clipPopup.filteredItems.length - 1)
                clipPopup.selectedIndex++;
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            if (clipPopup.selectedIndex > 0)
                clipPopup.selectedIndex--;
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            var item = clipPopup.filteredItems[clipPopup.selectedIndex];
            if (item) {
                clipGetProc.clipId = item.id;
                clipGetProc.running = true;
                clipPopup.showing = false;
            }
            event.accepted = true;
        }
    }

    // Centered card
    Rectangle {
        width: 560; height: 620
        anchors.centerIn: parent
        radius: 16
        color: Qt.rgba(clipPopup.bg.r, clipPopup.bg.g, clipPopup.bg.b, 0.94)
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08)

        // Prevent clicks on the card from closing
        MouseArea { anchors.fill: parent }

        Column {
            anchors.fill: parent; anchors.margins: 20; spacing: 12

            // Header
            Row {
                width: parent.width; spacing: 10
                Text {
                    text: String.fromCodePoint(0xf0ea) + "  Clipboard"
                    color: clipPopup.fg
                    font { pixelSize: 18; family: clipPopup.fontFamily; bold: true }
                }
                Item { width: parent.width - 250; height: 1 }
                Text {
                    text: clipPopup.clipItems.length + " items"
                    color: clipPopup.dim
                    font { pixelSize: 11; family: clipPopup.fontFamily }
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Search bar
            Rectangle {
                width: parent.width; height: 40; radius: 10
                color: Qt.rgba(1, 1, 1, 0.06)
                border.width: searchInput.activeFocus ? 1 : 0
                border.color: clipPopup.primary

                Row {
                    anchors.fill: parent; anchors.margins: 10; spacing: 8
                    Text {
                        text: String.fromCodePoint(0xf002)
                        color: clipPopup.dim
                        font { pixelSize: 14; family: clipPopup.fontFamily }
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    TextInput {
                        id: searchInput
                        width: parent.width - 30; height: parent.height
                        color: clipPopup.fg
                        font { pixelSize: 14; family: clipPopup.fontFamily }
                        clip: true
                        verticalAlignment: TextInput.AlignVCenter
                        selectByMouse: true
                        onTextChanged: { clipPopup.searchText = text; clipPopup.selectedIndex = 0; }
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Escape) {
                                clipPopup.showing = false;
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Down) {
                                if (clipPopup.selectedIndex < clipPopup.filteredItems.length - 1)
                                    clipPopup.selectedIndex++;
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up) {
                                if (clipPopup.selectedIndex > 0)
                                    clipPopup.selectedIndex--;
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                var item = clipPopup.filteredItems[clipPopup.selectedIndex];
                                if (item) {
                                    clipGetProc.clipId = item.id;
                                    clipGetProc.running = true;
                                    clipPopup.showing = false;
                                }
                                event.accepted = true;
                            }
                        }

                        Text {
                            text: "Search clipboard..."
                            color: clipPopup.dim
                            font: parent.font
                            visible: !parent.text && !parent.activeFocus
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.06) }

            // Clip list
            Flickable {
                width: parent.width; height: parent.height - 120
                contentHeight: clipColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: clipColumn
                    width: parent.width; spacing: 4

                    Repeater {
                        model: clipPopup.filteredItems

                        Rectangle {
                            required property var modelData
                            required property int index
                            width: parent.width
                            height: modelData.isImage ? 100 : 48
                            radius: 10
                            color: index === clipPopup.selectedIndex ? Qt.rgba(clipPopup.primary.r, clipPopup.primary.g, clipPopup.primary.b, 0.15) : clipMA.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.03)
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Row {
                                anchors.fill: parent; anchors.margins: 10; spacing: 12

                                // Index or image icon
                                Text {
                                    text: (index + 1).toString()
                                    color: modelData.isImage ? clipPopup.pink : clipPopup.primary
                                    font { pixelSize: 12; family: clipPopup.fontFamily; bold: true }
                                    width: 24
                                    horizontalAlignment: Text.AlignRight
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                // Image thumbnail
                                Image {
                                    visible: modelData.isImage && modelData.thumb !== ""
                                    source: modelData.thumb ? "file://" + modelData.thumb : ""
                                    width: 72; height: 72
                                    fillMode: Image.PreserveAspectCrop
                                    sourceSize.width: 144; sourceSize.height: 144
                                    anchors.verticalCenter: parent.verticalCenter

                                    Rectangle {
                                        anchors.fill: parent; radius: 8
                                        color: "transparent"
                                        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.1)
                                    }
                                }

                                // Content preview (text entries)
                                Column {
                                    visible: !modelData.isImage
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 50

                                    Text {
                                        text: {
                                            var t = modelData.content;
                                            if (t.length > 100) t = t.substring(0, 100) + "…";
                                            return t.replace(/\n/g, " ↵ ");
                                        }
                                        color: clipPopup.fg
                                        font { pixelSize: 13; family: clipPopup.fontFamily }
                                        elide: Text.ElideRight
                                        width: parent.width
                                        wrapMode: Text.NoWrap
                                    }
                                }

                                // Image size label (image entries)
                                Column {
                                    visible: modelData.isImage
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    Text {
                                        text: modelData.content
                                        color: clipPopup.fg
                                        font { pixelSize: 13; family: clipPopup.fontFamily }
                                    }
                                    Text {
                                        text: "Click to copy"
                                        color: clipPopup.dim
                                        font { pixelSize: 10; family: clipPopup.fontFamily }
                                    }
                                }
                            }

                            MouseArea {
                                id: clipMA
                                anchors.fill: parent; hoverEnabled: true
                                onClicked: {
                                    clipGetProc.clipId = modelData.id;
                                    clipGetProc.running = true;
                                    clipPopup.showing = false;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
