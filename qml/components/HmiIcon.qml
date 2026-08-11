pragma ComponentBehavior: Bound
import QtQuick

// Lucide icon with a baked color variant (software rendering cannot recolor
// SVGs, so scripts/sync_godot_assets.sh generates one SVG per tone).
// Usage: HmiIcon { name: "activity"; tone: "cyan"; size: 36 }
Image {
    id: icon
    property string name: ""
    property string tone: "white"   // white | muted | cyan | green | yellow | red | orange
    property int size: 24

    readonly property var validTones: ["white", "muted", "cyan", "green", "yellow", "red", "orange"]
    readonly property string effectiveTone: icon.validTones.indexOf(icon.tone) >= 0 ? icon.tone : "white"

    width: icon.size
    height: icon.size
    source: icon.name !== "" ? "qrc:/resources/icons/lucide/" + icon.name + "_" + icon.effectiveTone + ".svg" : ""
    sourceSize: Qt.size(icon.size * 2, icon.size * 2)
    smooth: true
    asynchronous: true
}
