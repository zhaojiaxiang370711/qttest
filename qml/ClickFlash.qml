pragma ComponentBehavior: Bound
import QtQuick

// Click feedback flash: call flash() to replay a 220ms white fade-out over the
// parent area (shell_controller.gd draw_click_flash, peak alpha 0.22).
Rectangle {
    id: flashOverlay
    anchors.fill: parent
    color: flashOverlay.flashColor
    opacity: 0
    radius: 0

    property color flashColor: "white"

    function flash() {
        flashAnim.restart();
    }

    NumberAnimation {
        id: flashAnim
        target: flashOverlay
        property: "opacity"
        from: 0.22
        to: 0
        duration: 220
    }
}
