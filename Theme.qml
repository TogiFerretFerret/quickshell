//@ pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // Semantic colors — updated live from pywal
    property color bg:        "#0e1120"
    property color fg:        "#c2c3c7"
    property color surface:   "#0e1120"
    property color dim:       "#5d6172"
    property color primary:   "#1376C6"
    property color secondary: "#5E90B2"
    property color accent:    "#2393D7"
    property color red:       "#f38ba8"
    property color green:     "#a6e3a1"
    property color yellow:    "#f9e2af"
    property color maroon:    "#eba0ac"
    property color pillBg:    "#0e1120"
    property color pillBorder:"#5d6172"

    property string fontFamily: "JetBrainsMono Nerd Font"

    function updateDerived() {
        root.pillBg = Qt.rgba(root.bg.r, root.bg.g, root.bg.b, 0.7);
        root.pillBorder = root.dim;
    }

    onBgChanged: updateDerived()
    onDimChanged: updateDerived()

    FileView {
        id: walFile
        path: Qt.resolvedUrl("file://" + Quickshell.env("HOME") + "/.cache/wal/colors.json")
        watchChanges: true

        onFileChanged: walFile.reload()

        function apply() {
            try {
                var obj = JSON.parse(walFile.text());
                if (obj.special) {
                    root.bg  = obj.special.background;
                    root.fg  = obj.special.foreground;
                }
                if (obj.colors) {
                    root.surface   = obj.colors.color0;
                    root.dim       = obj.colors.color8;
                    root.primary   = obj.colors.color4;
                    root.secondary = obj.colors.color5;
                    root.accent    = obj.colors.color6;
                }
                root.updateDerived();
            } catch(e) {
                console.log("Theme: failed to parse pywal colors:", e);
            }
        }

        Component.onCompleted: apply()
        onLoaded: apply()
    }

    Component.onCompleted: updateDerived()
}
