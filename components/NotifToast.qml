import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick

PanelWindow {
    id: toastWindow

    property color bg: "#111318"
    property color fg: "#e1e2e9"
    property color dim: "#5d6172"
    property color primary: "#a3c9ff"
    property color accent: "#2393D7"
    property color red: "#f38ba8"
    property string fontFamily: "JetBrainsMono Nerd Font"

    property bool showing: toastModel.count > 0

    visible: showing
    anchors { top: true; right: true }
    margins.top: 50; margins.right: 10
    implicitWidth: 380
    implicitHeight: toastCol.implicitHeight + 16
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore

    // Toast model: { summary, body, appName, appIcon, urgency, nid, notifObj, expireMs }
    property var toastModel: ListModel {}

    function showNotification(notif) {
        // Max 3 visible toasts
        if (toastModel.count >= 3) {
            var old = toastModel.get(toastModel.count - 1);
            if (old.notifObj) old.notifObj.dismiss();
            toastModel.remove(toastModel.count - 1);
        }

        var timeout = notif.expireTimeout;
        if (timeout <= 0) {
            if (notif.urgency === 2) timeout = 0; // critical = sticky
            else if (notif.urgency === 0) timeout = 3000;
            else timeout = 6000;
        }

        toastModel.insert(0, {
            summary: notif.summary || "",
            body: notif.body || "",
            appName: notif.appName || "",
            appIcon: notif.appIcon || "",
            image: notif.image || "",
            urgency: notif.urgency || 1,
            nid: notif.id,
            notifObj: notif,
            expireMs: timeout
        });
    }

    function dismissToast(index) {
        if (index >= 0 && index < toastModel.count) {
            toastModel.remove(index);
        }
    }

    Column {
        id: toastCol
        anchors.top: parent.top; anchors.topMargin: 8
        anchors.right: parent.right; anchors.rightMargin: 8
        width: 364
        spacing: 8

        Repeater {
            model: toastModel

            Rectangle {
                id: toastCard
                required property var model
                required property int index
                width: parent.width
                height: toastContent.implicitHeight + 24
                radius: 16
                color: Qt.rgba(toastWindow.bg.r, toastWindow.bg.g, toastWindow.bg.b, 0.97)
                border.width: 1
                border.color: model.urgency === 2
                    ? Qt.rgba(toastWindow.red.r, toastWindow.red.g, toastWindow.red.b, 0.4)
                    : Qt.rgba(1, 1, 1, 0.06)
                clip: true

                // Critical glow
                Rectangle {
                    anchors.fill: parent; radius: 16
                    color: "transparent"
                    border.width: model.urgency === 2 ? 1 : 0
                    border.color: Qt.rgba(toastWindow.red.r, toastWindow.red.g, toastWindow.red.b, 0.15)
                    visible: model.urgency === 2
                }

                // Enter animation
                opacity: 0; x: 20
                Component.onCompleted: { opacity = 1; x = 0; }
                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                // Auto-dismiss timer
                Timer {
                    interval: model.expireMs > 0 ? model.expireMs : 0
                    running: model.expireMs > 0
                    onTriggered: toastWindow.dismissToast(toastCard.index)
                }

                Row {
                    id: toastContent
                    anchors.fill: parent; anchors.margins: 12
                    spacing: 10

                    // Notification image (screenshot, album art, etc.)
                    Image {
                        id: toastImg
                        width: 48; height: 48
                        source: model.image || ""
                        sourceSize.width: 48; sourceSize.height: 48
                        fillMode: Image.PreserveAspectCrop
                        visible: status === Image.Ready
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // App icon fallback (freedesktop theme icon)
                    IconImage {
                        id: toastIcon
                        implicitSize: 32
                        source: model.appIcon || ""
                        visible: !toastImg.visible && source !== ""
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        property int iconSpace: toastImg.visible ? 58 : toastIcon.visible ? 42 : 0
                        width: parent.width - iconSpace - closeBtn.width - 10
                        spacing: 3
                        anchors.verticalCenter: parent.verticalCenter

                        // App name
                        Text {
                            text: model.appName
                            color: toastWindow.dim
                            font { pixelSize: 10; family: toastWindow.fontFamily }
                            elide: Text.ElideRight; width: parent.width
                        }

                        // Summary
                        Text {
                            text: model.summary
                            color: toastWindow.fg
                            font { pixelSize: 14; family: toastWindow.fontFamily; bold: true }
                            elide: Text.ElideRight; width: parent.width
                            visible: text !== ""
                        }

                        // Body
                        Text {
                            text: model.body
                            color: Qt.rgba(toastWindow.fg.r, toastWindow.fg.g, toastWindow.fg.b, 0.8)
                            font { pixelSize: 12; family: toastWindow.fontFamily }
                            wrapMode: Text.WordWrap; width: parent.width
                            maximumLineCount: 3; elide: Text.ElideRight
                            visible: text !== ""
                        }
                    }

                    // Close button
                    Rectangle {
                        id: closeBtn
                        width: 20; height: 20; radius: 10
                        anchors.top: parent.top
                        color: closeBtnMA.containsMouse ? toastWindow.red : Qt.rgba(1, 1, 1, 0.08)
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text {
                            anchors.centerIn: parent
                            text: "×"; color: closeBtnMA.containsMouse ? toastWindow.bg : toastWindow.dim
                            font { pixelSize: 14; family: toastWindow.fontFamily; bold: true }
                        }
                        MouseArea {
                            id: closeBtnMA; anchors.fill: parent; hoverEnabled: true
                            onClicked: toastWindow.dismissToast(toastCard.index)
                        }
                    }
                }

                // Click to dismiss
                MouseArea {
                    anchors.fill: parent; z: -1
                    onClicked: toastWindow.dismissToast(toastCard.index)
                }
            }
        }
    }
}
