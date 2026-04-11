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
    property string currentTab: "local" // "local", "collection", or "online"

    visible: showing
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    color: Qt.rgba(0, 0, 0, 0.5) // Scrim

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
        command: ["/home/river/.config/hypr/scripts/wallpaper-list.py", "--online-only", "--query", wpWindow.searchText || "citlali"]
        stdout: SplitParser { onRead: data => {
            try { wpWindow.onlineWallpapers = JSON.parse(data); } catch(e) {}
        }}
    }

    onShowingChanged: if (showing) { 
        localProc.running = true; 
        collectionProc.running = true;
        if (currentTab === "online") onlineProc.running = true;
        searchInput.forceActiveFocus(); 
    }
    
    onCurrentTabChanged: {
        if (showing && currentTab === "online" && onlineWallpapers.length === 0) onlineProc.running = true;
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
                
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 30; anchors.rightMargin: 30
                    spacing: 30

                    Text {
                        text: "󰸉 Wallpapers"
                        color: wpWindow.fg
                        font { pixelSize: 20; family: wpWindow.fontFamily; bold: true }
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
                            onAccepted: if (wpWindow.currentTab === "online") onlineProc.running = true
                            
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
                        Text { anchors.centerIn: parent; text: "󰄭"; color: wpWindow.fg; font.pixelSize: 16 }
                        MouseArea { id: refreshMA; anchors.fill: parent; hoverEnabled: true; onClicked: onlineProc.running = true }
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
                
                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 20
                    contentWidth: grid.width
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    Grid {
                        id: grid
                        columns: 4
                        spacing: 20
                        width: parent.width - 20

                        Repeater {
                            model: {
                                var base = wpWindow.currentTab === "local" ? wpWindow.localWallpapers : 
                                           wpWindow.currentTab === "collection" ? wpWindow.collectionWallpapers :
                                           wpWindow.onlineWallpapers;
                                if (wpWindow.searchText === "") return base;
                                return base.filter(w => w.name.toLowerCase().includes(wpWindow.searchText.toLowerCase()));
                            }

                            delegate: Rectangle {
                                required property var modelData
                                width: (grid.width - (grid.spacing * (grid.columns - 1))) / grid.columns
                                height: width * 0.65; radius: 16
                                color: Qt.rgba(1, 1, 1, 0.03)
                                border.width: 2; border.color: itemMA.containsMouse ? wpWindow.primary : Qt.rgba(1, 1, 1, 0.05)
                                clip: true
                                
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                Image {
                                    anchors.fill: parent
                                    source: modelData.thumb
                                    sourceSize.width: 320
                                    sourceSize.height: 200
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    
                                    // Loading indicator
                                    Rectangle {
                                        anchors.fill: parent
                                        color: Qt.rgba(0, 0, 0, 0.3)
                                        visible: parent.status !== Image.Ready
                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰄦"
                                            color: wpWindow.dim
                                            font.pixelSize: 32
                                        }
                                    }
                                }

                                // Name overlay on hover
                                Rectangle {
                                    anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
                                    height: 40
                                    color: Qt.rgba(0, 0, 0, 0.7)
                                    visible: itemMA.containsMouse
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        width: parent.width - 20
                                        text: modelData.name
                                        color: wpWindow.fg
                                        font { pixelSize: 11; family: wpWindow.fontFamily }
                                        elide: Text.ElideRight
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }

                                MouseArea {
                                    id: itemMA
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        applyProc.command = ["/home/river/.config/hypr/scripts/apply-wallpaper.sh", modelData.source, modelData.full, modelData.name];
                                        applyProc.running = true;
                                        wpWindow.showing = false;
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Empty state / Loading
                Column {
                    anchors.centerIn: parent
                    spacing: 15
                    visible: (wpWindow.currentTab === "online" && onlineProc.running) || 
                             (wpWindow.currentTab === "local" && localWallpapers.length === 0) ||
                             (wpWindow.currentTab === "collection" && collectionWallpapers.length === 0 && !collectionProc.running)
                    
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: (onlineProc.running || collectionProc.running) ? "󰑐" : "󰸉"
                        color: wpWindow.dim
                        font.pixelSize: 48
                        RotationAnimation on rotation {
                            from: 0; to: 360; duration: 1000; loops: Animation.Infinite; 
                            running: onlineProc.running || collectionProc.running
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: onlineProc.running ? "Fetching from Wallhaven..." : 
                              collectionProc.running ? "Loading saved collection..." : "No wallpapers found"
                        color: wpWindow.dim
                        font { pixelSize: 16; family: wpWindow.fontFamily }
                    }
                }
            }
        }
    }

    Process { id: applyProc }

    // Keyboard
    Shortcut { sequence: "Escape"; onActivated: wpWindow.showing = false }
    Shortcut { sequence: "Tab"; onActivated: {
        if (wpWindow.currentTab === "local") wpWindow.currentTab = "collection";
        else if (wpWindow.currentTab === "collection") wpWindow.currentTab = "online";
        else wpWindow.currentTab = "local";
    } }
}
