pragma ComponentBehavior: Bound
import QtQuick
import QxznHmi

// HMI inset (recessed) card: rounded fill + inner neumorph shadow drawn inside
// the fill + edge lines at strength 0.68. Mirrors draw_hmi_inset.
Item {
    id: root
    default property alias content: container.data
    property real radius: Theme.radiusCard
    property color fillColor: Theme.panel

    Rectangle {
        id: insetBody
        anchors.fill: parent
        radius: root.radius
        color: root.fillColor
        border.width: 1
        border.color: Theme.cardBorder
    }

    NeumorphShadow {
        inset: true
        anchors.fill: insetBody
        opacity: 0.82
    }

    // edge lines, strength 0.68 (see HmiCard for the geometry)
    Rectangle {
        x: 1 + root.radius + 8
        y: 1
        width: Math.max(0, root.width - 2 * (root.radius + 8) - 2)
        height: 1
        color: Theme.cardHighlight
        opacity: 0.218
    }
    Rectangle {
        x: 1
        y: 1 + root.radius + 8
        width: 1
        height: Math.max(0, root.height - 2 * (root.radius + 8) - 2)
        color: Theme.cardHighlight
        opacity: 0.122
    }
    Rectangle {
        x: 1 + root.radius + 8
        y: root.height - 2
        width: Math.max(0, root.width - 2 * (root.radius + 8) - 2)
        height: 1
        color: Theme.edgeDark
        opacity: 0.326
    }
    Rectangle {
        x: root.width - 2
        y: 1 + root.radius + 8
        width: 1
        height: Math.max(0, root.height - 2 * (root.radius + 8) - 2)
        color: Theme.edgeDark
        opacity: 0.218
    }

    Item {
        id: container
        anchors.fill: parent
    }
}
