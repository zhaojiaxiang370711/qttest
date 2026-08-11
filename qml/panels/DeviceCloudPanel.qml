pragma ComponentBehavior: Bound
import QtQuick
import QxznHmi

// 云端设备绑定面板（简化静态）。移植自 device_page.gd _draw_cloud_pairing_panel。
// 面板框 Rect2(270,120,740,500)@1280 x1.5 -> 页面局部 (357,30,1110,750)。
// 面板内部坐标/字号为 Godot 原始值（未缩放），字号经 Theme.fontPx 取等值。
// 按任务要求显示静态设备码与 6 位配对码（Godot 初值为 "读取中..."/"------"）；
// 状态色取 Godot 有配对码未绑定分支 -> HMI_CYAN。
Item {
    id: root
    visible: AppState.overlayPanel === "cloud_pairing"

    // Qt.colorAlpha 过不了 qmllint（Qt 全局对象类型信息缺失），用 Qt.rgba 实现。
    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    // 静态种子（Godot 从本地 data-service 读取，移植阶段硬编码）。
    readonly property string deviceCode: "QXZN-PD02-0001"
    readonly property string pairingCode: "538421"

    function notPorted(name) {
        AppState.showCallout("info", "未移植", name + "将在后续阶段移植");
    }

    FontMetrics { id: fm30; font.family: Theme.bodyFamily; font.pixelSize: Theme.fontPx(19) }
    FontMetrics { id: fm22; font.family: Theme.bodyFamily; font.pixelSize: Theme.fontPx(14) }
    FontMetrics { id: fm14; font.family: Theme.bodyFamily; font.pixelSize: Theme.fontTiny }
    FontMetrics { id: fm12; font.family: Theme.bodyFamily; font.pixelSize: Theme.fontPx(8) }

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
        x: 357
        y: 30
        width: 1110
        height: 750
        radius: Theme.radiusCardInner          // Godot 24，取最近 token 22
        fillColor: root.alpha(Theme.panel, 0.94)
        TapHandler {}

        // 头部 _draw_panel_shell("云端设备绑定", cloud_pairing, HMI_CYAN)
        Rectangle {
            x: 24
            y: 20
            width: 42
            height: 42
            radius: Theme.radiusTab
            color: root.alpha(Theme.cyan, 0.17)
            HmiIcon {  // Godot 自绘 cloud 符号，资源集无 cloud，取 wifi 代替
                name: "wifi"
                tone: "cyan"
                size: 28
                anchors.centerIn: parent
            }
        }
        Text {
            x: 82
            y: 46 - fm22.ascent
            text: "云端设备绑定"
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

        // body: (28,98,1054,624)
        Item {
            id: body
            x: 28
            y: 98
            width: panel.width - 56
            height: panel.height - 126

            Text {  // 说明 wrapped (0,0,body.w,48)，原始 13 -> 14，2 行
                x: 0
                y: 0
                width: body.width
                height: 48
                text: "在网站登录后进入“我的设备”，输入这里显示的设备码和 6 位配对码即可绑定这台设备。"
                color: Theme.muted
                font.pixelSize: Theme.fontTiny
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            // 设备码 inset (0,62,body.w,76) r18
            HmiInset {
                id: codeBox
                x: 0
                y: 62
                width: body.width
                height: 76
                radius: Theme.radiusTab          // Godot 18，取 token 18
                fillColor: Qt.rgba(0, 0, 0, 0.18)
                Text {  // "设备码" 基线 (20,23)，原始 12 = fontPx(8)
                    x: 20
                    y: 23 - fm12.ascent
                    text: "设备码"
                    color: Theme.muted
                    font.pixelSize: Theme.fontPx(8)
                }
                Text {  // 设备码基线 (20,57)，原始 29 -> fontPx(19)=30
                    x: 20
                    y: 57 - fm30.ascent
                    width: codeBox.width - 40
                    text: root.deviceCode
                    color: Theme.text
                    font.pixelSize: Theme.fontPx(19)
                    elide: Text.ElideRight
                }
            }

            // 配对码 inset (0,156,body.w,112) r22
            HmiInset {
                id: pairingBox
                x: 0
                y: 156
                width: body.width
                height: 112
                radius: Theme.radiusCardInner    // Godot 22，取 token 22
                fillColor: Qt.rgba(0, 0, 0, 0.20)
                Text {  // "6 位配对码" 基线 (22,28)，原始 13 -> 14
                    x: 22
                    y: 28 - fm14.ascent
                    text: "6 位配对码"
                    color: Theme.muted
                    font.pixelSize: Theme.fontTiny
                }
                Text {  // 配对码 Rect2(0,34,w,52) 居中，原始 44 = fontPx(28)；未绑定 -> cyan
                    x: 0
                    y: 34
                    width: pairingBox.width
                    height: 52
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: root.pairingCode
                    color: Theme.cyan
                    font.pixelSize: Theme.fontPx(28)
                }
            }

            // 状态 inset (0,286,body.w,64) r18，cyan alpha 0.10
            HmiInset {
                id: statusBox
                x: 0
                y: 286
                width: body.width
                height: 64
                radius: Theme.radiusTab
                fillColor: root.alpha(Theme.cyan, 0.10)
                Rectangle {  // 状态点：Godot 中心 (24,32) r5
                    width: 10
                    height: 10
                    radius: 5
                    x: 24 - width / 2
                    y: 32 - height / 2
                    color: Theme.cyan
                }
                Text {  // wrapped (42,13,w-62,40)，原始 13 -> 14，2 行
                    x: 42
                    y: 13
                    width: statusBox.width - 62
                    height: 40
                    text: "配对码已生成，请在网站“我的设备”中输入设备码和配对码完成绑定。"
                    color: Theme.text
                    font.pixelSize: Theme.fontTiny
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }
            }

            // 按钮行 y=body.h-54=570
            PanelBtn {  // 刷新设备码 (0,570,162,48)
                x: 0
                y: body.height - 54
                width: 162
                height: 48
                text: "刷新设备码"
                tint: Theme.primary
                onClicked: root.notPorted("刷新设备码")
            }
            PanelBtn {  // 刷新配对码 (178,570,220,48) wide
                x: 178
                y: body.height - 54
                width: 220
                height: 48
                text: "刷新配对码"
                tint: Theme.cyan
                wide: true
                onClicked: root.notPorted("刷新配对码")
            }
            PanelBtn {  // 检查绑定状态 (414,570,body.w-414,48) wide
                x: 414
                y: body.height - 54
                width: body.width - 414
                height: 48
                text: "检查绑定状态"
                tint: Theme.success
                wide: true
                onClicked: root.notPorted("检查绑定状态")
            }
        }
    }
}
