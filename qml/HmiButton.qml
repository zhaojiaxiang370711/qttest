pragma ComponentBehavior: Bound
import QtQuick
import QxznHmi

// Shell action button. kind: primary (cyan fill, black text),
// ghost (translucent, white border), danger (red fill, white text).
Rectangle {
    id: button
    property string text: ""
    property string kind: "primary"     // primary | ghost | danger
    signal clicked()

    implicitWidth: label.implicitWidth + Theme.px(64)
    implicitHeight: Theme.px(37)        // 56
    radius: Theme.radiusButton
    transformOrigin: Item.Center
    color: button.kind === "primary" ? Theme.primary
         : button.kind === "danger" ? Theme.danger
         : Qt.rgba(1, 1, 1, 0.06)
    border.width: button.kind === "ghost" ? 1 : 0
    border.color: Qt.rgba(1, 1, 1, 0.40)
    scale: tap.pressed ? 0.97 : 1.0
    Behavior on scale { NumberAnimation { duration: 80 } }

    Text {
        id: label
        anchors.centerIn: parent
        text: button.text
        color: button.kind === "primary" ? "#050505" : Theme.text
        font.pixelSize: Theme.fontBody
    }

    TapHandler {
        id: tap
        onTapped: button.clicked()
    }
}
