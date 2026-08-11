pragma ComponentBehavior: Bound
import QtQuick
import QxznHmi

// 出拳控制面板（简化静态）。移植自 device_page.gd _draw_punch_control_panel。
// 面板框 Rect2(92,106,1096,548)@1280 x1.5 -> 页面局部 (90,9,1644,822)。
// 面板内部坐标/字号为 Godot 原始值（未缩放），字号经 Theme.fontPx 取等值。
// 种子：ros2 断开、关节未检测、关节值 0.00；所有按钮 -> 未移植 callout。
Item {
    id: root
    visible: AppState.overlayPanel === "punch_control"

    // Qt.colorAlpha 过不了 qmllint（Qt 全局对象类型信息缺失），用 Qt.rgba 实现。
    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    function notPorted(name) {
        AppState.showCallout("info", "未移植", name + "将在后续阶段移植");
    }

    // Godot PUNCH_SYSTEM_COMMANDS / PUNCH_ACTIONS / PUNCH_CHOREO_ACTIONS / JOINT_CONTROLS。
    readonly property var systemCmds: [
        { "label": "初始化",   "color": Theme.primary },
        { "label": "对战姿态", "color": Theme.warn },
        { "label": "归位",     "color": Theme.success }
    ]
    readonly property var punchActions: [
        "左直拳击头", "右直拳击头", "左摆拳击头", "右摆拳击头",
        "左勾拳击头", "右勾拳击头", "左摆拳击腹", "右摆拳击腹",
        "侧闪躲左",   "侧闪躲右",   "后仰",       "左摆+右直"
    ]
    readonly property var choreoActions: [
        "左摆拳", "右摆拳", "左闪躲", "右闪躲",
        "后闪躲", "左直拳", "右直拳", "下巴左勾"
    ]
    readonly property var jointControls: ["腰部横滚", "腰部俯仰", "腰部旋转", "左肘", "右肘"]

    FontMetrics { id: fm22; font.family: Theme.bodyFamily; font.pixelSize: Theme.fontPx(14) }
    FontMetrics { id: fm17; font.family: Theme.bodyFamily; font.pixelSize: Theme.fontSmall }
    FontMetrics { id: fm14; font.family: Theme.bodyFamily; font.pixelSize: Theme.fontTiny }
    FontMetrics { id: fm11; font.family: Theme.bodyFamily; font.pixelSize: Theme.fontPx(7) }

    // Godot 面板按钮 _draw_panel_button（同音量面板注释）。
    component PanelBtn: Rectangle {
        id: pb
        property string text: ""
        property color tint: Theme.primary
        property bool selected: false
        property bool danger: false
        property bool wide: false
        signal clicked()
        radius: Theme.radiusButton              // Godot 15，取最近 token 18
        color: root.alpha(pb.tint, pb.danger ? 0.14 : (pb.selected ? 0.24 : 0.10))
        border.width: 1
        border.color: root.alpha(pb.tint, pb.selected ? 0.54 : 0.28)
        Text {
            anchors.centerIn: parent
            text: pb.text
            color: (pb.selected || pb.wide) ? Theme.text : pb.tint
            font.pixelSize: Theme.fontTiny
        }
        ClickFlash { id: pbFlash; radius: pb.radius; flashColor: pb.tint }
        TapHandler { onTapped: { pbFlash.flash(); pb.clicked(); } }
    }

    // Godot _draw_status_chip（同气泵面板注释）。
    component StatusChip: HmiInset {
        id: chip
        property string label: ""
        property string value: ""
        property color valueColor: Theme.muted
        radius: Theme.radiusTab
        fillColor: Qt.rgba(0, 0, 0, 0.17)
        Text {
            x: 16
            y: 21 - fm11.ascent
            text: chip.label
            color: Theme.muted
            font.pixelSize: Theme.fontPx(7)
        }
        Text {
            x: 16
            y: 44 - fm17.ascent
            width: chip.width - 32
            text: chip.value
            color: chip.valueColor
            font.pixelSize: Theme.fontSmall
            elide: Text.ElideRight
        }
    }

    // Godot _draw_panel_section：inset r18 Color(0,0,0,0.15) + 标题基线 (18,25)。
    component Section: HmiInset {
        id: sec
        property string title: ""
        radius: Theme.radiusTab
        fillColor: Qt.rgba(0, 0, 0, 0.15)
        Text {
            x: 18
            y: 25 - fm14.ascent
            text: sec.title
            color: Theme.muted
            font.pixelSize: Theme.fontTiny
        }
    }

    // 遮罩：Godot Rect2(32,100,1216,588)@1280 x1.5 = 整页，Color(0,0,0,0.46)。
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.46)
        TapHandler { onTapped: AppState.closeOverlay() }
    }

    HmiCard {
        id: panel
        x: 90
        y: 9
        width: 1644
        height: 822
        radius: Theme.radiusCardInner          // Godot 24，取最近 token 22
        fillColor: root.alpha(Theme.panel, 0.94)
        TapHandler {}

        // 头部 _draw_panel_shell("出拳控制", punch_control, HMI_WARN)
        Rectangle {
            x: 24
            y: 20
            width: 42
            height: 42
            radius: Theme.radiusTab
            color: root.alpha(Theme.warn, 0.17)
            HmiIcon {
                name: "hand-fist"
                tone: "yellow"
                size: 28
                anchors.centerIn: parent
            }
        }
        Text {
            x: 82
            y: 46 - fm22.ascent
            text: "出拳控制"
            color: Theme.text
            font.pixelSize: Theme.fontPx(14)   // 原始 22
        }
        Rectangle {
            id: closeBtn
            x: panel.width - 62
            y: 21
            width: 40
            height: 40
            radius: Theme.radiusTab
            color: root.alpha(Theme.danger, 0.10)
            border.width: 1
            border.color: root.alpha(Theme.danger, 0.20)
            Rectangle {
                width: 20
                height: 2
                anchors.centerIn: parent
                rotation: 45
                color: Theme.text
            }
            Rectangle {
                width: 20
                height: 2
                anchors.centerIn: parent
                rotation: -45
                color: Theme.text
            }
            ClickFlash { id: closeFlash; radius: closeBtn.radius; flashColor: Theme.danger }
            TapHandler {
                onTapped: {
                    closeFlash.flash();
                    AppState.closeOverlay();
                }
            }
        }
        Rectangle {
            x: 24
            y: 78
            width: panel.width - 48
            height: 1
            color: Qt.rgba(1, 1, 1, 0.06)
        }

        // body: (28,98,1588,696)
        Item {
            id: body
            x: 28
            y: 98
            width: panel.width - 56
            height: panel.height - 126

            StatusChip { x: 0;   y: 0; width: 170; height: 52; label: "ROS2";     value: "已断开"; valueColor: Theme.danger }
            StatusChip { x: 186; y: 0; width: 170; height: 52; label: "关节状态"; value: "未检测"; valueColor: Theme.muted }
            PanelBtn {  // 刷新状态 (body.w-174,0,174,48)
                x: body.width - 174
                y: 0
                width: 174
                height: 48
                text: "刷新状态"
                tint: Theme.primary
                onClicked: root.notPorted("刷新状态")
            }

            // 左栏 "系统与模式": Godot Rect2(0,72,218,body.h-72)
            Section {
                id: leftSec
                x: 0
                y: 72
                width: 218
                height: body.height - 72
                title: "系统与模式"
                Repeater {
                    model: root.systemCmds
                    delegate: PanelBtn {
                        required property int index
                        required property var modelData
                        x: 18
                        y: 42 + index * 54
                        width: leftSec.width - 36
                        height: 42
                        text: modelData.label
                        tint: modelData.color
                        wide: true
                        onClicked: root.notPorted(modelData.label)
                    }
                }
                PanelBtn { x: 18; y: 214; width: leftSec.width - 36; height: 42; text: "腰部归零"; tint: Theme.cyan; onClicked: root.notPorted("腰部归零") }
                PanelBtn { x: 18; y: 266; width: leftSec.width - 36; height: 42; text: "手臂归位"; tint: Theme.cyan; onClicked: root.notPorted("手臂归位") }
            }

            // 中栏 "出拳动作": Godot Rect2(236,72,490,body.h-72)；3 列 gap 8，宽 146 高 39。
            Section {
                id: midSec
                x: 236
                y: 72
                width: 490
                height: body.height - 72
                title: "出拳动作"
                Repeater {
                    model: root.punchActions
                    delegate: PanelBtn {
                        required property int index
                        required property var modelData
                        readonly property int col: index % 3
                        readonly property int row: Math.floor(index / 3)
                        x: 18 + col * (146 + 8)
                        y: 42 + row * 48
                        width: 146
                        height: 39
                        text: modelData
                        tint: Theme.warn
                        onClicked: root.notPorted(modelData)
                    }
                }
            }

            // 右栏 "编排与关节": Godot Rect2(744,72,body.w-744,body.h-72)
            Section {
                id: rightSec
                x: 744
                y: 72
                width: body.width - 744
                height: body.height - 72
                title: "编排与关节"
                Repeater {  // 编排按钮 2 列，宽 (844-42)/2=401，高 31
                    model: root.choreoActions
                    delegate: PanelBtn {
                        required property int index
                        required property var modelData
                        readonly property int col: index % 2
                        readonly property int row: Math.floor(index / 2)
                        x: 18 + col * (401 + 8)
                        y: 42 + row * 38
                        width: 401
                        height: 31
                        text: modelData
                        tint: Theme.primary
                        onClicked: root.notPorted("编排预览 " + modelData)
                    }
                }
                Text {  // "关节微调" 基线 (18,206)，原始 13 -> 14
                    x: 18
                    y: 206 - fm14.ascent
                    text: "关节微调"
                    color: Theme.muted
                    font.pixelSize: Theme.fontTiny
                }
                Repeater {  // 5 关节行 y=226+i*34：标签/值/-/+
                    model: root.jointControls
                    delegate: Item {
                        id: jointRow
                        required property int index
                        required property var modelData
                        x: 0
                        y: 226 + index * 34
                        width: rightSec.width
                        height: 28
                        Text {  // 标签基线 (18,21)，原始 11
                            x: 18
                            y: 21 - fm11.ascent
                            width: 88
                            text: jointRow.modelData
                            color: Theme.muted
                            font.pixelSize: Theme.fontPx(7)
                            elide: Text.ElideRight
                        }
                        Text {  // 值基线 (102,21)，原始 10 -> 11；静态 0.00
                            x: 102
                            y: 21 - fm11.ascent
                            text: "0.00"
                            color: Theme.mutedSoft
                            font.pixelSize: Theme.fontPx(7)
                        }
                        PanelBtn { x: 178; y: 0; width: 44; height: 28; text: "-"; tint: Theme.cyan; onClicked: root.notPorted("关节微调 " + jointRow.modelData) }
                        PanelBtn { x: 230; y: 0; width: 44; height: 28; text: "+"; tint: Theme.cyan; onClicked: root.notPorted("关节微调 " + jointRow.modelData) }
                    }
                }
            }
        }
    }
}
