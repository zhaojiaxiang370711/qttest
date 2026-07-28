pragma ComponentBehavior: Bound
import QtQuick
import QxznHmi

// 自动高度调整面板。移植自 device_page.gd _draw_face_panel /
// _draw_height_control_progress / _draw_height_phase_progress。
// 面板框 Rect2(278,156,724,388)@1280 x1.5 -> 页面局部 (369,84,1086,582)。
// 面板内部坐标/字号为 Godot 原始值（未缩放），字号经 Theme.fontPx 取等值。
// 种子：height_inflight=false、status 空 -> idle：阶段 "等待开始"、值 "待开始"
// (HMI_WARN)、三段进度 0、message 回退 "等待高度控制状态"。
Item {
    id: root
    visible: AppState.overlayPanel === "face"

    // Qt.colorAlpha 过不了 qmllint（Qt 全局对象类型信息缺失），用 Qt.rgba 实现。
    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    // idle 静态种子（Godot height_control_status 空 -> progress 0）。
    readonly property real phaseProgress: 0.0
    readonly property color phaseColor: Theme.warn   // idle -> HMI_WARN

    function notPorted(name) {
        AppState.showCallout("info", "未移植", name + "将在后续阶段移植");
    }

    FontMetrics { id: fm22; font.family: Theme.bodyFamily; font.pixelSize: Theme.fontPx(14) }
    FontMetrics { id: fm20; font.family: Theme.bodyFamily; font.pixelSize: Theme.fontPx(13) }
    FontMetrics { id: fm19; font.family: Theme.bodyFamily; font.pixelSize: Theme.fontPx(12) }
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
        x: 369
        y: 84
        width: 1086
        height: 582
        radius: Theme.radiusCardInner          // Godot 24，取最近 token 22
        fillColor: root.alpha(Theme.panel, 0.94)
        TapHandler {}

        // 头部 _draw_panel_shell("自动高度调整", face, HMI_WARN)
        Rectangle {
            x: 24
            y: 20
            width: 42
            height: 42
            radius: Theme.radiusTab
            color: root.alpha(Theme.warn, 0.17)
            HmiIcon {
                name: "user"
                tone: "yellow"
                size: 28
                anchors.centerIn: parent
            }
        }
        Text {
            x: 82
            y: 46 - fm22.ascent
            text: "自动高度调整"
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

        // body: (28,98,1030,456)
        Item {
            id: body
            x: 28
            y: 98
            width: panel.width - 56
            height: panel.height - 126

            Rectangle {  // "开始自动高度调整" (0,0,body.w,56)：success wide 面板按钮
                id: startBtn
                x: 0
                y: 0
                width: body.width
                height: 56
                radius: Theme.radiusButton
                color: root.alpha(Theme.success, 0.10)
                border.width: 1
                border.color: root.alpha(Theme.success, 0.28)
                Text {
                    anchors.centerIn: parent
                    text: "开始自动高度调整"
                    color: Theme.text
                    font.pixelSize: Theme.fontTiny
                }
                ClickFlash { id: startFlash; radius: startBtn.radius; flashColor: Theme.success }
                TapHandler {
                    onTapped: {
                        startFlash.flash();
                        root.notPorted("开始自动高度调整");
                    }
                }
            }

            // 进度 inset: Godot Rect2(0,88,body.w,142) r18，Color(0,0,0,0.18)
            HmiInset {
                id: progressBox
                x: 0
                y: 88
                width: body.width
                height: 142
                radius: Theme.radiusTab              // Godot 18，取 token 18
                fillColor: Qt.rgba(0, 0, 0, 0.18)

                Text {  // "调整进度" 基线 (18,28)，原始 14
                    x: 18
                    y: 28 - fm14.ascent
                    text: "调整进度"
                    color: Theme.muted
                    font.pixelSize: Theme.fontTiny
                }
                Text {  // 阶段标签基线 (18,56)，原始 20 = fontPx(13)，fit 240
                    x: 18
                    y: 56 - fm20.ascent
                    width: 240
                    text: "等待开始"
                    color: Theme.text
                    font.pixelSize: Theme.fontPx(13)
                    elide: Text.ElideRight
                }
                Text {  // 值标签基线 (w-130,56)，原始 19 = fontPx(12)，fit 112
                    x: progressBox.width - 130
                    y: 56 - fm19.ascent
                    width: 112
                    text: "待开始"
                    color: root.phaseColor
                    font.pixelSize: Theme.fontPx(12)
                    elide: Text.ElideRight
                }

                // 三段进度条: Godot Rect2(18,78,w-36,8)，gap 7，seg_w=(994-14)/3=326.67
                Repeater {
                    model: 3
                    delegate: Rectangle {
                        id: seg
                        required property int index
                        // 每段填充比例：clamp((pct - i/3) / (1/3), 0, 1)
                        readonly property real segPct: Math.max(0, Math.min(1, root.phaseProgress * 3 - index))
                        x: 18 + index * (326.67 + 7)
                        y: 78
                        width: 326.67
                        height: 8
                        radius: Theme.radiusPill       // 钳制为 h/2=4，等同 Godot r4
                        color: Qt.rgba(1, 1, 1, 0.18)  // Godot 源值
                        Rectangle {
                            width: seg.width * seg.segPct
                            height: seg.height
                            visible: seg.segPct > 0
                            radius: seg.radius
                            color: root.alpha(root.phaseColor, 0.94)
                        }
                    }
                }

                Text {  // message 基线区 (18,102,w-36,24)，原始 11 = fontPx(7)，1 行
                    x: 18
                    y: 102
                    width: progressBox.width - 36
                    height: 24
                    text: "等待高度控制状态"
                    color: Theme.muted
                    font.pixelSize: Theme.fontPx(7)
                    elide: Text.ElideRight
                }
            }
        }
    }
}
