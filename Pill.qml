import QtQuick
import QtQuick.Layouts

// Reusable pill container for bar modules
Rectangle {
    id: pill

    property alias content: contentRow.children
    property alias rowSpacing: contentRow.spacing

    implicitWidth: contentRow.implicitWidth + 24
    implicitHeight: 32
    radius: 16
    color: Theme.pillBg
    border.width: 2
    border.color: Theme.pillBorder

    Behavior on color { ColorAnimation { duration: 300 } }
    Behavior on border.color { ColorAnimation { duration: 300 } }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 6
    }
}
