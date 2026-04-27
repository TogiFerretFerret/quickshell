import Quickshell
import Quickshell.Io
import QtQuick

Rectangle {
    id: scope
    width: 180; height: 34; radius: 17
    clip: true

    scale: scopeMA.containsMouse ? 1.033727 : 1.0
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
    MouseArea { id: scopeMA; anchors.fill: parent; hoverEnabled: true }

    property color pillBg: "#000000"
    property color pillBorder: "#ffffff"
    property color waveColor: "#a6e3a1"
    property string rateText: "OFF"

    color: pillBg
    border.width: 1
    border.color: pillBorder

    property var samples: []
    readonly property bool active: scope.rateText !== "OFF" && scope.rateText !== "IDLE"

    Process {
        id: cavaProc
        command: ["cava", "-p", "/home/river/.config/hypr/scripts/cava-scope.conf"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var raw = data.split(";");
                var arr = [];
                for (var i = 0; i < raw.length; i++) {
                    var val = parseInt(raw[i].trim());
                    if (!isNaN(val)) arr.push(val / 100);
                }
                if (arr.length >= 2) scope.samples = arr;
            }
        }
    }

    // Normalize samples
    property var normSamples: {
        var s = scope.samples;
        var len = Math.min(s.length, 32);
        var peak = 0.0;
        for (var i = 0; i < len; i++) { if (s[i] > peak) peak = s[i]; }
        var norm = peak > 0.01 ? peak : 1.0;
        var out = [];
        for (var i = 0; i < 32; i++) {
            if (i < len) {
                var raw = s[i] / norm;
                out.push(Math.min(Math.pow(raw, 1.8), 1.0));
            } else {
                out.push(0.0);
            }
        }
        return out;
    }

    Text {
        id: rateLabel
        anchors.left: parent.left; anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: scope.rateText
        color: scope.waveColor
        font { pixelSize: 11; family: "JetBrainsMono Nerd Font"; bold: true }
        z: 2
    }

    ShaderEffect {
        id: waveShader
        anchors.left: rateLabel.right; anchors.right: parent.right
        anchors.top: parent.top; anchors.bottom: parent.bottom
        anchors.leftMargin: 8; anchors.rightMargin: 12

        property real isActive: scope.active ? 1.0 : 0.0
        property real sampleCount: Math.min(scope.samples.length, 32)
        property real pixelHeight: waveShader.height
        property color waveColor: scope.waveColor
        property vector4d widthRatio: Qt.vector4d(waveShader.width / waveShader.height, 0, 0, 0)
        property vector4d b0: Qt.vector4d(normSamples[0],  normSamples[1],  normSamples[2],  normSamples[3])
        property vector4d b1: Qt.vector4d(normSamples[4],  normSamples[5],  normSamples[6],  normSamples[7])
        property vector4d b2: Qt.vector4d(normSamples[8],  normSamples[9],  normSamples[10], normSamples[11])
        property vector4d b3: Qt.vector4d(normSamples[12], normSamples[13], normSamples[14], normSamples[15])
        property vector4d b4: Qt.vector4d(normSamples[16], normSamples[17], normSamples[18], normSamples[19])
        property vector4d b5: Qt.vector4d(normSamples[20], normSamples[21], normSamples[22], normSamples[23])
        property vector4d b6: Qt.vector4d(normSamples[24], normSamples[25], normSamples[26], normSamples[27])
        property vector4d b7: Qt.vector4d(normSamples[28], normSamples[29], normSamples[30], normSamples[31])

        blending: true
        fragmentShader: "oscilloscope.frag.qsb"
    }
}
