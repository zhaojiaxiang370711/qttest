pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

Rectangle {
    id: bar
    color: "#16191f"
    property int activeNav: 0

    // Left cluster (Row lays children left-to-right; the Row itself is vertically centered
    // on the bar — do NOT put anchors.verticalCenter on children inside a Row, Row ignores it).
    Row {
        anchors.left: parent.left
        anchors.leftMargin: 24
        anchors.verticalCenter: parent.verticalCenter
        spacing: 24

        Rectangle { width: 48; height: 48; radius: 24; color: "#2a2f38"
            Label { anchors.centerIn: parent; text: "👤"; font.pixelSize: 24 } }
        Column { spacing: 2
            Label { text: "QXZN 运行时"; color: "#e6e8eb"; font.pixelSize: 20; font.bold: true }
            Label { text: "15.6″ HMI"; color: "#8a9099"; font.pixelSize: 12 } }

        Repeater {
            model: ["首页", "课程", "健身", "设置"]
            delegate: Rectangle {
                id: navItem
                required property int index
                required property string modelData
                width: navLabel.implicitWidth + 24; height: 40; radius: 8
                color: bar.activeNav === navItem.index ? "#243040" : "transparent"
                Label { id: navLabel; anchors.centerIn: parent; text: navItem.modelData; color: bar.activeNav === navItem.index ? "#3fd0c9" : "#aab2bd"; font.pixelSize: 16 }
                TapHandler { onTapped: bar.activeNav = navItem.index }
            }
        }
    }

    // Right cluster: wifi, battery, clock, exit.
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 24
        anchors.verticalCenter: parent.verticalCenter
        spacing: 20
        Label { text: "📶"; font.pixelSize: 18 }
        Label { text: "🔋 87%"; color: "#aab2bd"; font.pixelSize: 14 }
        Label { id: clock; text: "--:--:--"; color: "#e6e8eb"; font.pixelSize: 18; font.bold: true }
        Rectangle { width: 40; height: 40; radius: 8; color: "#2a2f38"
            Label { anchors.centerIn: parent; text: "✕"; color: "#e6e8eb"; font.pixelSize: 16 }
            TapHandler { onTapped: Qt.quit() } }
    }

    Timer { interval: 1000; running: true; repeat: true;
        onTriggered: clock.text = Qt.formatDateTime(new Date(), "HH:mm:ss") }
    Component.onCompleted: clock.text = Qt.formatDateTime(new Date(), "HH:mm:ss")
}
