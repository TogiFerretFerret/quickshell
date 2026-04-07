import Quickshell
import Quickshell.Io
import QtQuick

// System info data provider - all properties available to bar via root.sys.*
Item {
    id: sysInfo

    // Basic stats
    property int cpuUsage: 0
    property int memUsage: 0
    property int memTotalMB: 0
    property int memUsedMB: 0
    property int temperature: 0
    property int battLevel: 0
    property bool battCharging: false
    property string battIcon: String.fromCodePoint(0xf0079)
    property string battTimeRemaining: ""
    property int brightness: 0
    property string cavaOutput: ""

    // Hover detail strings (populated by slower/separate processes)
    property string cpuDetail: ""
    property string memDetail: ""
    property string tempDetail: ""

    // Internal
    property real _lastIdle: 0
    property real _lastTotal: 0

    // Battery icon helper
    readonly property string _iCharge: String.fromCodePoint(0xf140b)
    readonly property string _iBatFull: String.fromCodePoint(0xf0079)
    readonly property string _iBat70: String.fromCodePoint(0xf0081)
    readonly property string _iBat50: String.fromCodePoint(0xf007f)
    readonly property string _iBat30: String.fromCodePoint(0xf007d)
    readonly property string _iBat10: String.fromCodePoint(0xf007b)
    readonly property string _iBatLow: String.fromCodePoint(0xf007a)

    // ── Fast poll (2s) ──
    Process { id: cpuProc; command: ["sh", "-c", "head -1 /proc/stat"]; running: true
        stdout: SplitParser { onRead: data => {
            if (!data) return; var p = data.trim().split(/\s+/);
            var idle = parseInt(p[4]) + parseInt(p[5]);
            var total = p.slice(1, 8).reduce((a, b) => a + parseInt(b), 0);
            if (sysInfo._lastTotal > 0) { var dt = total - sysInfo._lastTotal;
                sysInfo.cpuUsage = dt > 0 ? Math.round(100 * (1 - (idle - sysInfo._lastIdle) / dt)) : 0; }
            sysInfo._lastTotal = total; sysInfo._lastIdle = idle;
        }}
    }

    Process { id: memProc; command: ["sh", "-c", "free -m | grep Mem"]; running: true
        stdout: SplitParser { onRead: data => {
            if (!data) return; var p = data.trim().split(/\s+/);
            sysInfo.memTotalMB = parseInt(p[1]) || 0;
            sysInfo.memUsedMB = parseInt(p[2]) || 0;
            sysInfo.memUsage = Math.round(100 * sysInfo.memUsedMB / (sysInfo.memTotalMB || 1));
        }}
    }

    Process { id: tempProc; command: ["sh", "-c", "cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -rn | head -1"]; running: true
        stdout: SplitParser { onRead: data => { sysInfo.temperature = Math.round((parseInt(data.trim()) || 0) / 1000); } }
    }

    Process { id: battProc; command: ["sh", "-c",
        "printf '%s\\n%s\\n%s' " +
        "\"$(cat /sys/class/power_supply/macsmc-battery/capacity 2>/dev/null || cat /sys/class/power_supply/BAT*/capacity 2>/dev/null || echo 99)\" " +
        "\"$(cat /sys/class/power_supply/macsmc-battery/status 2>/dev/null || cat /sys/class/power_supply/BAT*/status 2>/dev/null || echo Discharging)\" " +
        "\"$(acpi -b 2>/dev/null | grep -oP '\\d+:\\d+' | head -1 || echo '')\""]; running: true
        stdout: StdioCollector { onStreamFinished: {
            var lines = text.trim().split("\n");
            sysInfo.battLevel = parseInt(lines[0]) || 0;
            sysInfo.battCharging = (lines[1] || "").trim() === "Charging";
            sysInfo.battTimeRemaining = (lines[2] || "").trim();
            var l = sysInfo.battLevel;
            sysInfo.battIcon = sysInfo.battCharging ? sysInfo._iCharge :
                l >= 90 ? sysInfo._iBatFull : l >= 70 ? sysInfo._iBat70 :
                l >= 50 ? sysInfo._iBat50 : l >= 30 ? sysInfo._iBat30 :
                l >= 10 ? sysInfo._iBat10 : sysInfo._iBatLow;
        }}
    }

    Process { id: blProc; command: ["sh", "-c",
        "echo $(( $(brightnessctl g) * 100 / $(brightnessctl m) ))"]; running: true
        stdout: SplitParser { onRead: data => { sysInfo.brightness = parseInt(data.trim()) || 0; } }
    }

    Timer { interval: 2000; running: true; repeat: true; onTriggered: {
        cpuProc.running = true; memProc.running = true; tempProc.running = true;
        battProc.running = true; blProc.running = true;
    }}

    // ── Slow poll (5s) - hover details ──
    Process { id: cpuDetailProc; command: ["sh", "-c",
        "top -bn1 | head -5 | tail -3"]; running: true
        stdout: StdioCollector { onStreamFinished: { sysInfo.cpuDetail = text.trim(); } }
    }

    Process { id: memDetailProc; command: ["sh", "-c",
        "free -h | head -3 && echo '---' && df -h / /home 2>/dev/null | tail -2"]; running: true
        stdout: StdioCollector { onStreamFinished: { sysInfo.memDetail = text.trim(); } }
    }

    Process { id: tempDetailProc; command: ["sh", "-c",
        "paste <(cat /sys/class/thermal/thermal_zone*/type) <(cat /sys/class/thermal/thermal_zone*/temp) 2>/dev/null | awk '{printf \"%s: %d°C\\n\", $1, $2/1000}'"]; running: true
        stdout: StdioCollector { onStreamFinished: { sysInfo.tempDetail = text.trim(); } }
    }

    Timer { interval: 5000; running: true; repeat: true; onTriggered: {
        cpuDetailProc.running = true; memDetailProc.running = true; tempDetailProc.running = true;
    }}

    // Cava
    Process { id: cavaProc; command: ["bash", Quickshell.env("HOME") + "/.config/waybar/WaybarCava.sh"]; running: true
        stdout: SplitParser { onRead: data => { sysInfo.cavaOutput = data.trim(); } }
    }
}
