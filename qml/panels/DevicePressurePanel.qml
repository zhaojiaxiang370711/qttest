pragma ComponentBehavior: Bound
import QtQuick
import QxznHmi

// 压力通道面板。移植自 device_page.gd _draw_pressure_panel / _draw_pressure_card。
// 面板框 Rect2(236,122,808,520)@1280 x1.5 -> 页面局部 (306,33,1212,780)。
// 面板内部坐标/字号为 Godot 原始值（未缩放），字号经 Theme.fontPx 取等值。
// 通道定义照抄 PRESSURE_CHANNELS（0x14E 头 x3、0x14D 下巴/手 x3、0x14C 腰 x3）；
// 数值为静态代表值（Godot 初始读数为 0.0，此处按任务要求给静态值）。
Item {
    id: root
    visible: AppState.overlayPanel === "pressure"

    // Qt.colorAlpha 过不了 qmllint（Qt 全局对象类型信息缺失），用 Qt.rgba 实现。
    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    // Godot PRESSURE_CHANNELS + 静态代表值（_format_pressure: <100 保留 1 位小数）。
    readonly property var channels: [
        { "can": "0x14E", "label": "头左", "value": "12.4" },
        { "can": "0x14E", "label": "头中", "value": "9.8" },
        { "can": "0x14E", "label": "头右", "value": "15.1" },
        { "can": "0x14D", "label": "下巴", "value": "6.3" },
        { "can": "0x14D", "label": "左手", "value": "22.7" },
        { "can": "0x14D", "label": "右手", "value": "18.9" },
        { "can": "0x14C", "label": "腰左", "value": "11.2" },
        { "can": "0x14C", "label": "腰中", "value": "8.5" },
        { "can": "0x14C", "label": "腰右", "value": "13.6" }
    ]

    function notPorted(name) {
        AppState.showCallout("info", "未移植", name + "将在后续阶段移植");
    }

    FontMetrics { id: fm28; font.family: Theme.bodyFamily; font.pixelSize: Theme.fontPx(18) }
    FontMetrics { id: fm22; font.family: Theme.bodyFamily; font.pixelSize: Theme.fontPx(14) }
    FontMetrics { id: fm14; font.family: Theme.bodyFamily; font.pixelSize: Theme.fontTiny }
    FontMetrics { id: fm11; font.family: Theme.bodyFamily; font.pixelSize: Theme.fontPx(7) }

    // 遮罩：Godot Rect2(32,100,1216,588)@1280 x1.5 = 整页，Color(0,0,0,0.46)。
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.46)
        TapHandler { onTapped: AppState.closeOverlay() }
    }

    HmiCard {
        id: panel
        x: 306
        y: 33
        width: 1212
        height: 780
        radius: Theme.radiusCardInner          // Godot 24，取最近 token 22
        fillColor: root.alpha(Theme.panel, 0.94)
        TapHandler {}

        // 头部 _draw_panel_shell("压力通道", pressure, HMI_PRIMARY)
        Rectangle {
            x: 24
            y: 20
            width: 42
            height: 42
            radius: Theme.radiusTab
            color: root.alpha(Theme.primary, 0.17)
            HmiIcon {
                name: "activity"
                tone: "cyan"
                size: 28
                anchors.centerIn: parent
            }
        }
        Text {
            x: 82
            y: 46 - fm22.ascent
            text: "压力通道"
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

        // body: (28,98,1156,654)；3 列 gap 12，卡宽 (1156-24)/3=377.33，卡高 86。
        Item {
            id: body
            x: 28
            y: 98
            width: panel.width - 56
            height: panel.height - 126

            Repeater {
                model: root.channels
                delegate: HmiInset {
                    id: cell
                    required property int index
                    required property var modelData
                    readonly property int col: index % 3
                    readonly property int row: Math.floor(index / 3)

                    x: col * (377.33 + 12)
                    y: row * (86 + 12)
                    width: 377.33
                    height: 86
                    radius: Theme.radiusTab              // Godot 18，取最近 token 18
                    fillColor: Qt.rgba(0, 0, 0, 0.18)    // Godot 源值

                    Text {  // 标签基线 (18,24)，原始 15 -> 14
                        x: 18
                        y: 24 - fm14.ascent
                        text: cell.modelData.label
                        color: Theme.muted
                        font.pixelSize: Theme.fontTiny
                    }
                    Text {  // 数值基线 (18,62)，原始 28 = fontPx(18)
                        x: 18
                        y: 62 - fm28.ascent
                        width: cell.width - 36
                        text: cell.modelData.value
                        color: Theme.primary
                        font.pixelSize: Theme.fontPx(18)
                        elide: Text.ElideRight
                    }
                    Text {  // CAN id：Godot rect.end-(72,16) 基线，原始 10 -> fontPx(7)=11
                        x: cell.width - 72
                        y: cell.height - 16 - fm11.ascent
                        text: cell.modelData.can
                        color: Theme.mutedSoft
                        font.pixelSize: Theme.fontPx(7)
                    }
                }
            }

            Rectangle {  // "刷新设备状态" (0,body.h-50,body.w,48)：primary 面板按钮
                id: refreshBtn
                x: 0
                y: body.height - 50
                width: body.width
                height: 48
                radius: Theme.radiusButton
                color: root.alpha(Theme.primary, 0.10)
                border.width: 1
                border.color: root.alpha(Theme.primary, 0.28)
                Text {
                    anchors.centerIn: parent
                    text: "刷新设备状态"
                    color: Theme.primary
                    font.pixelSize: Theme.fontTiny
                }
                ClickFlash { id: refreshFlash; radius: refreshBtn.radius; flashColor: Theme.primary }
                TapHandler {
                    onTapped: {
                        refreshFlash.flash();
                        root.notPorted("刷新设备状态");
                    }
                }
            }
        }
    }
}
