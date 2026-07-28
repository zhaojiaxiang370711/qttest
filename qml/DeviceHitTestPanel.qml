pragma ComponentBehavior: Bound
import QtQuick
import QxznHmi

// 击打测试面板（简化静态）。移植自 device_page.gd _draw_hit_test_panel。
// 面板框 Rect2(318,138,644,456)@1280 x1.5 -> 页面局部 (429,57,966,684)。
// 面板内部坐标/字号为 Godot 原始值（未缩放），字号经 Theme.fontPx 取等值。
// 种子：hit 未激活、未标定 -> "等待开始"/muted，score=0，mode="test"。
Item {
    id: root
    visible: AppState.overlayPanel === "hit_test"

    // Qt.colorAlpha 过不了 qmllint（Qt 全局对象类型信息缺失），用 Qt.rgba 实现。
    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    function notPorted(name) {
        AppState.showCallout("info", "未移植", name + "将在后续阶段移植");
    }

    function ddsStateLabel(state) {
        if (state === "ready")
            return "DDS 已就绪";
        if (state === "receiving")
            return "DDS 接收中";
        if (state === "loading")
            return "DDS 初始化";
        if (state === "error")
            return "DDS 错误";
        return "离线模式";
    }

    function ddsStateColor(state) {
        if (state === "ready" || state === "receiving")
            return Theme.success;
        if (state === "loading")
            return Theme.warn;
        if (state === "error")
            return Theme.danger;
        return Theme.muted;
    }

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

    // 遮罩：Godot Rect2(32,100,1216,588)@1280 x1.5 = 整页，Color(0,0,0,0.46)。
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.46)
        TapHandler { onTapped: AppState.closeOverlay() }
    }

    HmiCard {
        id: panel
        x: 429
        y: 57
        width: 966
        height: 684
        radius: Theme.radiusCardInner          // Godot 24，取最近 token 22
        fillColor: root.alpha(Theme.panel, 0.94)
        TapHandler {}

        // 头部 _draw_panel_shell("击打测试", hit_test, HMI_DANGER)
        Rectangle {
            x: 24
            y: 20
            width: 42
            height: 42
            radius: Theme.radiusTab
            color: root.alpha(Theme.danger, 0.17)
            HmiIcon {
                name: "target"
                tone: "red"
                size: 28
                anchors.centerIn: parent
            }
        }
        Text {
            x: 82
            y: 46 - fm22.ascent
            text: "击打测试"
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

        // body: (28,98,910,558)
        Item {
            id: body
            x: 28
            y: 98
            width: panel.width - 56
            height: panel.height - 126

            StatusChip {
                x: 0
                y: 0
                width: 180
                height: 58
                label: "DDS 状态"
                value: root.ddsStateLabel(DdsBridge.state)
                valueColor: root.ddsStateColor(DdsBridge.state)
            }
            StatusChip {
                x: 198
                y: 0
                width: 180
                height: 58
                label: "最近部位"
                value: SessionModel.lastSegment.length > 0 ? SessionModel.lastSegment : "暂无"
                valueColor: SessionModel.lastSegment.length > 0 ? Theme.primary : Theme.muted
            }
            PanelBtn {  // 刷新状态 (body.w-172,5,172,48)
                x: body.width - 172
                y: 5
                width: 172
                height: 48
                text: "刷新状态"
                tint: Theme.primary
                onClicked: root.notPorted("刷新状态")
            }

            Text {  // 大分数 Rect2(0,86,body.w,92) 居中，原始 72 = fontPx(46)
                x: 0
                y: 86
                width: body.width
                height: 92
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: String(SessionModel.strikes)
                color: Theme.danger
                font.pixelSize: Theme.fontPx(46)
            }
            Text {  // "击打计数" Rect2(0,164,body.w,28) 居中，原始 16 = fontPx(10)
                x: 0
                y: 164
                width: body.width
                height: 28
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: "击打计数"
                color: Theme.muted
                font.pixelSize: Theme.fontPx(10)
            }

            PanelBtn {  // 开始游戏 (72,220,220,62) wide
                x: 72
                y: 220
                width: 220
                height: 62
                text: "开始游戏"
                tint: Theme.success
                wide: true
                onClicked: root.notPorted("开始游戏")
            }
            PanelBtn {  // 结束游戏 (318,220,220,62) danger+wide
                x: 318
                y: 220
                width: 220
                height: 62
                text: "结束游戏"
                tint: Theme.danger
                danger: true
                wide: true
                onClicked: root.notPorted("结束游戏")
            }

            // 说明条 (48,314,body.w-96,58) r16
            HmiInset {
                id: guide
                x: 48
                y: 314
                width: body.width - 96
                height: 58
                radius: Theme.radiusTab          // Godot 16，取最近 token 18
                fillColor: Qt.rgba(0, 0, 0, 0.16)
                Text {  // Godot guide.grow(-14) 内 wrapped，原始 13 -> 14，2 行
                    x: 14
                    y: 14
                    width: guide.width - 28
                    height: guide.height - 28
                    text: "键盘与 DDS 击打都会计数；灯带仅由游戏或页面显式发送命令。"
                    color: Theme.muted
                    font.pixelSize: Theme.fontTiny
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }
        }
    }
}
