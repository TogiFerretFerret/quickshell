import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

PanelWindow {
    id: vpnPopup

    property bool showing: false
    property color bg: "#111318"
    property color fg: "#e1e2e9"
    property color dim: "#5d6172"
    property color primary: "#1376C6"
    property color green: "#a6e3a1"
    property color red: "#f38ba8"
    property string fontFamily: "JetBrainsMono Nerd Font"

    // nav state
    property int    level: 0              // 0 = country, 1 = city/server
    property string selectedCountry: ""
    property string selectedCity: ""
    property string activeVpn: ""        // connected hostname e.g. us1234.nordvpn.com
    property string activeCountry: ""    // country name from index matching activeVpn
    property bool   connecting: false
    property string connectStatus: ""

    // data
    property var countryList: []
    property var _indexServers: ({})

    // computed
    property string countrySearch: ""
    property string serverSearch: ""

    property var filteredCountries: {
        if (!countrySearch) return countryList;
        var s = countrySearch.toLowerCase();
        var out = [];
        for (var i = 0; i < countryList.length; i++)
            if (countryList[i].toLowerCase().indexOf(s) >= 0) out.push(countryList[i]);
        return out;
    }

    property var cityList: {
        var all = _indexServers[selectedCountry] || [];
        var seen = {}; var out = [];
        for (var i = 0; i < all.length; i++) {
            var c = all[i].city || "";
            if (c && !seen[c]) { seen[c] = true; out.push(c); }
        }
        out.sort();
        return out;
    }

    property var filteredServers: {
        var all = _indexServers[selectedCountry] || [];
        var out = [];
        for (var i = 0; i < all.length; i++) {
            if (selectedCity && all[i].city !== selectedCity) continue;
            if (serverSearch) {
                var s = serverSearch.toLowerCase();
                if (all[i].city.toLowerCase().indexOf(s) < 0 &&
                    all[i].name.toLowerCase().indexOf(s) < 0) continue;
            }
            out.push(all[i]);
        }
        return out;
    }

    // ── Index file ────────────────────────────────────────────────────────────
    FileView {
        id: indexFile
        path: Qt.resolvedUrl("file://" + Quickshell.env("HOME") + "/.local/share/nordvpn-index.json")
        onLoaded: {
            try {
                var d = JSON.parse(indexFile.text());
                vpnPopup.countryList   = d.countries || [];
                vpnPopup._indexServers = d.servers   || {};
            } catch(e) { console.log("VpnPopup: index parse error:", e); }
        }
        Component.onCompleted: reload()
    }

    // ── Active VPN poll ───────────────────────────────────────────────────────
    Process {
        id: pollActive
        command: ["nordvpn", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n");
                var connected = false; var hostname = "";
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (line.indexOf("Status: Connected") === 0) connected = true;
                    if (line.indexOf("Hostname: ") === 0) hostname = line.substring(10).trim();
                }
                vpnPopup.activeVpn = connected ? hostname : "";
                vpnPopup.activeCountry = vpnPopup.findCountryForHostname(vpnPopup.activeVpn);
                vpnPopup.connecting = false;
            }
        }
    }
    Timer { interval: 4000; repeat: true; running: vpnPopup.showing; onTriggered: pollActive.running = true }

    // ── Connect ───────────────────────────────────────────────────────────────
    Process {
        id: connectProc
        property string pendingHost: ""
        property string pendingGroup: ""
        command: ["/home/river/.local/bin/nordvpn-connect", pendingHost, pendingGroup]
        stdout: StdioCollector {
            onTextChanged: {
                var lines = text.trim().split("\n");
                var last = lines[lines.length - 1];
                if (last === "connecting") {
                    vpnPopup.connectStatus = "connecting...";
                } else if (last === "done") {
                    vpnPopup.connectStatus = "";
                    pollActive.running = true;
                } else if (last.indexOf("error:") === 0) {
                    vpnPopup.connectStatus = last;
                    vpnPopup.connecting    = false;
                    pollActive.running     = true;
                }
            }
        }
        onRunningChanged: if (!running) { vpnPopup.connecting = false; pollActive.running = true; }
    }

    // ── Disconnect ────────────────────────────────────────────────────────────
    Process {
        id: disconnectProc
        command: ["/home/river/.local/bin/nordvpn-disconnect"]
        onRunningChanged: if (!running) pollActive.running = true
    }

    function connect(name, hostname) {
        if (connecting) return;
        connectStatus = "connecting...";
        connectProc.pendingHost = hostname;
        connectProc.pendingGroup = "";
        connectProc.running = true;
        connecting = true; activeVpn = hostname;
    }

    function connectSpecialty(group, label) {
        if (connecting) return;
        connectStatus = "connecting...";
        connectProc.pendingHost = "";
        connectProc.pendingGroup = group;
        connectProc.running = true;
        connecting = true; activeVpn = "(" + label + ")";
    }

    function findCountryForHostname(hostname) {
        if (!hostname) return "";
        for (var country in _indexServers) {
            var servers = _indexServers[country];
            for (var i = 0; i < servers.length; i++) {
                if (servers[i].hostname === hostname) return country;
            }
        }
        return "";
    }
    function disconnect() {
        if (activeVpn === "") return;
        disconnectProc.running = true;
        connecting = true; activeVpn = "";
    }
    function goCountry(c) {
        selectedCountry = c; selectedCity = ""; serverSearch = "";
        serverSearchInput.text = "";
        level = 1; serverSearchInput.forceActiveFocus();
    }
    function goBack() { level = 0; countrySearch = ""; countrySearchInput.text = ""; countrySearchInput.forceActiveFocus(); }

    // ── Window ────────────────────────────────────────────────────────────────
    visible: showing
    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    onShowingChanged: {
        if (showing) {
            level = 0; countrySearch = ""; serverSearch = "";
            countrySearchInput.text = ""; serverSearchInput.text = "";
            pollActive.running = true;
            countrySearchInput.forceActiveFocus();
        }
    }

    Keys.onPressed: function(ev) {
        if (ev.key === Qt.Key_Escape) {
            if (level === 1) goBack();
            else vpnPopup.showing = false;
            ev.accepted = true;
        }
    }

    // click outside to close
    MouseArea { anchors.fill: parent; onClicked: vpnPopup.showing = false }

    // ── Card ──────────────────────────────────────────────────────────────────
    Rectangle {
        width: 700; height: 560
        anchors.centerIn: parent
        radius: 16
        color: Qt.rgba(vpnPopup.bg.r, vpnPopup.bg.g, vpnPopup.bg.b, 0.96)
        border.width: 1; border.color: Qt.rgba(1,1,1,0.08)

        MouseArea { anchors.fill: parent }  // block click-through

        Column {
            anchors.fill: parent; anchors.margins: 20; spacing: 12

            // ── Header ────────────────────────────────────────────────────────
            Row {
                width: parent.width; height: 30; spacing: 10

                // back button on level 1
                Rectangle {
                    visible: level === 1
                    width: 28; height: 28; radius: 8
                    color: backMA.containsMouse ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.06)
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Text { anchors.centerIn: parent; text: ""; color: vpnPopup.fg
                        font { pixelSize: 14; family: vpnPopup.fontFamily } }
                    MouseArea { id: backMA; anchors.fill: parent; hoverEnabled: true; onClicked: goBack() }
                }

                Text {
                    text: level === 0 ? "  NordVPN" : "  " + selectedCountry
                    color: vpnPopup.primary
                    font { pixelSize: 17; family: vpnPopup.fontFamily; bold: true }
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    visible: vpnPopup.connecting
                    text: "  " + (vpnPopup.connectStatus || "connecting...")
                    color: vpnPopup.connectStatus.indexOf("error:") === 0 ? vpnPopup.red : vpnPopup.primary
                    font { pixelSize: 12; family: vpnPopup.fontFamily }
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    visible: !vpnPopup.connecting && vpnPopup.activeVpn !== "" && vpnPopup.connectStatus === ""
                    text: "   " + vpnPopup.activeVpn + (vpnPopup.activeCountry ? "  (" + vpnPopup.activeCountry + ")" : "")
                    color: vpnPopup.green; font { pixelSize: 12; family: vpnPopup.fontFamily }
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight; width: 320
                }
                Text {
                    visible: !vpnPopup.connecting && vpnPopup.activeVpn === "" && vpnPopup.connectStatus === ""
                    text: "  not connected"
                    color: vpnPopup.dim; font { pixelSize: 12; family: vpnPopup.fontFamily }
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item { width: 1; height: 1 }

                Rectangle {
                    visible: vpnPopup.activeVpn !== ""
                    width: 88; height: 26; radius: 8
                    anchors.verticalCenter: parent.verticalCenter
                    color: discMA.containsMouse ? Qt.rgba(1,0.2,0.2,0.3) : Qt.rgba(1,0.2,0.2,0.14)
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text { anchors.centerIn: parent; text: "Disconnect"
                        color: vpnPopup.red; font { pixelSize: 11; family: vpnPopup.fontFamily } }
                    MouseArea { id: discMA; anchors.fill: parent; hoverEnabled: true; onClicked: vpnPopup.disconnect() }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.06) }

            // ── Level 0: Country picker ───────────────────────────────────────
            Column {
                visible: level === 0
                width: parent.width; height: parent.height - 57; spacing: 10

                // Specialty servers
                Column {
                    width: parent.width; spacing: 6

                    Text {
                        text: "SPECIALTY SERVERS"
                        color: vpnPopup.dim
                        font { pixelSize: 10; family: vpnPopup.fontFamily; bold: true }
                        leftPadding: 2
                    }

                    Row {
                        width: parent.width; spacing: 6

                        property var specialties: [
                            { group: "p2p",             label: "P2P",            icon: "" },
                            { group: "double_vpn",      label: "Double VPN",     icon: "" },
                            { group: "onion_over_vpn",  label: "Onion Over VPN", icon: "" },
                            { group: "obfuscated",      label: "Obfuscated",     icon: "󰛡" }
                        ]

                        Repeater {
                            model: parent.specialties

                            Rectangle {
                                required property var modelData
                                height: 34
                                width: (parent.parent.width - 18) / 4
                                radius: 10
                                property bool isActive: vpnPopup.activeVpn === "(" + modelData.label + ")"
                                color: isActive
                                    ? Qt.rgba(vpnPopup.green.r, vpnPopup.green.g, vpnPopup.green.b, 0.18)
                                    : spMA.containsMouse ? Qt.rgba(vpnPopup.primary.r, vpnPopup.primary.g, vpnPopup.primary.b, 0.2)
                                                        : Qt.rgba(vpnPopup.primary.r, vpnPopup.primary.g, vpnPopup.primary.b, 0.08)
                                Behavior on color { ColorAnimation { duration: 100 } }
                                border.width: 1
                                border.color: isActive
                                    ? Qt.rgba(vpnPopup.green.r, vpnPopup.green.g, vpnPopup.green.b, 0.4)
                                    : Qt.rgba(vpnPopup.primary.r, vpnPopup.primary.g, vpnPopup.primary.b, 0.25)

                                Column {
                                    anchors.centerIn: parent; spacing: 1
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.icon
                                        color: isActive ? vpnPopup.green : vpnPopup.primary
                                        font { pixelSize: 13; family: vpnPopup.fontFamily }
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.label
                                        color: isActive ? vpnPopup.green : vpnPopup.fg
                                        font { pixelSize: 10; family: vpnPopup.fontFamily; bold: isActive }
                                    }
                                }

                                MouseArea {
                                    id: spMA; anchors.fill: parent; hoverEnabled: true
                                    onClicked: vpnPopup.connectSpecialty(modelData.group, modelData.label)
                                }
                            }
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.06) }

                // Search
                Rectangle {
                    width: parent.width; height: 40; radius: 10
                    color: Qt.rgba(1,1,1,0.06)
                    border.width: countrySearchInput.activeFocus ? 1 : 0
                    border.color: vpnPopup.primary

                    Row {
                        anchors.fill: parent; anchors.margins: 12; spacing: 8
                        Text { text: ""; color: vpnPopup.dim; anchors.verticalCenter: parent.verticalCenter
                            font { pixelSize: 14; family: vpnPopup.fontFamily } }
                        TextInput {
                            id: countrySearchInput
                            width: parent.width - 30; height: parent.height
                            color: vpnPopup.fg; font { pixelSize: 14; family: vpnPopup.fontFamily }
                            clip: true; verticalAlignment: TextInput.AlignVCenter; selectByMouse: true
                            onTextChanged: { vpnPopup.countrySearch = text; }
                            Keys.onPressed: function(ev) {
                                if (ev.key === Qt.Key_Escape) { vpnPopup.showing = false; ev.accepted = true; }
                                else if (ev.key === Qt.Key_Return && vpnPopup.filteredCountries.length > 0)
                                    { goCountry(vpnPopup.filteredCountries[0]); ev.accepted = true; }
                            }
                            Text { text: "Search countries..."; color: vpnPopup.dim; font: parent.font
                                visible: !parent.text && !parent.activeFocus
                                anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }

                Text {
                    text: vpnPopup.filteredCountries.length + " countries"
                    color: vpnPopup.dim; font { pixelSize: 11; family: vpnPopup.fontFamily }
                }

                Flickable {
                    width: parent.width; height: parent.height - 160
                    contentHeight: countryGrid.implicitHeight
                    clip: true; boundsBehavior: Flickable.StopAtBounds

                    Grid {
                        id: countryGrid
                        width: parent.width; columns: 3; spacing: 6

                        Repeater {
                            model: vpnPopup.filteredCountries

                            Rectangle {
                                required property string modelData
                                width: (countryGrid.width - 12) / 3; height: 42; radius: 10
                                property bool isActive: vpnPopup.activeCountry === modelData
                                color: isActive
                                    ? Qt.rgba(vpnPopup.green.r, vpnPopup.green.g, vpnPopup.green.b, 0.18)
                                    : cMA.containsMouse ? Qt.rgba(1,1,1,0.1) : Qt.rgba(1,1,1,0.04)
                                Behavior on color { ColorAnimation { duration: 100 } }

                                Row {
                                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 8; spacing: 6
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData; elide: Text.ElideRight
                                        width: parent.width - 30
                                        color: isActive ? vpnPopup.green : vpnPopup.fg
                                        font { pixelSize: 13; family: vpnPopup.fontFamily; bold: isActive }
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: ""
                                        color: vpnPopup.dim; font { pixelSize: 11; family: vpnPopup.fontFamily }
                                    }
                                }
                                MouseArea { id: cMA; anchors.fill: parent; hoverEnabled: true
                                    onClicked: goCountry(modelData) }
                            }
                        }
                    }
                }
            }

            // ── Level 1: City chips + server list ─────────────────────────────
            Column {
                visible: level === 1
                width: parent.width; height: parent.height - 57; spacing: 10

                // City chips
                Flickable {
                    width: parent.width; height: 36
                    contentWidth: cityRow.implicitWidth; clip: true
                    flickableDirection: Flickable.HorizontalFlick

                    Row {
                        id: cityRow; spacing: 6

                        // "All" chip
                        Rectangle {
                            height: 30; width: allCityLabel.implicitWidth + 24; radius: 15
                            color: vpnPopup.selectedCity === ""
                                ? Qt.rgba(vpnPopup.primary.r, vpnPopup.primary.g, vpnPopup.primary.b, 0.35)
                                : allChipMA.containsMouse ? Qt.rgba(1,1,1,0.1) : Qt.rgba(1,1,1,0.06)
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Text { id: allCityLabel; anchors.centerIn: parent; text: "All"
                                color: vpnPopup.selectedCity === "" ? vpnPopup.fg : vpnPopup.dim
                                font { pixelSize: 12; family: vpnPopup.fontFamily; bold: vpnPopup.selectedCity === "" } }
                            MouseArea { id: allChipMA; anchors.fill: parent; hoverEnabled: true
                                onClicked: { vpnPopup.selectedCity = ""; } }
                        }

                        Repeater {
                            model: vpnPopup.cityList
                            Rectangle {
                                required property string modelData
                                height: 30; width: chipLabel.implicitWidth + 24; radius: 15
                                property bool sel: vpnPopup.selectedCity === modelData
                                color: sel
                                    ? Qt.rgba(vpnPopup.primary.r, vpnPopup.primary.g, vpnPopup.primary.b, 0.35)
                                    : chipMA.containsMouse ? Qt.rgba(1,1,1,0.1) : Qt.rgba(1,1,1,0.06)
                                Behavior on color { ColorAnimation { duration: 100 } }
                                Text { id: chipLabel; anchors.centerIn: parent; text: modelData
                                    color: sel ? vpnPopup.fg : vpnPopup.dim
                                    font { pixelSize: 12; family: vpnPopup.fontFamily; bold: sel } }
                                MouseArea { id: chipMA; anchors.fill: parent; hoverEnabled: true
                                    onClicked: vpnPopup.selectedCity = modelData }
                            }
                        }
                    }
                }

                // Server search
                Rectangle {
                    width: parent.width; height: 40; radius: 10
                    color: Qt.rgba(1,1,1,0.06)
                    border.width: serverSearchInput.activeFocus ? 1 : 0
                    border.color: vpnPopup.primary

                    Row {
                        anchors.fill: parent; anchors.margins: 12; spacing: 8
                        Text { text: ""; color: vpnPopup.dim; anchors.verticalCenter: parent.verticalCenter
                            font { pixelSize: 14; family: vpnPopup.fontFamily } }
                        TextInput {
                            id: serverSearchInput
                            width: parent.width - 30; height: parent.height
                            color: vpnPopup.fg; font { pixelSize: 14; family: vpnPopup.fontFamily }
                            clip: true; verticalAlignment: TextInput.AlignVCenter; selectByMouse: true
                            onTextChanged: vpnPopup.serverSearch = text
                            Keys.onPressed: function(ev) {
                                if (ev.key === Qt.Key_Escape) { goBack(); ev.accepted = true; }
                                else if (ev.key === Qt.Key_Return && vpnPopup.filteredServers.length > 0) {
                                    var s = vpnPopup.filteredServers[0];
                                    vpnPopup.connect(s.name, s.hostname);
                                    ev.accepted = true;
                                }
                            }
                            Text { text: "Filter servers..."; color: vpnPopup.dim; font: parent.font
                                visible: !parent.text && !parent.activeFocus
                                anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }

                Text {
                    text: vpnPopup.filteredServers.length + " servers"
                    color: vpnPopup.dim; font { pixelSize: 11; family: vpnPopup.fontFamily }
                }

                Flickable {
                    width: parent.width; height: parent.height - 136
                    contentHeight: serverCol.implicitHeight
                    clip: true; boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: serverCol; width: parent.width; spacing: 4

                        Repeater {
                            model: vpnPopup.filteredServers

                            Rectangle {
                                required property var modelData
                                width: parent.width; height: 44; radius: 10
                                property bool isActive: modelData.hostname === vpnPopup.activeVpn
                                color: isActive
                                    ? Qt.rgba(vpnPopup.green.r, vpnPopup.green.g, vpnPopup.green.b, 0.15)
                                    : sMA.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.03)
                                Behavior on color { ColorAnimation { duration: 100 } }

                                Row {
                                    anchors { fill: parent; leftMargin: 14; rightMargin: 12 }
                                    spacing: 10

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 50
                                        Text {
                                            text: modelData.city || modelData.name
                                            color: isActive ? vpnPopup.green : vpnPopup.fg
                                            font { pixelSize: 13; family: vpnPopup.fontFamily }
                                            elide: Text.ElideRight; width: parent.width
                                        }
                                        Text {
                                            text: modelData.hostname
                                            color: vpnPopup.dim
                                            font { pixelSize: 10; family: vpnPopup.fontFamily }
                                        }
                                    }

                                    Rectangle {
                                        width: 32; height: 26; radius: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: isActive
                                            ? Qt.rgba(1,0.2,0.2, btnMA.containsMouse ? 0.3 : 0.18)
                                            : Qt.rgba(0.4,0.9,0.4, btnMA.containsMouse ? 0.25 : 0.12)
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                        Text { anchors.centerIn: parent
                                            text: isActive ? "" : ""
                                            color: isActive ? vpnPopup.red : vpnPopup.green
                                            font { pixelSize: 12; family: vpnPopup.fontFamily } }
                                        MouseArea { id: btnMA; anchors.fill: parent; hoverEnabled: true
                                            onClicked: isActive ? vpnPopup.disconnect() : vpnPopup.connect(modelData.name, modelData.hostname) }
                                    }
                                }

                                MouseArea { id: sMA; anchors.fill: parent; hoverEnabled: true; z: -1
                                    onClicked: vpnPopup.connect(modelData.name, modelData.hostname) }
                            }
                        }
                    }
                }
            }
        }
    }
}
