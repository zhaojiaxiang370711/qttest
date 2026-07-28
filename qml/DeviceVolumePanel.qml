pragma ComponentBehavior: Bound
import QtQuick
import QxznHmi

// 音量面板。移植自 device_page.gd _draw_volume_panel。
// 面板框 Rect2(300,138,680,470)@1280 x1.5 -> 页面局部 (402,57,1020,705)。
// 注意：Godot 面板内部坐标与字号未走 _layout_*（_draw_panel_shell 原始值），
// 面板内容按原始像素复刻；字号经 Theme.fontPx 取等值（如原始 44 = fontPx(28)）。
// 种子：ShellData.deviceStatus.volume=1.0、muted=false；预设/静音为面板内本地态。
Item {
    id: root
    visible: AppState.overlayPanel === "volume"

    // Qt.colorAlpha 过不了 qmllint（Qt 全局对象类型信息缺失），用 Qt.rgba 实现。
    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    property int volumePercent: Math.round(ShellData.deviceStatus.volume * 100)  // 100
    property bool mutedState: ShellData.deviceStatus.muted

    function notPorted(name) {
        AppState.showCallout("info", "未移植", name + "将在后续阶段移植");
    }

    FontMetrics { id: fm22; font.family: Theme.bodyFamily; font.pixelSize: Theme.fontPx(14) }
    FontMetrics { id: fm14; font.family: Theme.bodyFamily; font.pixelSize: Theme.fontTiny }

    // Godot 面板按钮 _draw_panel_button：填充 tint alpha 0.10(选中 0.24/危险 0.14)，
    // 描边 0.28(选中 0.54)，半径 15；h>=46 字号 15 否则 13，wide/选中时白字。
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
            font.pixelSize: Theme.fontTiny      // Godot 15/13 -> 14
        }
        ClickFlash { id: pbFlash; radius: pb.radius; flashColor: pb.tint }
        TapHandler { onTapped: { pbFlash.flash(); pb.clicked(); } }
    }

    // 遮罩：Godot Rect2(32,100,1216,588)@1280 x1.5 = 整页，Color(0,0,0,0.46)；点外部关闭。
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.46)
        TapHandler { onTapped: AppState.closeOverlay() }
    }

    HmiCard {
        id: panel
        x: 402
        y: 57
        width: 1020
        height: 705
        radius: Theme.radiusCardInner          // Godot 24（未缩放），取最近 token 22
        fillColor: root.alpha(Theme.panel, 0.94)
        TapHandler {}                          // 吞掉面板区点击，防止穿透到遮罩

        // 头部 _draw_panel_shell("音量面板", volume_settings, HMI_SUCCESS)
        Rectangle {  // 图标盒 (24,20,42,42) r12，tint alpha 0.17
            x: 24
            y: 20
            width: 42
            height: 42
            radius: Theme.radiusTab            // Godot 12，取最近 token 18
            color: root.alpha(Theme.success, 0.17)
            HmiIcon {
                name: "sliders"
                tone: "green"
                size: 28
                anchors.centerIn: parent
            }
        }
        Text {  // 标题基线 (82,46)，原始字号 22 = fontPx(14)
            x: 82
            y: 46 - fm22.ascent
            text: "音量面板"
            color: Theme.text
            font.pixelSize: Theme.fontPx(14)
        }
        Rectangle {  // 关闭按钮 (w-62,21,40,40) r13，danger alpha 0.10 + 描边 0.20
            id: closeBtn
            x: panel.width - 62
            y: 21
            width: 40
            height: 40
            radius: Theme.radiusTab            // Godot 13，取最近 token 18
            color: root.alpha(Theme.danger, 0.10)
            border.width: 1
            border.color: root.alpha(Theme.danger, 0.20)
            Rectangle {  // X：Godot 两条 (13,13)-(27,27) 斜线，宽 2
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
        Rectangle {  // 分隔线 (24,78)-(w-24,78)，Color(1,1,1,0.06)
            x: 24
            y: 78
            width: panel.width - 48
            height: 1
            color: Qt.rgba(1, 1, 1, 0.06)
        }

        // body: Godot panel.pos+(28,98)，size-(56,126) -> (28,98,964,579)
        Item {
            id: body
            x: 28
            y: 98
            width: panel.width - 56
            height: panel.height - 126

            Text {  // 大百分比: Rect2(0,0,w,64) 居中，原始字号 44 = fontPx(28)
                x: 0
                y: 0
                width: body.width
                height: 64
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: root.volumePercent + "%"
                color: root.mutedState ? Theme.muted : Theme.success
                font.pixelSize: Theme.fontPx(28)
            }
            Rectangle {  // 滑条底 (54,88,w-108,14) r7，Color(1,1,1,0.08)=Theme.cardHighlight
                x: 54
                y: 88
                width: body.width - 108
                height: 14
                radius: Theme.radiusPill       // 渲染钳制为 h/2=7，等同 Godot r7
                color: Theme.cardHighlight
            }
            Rectangle {  // 填充 success alpha 0.78
                x: 54
                y: 88
                width: (body.width - 108) * root.volumePercent / 100
                height: 14
                visible: width > 0
                radius: Theme.radiusPill
                color: root.alpha(Theme.success, 0.78)
            }
            Text {  // 基线 (32,135)，原始 15 -> 14；current_audio_label 回退 "默认输出"
                x: 32
                y: 135 - fm14.ascent
                width: body.width - 64
                text: "音频输出: 默认输出"
                color: Theme.text
                font.pixelSize: Theme.fontTiny
                elide: Text.ElideRight
            }
            PanelBtn {  // (32,158,176,42)
                x: 32
                y: 158
                width: 176
                height: 42
                text: "刷新输出"
                tint: Theme.primary
                onClicked: root.notPorted("刷新输出")
            }
            PanelBtn {  // (220,158,176,42)
                x: 220
                y: 158
                width: 176
                height: 42
                text: "切换输出"
                tint: Theme.cyan
                onClicked: root.notPorted("切换输出")
            }
            PanelBtn {  // (408,158,176,42)
                x: 408
                y: 158
                width: 176
                height: 42
                text: root.mutedState ? "取消静音" : "静音"
                tint: Theme.warn
                selected: root.mutedState
                onClicked: root.mutedState = !root.mutedState
            }
            // 预设行 y=226：gap 12，宽 (964-64-48)/5=170.4
            PanelBtn {
                x: 32
                y: 226
                width: 170.4
                height: 44
                text: "0%"
                tint: Theme.success
                selected: root.volumePercent === 0
                onClicked: { root.volumePercent = 0; root.mutedState = true; }
            }
            PanelBtn {
                x: 32 + 182.4
                y: 226
                width: 170.4
                height: 44
                text: "30%"
                tint: Theme.success
                selected: root.volumePercent === 30
                onClicked: { root.volumePercent = 30; root.mutedState = false; }
            }
            PanelBtn {
                x: 32 + 364.8
                y: 226
                width: 170.4
                height: 44
                text: "50%"
                tint: Theme.success
                selected: root.volumePercent === 50
                onClicked: { root.volumePercent = 50; root.mutedState = false; }
            }
            PanelBtn {
                x: 32 + 547.2
                y: 226
                width: 170.4
                height: 44
                text: "80%"
                tint: Theme.success
                selected: root.volumePercent === 80
                onClicked: { root.volumePercent = 80; root.mutedState = false; }
            }
            PanelBtn {
                x: 32 + 729.6
                y: 226
                width: 170.4
                height: 44
                text: "100%"
                tint: Theme.success
                selected: root.volumePercent === 100
                onClicked: { root.volumePercent = 100; root.mutedState = false; }
            }
            PanelBtn {  // (32,302,w-64,48) wide
                x: 32
                y: 302
                width: body.width - 64
                height: 48
                text: "播放测试音"
                tint: Theme.success
                wide: true
                onClicked: root.notPorted("播放测试音")
            }
        }
    }
}
