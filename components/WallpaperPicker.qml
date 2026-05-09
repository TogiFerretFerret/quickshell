import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

PanelWindow {
    id: wpWindow

    property color bg: "#0e1120"
    property color primary: "#a3c9ff"
    property color fg: "#e1e2e9"
    property color dim: "#5d6172"
    property color red: "#f38ba8"
    property color green: "#a6e3a1"
    property color yellow: "#f9e2af"
    property color purple: "#cba6f7"
    property string fontFamily: "JetBrainsMono Nerd Font"

    property bool showing: false
    property var localWallpapers: []
    property var collectionWallpapers: []
    property var onlineWallpapers: []
    property string searchText: ""
    property string onlineQuery: ""
    property string currentTab: "local" // "local", "collection", or "online"
    property string currentFolder: "" // "" = root folder view, "Genshin" = inside Genshin, etc.

    // Build folder listing + wallpapers for current local view
    property var localFolderEntries: {
        if (wpWindow.currentTab !== "local") return [];

        var walls = wpWindow.localWallpapers;
        if (wpWindow.currentFolder === "") {
            // Root: show folders as entries + root-level wallpapers
            var folders = {};
            var rootWalls = [];
            for (var i = 0; i < walls.length; i++) {
                var name = walls[i].name;
                var slashIdx = name.indexOf("/");
                if (slashIdx !== -1) {
                    var folder = name.substring(0, slashIdx);
                    if (!folders[folder]) folders[folder] = 0;
                    folders[folder]++;
                } else {
                    // Hide loose files in root - only show folders
                }
            }
            // Build folder entries
            var entries = [];
            var folderNames = Object.keys(folders).sort();
            for (var j = 0; j < folderNames.length; j++) {
                entries.push({
                    isFolder: true,
                    name: folderNames[j],
                    count: folders[folderNames[j]],
                    thumb: "",
                    source: "local",
                    full: "",
                    path: ""
                });
            }
            // Add root wallpapers after folders
            for (var k = 0; k < rootWalls.length; k++) {
                var w = Object.assign({}, rootWalls[k]);
                w.isFolder = false;
                entries.push(w);
            }
            return entries;
        } else {
            // Inside a folder: show ".." + wallpapers in this folder
            var prefix = wpWindow.currentFolder + "/";
            var entries2 = [];
            // ".." entry
            entries2.push({
                isFolder: true,
                name: "..",
                count: -1,
                thumb: "",
                source: "local",
                full: "",
                path: ""
            });
            for (var m = 0; m < walls.length; m++) {
                if (walls[m].name.indexOf(prefix) === 0) {
                    var w2 = Object.assign({}, walls[m]);
                    w2.isFolder = false;
                    // Show just the filename, not the folder prefix
                    w2.displayName = walls[m].name.substring(prefix.length);
                    entries2.push(w2);
                }
            }
            return entries2;
        }
    }

    // Keyboard Navigation State
    property int selectedIndex: 0
    property var filteredWallpapers: {
        var base = wpWindow.currentTab === "local" ? wpWindow.localFolderEntries :
                   wpWindow.currentTab === "collection" ? wpWindow.collectionWallpapers :
                   wpWindow.onlineWallpapers;
        if (wpWindow.searchText === "") return base;
        return base.filter(w => {
            var label = w.displayName || w.name;
            return label.toLowerCase().includes(wpWindow.searchText.toLowerCase());
        });
    }

    onFilteredWallpapersChanged: {
        selectedIndex = 0;
        flickable.contentY = 0; // Reset scroll on change
    }

    visible: showing
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    color: Qt.rgba(0, 0, 0, 0.5) // Scrim

    function moveSelection(row, col) {
        var cols = 4;
        var newIndex = selectedIndex + (row * cols) + col;
        if (newIndex >= 0 && newIndex < filteredWallpapers.length) {
            selectedIndex = newIndex;
            ensureVisible(newIndex);
        }
    }

    function ensureVisible(index) {
        var cols = 4;
        var spacing = 20;
        var row = Math.floor(index / cols);

        var itemWidth = (grid.width - (spacing * 3)) / cols;
        var itemHeight = itemWidth * 0.65;

        var itemTop = row * (itemHeight + spacing);
        var itemBottom = itemTop + itemHeight;

        var viewTop = flickable.contentY;
        var viewBottom = viewTop + flickable.height;

        if (itemTop < viewTop) {
            flickable.contentY = itemTop;
        } else if (itemBottom > viewBottom) {
            flickable.contentY = itemBottom - flickable.height;
        }
    }

    function activateSelected() {
        if (selectedIndex < 0 || selectedIndex >= filteredWallpapers.length) return;
        var item = filteredWallpapers[selectedIndex];
        if (item.isFolder) {
            if (item.name === "..") {
                wpWindow.currentFolder = "";
            } else {
                wpWindow.currentFolder = item.name;
            }
            wpWindow.searchText = "";
            searchInput.text = "";
        } else {
            applyProc.command = ["/home/river/.config/hypr/scripts/apply-wallpaper.sh", item.source, item.full, item.name];
            applyProc.running = true;
            wpWindow.showing = false;
        }
    }

    Process {
        id: localProc
        command: ["/home/river/.config/hypr/scripts/wallpaper-list.py", "--local-only"]
        stdout: SplitParser { onRead: data => {
            try { wpWindow.localWallpapers = JSON.parse(data); } catch(e) {}
        }}
    }

    Process {
        id: collectionProc
        command: ["/home/river/.config/hypr/scripts/wallpaper-list.py", "--collection-only"]
        stdout: SplitParser { onRead: data => {
            try { wpWindow.collectionWallpapers = JSON.parse(data); } catch(e) {}
        }}
    }

    Process {
        id: onlineProc
        command: ["python3", "/home/river/.config/hypr/scripts/wallpaper-list.py", "--online-only", "--query", wpWindow.onlineQuery]
        stdout: SplitParser { onRead: data => {
            try {
                var parsed = JSON.parse(data);
                wpWindow.onlineWallpapers = parsed;
            } catch(e) {}
        }}
    }

    onShowingChanged: if (showing) {
        wpWindow.searchText = "";
        wpWindow.onlineQuery = "";
        wpWindow.currentFolder = "";
        searchInput.text = "";
        localProc.running = true;
        collectionProc.running = true;
        searchInput.forceActiveFocus(); // Start in Insert Mode
    }

    onCurrentTabChanged: {
        wpWindow.searchText = "";
        wpWindow.currentFolder = "";
        searchInput.text = "";
        if (showing && currentTab === "collection") collectionProc.running = true;
    }

    // Click outside to dismiss
    MouseArea { anchors.fill: parent; onClicked: wpWindow.showing = false }

    Rectangle {
        id: mainCard
        anchors.centerIn: parent
        width: 1100; height: 650; radius: 24
        color: wpWindow.bg
        border.width: 2; border.color: Qt.rgba(wpWindow.primary.r, wpWindow.primary.g, wpWindow.primary.b, 0.3)
        clip: true

        focus: true
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Down || event.key === Qt.Key_J) { moveSelection(1, 0); event.accepted = true; }
            else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) { moveSelection(-1, 0); event.accepted = true; }
            else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) { moveSelection(0, -1); event.accepted = true; }
            else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) { moveSelection(0, 1); event.accepted = true; }
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                activateSelected();
                event.accepted = true;
            } else if (event.key === Qt.Key_Slash) {
                searchInput.forceActiveFocus();
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                if (wpWindow.currentTab === "local" && wpWindow.currentFolder !== "") {
                    wpWindow.currentFolder = "";
                    wpWindow.searchText = "";
                    searchInput.text = "";
                } else {
                    wpWindow.showing = false;
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Backspace) {
                if (wpWindow.currentTab === "local" && wpWindow.currentFolder !== "") {
                    wpWindow.currentFolder = "";
                    wpWindow.searchText = "";
                    searchInput.text = "";
                    event.accepted = true;
                }
            } else if (event.key === Qt.Key_Tab) {
                if (wpWindow.currentTab === "local") wpWindow.currentTab = "collection";
                else if (wpWindow.currentTab === "collection") wpWindow.currentTab = "online";
                else wpWindow.currentTab = "local";
                event.accepted = true;
            }
        }

        opacity: wpWindow.showing ? 1.0 : 0.0
        scale: wpWindow.showing ? 1.0 : 0.9
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 0
            spacing: 0

            // Header / Tabs
            Rectangle {
                Layout.fillWidth: true
                height: 70
                color: Qt.rgba(1, 1, 1, 0.02)
                z: 2 // Keep header above the flickable content

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 30; anchors.rightMargin: 30
                    spacing: 30

                    // Title with breadcrumb
                    Row {
                        spacing: 8
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            text: "󰸉 Wallpapers"
                            color: wpWindow.currentFolder === "" ? wpWindow.fg : wpWindow.dim
                            font { pixelSize: 20; family: wpWindow.fontFamily; bold: wpWindow.currentFolder === "" }

                            MouseArea {
                                anchors.fill: parent
                                visible: wpWindow.currentFolder !== ""
                                onClicked: { wpWindow.currentFolder = ""; wpWindow.searchText = ""; searchInput.text = ""; }
                                cursorShape: Qt.PointingHandCursor
                            }
                        }

                        Text {
                            text: "  " + wpWindow.currentFolder
                            color: wpWindow.fg
                            font { pixelSize: 20; family: wpWindow.fontFamily; bold: true }
                            visible: wpWindow.currentTab === "local" && wpWindow.currentFolder !== ""
                        }
                    }

                    // Tabs
                    Row {
                        spacing: 10
                        Layout.alignment: Qt.AlignVCenter

                        Repeater {
                            model: [
                                { id: "local", label: "󰋜 Local", color: wpWindow.green },
                                { id: "collection", label: "󰄭 Saved", color: wpWindow.purple },
                                { id: "online", label: "󰖟 Online", color: wpWindow.yellow }
                            ]

                            Rectangle {
                                required property var modelData
                                width: 110; height: 36; radius: 18
                                color: wpWindow.currentTab === modelData.id ? Qt.rgba(modelData.color.r, modelData.color.g, modelData.color.b, 0.2) : "transparent"
                                border.width: 1; border.color: wpWindow.currentTab === modelData.id ? modelData.color : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: wpWindow.currentTab === modelData.id ? modelData.color : wpWindow.dim
                                    font { pixelSize: 13; family: wpWindow.fontFamily; bold: wpWindow.currentTab === modelData.id }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: wpWindow.currentTab = parent.modelData.id
                                }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Search Box
                    Rectangle {
                        width: 250; height: 36; radius: 18
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.width: 1; border.color: searchInput.activeFocus ? wpWindow.primary : Qt.rgba(1, 1, 1, 0.1)

                        TextInput {
                            id: searchInput
                            anchors.fill: parent
                            anchors.leftMargin: 15; anchors.rightMargin: 15
                            verticalAlignment: TextInput.AlignVCenter
                            color: wpWindow.fg
                            font { pixelSize: 13; family: wpWindow.fontFamily }
                            onTextChanged: wpWindow.searchText = text

                            Keys.onPressed: (event) => {
                                if (event.key === Qt.Key_Escape || event.key === Qt.Key_Down) {
                                    mainCard.forceActiveFocus(); // Exit to Normal Mode
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    if (wpWindow.currentTab === "online" && wpWindow.searchText !== "") {
                                        wpWindow.onlineQuery = wpWindow.searchText;
                                        wpWindow.onlineWallpapers = [];
                                        onlineProc.running = false;
                                        onlineProc.running = true;
                                        wpWindow.searchText = "";
                                        searchInput.text = "";
                                        mainCard.forceActiveFocus();
                                    } else {
                                        activateSelected();
                                    }
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Tab) {
                                    if (wpWindow.currentTab === "local") wpWindow.currentTab = "collection";
                                    else if (wpWindow.currentTab === "collection") wpWindow.currentTab = "online";
                                    else wpWindow.currentTab = "local";
                                    event.accepted = true;
                                }
                            }

                            Text {
                                text: wpWindow.currentTab === "online" ? "Search online..." : "Filter list..."
                                color: wpWindow.dim
                                visible: parent.text === ""
                                font: parent.font
                                anchors.fill: parent
                                verticalAlignment: TextInput.AlignVCenter
                            }
                        }
                    }

                    // Search/Refresh button
                    Rectangle {
                        width: 36; height: 36; radius: 18
                        color: refreshMA.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05)
                        visible: wpWindow.currentTab === "online"

                        Text {
                            anchors.centerIn: parent;
                            text: onlineProc.running ? "󰑐" : "󰄭";
                            color: wpWindow.fg;
                            font.pixelSize: 16
                            RotationAnimation on rotation {
                                from: 0; to: 360; duration: 1000; loops: Animation.Infinite;
                                running: onlineProc.running
                            }
                        }

                        MouseArea { id: refreshMA; anchors.fill: parent; hoverEnabled: true;
                            onClicked: {
                                wpWindow.onlineQuery = wpWindow.searchText;
                                wpWindow.onlineWallpapers = [];
                                onlineProc.running = false;
                                onlineProc.running = true;
                                wpWindow.searchText = "";
                                searchInput.text = "";
                                mainCard.forceActiveFocus();
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom; width: parent.width; height: 1
                    color: Qt.rgba(1, 1, 1, 0.05)
                }
            }

            // Grid Content
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                z: 1

                Flickable {
                    id: flickable
                    anchors.fill: parent
                    anchors.margins: 20
                    contentWidth: width
                    contentHeight: grid.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }

                    Grid {
                        id: grid
                        columns: 4
                        spacing: 20
                        width: flickable.width

                        Repeater {
                            model: wpWindow.filteredWallpapers

                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                width: (grid.width - (grid.spacing * 3)) / 4
                                height: width * 0.65
                                radius: 16
                                color: modelData.isFolder ? Qt.rgba(wpWindow.primary.r, wpWindow.primary.g, wpWindow.primary.b, 0.05) : Qt.rgba(1, 1, 1, 0.03)
                                border.width: 3
                                border.color: wpWindow.selectedIndex === index
                                    ? wpWindow.primary
                                    : (itemMA.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.05))
                                clip: true

                                Behavior on border.color { ColorAnimation { duration: 100 } }

                                SequentialAnimation on border.color {
                                    running: wpWindow.selectedIndex === index
                                    loops: Animation.Infinite
                                    ColorAnimation { to: Qt.lighter(wpWindow.primary, 1.2); duration: 800 }
                                    ColorAnimation { to: wpWindow.primary; duration: 800 }
                                }

                                // Folder icon (for folder entries)
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 8
                                    visible: modelData.isFolder

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.name === ".." ? "󰌍" : "󰉋"
                                        color: modelData.name === ".." ? wpWindow.yellow : wpWindow.primary
                                        font.pixelSize: 42
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.name === ".." ? "Back" : modelData.name
                                        color: wpWindow.fg
                                        font { pixelSize: 13; family: wpWindow.fontFamily; bold: true }
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.count > 0 ? modelData.count + " wallpapers" : ""
                                        color: wpWindow.dim
                                        font { pixelSize: 11; family: wpWindow.fontFamily }
                                        visible: modelData.count > 0
                                    }
                                }

                                // Wallpaper thumbnail (for wallpaper entries)
                                Image {
                                    anchors.fill: parent
                                    source: modelData.isFolder ? "" : modelData.thumb
                                    sourceSize.width: 320; sourceSize.height: 200
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    visible: !modelData.isFolder

                                    Rectangle {
                                        anchors.fill: parent
                                        color: Qt.rgba(0, 0, 0, 0.3); visible: parent.status !== Image.Ready && !modelData.isFolder
                                        Text { anchors.centerIn: parent; text: "󰄦"; color: wpWindow.dim; font.pixelSize: 32 }
                                    }
                                }

                                // Name label on hover
                                Rectangle {
                                    anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
                                    height: 40
                                    color: Qt.rgba(0, 0, 0, 0.7)
                                    visible: !modelData.isFolder && (itemMA.containsMouse || wpWindow.selectedIndex === index)

                                    Text {
                                        anchors.centerIn: parent
                                        width: parent.width - 20
                                        text: modelData.displayName || modelData.name
                                        color: wpWindow.fg
                                        font { pixelSize: 11; family: wpWindow.fontFamily; bold: wpWindow.selectedIndex === index }
                                        elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
                                    }
                                }

                                MouseArea {
                                    id: itemMA
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        wpWindow.selectedIndex = index;
                                        activateSelected();
                                    }
                                }
                            }
                        }
                    }
                }

                // Empty state / Loading
                Column {
                    anchors.centerIn: parent; spacing: 15
                    visible: wpWindow.filteredWallpapers.length === 0

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: (onlineProc.running || collectionProc.running) ? "󰑐" : "󰸉"
                        color: wpWindow.dim
                        font.pixelSize: 48
                        RotationAnimation on rotation {
                            from: 0; to: 360; duration: 1000; loops: Animation.Infinite;
                            running: (onlineProc.running || collectionProc.running)
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: onlineProc.running ? "Searching Wallhaven..." :
                              (wpWindow.currentTab === "online" && wpWindow.onlineWallpapers.length === 0) ? "Type a query and press Enter to search" :
                              collectionProc.running ? "Loading saved collection..." : "No wallpapers found"
                        color: wpWindow.dim; font { pixelSize: 16; family: wpWindow.fontFamily }
                    }
                }
            }
        }
    }

    Process { id: applyProc }
}
