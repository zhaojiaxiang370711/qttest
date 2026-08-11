pragma ComponentBehavior: Bound
import QtQuick
import QxznHmi

// Top-center callout popup driven by AppState.callout* (effects_layer.gd).
// Timeline 0.95s: first 16% slide down 12px + fade in, last 20% fade out.
Item {
    id: host
    anchors.fill: parent

    readonly property var textColors: ({
        "info": "#E3FAFF",
        "success": "#E6FFEE",
        "warning": "#FFEEB8",
        "danger": "#FFE0E6"
    })
    readonly property var validTypes: ["info", "success", "warning", "danger"]
    readonly property string calloutType: host.validTypes.indexOf(AppState.calloutType) >= 0 ? AppState.calloutType : "info"

    BorderImage {
        id: frame
        width: Theme.px(540)
        height: Theme.px(122)
        anchors.horizontalCenter: parent.horizontalCenter
        source: "qrc:/resources/images/callouts/callout_" + host.calloutType + ".png"
        border.left: 120
        border.top: 60
        border.right: 120
        border.bottom: 60
        visible: AppState.calloutMessage !== "" && frame.life < 1

        property real life: 0
        readonly property real entrance: Math.min(frame.life / 0.16, 1)
        y: Theme.px(62) - (1 - frame.entrance) * 12
        opacity: frame.life < 0.16 ? frame.life / 0.16
               : frame.life > 0.8 ? (1 - frame.life) / 0.2
               : 1

        Column {
            anchors.centerIn: parent
            spacing: 6
            Text {
                visible: AppState.calloutTitle !== ""
                text: AppState.calloutTitle
                color: host.textColors[host.calloutType]
                font.pixelSize: Theme.fontCaption
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                text: AppState.calloutMessage
                color: host.textColors[host.calloutType]
                font.pixelSize: AppState.calloutTitle !== "" ? Theme.fontTitle : Theme.fontCallout
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    NumberAnimation {
        id: calloutAnim
        target: frame
        property: "life"
        from: 0
        to: 1
        duration: 950
    }

    Connections {
        target: AppState
        function onCalloutSeqChanged() {
                calloutAnim.restart();
        }
    }
}
