pragma ComponentBehavior: Bound
import QtQuick
import QxznHmi

// 战力测试页 (combat)。移植自 scripts/pages/combat_power_page.gd（1280x720 基准，
// 运行时 x1.5）。页面局部坐标 = Godot 屏幕坐标 - (48,150)，代码中用
// Theme.px(base) - 48 / -150 标注源值。
// 静态种子：combat_power_model.gd 初始态 selected_mode="speed"、score=0（显示
// "000"，pad_zeros(3)）、active/loading/ended=false、message=""。
// 所有按钮动作统一走未移植 callout（硬件运行时后续阶段接入）。
Item {
    id: page

    // Godot 初始选中模式 seed：selected_mode="speed"。
    readonly property string seedMode: "speed"

    function modeColor(modeId) {
        if (modeId === "reaction")
            return Theme.warn;
        if (modeId === "power")
            return Theme.danger;
        return Theme.primary;
    }

    // 模式图标：Godot draw_symbol_icon 的 combat/agility/impact 自定义符号，
    // 用 Lucide swords/zap/target 对应。
    function modeIcon(modeId) {
        if (modeId === "reaction")
            return "zap";
        if (modeId === "power")
            return "target";
        return "swords";
    }

    function notPorted() {
        AppState.showCallout("info", "未移植", "战力测试需要硬件运行时，后续阶段接入");
    }

    // Qt.colorAlpha 过不了 qmllint（Qt 全局对象类型信息缺失），用 Qt.rgba 实现。
    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    // ---- header: Godot header_y=126，图标中心 (78,124)，标题基线 (104,131) ----
    // Godot 自绘拳击手套图标（4 个图元，约 34x42@1280），用 Lucide hand-fist 替代。
    HmiIcon {
        name: "hand-fist"
        tone: "red"
        size: Theme.px(34)    // 51
        x: Theme.px(78) - 48 - width / 2
        y: Theme.px(128) - 150 - height / 2
    }

    Text {
        id: headerTitle
        x: Theme.px(104) - 48                       // 108
        y: Theme.px(131) - 150 - headerMetrics.ascent   // Godot 基线 y=131@1280
        text: "战斗力评估中心"
        color: Theme.text
        font.pixelSize: Theme.fontPx(34)            // 53
    }
    FontMetrics {
        id: headerMetrics
        font: headerTitle.font
    }

    // 状态 pill: Rect2(1030, 115, 170, 44)@1280，idle -> "设备待命" muted。
    HmiInset {
        id: statusPill
        x: Theme.px(1030) - 48
        y: Theme.px(115) - 150
        width: Theme.px(170)                        // 255
        height: Theme.px(44)                        // 66
        radius: Theme.radiusPill                    // Godot 圆角 h/2=22@1280(=33)，取最近 token
        fillColor: page.alpha(Theme.windowBackground, 0.34)  // Godot Color(0,0,0,0.34)

        readonly property color statusColor: Theme.muted

        // 状态灯：外圆 r7.5@1280(alpha 0.40) + 内圆 r5.2@1280，中心 (x+28, 中)。
        Rectangle {
            width: 22; height: 22; radius: 11       // r7.5 x1.5 = 11.25
            x: Theme.px(28) - width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: page.alpha(statusPill.statusColor, 0.40)
        }
        Rectangle {
            width: 16; height: 16; radius: 8        // r5.2 x1.5 = 7.8
            x: Theme.px(28) - width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: statusPill.statusColor
        }
        Text {
            x: Theme.px(44)                          // Godot 文本区 (x+44, w-54)
            width: Theme.px(116)
            height: parent.height
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: "设备待命"
            color: statusPill.statusColor
            font.pixelSize: Theme.fontPx(16)         // 25
        }
    }

    // ---- 大分数卡: Rect2(56, 176, 1168, 252)@1280，半径 22@1280 ----
    HmiCard {
        id: scoreCard
        x: Theme.px(56) - 48                         // 36
        y: Theme.px(176) - 150                       // 114
        width: Theme.px(1168)                        // 1752
        height: Theme.px(252)                        // 378
        radius: Theme.radiusCard                     // Godot 22@1280(=33)，取最近 token
        // Godot 源值 Color(0.025,0.048,0.105,0.82) 深蓝，Theme 无对应 token。
        fillColor: Qt.rgba(0.025, 0.048, 0.105, 0.82)

        // 标签行: Rect2(card.x, card.y+66, w, 30)，seed：speed 模式 -> "实时数据 (次)"。
        Text {
            x: 0
            y: Theme.px(66)                          // 99
            width: scoreCard.width
            height: Theme.px(30)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: "实时数据 (次)"
            color: Theme.muted
            font.pixelSize: Theme.fontPx(20)         // 31
        }
        // 分数: Rect2(card.x, card.y+108, w, 84)，Godot 字号 88；seed score=0 -> "000"。
        Text {
            x: 0
            y: Theme.px(108)                         // 162
            width: scoreCard.width
            height: Theme.px(84)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: "000"
            color: Theme.primary
            font.pixelSize: Theme.fontHuge           // 137 = Godot 88
        }
        // idle 状态无结果行/校准条/倒计时（ended/active/message 均为空）。
    }

    // ---- 动作按钮: Rect2(56,448,570,68) 与 Rect2(654,448,570,68)@1280，半径 18@1280 ----
    // 开始（idle=enabled）：HMI_PRIMARY alpha 0.84 填充 + 白 0.18 描边。
    Rectangle {
        id: startButton
        x: Theme.px(56) - 48
        y: Theme.px(448) - 150                       // 522
        width: Theme.px(570)                         // 855
        height: Theme.px(68)                         // 102
        radius: Theme.radiusCard                     // Godot 18@1280(=27)，取最近 token
        color: page.alpha(Theme.primary, 0.84)
        border.width: 1
        border.color: page.alpha(Theme.text, 0.18)

        Text {
            anchors.centerIn: parent
            text: "▶  开始测试"
            color: Theme.text
            font.pixelSize: Theme.fontPx(23)         // 36
        }
        ClickFlash {
            id: startFlash
            radius: startButton.radius
            flashColor: Theme.primary
        }
        TapHandler {
            onTapped: {
                startFlash.flash();
                page.notPorted();
            }
        }
    }

    // 结束（idle=disabled）：深色 inset + muted 文本。
    HmiInset {
        id: stopButton
        x: Theme.px(654) - 48                        // 933
        y: Theme.px(448) - 150
        width: Theme.px(570)
        height: Theme.px(68)
        radius: Theme.radiusCard                     // Godot 18@1280(=27)
        // Godot 源值 Color(0.012,0.027,0.060,0.82) 深蓝 inset，Theme 无对应 token。
        fillColor: Qt.rgba(0.012, 0.027, 0.060, 0.82)

        Text {
            anchors.centerIn: parent
            text: "■  结束测试"
            color: page.alpha(Theme.muted, 0.72)
            font.pixelSize: Theme.fontPx(22)         // 34
        }
        ClickFlash {
            id: stopFlash
            radius: stopButton.radius
            flashColor: Theme.danger
        }
        TapHandler {
            onTapped: {
                stopFlash.flash();
                page.notPorted();
            }
        }
    }

    // ---- 三模式卡: y=536，h=88，w=(1168-40)/3=376，gap=20 @1280；半径 16@1280 ----
    Repeater {
        model: ShellData.combatModes
        delegate: HmiCard {
            id: modeCard
            required property int index
            required property var modelData

            readonly property bool active: page.seedMode === modelData.id
            readonly property color cardColor: modelData.color

            x: Theme.px(56 + index * (376 + 20)) - 48    // 36 / 630 / 1224
            y: Theme.px(536) - 150                        // 654
            width: Theme.px(376)                          // 564
            height: Theme.px(88)                          // 132
            radius: Theme.radiusCardInner                 // Godot 16@1280(=24)，取最近 token
            // Godot 填充 HMI_PANEL alpha active 0.68 / 非 active 0.48。
            fillColor: page.alpha(Theme.panel, active ? 0.68 : 0.48)

            // 选中边框：rect.grow(-1) + 模式色 alpha 0.76，线宽 1.8@1280。
            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                visible: modeCard.active
                radius: Theme.radiusCardInner - 2
                color: "transparent"
                border.width: 2
                border.color: page.alpha(modeCard.cardColor, 0.76)
            }
            // 选中圆点：rect.end - (23, h-22) @1280，r5.5，恒 HMI_PRIMARY。
            Rectangle {
                visible: modeCard.active
                width: 16; height: 16; radius: 8          // r5.5 x1.5 = 8.25
                x: Theme.px(376 - 23) - width / 2         // 中心 x=353@1280
                y: Theme.px(22) - height / 2              // 中心 y=22@1280
                color: Theme.primary
            }
            HmiIcon {
                name: page.modeIcon(modeCard.modelData.id)
                tone: modeCard.active ? modeCard.modelData.tone : "muted"
                size: Theme.px(34)                        // 图标 34@1280 -> 51
                x: (modeCard.width - width) / 2           // 中心 x = w/2
                y: Theme.px(28) - height / 2              // 中心 y=28@1280
            }
            Text {
                x: Theme.px(18)
                y: Theme.px(46)                           // 69
                width: modeCard.width - Theme.px(36)
                height: Theme.px(30)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: modeCard.modelData.title
                color: modeCard.active ? Theme.text : Theme.muted
                font.pixelSize: Theme.fontTitle           // Godot 19 -> 30
            }
            ClickFlash {
                id: modeFlash
                radius: modeCard.radius
                flashColor: modeCard.cardColor
            }
            TapHandler {
                onTapped: {
                    modeFlash.flash();
                    page.notPorted();
                }
            }
        }
    }

    // ---- 说明条: Rect2(56, 642, 1168, 46)@1280，半径 17@1280 ----
    HmiCard {
        id: instructionBar
        x: Theme.px(56) - 48
        y: Theme.px(642) - 150                       // 813
        width: Theme.px(1168)
        height: Theme.px(46)                         // 69
        radius: Theme.radiusCard                     // Godot 17@1280(=25.5)，取最近 token
        fillColor: page.alpha(Theme.panel, 0.64)  // Godot HMI_PANEL alpha 0.64

        // 模式图标：中心 (x+42, 中)，23@1280，speed -> swords cyan。
        HmiIcon {
            name: page.modeIcon(page.seedMode)
            tone: "cyan"
            size: Theme.px(23)                       // 34
            x: Theme.px(42) - width / 2
            anchors.verticalCenter: parent.verticalCenter
        }
        // 文本基线 y = rect.y+29 = 671@1280 -> 局部 856.5 -> 条内 43.5。
        // seed 为 speed 模式文案（reaction/power 文案见 Godot 源 _instruction_*）。
        FontMetrics {
            id: insMetrics
            font.family: Theme.bodyFamily
            font.pixelSize: Theme.fontPx(16)
        }
        Text {
            x: Theme.px(64)                          // Godot x = rect.x+30+34 = 120@1280
            y: 43.5 - insMetrics.ascent
            text: "拳速测试"
            color: Theme.primary
            font.pixelSize: Theme.fontPx(16)
        }
        Text {
            x: Theme.px(64 + 92)                     // Godot 固定步进 +92
            y: 43.5 - insMetrics.ascent
            text: "快速连续击打"
            color: Theme.text
            font.pixelSize: Theme.fontPx(16)
        }
        Text {
            x: Theme.px(64 + 92 + 110)               // +110
            y: 43.5 - insMetrics.ascent
            text: "头部中间"
            color: Theme.danger
            font.pixelSize: Theme.fontPx(16)
        }
        Text {
            x: Theme.px(64 + 92 + 110 + 80)          // +80
            y: 43.5 - insMetrics.ascent
            text: "限时10秒。"
            color: Theme.text
            font.pixelSize: Theme.fontPx(16)
        }
        Text {
            x: Theme.px(520)                         // Godot rect.x+520
            y: 43.5 - insMetrics.ascent
            text: "| 测试前5秒校准，请静立。"
            color: Theme.muted
            font.pixelSize: Theme.fontPx(16)
        }
    }
}
