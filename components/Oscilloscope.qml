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
    
    // These will be passed from shell.qml to match the theme
    property color pillBg: "#000000"
    property color pillBorder: "#ffffff"
    property color waveColor: "#a6e3a1"
    property string rateText: "OFF"
    
    color: pillBg
    border.width: 1
    border.color: pillBorder
    
    property var samples: []
    
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

    // Integrated Rate Text (Left side)
    Text {
        id: rateLabel
        anchors.left: parent.left; anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: scope.rateText
        color: scope.waveColor
        font { pixelSize: 11; family: "JetBrainsMono Nerd Font"; bold: true }
        z: 2
    }

    // Dynamic visibility/rendering based on activity
    readonly property bool active: scope.rateText !== "OFF" && scope.rateText !== "IDLE"

    Canvas {
        id: canvas
        anchors.left: rateLabel.right; anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
        anchors.leftMargin: 8; anchors.rightMargin: 12
        renderTarget: Canvas.FramebufferObject
        
        // Only paint if there is active audio
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.clearRect(0, 0, width, height);
            
            var mid = height / 2;
            if (!scope.active || scope.samples.length < 2) {
                // Draw a simple flat line when idle
                ctx.strokeStyle = scope.waveColor;
                ctx.globalAlpha = 0.5;
                ctx.lineWidth = 1;
                ctx.beginPath();
                ctx.moveTo(0, mid);
                ctx.lineTo(width, mid);
                ctx.stroke();
                return;
            }
            
            ctx.strokeStyle = scope.waveColor;
            ctx.lineCap = "round"; ctx.lineJoin = "round";
            
            ctx.beginPath();
            ctx.globalAlpha = 0.2; ctx.lineWidth = 3;
            drawWaveform(ctx); ctx.stroke();
            
            ctx.beginPath();
            ctx.globalAlpha = 1.0; ctx.lineWidth = 1.2;
            ctx.shadowBlur = 6; ctx.shadowColor = scope.waveColor;
            drawWaveform(ctx); ctx.stroke();
        }

        function drawWaveform(ctx) {
            var len = scope.samples.length;
            var step = width / (len - 1);
            var mid = height / 2;
            
            var pts = [];
            for (var i = 0; i < len; i++) {
                var x = i * step;
                var val = 0;
                
                if (i > 0 && i < len - 1) {
                    var raw = scope.samples[i];
                    val = (raw * raw) * 2.0; 
                    if (val > 1.0) val = 1.0;
                }
                
                var maxH = (height / 2) * 0.85;
                var sign = (i % 2 === 0) ? 1 : -1;
                pts.push({x: x, y: mid - (val * maxH * sign)});
            }
            
            ctx.moveTo(pts[0].x, pts[0].y);
            for (var i = 1; i < len - 2; i++) {
                var xc = (pts[i].x + pts[i+1].x) / 2;
                var yc = (pts[i].y + pts[i+1].y) / 2;
                ctx.quadraticCurveTo(pts[i].x, pts[i].y, xc, yc);
            }
            if (len > 2) {
                ctx.quadraticCurveTo(pts[len-2].x, pts[len-2].y, pts[len-1].x, pts[len-1].y);
            }
        }
    }
    
    Timer { 
        interval: scope.active ? 25 : 500 // 40 FPS when active, 2 FPS when idle
        running: true; repeat: true; 
        onTriggered: canvas.requestPaint() 
    }
}
