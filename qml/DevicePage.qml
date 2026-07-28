pragma ComponentBehavior: Bound
import QtQuick
import QxznHmi

// 设备页 (device)。移植自 scripts/pages/device_page.gd（1280x720 基准，运行时
// 坐标 x1.5、字号 x1.56）。页面局部坐标 = Godot 屏幕坐标 - (48,150)。
// 结构：连接状态条 + 设备工具网格（ShellData.deviceCards 13 张，4 列）+ 底部
// 语言/云绑定/气泵条 + 10 个覆盖面板（AppState.overlayPanel == id 时内嵌显示）。
// 种子：ShellData.deviceStatus；气泵取 device_model.gd 初值（待机/0/2600）。
//
// 与 Godot 的既定偏差：
// - Godot 工具网格为 12 卡 3 行；按移植任务改为 13 卡 4 行，网格区矩形保持
//   Godot 源值，卡高由 105 压缩为 73.5，卡内图标/文字紧凑重排。
// - 语言/云绑定按钮：Godot 按钮矩形 x1.5 但按钮内部图标/文字为原始值（源码
//   如此，未走 _layout_*），此处按原样复刻，内容偏上。
Item {
    id: page

    readonly property var devStatus: ShellData.deviceStatus
    // 气泵静态种子（device_model.gd：pump_running=false、current=0、SAFE_PUMP_TARGET=2600）
    readonly property bool pumpRunning: false
    readonly property int pumpCurrent: 0
    readonly property int pumpTarget: 2600

    // Qt.colorAlpha 过不了 qmllint（Qt 全局对象类型信息缺失），用 Qt.rgba 实现。
    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    function notPorted(name) {
        AppState.showCallout("info", "未移植", name + "将在后续阶段移植");
    }

    function ddsStatusValue(state) {
        if (state === "ready")
            return "已就绪";
        if (state === "receiving")
            return "接收中";
        if (state === "loading")
            return "初始化";
        if (state === "error")
            return "错误";
        return "离线模式";
    }

    function ddsStatusColor(state) {
        if (state === "ready" || state === "receiving")
            return Theme.success;
        if (state === "loading")
            return Theme.warn;
        if (state === "error")
            return Theme.danger;
        return Theme.muted;
    }

    function ddsStatusTone(state) {
        if (state === "ready" || state === "receiving")
            return "green";
        if (state === "loading")
            return "yellow";
        if (state === "error")
            return "red";
        return "muted";
    }

    // Godot draw_symbol_icon 自绘符号 -> Lucide 映射（resources/icons/lucide 可用集）。
    function toolIcon(cardId) {
        switch (cardId) {
        case "language_settings": return "user";
        case "pump_start": return "play";
        case "pump_stop": return "pause";
        case "punch_control": return "hand-fist";
        case "system_management": return "power";
        case "pump_control": return "zap";
        case "pressure": return "activity";
        case "face": return "user";
        case "hit_test": return "target";
        case "volume_settings": return "sliders";
        case "sound_test": return "music";
        case "display_settings": return "monitor-play";
        case "dev_tools": return "sliders";
        }
        return "activity";
    }

    // 面板卡 -> 覆盖面板 id（device_page.gd 面板 id）；动作卡 -> 未移植 callout。
    function activateTool(cardId, title) {
        switch (cardId) {
        case "punch_control":
        case "pump_control":
        case "pressure":
        case "face":
        case "hit_test":
        case "dev_tools":
            AppState.openOverlay(cardId);
            break;
        case "system_management":
            AppState.openOverlay("system");
            break;
        case "volume_settings":
            AppState.openOverlay("volume");
            break;
        case "display_settings":
            AppState.openOverlay("display");
            break;
        default:
            // pump_start / pump_stop / sound_test / language_settings
            page.notPorted(title);
            break;
        }
    }

    // 各字号对应的 ascent（Godot draw_text 的 y 是基线，QML Text 的 y 是顶部）。
    FontMetrics { id: fm33; font.family: Theme.bodyFamily; font.pixelSize: Theme.fontPx(21) }
    FontMetrics { id: fm30; font.family: Theme.bodyFamily; font.pixelSize: Theme.fontPx(19) }
    FontMetrics { id: fm28; font.family: Theme.bodyFamily; font.pixelSize: Theme.fontPx(18) }
    FontMetrics { id: fm22; font.family: Theme.bodyFamily; font.pixelSize: Theme.fontPx(14) }
    FontMetrics { id: fm20; font.family: Theme.bodyFamily; font.pixelSize: Theme.fontPx(13) }
    FontMetrics { id: fm19; font.family: Theme.bodyFamily; font.pixelSize: Theme.fontPx(12) }
    FontMetrics { id: fm17; font.family: Theme.bodyFamily; font.pixelSize: Theme.fontPx(11) }
    FontMetrics { id: fm14; font.family: Theme.bodyFamily; font.pixelSize: Theme.fontTiny }

    // ---- 连接状态条: Godot STATUS_RECT Rect2(56,124,1168,86)@1280 -> 局部 (36,36,1752,129) ----
    HmiCard {
        id: statusCard
        x: Theme.px(56) - 48                          // 36
        y: Theme.px(124) - 150                        // 36
        width: Theme.px(1168)                         // 1752
        height: Theme.px(86)                          // 129
        radius: Theme.radiusCard                      // Godot 22@1280(=33)，取最近 token 28
        fillColor: page.alpha(Theme.panel, 0.56)   // Godot HMI_PANEL alpha 0.56

        Text {  // Godot 基线 (24,31)@1280，字号 _font_size(18)=28
            x: Theme.px(24)
            y: Theme.px(31) - fm28.ascent
            text: "连接状态"
            color: Theme.text
            font.pixelSize: Theme.fontPx(18)
        }

        // 三个状态块行: Godot Rect2(card.pos+(150,13), card.w-174, 60)@1280，
        // gap 14 -> 局部行 (225,19.5,1491,90)，gap 21，块宽 483。
        Repeater {
            model: [
                { "title": "ROS2", "icon": "activity", "tone": page.devStatus.ros2Online ? "green" : "red", "stateColor": page.devStatus.ros2Online ? Theme.success : Theme.danger, "value": page.devStatus.ros2Online ? "已连接" : "已断开" },
                { "title": "CAN",  "icon": "activity", "tone": page.devStatus.canOnline ? "green" : "red",  "stateColor": page.devStatus.canOnline ? Theme.success : Theme.danger,  "value": page.devStatus.canOnline ? "已连接" : "已断开" },
                { "title": "DDS",  "icon": "wifi",     "tone": page.ddsStatusTone(DdsBridge.state),          "stateColor": page.ddsStatusColor(DdsBridge.state),                    "value": page.ddsStatusValue(DdsBridge.state) }
            ]
            delegate: HmiInset {
                id: statusBlock
                required property int index
                required property var modelData
                readonly property color stateColor: modelData.stateColor

                x: Theme.px(150) + index * (483 + Theme.px(14))
                y: Theme.px(13)                          // 19.5
                width: 483
                height: Theme.px(60)                     // 90
                radius: Theme.radiusCardInner            // Godot 16@1280(=24)，取最近 token 22
                fillColor: Qt.rgba(0, 0, 0, 0.20)        // Godot 源值

                Rectangle {  // 图标底: Godot (16,13,34,34)@1280 r10 -> (24,19.5,51,51)
                    x: Theme.px(16)
                    y: Theme.px(13)
                    width: Theme.px(34)
                    height: Theme.px(34)
                    radius: Theme.radiusTab              // Godot 10@1280(=15)，取最近 token 18
                    color: page.alpha(statusBlock.stateColor, 0.16)
                    HmiIcon {  // Godot 中心 (33,30)@1280，22@1280 -> 33
                        name: statusBlock.modelData.icon
                        tone: statusBlock.modelData.tone
                        size: Theme.px(22)
                        anchors.centerIn: parent
                    }
                }
                Text {  // 标题基线 (64,23)@1280，_font_size(13)=20
                    x: Theme.px(64)
                    y: Theme.px(23) - fm20.ascent
                    text: statusBlock.modelData.title
                    color: Theme.muted
                    font.pixelSize: Theme.fontPx(13)
                }
                Text {  // 值基线 (64,45)@1280，_font_size(19)=30，fit 宽块宽-82@1280
                    x: Theme.px(64)
                    y: Theme.px(45) - fm30.ascent
                    width: statusBlock.width - Theme.px(82)
                    text: statusBlock.modelData.value
                    color: statusBlock.stateColor
                    font.pixelSize: Theme.fontPx(19)
                    elide: Text.ElideRight
                }
            }
        }
    }

    // ---- 设备工具卡: Godot TOOLS_RECT Rect2(56,226,1168,322)@1280 -> 局部 (36,189,1752,483) ----
    HmiCard {
        id: toolsCard
        x: Theme.px(56) - 48
        y: Theme.px(226) - 150                        // 189
        width: Theme.px(1168)
        height: Theme.px(322)                         // 483
        radius: Theme.radiusCard                      // Godot 22@1280(=33)，取最近 token 28
        fillColor: page.alpha(Theme.panel, 0.58)   // Godot HMI_PANEL alpha 0.58

        Text {  // "设备工具" 基线 (24,34)@1280，_font_size(21)=33
            x: Theme.px(24)
            y: Theme.px(34) - fm33.ascent
            text: "设备工具"
            color: Theme.text
            font.pixelSize: Theme.fontPx(21)
        }

        // 气泵摘要 pill: Godot Rect2(card.end.x-372, card.y+18, 336, 36)@1280
        // -> 卡内 (1224,27,504,54)；种子待机 -> muted 圆点。
        HmiInset {
            id: pumpPill
            x: toolsCard.width - Theme.px(372)        // 1194
            y: Theme.px(18)                           // 27
            width: Theme.px(336)                      // 504
            height: Theme.px(36)                      // 54
            radius: Theme.radiusPill                  // Godot 圆角 h/2=27，取最近 token 29
            fillColor: Qt.rgba(0, 0, 0, 0.22)         // Godot 源值

            Rectangle {  // 状态点: Godot 中心 (18, h/2)@1280，r4.5 -> 27,27 r6.75
                width: 14
                height: 14
                radius: 7
                x: Theme.px(18) - width / 2
                anchors.verticalCenter: parent.verticalCenter
                color: page.pumpRunning ? Theme.success : Theme.muted
            }
            Text {  // 基线 (32,23)@1280，_font_size(12)=19
                x: Theme.px(32)
                y: Theme.px(23) - fm19.ascent
                width: pumpPill.width - Theme.px(46)
                text: (page.pumpRunning ? "运行中" : "待机") + "  当前压力 " + page.pumpCurrent + "  目标压力 " + page.pumpTarget
                color: Theme.text
                font.pixelSize: Theme.fontPx(12)
                elide: Text.ElideRight
            }
        }
    }

    // 工具网格: Godot 网格区 Rect2(tools.pos+(24,60), tools.size-(48,84))@1280
    // -> 局部 (72,279,1680,357)，gap 14@1280(=21)。
    // 任务定义 13 卡 4 列 -> 4 行：卡宽 (1680-63)/4=404.25，卡高 (357-63)/4=73.5。
    Repeater {
        model: ShellData.deviceCards
        delegate: HmiCard {
            id: toolCard
            required property int index
            required property var modelData
            readonly property int col: index % 4
            readonly property int row: Math.floor(index / 4)
            readonly property color tint: modelData.color

            x: 72 + col * (404.25 + Theme.px(14))
            y: 279 + row * (73.5 + Theme.px(14))
            width: 404.25
            height: 73.5
            radius: Theme.radiusCard                  // Godot 18@1280(=27)，取最近 token 28
            fillColor: page.alpha(Theme.panel, 0.64)  // Godot glass card 非悬停 0.64

            Rectangle {  // 图标盒: Godot (16,15,44,44)@1280 r13；紧凑卡取 46x46
                x: 13
                y: (toolCard.height - height) / 2
                width: 46
                height: 46
                radius: Theme.radiusTab               // Godot 13@1280(=19.5)，取最近 token 18
                color: page.alpha(toolCard.tint, 0.16)
                HmiIcon {  // Godot 符号 29@1280(=43.5)，紧凑取 28
                    name: page.toolIcon(toolCard.modelData.id)
                    tone: toolCard.modelData.tone
                    size: 28
                    anchors.centerIn: parent
                }
            }
            Text {  // 标题: Godot _font_size(18)=28，fit 宽卡宽-92@1280
                x: 72
                y: 8
                width: toolCard.width - 86
                text: toolCard.modelData.title
                color: Theme.text
                font.pixelSize: Theme.fontPx(18)
                elide: Text.ElideRight
            }
            Text {  // 副标题: Godot _font_size(12)=19
                x: 72
                y: 41
                width: toolCard.width - 86
                text: toolCard.modelData.subtitle
                color: Theme.muted
                font.pixelSize: Theme.fontPx(12)
                elide: Text.ElideRight
            }
            ClickFlash {
                id: toolFlash
                radius: toolCard.radius
                flashColor: toolCard.tint
            }
            TapHandler {
                onTapped: {
                    toolFlash.flash();
                    page.activateTool(toolCard.modelData.id, toolCard.modelData.title);
                }
            }
        }
    }

    // ---- 底部条: Godot FOOTER_RECT Rect2(56,562,1168,88)@1280 -> 局部 (36,693,1752,132) ----
    HmiCard {
        id: footerCard
        x: Theme.px(56) - 48
        y: Theme.px(562) - 150                        // 693
        width: Theme.px(1168)
        height: Theme.px(88)                          // 132
        radius: Theme.radiusCard                      // Godot 22@1280(=33)，取最近 token 28
        fillColor: page.alpha(Theme.panel, 0.56)   // Godot HMI_PANEL alpha 0.56

        Text {  // "语言设置" 基线 (24,35)@1280，_font_size(14)=22
            x: Theme.px(24)
            y: Theme.px(35) - fm22.ascent
            text: "语言设置"
            color: Theme.muted
            font.pixelSize: Theme.fontPx(14)
        }

        // 语言按钮: Godot Rect2(footer.pos+(108,20), 166x48)@1280 -> (162,30,249,72)。
        // 注意：Godot 按钮内部图标/文字为未缩放原始值（_draw_language_button），按原样复刻。
        HmiInset {
            id: langButton
            x: Theme.px(108)
            y: Theme.px(20)
            width: Theme.px(166)                      // 249
            height: Theme.px(48)                      // 72
            radius: Theme.radiusPill                  // Godot 圆角 h/2=36，取 token 29
            fillColor: Qt.rgba(0, 0, 0, 0.24)         // Godot 源值

            HmiIcon {  // Godot 中心 (28,24) 原始值，20 原始值
                name: "user"
                tone: "cyan"
                size: 20
                x: 28 - width / 2
                y: 24 - height / 2
            }
            Text {  // Godot 基线 (50,30) 原始值，字号 15 原始值 -> 最近 token 14
                x: 50
                y: 30 - fm14.ascent
                width: langButton.width - 74
                text: "中文"
                color: Theme.text
                font.pixelSize: Theme.fontTiny
                elide: Text.ElideRight
            }
            HmiIcon {  // Godot 中心 rect.end-(21,24) 原始值，16 原始值
                name: "arrow-right"
                tone: "muted"
                size: 16
                x: langButton.width - 21 - width / 2
                y: langButton.height - 24 - height / 2
            }
            ClickFlash {
                id: langFlash
                radius: langButton.radius
                flashColor: Theme.primary
            }
            TapHandler {
                onTapped: {
                    langFlash.flash();
                    page.notPorted("语言设置");
                }
            }
        }

        // 云绑定按钮: Godot Rect2(footer.pos+(292,20), 220x48)@1280 -> (438,30,330,72)。
        // 内部同为原始值；种子 cloud_bound=false -> 青色 "云端绑定"。
        HmiInset {
            id: cloudButton
            x: Theme.px(292)
            y: Theme.px(20)
            width: Theme.px(220)                      // 330
            height: Theme.px(48)
            radius: Theme.radiusPill
            fillColor: Qt.rgba(0, 0, 0, 0.24)

            HmiIcon {  // Godot 用 lucide "cloud"，资源集无 cloud，取 wifi 代替
                name: "wifi"
                tone: "cyan"
                size: 20
                x: 28 - width / 2
                y: 24 - height / 2
            }
            Text {
                x: 50
                y: 30 - fm14.ascent
                width: cloudButton.width - 74
                text: "云端绑定"
                color: Theme.text
                font.pixelSize: Theme.fontTiny
                elide: Text.ElideRight
            }
            HmiIcon {
                name: "arrow-right"
                tone: "muted"
                size: 16
                x: cloudButton.width - 21 - width / 2
                y: cloudButton.height - 24 - height / 2
            }
            ClickFlash {
                id: cloudFlash
                radius: cloudButton.radius
                flashColor: Theme.cyan
            }
            TapHandler {
                onTapped: {
                    cloudFlash.flash();
                    AppState.openOverlay("cloud_pairing");
                }
            }
        }

        // 三个气泵指标: Godot Rect2(footer.pos+(532/682/832,18), 134x52)@1280
        // -> (798/1023/1248,27,201,78)。
        Repeater {
            model: [
                { "label": "气泵",     "value": page.pumpRunning ? "运行中" : "待机", "color": page.pumpRunning ? Theme.success : Theme.muted },
                { "label": "当前压力", "value": String(page.pumpCurrent),            "color": Theme.cyan },
                { "label": "目标压力", "value": String(page.pumpTarget),             "color": Theme.warn }
            ]
            delegate: HmiInset {
                id: metric
                required property int index
                required property var modelData

                x: Theme.px(532 + index * 150)
                y: Theme.px(18)
                width: Theme.px(134)                  // 201
                height: Theme.px(52)                  // 78
                radius: Theme.radiusCardInner         // Godot 16@1280(=24)，取最近 token 22
                fillColor: Qt.rgba(0, 0, 0, 0.16)     // Godot 源值

                Text {  // 标签基线 (16,20)@1280，_font_size(11)=17
                    x: Theme.px(16)
                    y: Theme.px(20) - fm17.ascent
                    text: metric.modelData.label
                    color: Theme.muted
                    font.pixelSize: Theme.fontPx(11)
                }
                Text {  // 值基线 (16,42)@1280，_font_size(18)=28
                    x: Theme.px(16)
                    y: Theme.px(42) - fm28.ascent
                    width: metric.width - Theme.px(32)
                    text: metric.modelData.value
                    color: metric.modelData.color
                    font.pixelSize: Theme.fontPx(18)
                    elide: Text.ElideRight
                }
            }
        }

        // 状态 toast: Godot Rect2(footer.end.x-224, footer.y+22, 188, 44)@1280
        // -> 局部相对 footer (1452-36,33) 即卡内 (1416,33,282,66)；model.message 空 -> 默认文案。
        Rectangle {
            x: footerCard.width - Theme.px(224)       // 1416
            y: Theme.px(22)                           // 33
            width: Theme.px(188)                      // 282
            height: Theme.px(44)                      // 66
            radius: Theme.radiusCardInner             // Godot 14@1280(=21)，取最近 token 22
            color: page.alpha(Theme.primary, 0.11) // Godot 源值

            Text {  // 基线 (18,28)@1280，_font_size(13)=20
                x: Theme.px(18)
                y: Theme.px(28) - fm20.ascent
                width: Theme.px(188) - Theme.px(36)
                text: "设备状态实时同步"
                color: Theme.text
                font.pixelSize: Theme.fontPx(13)
                elide: Text.ElideRight
            }
        }
    }

    // ---- 10 个覆盖面板（id 取 device_page.gd 面板 id；遮罩为整页 Color(0,0,0,0.46)）----
    DeviceVolumePanel { anchors.fill: parent }
    DeviceDisplayPanel { anchors.fill: parent }
    DeviceSystemPanel { anchors.fill: parent }
    DevicePressurePanel { anchors.fill: parent }
    DeviceFacePanel { anchors.fill: parent }
    DevicePumpPanel { anchors.fill: parent }
    DevicePunchPanel { anchors.fill: parent }
    DeviceHitTestPanel { anchors.fill: parent }
    DeviceDevToolsPanel { anchors.fill: parent }
    DeviceCloudPanel { anchors.fill: parent }
}
