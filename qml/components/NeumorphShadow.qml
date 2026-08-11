pragma ComponentBehavior: Bound
import QtQuick

// Nine-patch shadow baked from the Godot neumorph textures (96x96, margin 30).
// Hosts position this behind the fill with anchors.margins = -Theme.shadowExpand
// (raised) or 0 (inset, drawn inside the fill).
BorderImage {
    id: shadow
    property bool inset: false
    source: shadow.inset ? "qrc:/resources/images/neumorph/hmi_inset_shadow.png"
                         : "qrc:/resources/images/neumorph/hmi_raised_shadow.png"
    border.left: 30
    border.top: 30
    border.right: 30
    border.bottom: 30
    horizontalTileMode: BorderImage.Stretch
    verticalTileMode: BorderImage.Stretch
    smooth: true
}
