pragma Singleton
import QtQuick

// Shared design tokens for the Godot shell port.
// Geometry sources: runtime_layout.gd (panel15 profile), shell_controller.gd.
// panel15 scales 1280x720-base coordinates by 1.5 and font sizes by 1.56.
QtObject {
    // -- palette (shell_controller.gd HMI_* constants) --
    readonly property color panel: Qt.rgba(0.067, 0.067, 0.067, 0.82)
    readonly property color panelMask: Qt.rgba(0.02, 0.02, 0.02, 0.50)
    readonly property color text: "#F8FAFC"
    readonly property color muted: "#6B7B9C"
    readonly property color mutedSoft: Qt.rgba(0.420, 0.482, 0.612, 0.48)
    readonly property color primary: "#00F0FF"
    readonly property color cyan: "#00F0FF"
    readonly property color success: "#00FF78"
    readonly property color warn: "#FFE600"
    readonly property color danger: "#FF003C"
    readonly property color orange: "#FF5E00"
    // Godot HMI_PURPLE equals HMI_DANGER (shell_data.gd) -- kept for card data.
    readonly property color purple: "#FF003C"
    readonly property color cardBorder: Qt.rgba(1, 1, 1, 0.08)
    readonly property color cardHighlight: Qt.rgba(1, 1, 1, 0.08)
    readonly property color edgeDark: Qt.rgba(0, 0, 0, 0.11)
    readonly property color navSelected: Qt.rgba(0.34, 0.34, 0.35, 0.88)
    readonly property color windowBackground: "#050505"

    // -- fonts (family names confirmed via fc-scan on the bundled TTFs) --
    readonly property string bodyFamily: "Alimama ShuHeiTi"
    readonly property string brandFamily: "Alimama Agile VF"

    // -- scales (panel15 profile) --
    readonly property real layoutScale: 1.5
    readonly property real fontScale: 1.56
    readonly property real spacingScale: 1.62
    readonly property real touchScale: 1.56

    // px(): 1280x720-base coordinate to 1920x1080 logical px.
    function px(v) { return Math.round(v * layoutScale) }
    // fontPx(): Godot font size to Qt pixelSize.
    function fontPx(v) { return Math.round(v * fontScale) }

    // -- radii --
    readonly property int radiusCard: 28
    readonly property int radiusCardInner: 22
    readonly property int radiusTab: 18
    readonly property int radiusPill: 29
    readonly property int radiusButton: 18

    // -- font ladder: Godot base size -> x1.56 (values precomputed) --
    readonly property int fontTiny: 14      // 9
    readonly property int fontSmall: 17     // 11
    readonly property int fontCaption: 20   // 13
    readonly property int fontBody: 23      // 15 (nav tab labels)
    readonly property int fontTitle: 30     // 19
    readonly property int fontHeader: 36    // 23
    readonly property int fontCallout: 42   // 27 (callout text)
    readonly property int fontDisplay: 48   // 31
    readonly property int fontScore: 69     // 44
    readonly property int fontHuge: 137     // 88

    // -- layout anchors (runtime_layout.gd panel15 rects) --
    readonly property rect topBarRect: Qt.rect(63, 45, 1794, 87)
    readonly property rect pageRect: Qt.rect(48, 150, 1824, 882)

    // -- neumorph nine-patch metrics (shell_controller.gd) --
    readonly property int shadowPatchMargin: 30
    readonly property int shadowExpand: 18
}
