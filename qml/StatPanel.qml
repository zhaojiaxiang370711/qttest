import QtQuick
import QtQuick.Controls

Rectangle {
    id: panel
    property string title: ""
    property string value: ""
    property string caption: ""
    width: 220; height: 130; radius: 14; color: "#1b2027"
    Column {
        anchors.centerIn: parent; spacing: 6
        Label { text: panel.title; color: "#8a9099"; font.pixelSize: 14 }
        Label { text: panel.value; color: "#e6e8eb"; font.pixelSize: 40; font.bold: true }
        Label { text: panel.caption; color: "#5b626b"; font.pixelSize: 12 }
    }
}
