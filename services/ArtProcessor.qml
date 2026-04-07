import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: proc

    property string sourceUrl: ""
    property string roundedPath: ""
    property string bgPath: ""

    onSourceUrlChanged: {
        if (!sourceUrl) { roundedPath = ""; bgPath = ""; return; }
        var src = sourceUrl.replace("file://", "");
        if (!src || src.indexOf("/") < 0) { src = sourceUrl; }
        processProc.command = ["sh", "-c",
            "mkdir -p /tmp/qs-art && " +
            "magick '" + src + "' -resize 140x140^ -gravity center -extent 140x140 " +
            "\\( +clone -alpha extract -draw 'fill black polygon 0,0 0,14 14,0 fill white circle 14,14 14,0' " +
            "-draw 'fill black polygon 0,126 0,140 14,140 fill white circle 14,126 14,140' " +
            "-draw 'fill black polygon 126,0 140,0 140,14 fill white circle 126,14 126,0' " +
            "-draw 'fill black polygon 126,140 140,126 140,140 fill white circle 126,126 126,140' " +
            "\\) -alpha off -compose CopyOpacity -composite /tmp/qs-art/thumb.png && " +
            "magick '" + src + "' -resize 340x200^ -gravity center -extent 340x200 -blur 0x8 -brightness-contrast -50x-25 " +
            "\\( +clone -alpha extract -draw 'fill black polygon 0,0 0,14 14,0 fill white circle 14,14 14,0' " +
            "-draw 'fill black polygon 0,186 0,200 14,200 fill white circle 14,186 14,200' " +
            "-draw 'fill black polygon 326,0 340,0 340,14 fill white circle 326,14 326,0' " +
            "-draw 'fill black polygon 326,200 340,186 340,200 fill white circle 326,186 326,200' " +
            "\\) -alpha off -compose CopyOpacity -composite /tmp/qs-art/bg.png && " +
            "echo done"
        ];
        processProc.running = true;
    }

    Process {
        id: processProc
        stdout: SplitParser {
            onRead: data => {
                if (data.trim() === "done") {
                    proc.roundedPath = "file:///tmp/qs-art/thumb.png?" + Date.now();
                    proc.bgPath = "file:///tmp/qs-art/bg.png?" + Date.now();
                }
            }
        }
    }
}
