//@ pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property int cpuUsage: 0
    property int memUsage: 0
    property int temperature: 0
    property int batteryLevel: 0
    property bool batteryCharging: false
    property string batteryIcon: "󰁹"

    // Internal CPU state
    property real lastIdle: 0
    property real lastTotal: 0

    Process {
        id: cpuProc
        command: ["sh", "-c", "head -1 /proc/stat"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                if (!data) return;
                var p = data.trim().split(/\s+/);
                var idle = parseInt(p[4]) + parseInt(p[5]);
                var total = p.slice(1, 8).reduce((a, b) => a + parseInt(b), 0);
                if (root.lastTotal > 0) {
                    var dt = total - root.lastTotal;
                    var di = idle - root.lastIdle;
                    root.cpuUsage = dt > 0 ? Math.round(100 * (1 - di / dt)) : 0;
                }
                root.lastTotal = total;
                root.lastIdle = idle;
            }
        }
    }

    Process {
        id: memProc
        command: ["sh", "-c", "free | grep Mem"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                if (!data) return;
                var p = data.trim().split(/\s+/);
                var total = parseInt(p[1]) || 1;
                var used = parseInt(p[2]) || 0;
                root.memUsage = Math.round(100 * used / total);
            }
        }
    }

    Process {
        id: tempProc
        command: ["sh", "-c",
            "cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -rn | head -1"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var val = parseInt(data.trim()) || 0;
                root.temperature = Math.round(val / 1000);
            }
        }
    }

    Process {
        id: battProc
        command: ["sh", "-c",
            "printf '%s\\n%s' " +
            "\"$(cat /sys/class/power_supply/macsmc-battery/capacity 2>/dev/null || " +
            "cat /sys/class/power_supply/BAT*/capacity 2>/dev/null || echo 99)\" " +
            "\"$(cat /sys/class/power_supply/macsmc-battery/status 2>/dev/null || " +
            "cat /sys/class/power_supply/BAT*/status 2>/dev/null || echo Discharging)\""]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n");
                root.batteryLevel = parseInt(lines[0]) || 0;
                root.batteryCharging = (lines[1] || "").trim() === "Charging";
                var l = root.batteryLevel;
                if (root.batteryCharging) root.batteryIcon = "";
                else if (l >= 90) root.batteryIcon = "󰁹";
                else if (l >= 70) root.batteryIcon = "󰂁";
                else if (l >= 50) root.batteryIcon = "󰁿";
                else if (l >= 30) root.batteryIcon = "󰁽";
                else if (l >= 10) root.batteryIcon = "󰁻";
                else root.batteryIcon = "󰁺";
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            cpuProc.running = true;
            memProc.running = true;
            tempProc.running = true;
            battProc.running = true;
        }
    }
}
