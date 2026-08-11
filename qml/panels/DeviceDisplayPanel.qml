pragma ComponentBehavior: Bound
import QtQuick
import QxznHmi

// 显示面板。移植自 device_page.gd _draw_display_panel（Godot 面板标题 "息屏设置"）。
// 面板框 Rect2(330,154,620,414)@1280 x1.5 -> 页面局部 (447,81,930,621)。
// 面板内部坐标/字号为 Godot 原始值（未缩放），字号经 Theme.fontPx 取等值。
// 既定偏差：Godot 面板只有息屏块；按任务要求追加屏幕亮度块（种子
// ShellData.deviceStatus.brightness=0.8，亮度为 Qt 移植新增，Godot 无对应），
// 样式复刻音量面板的滑条+预设行，置于 Godot 息屏块下方。
Item {
    id: root
    visible: AppState.overlayPanel === "display"

    // Qt.colorAlpha 过不了 qmllint（Qt 全局对象类型信息缺失），用 Qt.rgba 实现。
    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    // 息屏种子：device_model.gd screen_off_delay=300；亮度种子：deviceStatus 0.8。
    property int delaySec: 300
    property int brightnessPercent: Math.round(ShellData.deviceStatus.brightness * 100)  // 80

    function delayLabel(sec) {
        switch (sec) {
        case 0: return "从不";
        case 60: return "1 分钟";
        case 180: return "3 分钟";
        case 300: return "5 分钟";
        case 600: return "10 分钟";
        }
        return Math.round(sec / 60) + " 分钟";
    }

    function notPorted(name) {
        AppState.showCallout("info", "未移植", name + "将在后续阶段移植");
    }

    FontMetrics { id: fm30; font.family: Theme.bodyFamily; font.pixelSize: Theme.fontPx(19) }
    FontMetrics { id: fm22; font.family: Theme.bodyFamily; font.pixelSize: Theme.fontPx(14) }
    FontMetrics { id: fm14; font.family: Theme.bodyFamily; font.pixelSize: Theme.fontTiny }

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

    // 遮罩：Godot Rect2(32,100,1216,588)@1280 x1.5 = 整页，Color(0,0,0,0.46)。
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.46)
        TapHandler { onTapped: AppState.closeOverlay() }
    }

    HmiCard {
        id: panel
        x: 447
        y: 81
        width: 930
        height: 621
        radius: Theme.radiusCardInner          // Godot 24，取最近 token 22
        fillColor: root.alpha(Theme.panel, 0.94)
        TapHandler {}

        // 头部 _draw_panel_shell("息屏设置", display_settings, HMI_CYAN)
        Rectangle {
            x: 24
            y: 20
            width: 42
            height: 42
            radius: Theme.radiusTab
            color: root.alpha(Theme.cyan, 0.17)
            HmiIcon {
                name: "monitor-play"
                tone: "cyan"
                size: 28
                anchors.centerIn: parent
            }
        }
        Text {
            x: 82
            y: 46 - fm22.ascent
            text: "息屏设置"
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

        // body: (28,98,874,495)
        Item {
            id: body
            x: 28
            y: 98
            width: panel.width - 56
            height: panel.height - 126

            // -- Godot 息屏块（原始布局） --
            Text {  // "息屏时间" 基线 (22,24)，原始 15 -> 14
                x: 22
                y: 24 - fm14.ascent
                text: "息屏时间"
                color: Theme.muted
                font.pixelSize: Theme.fontTiny
            }
            Text {  // 当前值基线 (22,58)，原始 30 = fontPx(19)
                x: 22
                y: 58 - fm30.ascent
                width: body.width - 44
                text: root.delayLabel(root.delaySec)
                color: Theme.text
                font.pixelSize: Theme.fontPx(19)
                elide: Text.ElideRight
            }
            Text {  // 提示基线 (22,96)，原始 13 -> 14
                x: 22
                y: 96 - fm14.ascent
                width: body.width - 44
                text: "息屏设置会保存在本机 Godot Shell 配置中"
                color: Theme.muted
                font.pixelSize: Theme.fontTiny
                elide: Text.ElideRight
            }
            // 选项行 y=142：gap 12，宽 (874-44-48)/5=156.4
            Repeater {
                model: [
                    { "value": 0,   "label": "从不" },
                    { "value": 60,  "label": "1 分钟" },
                    { "value": 180, "label": "3 分钟" },
                    { "value": 300, "label": "5 分钟" },
                    { "value": 600, "label": "10 分钟" }
                ]
                delegate: PanelBtn {
                    required property int index
                    required property var modelData
                    x: 22 + index * (156.4 + 12)
                    y: 142
                    width: 156.4
                    height: 46
                    text: modelData.label
                    tint: Theme.cyan
                    selected: root.delaySec === modelData.value
                    onClicked: root.delaySec = modelData.value
                }
            }
            PanelBtn {  // "立即息屏" (22,222,w-44,52) wide
                x: 22
                y: 222
                width: body.width - 44
                height: 52
                text: "立即息屏"
                tint: Theme.warn
                wide: true
                onClicked: root.notPorted("立即息屏")
            }

            // -- 亮度块（Qt 移植新增，Godot 无对应；样式复刻音量面板） --
            Text {  // 标签
                x: 22
                y: 308 - fm14.ascent
                text: "屏幕亮度"
                color: Theme.muted
                font.pixelSize: Theme.fontTiny
            }
            Text {  // 右对齐百分比，原始 30 = fontPx(19)
                x: body.width - 22 - 150
                y: 308 - fm30.ascent
                width: 150
                horizontalAlignment: Text.AlignRight
                text: root.brightnessPercent + "%"
                color: Theme.cyan
                font.pixelSize: Theme.fontPx(19)
            }
            Rectangle {  // 滑条底 (22,336,w-44,14)
                x: 22
                y: 336
                width: body.width - 44
                height: 14
                radius: Theme.radiusPill       // 钳制为 h/2=7
                color: Theme.cardHighlight
            }
            Rectangle {
                x: 22
                y: 336
                width: (body.width - 44) * root.brightnessPercent / 100
                height: 14
                visible: width > 0
                radius: Theme.radiusPill
                color: root.alpha(Theme.cyan, 0.78)
            }
            Repeater {  // 预设行 y=370
                model: [0, 30, 50, 80, 100]
                delegate: PanelBtn {
                    required property int index
                    required property var modelData
                    x: 22 + index * (156.4 + 12)
                    y: 370
                    width: 156.4
                    height: 44
                    text: modelData + "%"
                    tint: Theme.cyan
                    selected: root.brightnessPercent === modelData
                    onClicked: root.brightnessPercent = modelData
                }
            }
        }
    }
}
