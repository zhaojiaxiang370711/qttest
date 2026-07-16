import QtQuick
import QtQuick.Controls
import QxznHmi

ApplicationWindow {
    width: 1280
    height: 720
    visible: true
    color: "#0f1115"
    title: "QXZN HMI"
    font.family: "Alimama Shu HeiTi"

    TopBar {
        id: topBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 96
    }

    Loader {
        anchors.top: topBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        sourceComponent: topBar.activeNav === 0 ? dashboardComponent : placeholderComponent
    }
    Component { id: dashboardComponent; Dashboard {} }
    Component { id: placeholderComponent; PlaceholderPage {} }

    Shortcut { sequence: "Esc"; onActivated: Qt.quit() }

    Item {
        id: keySink
        anchors.fill: parent
        focus: true
        Keys.onPressed: function(event) { SessionModel.onKey(event.key) }
    }
    Component.onCompleted: keySink.forceActiveFocus()
}
