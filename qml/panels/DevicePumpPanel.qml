pragma ComponentBehavior: Bound
import QtQuick
import QxznHmi

// 气泵控制面板（简化静态）。移植自 device_page.gd _draw_pump_control_panel。
// 面板框 Rect2(206,116,868,528)@1280 x1.5 -> 页面局部 (261,24,1302,792)。
// 面板内部坐标/字号为 Godot 原始值（未缩放），字号经 Theme.fontPx 取等值。
// 种子：pump_running=false、current=0、target=SAFE_PUMP_TARGET=2600、auto=off。
Item {
    id: root
    visible: AppState.overlayPanel === "pump_control"

    // Qt.colorAlpha 过不了 qmllint（Qt 全局对象类型信息缺失），用 Qt.rgba 实现。
    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    property int pumpTarget: 2600

    function notPorted(name) {
        AppState.showCallout("info", "未移植", name + "将在后续阶段移植");
    }

    FontMetrics { id: fm42; font.family: Theme.bodyFamily; font.pixelSize: Theme.fontPx(27) }
    FontMetrics { id: fm34; font.family: Theme.bodyFamily; font.pixelSize: Theme.fontPx(22) }
    FontMetrics { id: fm22; font.family: Theme.bodyFamily; font.pixelSize: Theme.fontPx(14) }
    FontMetrics { id: fm17; font.family: Theme.bodyFamily; font.pixelSize: Theme.fontSmall }
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

    // Godot _draw_status_chip：inset r16 Color(0,0,0,0.17)，标签 11、值 18。
    component StatusChip: HmiInset {
        id: chip
        property string label: ""
        property string value: ""
        property color valueColor: Theme.muted
        radius: Theme.radiusTab                  // Godot 16，取最近 token 18
        fillColor: Qt.rgba(0, 0, 0, 0.17)
        Text {
            x: 16
            y: 21 - fm11.ascent
            text: chip.label
            color: Theme.muted
            font.pixelSize: Theme.fontPx(7)      // 原始 11
        }
        Text {
            x: 16
            y: 44 - fm17.ascent
            width: chip.width - 32
            text: chip.value
            color: chip.valueColor
            font.pixelSize: Theme.fontSmall      // 原始 18 -> 17
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
        x: 261
        y: 24
        width: 1302
        height: 792
        radius: Theme.radiusCardInner          // Godot 24，取最近 token 22
        fillColor: root.alpha(Theme.panel, 0.94)
        TapHandler {}

        // 头部 _draw_panel_shell("气泵控制", pump_control, HMI_CYAN)
        Rectangle {
            x: 24
            y: 20
            width: 42
            height: 42
            radius: Theme.radiusTab
            color: root.alpha(Theme.cyan, 0.17)
            HmiIcon {
                name: "zap"
                tone: "cyan"
                size: 28
                anchors.centerIn: parent
            }
        }
        Text {
            x: 82
            y: 46 - fm22.ascent
            text: "气泵控制"
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

        // body: (28,98,1246,666)
        Item {
            id: body
            x: 28
            y: 98
            width: panel.width - 56
            height: panel.height - 126

            // 4 状态芯片 (0/194/388/582,0,178,58)
            StatusChip { x: 0;   y: 0; width: 178; height: 58; label: "当前压力"; value: "0 kPa";    valueColor: Theme.cyan }
            StatusChip { x: 194; y: 0; width: 178; height: 58; label: "目标压力"; value: "2600 kPa"; valueColor: Theme.warn }
            StatusChip { x: 388; y: 0; width: 178; height: 58; label: "气泵";     value: "停止";     valueColor: Theme.muted }
            StatusChip { x: 582; y: 0; width: 178; height: 58; label: "自动模式"; value: "已停用";   valueColor: Theme.muted }

            // 保护压力表 (0,86,510,174) r22
            HmiInset {
                id: gauge
                x: 0
                y: 86
                width: 510
                height: 174
                radius: Theme.radiusCardInner      // Godot 22，取 token 22
                fillColor: Qt.rgba(0, 0, 0, 0.18)
                Text {  // 基线 (24,34)，原始 14
                    x: 24
                    y: 34 - fm14.ascent
                    text: "气泵保护压力"
                    color: Theme.muted
                    font.pixelSize: Theme.fontTiny
                }
                Text {  // 基线 (24,88)，原始 42 = fontPx(27)
                    x: 24
                    y: 88 - fm42.ascent
                    width: 210
                    text: "0 kPa"
                    color: Theme.text
                    font.pixelSize: Theme.fontPx(27)
                    elide: Text.ElideRight
                }
                Rectangle {  // 量程条 (248,80,226,18) r9；pct=(0-2000)/600 -> 0，无填充
                    x: 248
                    y: 80
                    width: 226
                    height: 18
                    radius: Theme.radiusPill       // 钳制为 h/2=9
                    color: Theme.cardHighlight
                }
                Text {  // "2000" 基线 (248,120)，原始 11
                    x: 248
                    y: 120 - fm11.ascent
                    text: "2000"
                    color: Theme.muted
                    font.pixelSize: Theme.fontPx(7)
                }
                Text {  // "2600" 基线 (bar.end-36,120)，原始 11
                    x: 248 + 226 - 36
                    y: 120 - fm11.ascent
                    text: "2600"
                    color: Theme.muted
                    font.pixelSize: Theme.fontPx(7)
                }
                Text {  // wrapped (24,122,w-48,34)，原始 12 = fontPx(8)
                    x: 24
                    y: 122
                    width: gauge.width - 48
                    height: 34
                    text: "目标压力限制为 2600 kPa，避免触发后端安全拒绝。"
                    color: Theme.muted
                    font.pixelSize: Theme.fontPx(8)
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }

            // 自动目标 (538,86,708,174) r22
            HmiInset {
                id: side
                x: 538
                y: 86
                width: body.width - 538
                height: 174
                radius: Theme.radiusCardInner
                fillColor: Qt.rgba(0, 0, 0, 0.18)
                Text {  // 基线 (22,32)，原始 14
                    x: 22
                    y: 32 - fm14.ascent
                    text: "自动目标"
                    color: Theme.muted
                    font.pixelSize: Theme.fontTiny
                }
                Text {  // 基线 (22,78)，原始 34 = fontPx(22)
                    x: 22
                    y: 78 - fm34.ascent
                    width: side.width - 44
                    text: root.pumpTarget + " kPa"
                    color: Theme.text
                    font.pixelSize: Theme.fontPx(22)
                    elide: Text.ElideRight
                }
                Repeater {  // 目标预设 (22/100/178/256,112,70,42)
                    model: [2200, 2400, 2500, 2600]
                    delegate: PanelBtn {
                        required property int index
                        required property var modelData
                        x: 22 + index * 78
                        y: 112
                        width: 70
                        height: 42
                        text: String(modelData)
                        tint: Theme.cyan
                        selected: root.pumpTarget === modelData
                        onClicked: root.pumpTarget = modelData
                    }
                }
            }

            // 动作行 y=292（简化：布局同 Godot）
            PanelBtn { x: 0;   y: 292; width: 200; height: 58; text: "开始自动充气"; tint: Theme.success; wide: true; onClicked: root.notPorted("开始自动充气") }
            PanelBtn { x: 216; y: 292; width: 170; height: 58; text: "停止充气"; tint: Theme.danger; danger: true; wide: true; onClicked: root.notPorted("停止充气") }
            PanelBtn { x: 402; y: 292; width: 170; height: 58; text: "手动启动"; tint: Theme.cyan; wide: true; onClicked: root.notPorted("手动启动") }
            PanelBtn { x: 588; y: 292; width: 170; height: 58; text: "手动停止"; tint: Theme.warn; wide: true; onClicked: root.notPorted("手动停止") }

            PanelBtn {  // 刷新气泵状态 (0,body.h-48,body.w,48)
                x: 0
                y: body.height - 48
                width: body.width
                height: 48
                text: "刷新气泵状态"
                tint: Theme.primary
                onClicked: root.notPorted("刷新气泵状态")
            }
        }
    }
}
