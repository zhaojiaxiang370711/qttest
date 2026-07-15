import QtQuick
import QtQuick.Controls

Rectangle {
    id: pill
    property string icon: ""
    property string caption: ""
    property string value: ""
    width: 150; height: 96; radius: 12; color: "#1b2027"
    Column {
        anchors.centerIn: parent; spacing: 4
        Label { text: pill.icon; font.pixelSize: 20; anchors.horizontalCenter: parent.horizontalCenter }
        Label { text: pill.value; color: "#3fd0c9"; font.pixelSize: 24; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
        Label { text: pill.caption; color: "#8a9099"; font.pixelSize: 12; anchors.horizontalCenter: parent.horizontalCenter }
    }
}
