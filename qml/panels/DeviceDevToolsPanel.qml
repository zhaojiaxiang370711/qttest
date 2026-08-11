pragma ComponentBehavior: Bound
import QtQuick
import QxznHmi

// 开发工具面板（简化静态）。移植自 device_page.gd _draw_dev_tools_panel /
// _draw_dev_tool_card / _draw_update_section。
// 面板框 Rect2(176,108,928,544)@1280 x1.5 -> 页面局部 (216,12,1392,816)。
// 面板内部坐标/字号为 Godot 原始值（未缩放），字号经 Theme.fontPx 取等值。
// 种子：ros_health 空（断开）、runtime_diagnostics 空、led_segments 空、ws 0、
// update_state="idle"（"未检查更新"）、诊断摘要为空（回退提示文案）。
Item {
    id: root
    visible: AppState.overlayPanel === "dev_tools"

    // Qt.colorAlpha 过不了 qmllint（Qt 全局对象类型信息缺失），用 Qt.rgba 实现。
    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    function notPorted(name) {
        AppState.showCallout("info", "未移植", name + "将在后续阶段移植");
    }

    // Godot DEV_TOOL_CARDS：跳转目标为 device_page.gd 面板 id。
    readonly property var devCards: [
        { "target": "punch_control", "title": "出拳控制",     "subtitle": "动作控制、编排预览、关节微调", "icon": "hand-fist", "tone": "yellow", "color": Theme.warn },
        { "target": "pump_control",  "title": "气泵控制",     "subtitle": "目标压力、自动/手动控制",     "icon": "zap",       "tone": "cyan",   "color": Theme.cyan },
        { "target": "pressure",      "title": "压力监测",     "subtitle": "9 通道传感器读数",           "icon": "activity",  "tone": "cyan",   "color": Theme.primary },
        { "target": "hit_test",      "title": "击打测试",     "subtitle": "启停检测与计分",             "icon": "target",    "tone": "red",    "color": Theme.danger },
        { "target": "face",          "title": "自动高度调整", "subtitle": "视觉测高、电机与高度控制",   "icon": "user",      "tone": "yellow", "color": Theme.warn },
        { "target": "system",        "title": "系统操作",     "subtitle": "息屏、重启、关机",           "icon": "power",     "tone": "red",    "color": Theme.purple }
    ]

    FontMetrics { id: fm22; font.family: Theme.bodyFamily; font.pixelSize: Theme.fontPx(14) }
    FontMetrics { id: fm17; font.family: Theme.bodyFamily; font.pixelSize: Theme.fontSmall }
    FontMetrics { id: fm16; font.family: Theme.bodyFamily; font.pixelSize: Theme.fontPx(10) }
    FontMetrics { id: fm14; font.family: Theme.bodyFamily; font.pixelSize: Theme.fontTiny }
    FontMetrics { id: fm12; font.family: Theme.bodyFamily; font.pixelSize: Theme.fontPx(8) }
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

    // 遮罩：Godot Rect2(32,100,1216,588)@1280 x1.5 = 整页，Color(0,0,0,0.46)。
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.46)
        TapHandler { onTapped: AppState.closeOverlay() }
    }

    HmiCard {
        id: panel
        x: 216
        y: 12
        width: 1392
        height: 816
        radius: Theme.radiusCardInner          // Godot 24，取最近 token 22
        fillColor: root.alpha(Theme.panel, 0.94)
        TapHandler {}

        // 头部 _draw_panel_shell("开发工具", dev_tools, HMI_PURPLE==danger)
        Rectangle {
            x: 24
            y: 20
            width: 42
            height: 42
            radius: Theme.radiusTab
            color: root.alpha(Theme.purple, 0.17)
            HmiIcon {
                name: "sliders"
                tone: "red"
                size: 28
                anchors.centerIn: parent
            }
        }
        Text {
            x: 82
            y: 46 - fm22.ascent
            text: "开发工具"
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

        // body: (28,98,1336,690)
        Item {
            id: body
            x: 28
            y: 98
            width: panel.width - 56
            height: panel.height - 126

            // 4 状态芯片 (0/194/388/582,0,176,54)
            StatusChip { x: 0;   y: 0; width: 176; height: 54; label: "ROS2";      value: "已断开";   valueColor: Theme.danger }
            StatusChip { x: 194; y: 0; width: 176; height: 54; label: "Runtime";   value: "未刷新";   valueColor: Theme.muted }
            StatusChip { x: 388; y: 0; width: 176; height: 54; label: "LED 段";    value: "0";        valueColor: Theme.cyan }
            StatusChip { x: 582; y: 0; width: 176; height: 54; label: "WebSocket"; value: "0 客户端"; valueColor: Theme.primary }

            // 6 入口卡网格 (0,78,body.w,214)：3 列 gap 12，卡 437.33x92，行距 106。
            Repeater {
                model: root.devCards
                delegate: HmiCard {
                    id: devCard
                    required property int index
                    required property var modelData
                    readonly property int col: index % 3
                    readonly property int row: Math.floor(index / 3)

                    x: col * (437.33 + 12)
                    y: 78 + row * 106
                    width: 437.33
                    height: 92
                    radius: Theme.radiusTab               // Godot 18，取 token 18
                    fillColor: root.alpha(Theme.panel, 0.60)  // Godot glass 非悬停 0.60

                    HmiIcon {  // Godot 符号中心 (32,34) 26
                        name: devCard.modelData.icon
                        tone: devCard.modelData.tone
                        size: 26
                        x: 32 - width / 2
                        y: 34 - height / 2
                    }
                    Text {  // 标题基线 (66,34)，原始 16 = fontPx(10)
                        x: 66
                        y: 34 - fm16.ascent
                        width: devCard.width - 84
                        text: devCard.modelData.title
                        color: Theme.text
                        font.pixelSize: Theme.fontPx(10)
                        elide: Text.ElideRight
                    }
                    Text {  // 副标题基线 (66,58)，原始 11
                        x: 66
                        y: 58 - fm11.ascent
                        width: devCard.width - 84
                        text: devCard.modelData.subtitle
                        color: Theme.muted
                        font.pixelSize: Theme.fontPx(7)
                        elide: Text.ElideRight
                    }
                    ClickFlash {
                        id: devFlash
                        radius: devCard.radius
                        flashColor: devCard.modelData.color
                    }
                    TapHandler {
                        onTapped: {
                            devFlash.flash();
                            AppState.openOverlay(devCard.modelData.target);
                        }
                    }
                }
            }

            // 诊断按钮行 y=320
            PanelBtn { x: 0;   y: 320; width: 148; height: 46; text: "ROS2 健康";   tint: Theme.primary; onClicked: root.notPorted("ROS2 健康") }
            PanelBtn { x: 160; y: 320; width: 148; height: 46; text: "Runtime 诊断"; tint: Theme.cyan;    onClicked: root.notPorted("Runtime 诊断") }
            PanelBtn { x: 320; y: 320; width: 148; height: 46; text: "压力最新值";  tint: Theme.cyan;    onClicked: root.notPorted("压力最新值") }
            PanelBtn { x: 480; y: 320; width: 148; height: 46; text: "LED 状态";    tint: Theme.warn;    onClicked: root.notPorted("LED 状态") }
            PanelBtn { x: 640; y: 320; width: 128; height: 46; text: "头部闪烁";    tint: Theme.warn;    onClicked: root.notPorted("头部闪烁") }
            PanelBtn { x: 780; y: 320; width: 128; height: 46; text: "LED 全灭";    tint: Theme.danger;  danger: true; onClicked: root.notPorted("LED 全灭") }

            // 运行时更新 (0,382,body.w,86) r18；idle -> muted 图标
            HmiInset {
                id: updateBox
                x: 0
                y: 382
                width: body.width
                height: 86
                radius: Theme.radiusTab
                fillColor: Qt.rgba(0, 0, 0, 0.15)
                Rectangle {  // 图标盒 (18,18,48,48) r14
                    x: 18
                    y: 18
                    width: 48
                    height: 48
                    radius: Theme.radiusTab        // Godot 14，取最近 token 18
                    color: root.alpha(Theme.muted, 0.16)
                    HmiIcon {  // Godot lucide "activity" 24，中心 (42,42)
                        name: "activity"
                        tone: "muted"
                        size: 24
                        anchors.centerIn: parent
                    }
                }
                Text {  // "运行时更新" 基线 (82,31)，原始 14
                    x: 82
                    y: 31 - fm14.ascent
                    text: "运行时更新"
                    color: Theme.text
                    font.pixelSize: Theme.fontTiny
                }
                Text {  // 摘要基线 (82,56)，原始 12 = fontPx(8)，fit w-410
                    x: 82
                    y: 56 - fm12.ascent
                    width: updateBox.width - 410
                    text: "未检查更新"
                    color: Theme.muted
                    font.pixelSize: Theme.fontPx(8)
                    elide: Text.ElideRight
                }
                PanelBtn { x: updateBox.width - 330; y: 20; width: 150; height: 46; text: "检查更新"; tint: Theme.cyan; wide: true; onClicked: root.notPorted("检查更新") }
                PanelBtn { x: updateBox.width - 166; y: 20; width: 148; height: 46; text: "下载并重启"; tint: Theme.warn; wide: true; onClicked: root.notPorted("下载并重启") }
            }

            // 诊断输出 (0,body.h-60,body.w,52) r16
            HmiInset {
                id: outputBox
                x: 0
                y: body.height - 60
                width: body.width
                height: 52
                radius: Theme.radiusTab          // Godot 16，取最近 token 18
                fillColor: Qt.rgba(0, 0, 0, 0.17)
                Text {  // 基线 (18, body.h-28) 相对盒内 (18,32)，原始 12
                    x: 18
                    y: 32 - fm12.ascent
                    width: outputBox.width - 36
                    text: "点击上方按钮刷新诊断状态"
                    color: Theme.muted
                    font.pixelSize: Theme.fontPx(8)
                    elide: Text.ElideRight
                }
            }
        }
    }
}
