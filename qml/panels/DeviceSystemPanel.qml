pragma ComponentBehavior: Bound
import QtQuick
import QxznHmi

// 系统操作面板。移植自 device_page.gd _draw_system_panel + _draw_confirm_dialog。
// 面板框 Rect2(350,166,580,360)@1280 x1.5 -> 页面局部 (477,99,870,540)。
// 面板内部坐标/字号为 Godot 原始值（未缩放），字号经 Theme.fontPx 取等值。
// 按任务要求：重启/关机先弹确认对话框（复刻 Godot 确认框 Rect2(390,214,500,292)
// @1280 的布局），确认动作 -> 未移植 callout（硬件动作后续阶段接入）。
Item {
    id: root
    visible: AppState.overlayPanel === "system"

    // Qt.colorAlpha 过不了 qmllint（Qt 全局对象类型信息缺失），用 Qt.rgba 实现。
    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    // ""/reboot/shutdown：确认对话框状态（Godot confirm_action）。
    property string confirmAction: ""
    readonly property color confirmTint: confirmAction === "shutdown" ? Theme.danger : Theme.warn

    function notPorted(name) {
        AppState.showCallout("info", "未移植", name + "将在后续阶段移植");
    }

    FontMetrics { id: fm22; font.family: Theme.bodyFamily; font.pixelSize: Theme.fontPx(14) }
    FontMetrics { id: fm16; font.family: Theme.bodyFamily; font.pixelSize: Theme.fontPx(10) }
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
        x: 477
        y: 99
        width: 870
        height: 540
        radius: Theme.radiusCardInner          // Godot 24，取最近 token 22
        fillColor: root.alpha(Theme.panel, 0.94)
        TapHandler {}

        // 头部 _draw_panel_shell("系统操作", system_management, HMI_PURPLE==danger)
        Rectangle {
            x: 24
            y: 20
            width: 42
            height: 42
            radius: Theme.radiusTab
            color: root.alpha(Theme.purple, 0.17)
            HmiIcon {
                name: "power"
                tone: "red"
                size: 28
                anchors.centerIn: parent
            }
        }
        Text {
            x: 82
            y: 46 - fm22.ascent
            text: "系统操作"
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

        // body: (28,98,814,414)
        Item {
            id: body
            x: 28
            y: 98
            width: panel.width - 56
            height: panel.height - 126

            Text {  // wrapped (20,4,w-40,44)，原始 14，muted，最多 2 行
                x: 20
                y: 4
                width: body.width - 40
                height: 44
                text: "系统操作会直接发送到 Web 后端或本机服务"
                color: Theme.muted
                font.pixelSize: Theme.fontTiny
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            PanelBtn {  // "立即息屏" (20,66,w-40,54) wide
                x: 20
                y: 66
                width: body.width - 40
                height: 54
                text: "立即息屏"
                tint: Theme.cyan
                wide: true
                onClicked: root.notPorted("立即息屏")
            }
            PanelBtn {  // "重启" (20,138,(w-56)/2,64) wide
                x: 20
                y: 138
                width: (body.width - 56) * 0.5
                height: 64
                text: "重启"
                tint: Theme.warn
                wide: true
                onClicked: root.confirmAction = "reboot"
            }
            PanelBtn {  // "关机" (36+(w-56)/2,138,(w-56)/2,64) danger+wide
                x: 36 + (body.width - 56) * 0.5
                y: 138
                width: (body.width - 56) * 0.5
                height: 64
                text: "关机"
                tint: Theme.danger
                danger: true
                wide: true
                onClicked: root.confirmAction = "shutdown"
            }
        }
    }

    // ---- 确认对话框（Godot _draw_confirm_dialog：遮罩 Color(0,0,0,0.42)，
    //       框 Rect2(390,214,500,292)@1280 x1.5 -> 页面局部 (537,171,750,438)）----
    Rectangle {
        anchors.fill: parent
        visible: root.confirmAction !== ""
        color: Qt.rgba(0, 0, 0, 0.42)
        TapHandler {}  // Godot 点确认框外部不关闭，仅吞噬
    }
    HmiCard {
        id: confirmCard
        visible: root.confirmAction !== ""
        x: 537
        y: 171
        width: 750
        height: 438
        radius: Theme.radiusCardInner          // Godot 24，取最近 token 22
        fillColor: root.alpha(Theme.panel, 0.97)
        TapHandler {}

        Rectangle {  // Godot 警告描边 tint alpha 0.35
            anchors.fill: parent
            radius: confirmCard.radius
            color: "transparent"
            border.width: 1
            border.color: root.alpha(root.confirmTint, 0.35)
        }
        Rectangle {  // 图标盒 (28,26,48,48) r14
            x: 28
            y: 26
            width: 48
            height: 48
            radius: Theme.radiusTab            // Godot 14，取最近 token 18
            color: root.alpha(root.confirmTint, 0.16)
            HmiIcon {  // Godot 自绘符号 30，取 power
                name: "power"
                tone: root.confirmAction === "shutdown" ? "red" : "yellow"
                size: 30
                anchors.centerIn: parent
            }
        }
        Text {  // 标题基线 (94,56)，原始 22 = fontPx(14)
            x: 94
            y: 56 - fm22.ascent
            text: root.confirmAction === "shutdown" ? "确认关机" : "确认重启"
            color: Theme.text
            font.pixelSize: Theme.fontPx(14)
        }
        Text {  // wrapped (32,104,w-64,86)，原始 14，muted，最多 3 行
            x: 32
            y: 104
            width: confirmCard.width - 64
            height: 86
            text: root.confirmAction === "shutdown"
                  ? "系统将立即关机，正在进行的训练和未保存的数据会中断。请确认后再继续。"
                  : "系统将立即重启设备，正在进行的训练和未保存的数据会中断。请确认后再继续。"
            color: Theme.muted
            font.pixelSize: Theme.fontTiny
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
        }
        Rectangle {  // 取消 (32,214,198,52)：muted alpha 0.12/0.28，彩色字，原始字号 16
            id: cancelBtn
            x: 32
            y: 214
            width: 198
            height: 52
            radius: Theme.radiusButton
            color: root.alpha(Theme.muted, 0.12)
            border.width: 1
            border.color: root.alpha(Theme.muted, 0.28)
            Text {
                anchors.centerIn: parent
                text: "取消"
                color: Theme.muted
                font.pixelSize: Theme.fontPx(10)   // 原始 16
            }
            ClickFlash { id: cancelFlash; radius: cancelBtn.radius; flashColor: Theme.muted }
            TapHandler {
                onTapped: {
                    cancelFlash.flash();
                    root.confirmAction = "";
                }
            }
        }
        Rectangle {  // 确认 (270,214,198,52)：tint 0.24/0.56 白字，原始字号 16
            id: acceptBtn
            x: 270
            y: 214
            width: 198
            height: 52
            radius: Theme.radiusButton
            color: root.alpha(root.confirmTint, 0.24)
            border.width: 1
            border.color: root.alpha(root.confirmTint, 0.56)
            Text {
                anchors.centerIn: parent
                text: root.confirmAction === "shutdown" ? "确认关机" : "确认重启"
                color: Theme.text
                font.pixelSize: Theme.fontPx(10)   // 原始 16
            }
            ClickFlash { id: acceptFlash; radius: acceptBtn.radius; flashColor: root.confirmTint }
            TapHandler {
                onTapped: {
                    acceptFlash.flash();
                    const name = root.confirmAction === "shutdown" ? "关机" : "重启";
                    root.confirmAction = "";
                    root.notPorted(name);
                }
            }
        }
    }
}
