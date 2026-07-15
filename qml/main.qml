import QtQuick
import QtQuick.Controls

ApplicationWindow {
    width: 1280
    height: 720
    visible: true
    color: "#0f1115"
    title: "QXZN HMI"
    font.family: "Alimama Shu HeiTi"

    Item {
        id: keySink
        anchors.fill: parent
        focus: true
        Keys.onPressed: function(event) { session.onKey(event.key) }
    }
    Component.onCompleted: keySink.forceActiveFocus()
}
