pragma ComponentBehavior: Bound
import QtQuick
import QxznHmi

// 健身小游戏子页。
// Godot 源：scripts/pages/fitness_page.gd + scripts/shell_card_grid.gd
// （_draw_game_image_card，5 张卡均有封面）。
// hero Rect2(56,134,1168,94)，返回键 (56,134,128,46)，网格 (56,260,1168,302)
// 2 列卡 568x132，底部信息卡 (56,596,1168,52) —— 均 1280 基准。
// 页面局部坐标 = Godot 屏幕坐标 - (48,150)。
Item {
    id: page

    // FITNESS_CARDS（shell_page_data.gd；ShellData 未收录该表，按源硬编码）
    readonly property var fitnessCards: [
        { "id": "interstellar_bounce", "title": "星际弹跳",   "subtitle": "3D 太空弹跳挑战：踩同色轨道、进入 BOOST，并冲进黑洞完成关卡。", "tag": "Godot", "color": "#00F0FF", "tone": "cyan"   },
        { "id": "tracking_challenge",  "title": "追踪挑战",   "subtitle": "记住点位顺序并按节奏击打，训练空间记忆与反应节拍。",           "tag": "Godot", "color": "#00F0FF", "tone": "cyan"   },
        { "id": "agility_challenge",   "title": "敏捷大挑战", "subtitle": "头部/腰部双通道目标飞来，快速判断、击中、闪避陷阱。",           "tag": "Godot", "color": "#FFE600", "tone": "yellow" },
        { "id": "fruit_slice",         "title": "切水果挑战", "subtitle": "第一人称 3D 切水果，QWER / ASDF 对应上下两排轨道。",             "tag": "C#",    "color": "#FF003C", "tone": "red"    },
        { "id": "performance_jam",     "title": "自由演奏",   "subtitle": "选择钢琴、吉他、贝斯、合成器或电子鼓，用 7 个点位即兴演奏。",     "tag": "Godot", "color": "#00FF78", "tone": "green"  }
    ]

    readonly property int cardW: Theme.px(568)      // 852
    readonly property int cardH: Theme.px(132)      // 198
    readonly property int columns: 2
    // Godot: gap_x = (1168 - 2*568) / 1 = 32 @1280
    readonly property real gapX: (Theme.px(1168) - columns * cardW) / (columns - 1)
    readonly property int gapY: Theme.px(20)        // 30
    readonly property int rows: Math.ceil(fitnessCards.length / columns)

    function alphaColor(hex, a) {
        var v = Math.max(0, Math.min(255, Math.round(a * 255))).toString(16);
        if (v.length < 2)
            v = "0" + v;
        return "#" + v + String(hex).substring(1);
    }

    function cardActivated(item) {
        // 5 个健身游戏入口 → 子游戏占位页（内容以后作为独立 Godot 游戏接入）
        AppState.openSubGame(item);
    }

    // 游戏封面卡：与娱乐页同一绘制（shell_card_grid.gd _draw_game_image_card）。
    component GameCard: Item {
        id: card
        required property var itemData
        signal activated(var item)

        readonly property color cardColor: itemData.color !== undefined ? itemData.color : "#00F0FF"
        readonly property string cardColorHex: itemData.color !== undefined ? String(itemData.color) : "#00F0FF"
        readonly property string cover: ShellData.coverFor(itemData.id !== undefined ? itemData.id : "")
        property real lift: hover.hovered ? -3 : 0
        Behavior on lift { NumberAnimation { duration: 80 } }

        HmiCard {
            anchors.fill: parent
            radius: Theme.px(22)
            fillColor: Qt.rgba(0, 0, 0, 0.46)
        }

        Item {
            id: imageArea
            x: Theme.px(2)
            y: Theme.px(2)
            width: card.width - Theme.px(2) * 2
            height: card.height - Theme.px(2) * 2

            Image {
                anchors.fill: parent
                source: card.cover
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
            }
            Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.18) }
            Rectangle {
                x: 0
                y: Math.round(imageArea.height * 0.42)
                width: imageArea.width
                height: imageArea.height - y
                color: Qt.rgba(0, 0, 0, 0.40)
            }
            Rectangle {
                x: 0
                y: 0
                width: Math.round(imageArea.width * 0.60)
                height: imageArea.height
                color: Qt.rgba(0, 0, 0, 0.22)
            }
        }

        Rectangle {
            x: Theme.px(24)
            y: Theme.px(2)
            width: card.width - Theme.px(24) * 2
            height: 1
            color: page.alphaColor(card.cardColorHex, 0.24)
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: Theme.px(1.5)
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.10)
            border.width: 1
            radius: Theme.px(22) - Theme.px(1.5)
        }
        Rectangle {
            x: Theme.px(18)
            y: Theme.px(16)
            height: Theme.px(22)
            width: Math.min(Math.max(tagText.text.length * 11 + Theme.px(24), Theme.px(58)), card.width - Theme.px(78))
            radius: height / 2
            color: page.alphaColor(card.cardColorHex, 0.24)
            Text {
                id: tagText
                anchors.centerIn: parent
                text: card.itemData.tag !== undefined ? card.itemData.tag : ""
                color: card.cardColor
                font.pixelSize: Theme.fontPx(10)
            }
        }
        Text {
            x: Theme.px(20)
            y: card.height - Theme.px(62) - Math.round(Theme.fontPx(24) * 0.78)
            width: card.width - Theme.px(62)
            text: card.itemData.title !== undefined ? card.itemData.title : ""
            color: Theme.text
            font.pixelSize: Theme.fontPx(24)
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: Theme.fontPx(14)
        }
        Text {
            x: Theme.px(20)
            y: card.height - Theme.px(62) + Theme.px(24) - Math.round(Theme.fontPx(13) * 0.78)
            width: card.width - Theme.px(66)
            text: card.itemData.subtitle !== undefined ? card.itemData.subtitle : ""
            color: Theme.muted
            font.pixelSize: Theme.fontPx(13)
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: Theme.fontPx(11)
        }
        Rectangle {
            x: card.width - Theme.px(30) - Theme.px(12)
            y: card.height - Theme.px(24) - Theme.px(12)
            width: Theme.px(24)
            height: Theme.px(24)
            radius: Theme.px(12)
            color: page.alphaColor(card.cardColorHex, 0.18)
            Canvas {
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.strokeStyle = card.cardColorHex;
                    ctx.lineWidth = Theme.px(2);
                    ctx.lineCap = "round";
                    ctx.lineJoin = "round";
                    var cx = width / 2, cy = height / 2;
                    ctx.beginPath();
                    ctx.moveTo(cx - 6, cy - 7.5);
                    ctx.lineTo(cx + 4.5, cy);
                    ctx.lineTo(cx - 6, cy + 7.5);
                    ctx.stroke();
                }
            }
        }

        ClickFlash {
            id: flash
            radius: Theme.px(22)
            flashColor: card.cardColor
        }
        HoverHandler { id: hover }
        TapHandler {
            onTapped: {
                flash.flash();
                card.activated(card.itemData);
            }
        }
    }

    // hero 卡：Rect2(56,134,1168,94)@1280 -> 局部 (36,51,1752,141)，glass radius 24 alpha 0.68
    HmiCard {
        x: Theme.px(56) - 48
        y: Theme.px(134) - 150
        width: Theme.px(1168)
        height: Theme.px(94)
        radius: Theme.px(24)
        fillColor: Qt.rgba(0.067, 0.067, 0.067, 0.68)
    }

    // 返回键：(56,134,128,46)@1280 -> 局部 (36,51,192,69)，radius 18，cyan alpha 0.12/0.40
    Rectangle {
        id: backButton
        x: Theme.px(56) - 48
        y: Theme.px(134) - 150
        width: Theme.px(128)
        height: Theme.px(46)
        radius: Theme.px(18)
        color: Qt.rgba(0, 0.941, 1, 0.12)
        border.color: Qt.rgba(0, 0.941, 1, 0.40)
        border.width: 1.5    // Godot _layout_len(1.0)

        // "<" 折线：(28,23)->(43,14)、(28,23)->(43,32)@1280 相对返回键，线宽 2.4
        Canvas {
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.strokeStyle = "#F8FAFC";
                ctx.lineWidth = 3.6;
                ctx.lineCap = "round";
                ctx.beginPath();
                ctx.moveTo(42, 34.5);
                ctx.lineTo(64.5, 21);
                ctx.moveTo(42, 34.5);
                ctx.lineTo(64.5, 48);
                ctx.stroke();
            }
        }
        // "返回"：相对 (56,29)@1280 baseline，font 16
        Text {
            x: Theme.px(56)
            y: Theme.px(29) - Math.round(Theme.fontPx(16) * 0.78)
            text: "返回"
            color: Theme.text
            font.pixelSize: Theme.fontPx(16)
        }
        ClickFlash {
            id: backFlash
            radius: backButton.radius
            flashColor: Theme.cyan
        }
        TapHandler {
            onTapped: {
                backFlash.flash();
                AppState.back();
            }
        }
    }

    // 标题 / 副标题：baseline (212,171) / (212,198)@1280，font 28 / 15
    Text {
        x: Theme.px(212) - 48
        y: Theme.px(171) - 150 - Math.round(Theme.fontPx(28) * 0.78)
        text: "健身小游戏"
        color: Theme.text
        font.pixelSize: Theme.fontPx(28)
    }
    Text {
        x: Theme.px(212) - 48
        y: Theme.px(198) - 150 - Math.round(Theme.fontPx(15) * 0.78)
        text: "星际弹跳、追踪挑战、敏捷挑战按需加载；切水果作为独立游戏启动。"
        color: Theme.muted
        font.pixelSize: Theme.fontPx(15)
    }

    // 卡网格视口：Rect2(56,260,1168,302)@1280 -> 局部 (36,240,1752,453)
    Flickable {
        id: grid
        x: Theme.px(56) - 48
        y: Theme.px(260) - 150
        width: Theme.px(1168)
        height: Theme.px(302)
        contentWidth: width
        contentHeight: page.rows * page.cardH + (page.rows - 1) * page.gapY
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        Repeater {
            model: page.fitnessCards
            delegate: GameCard {
                required property int index
                required property var modelData
                itemData: modelData
                width: page.cardW
                height: page.cardH
                x: (index % page.columns) * (page.cardW + page.gapX)
                y: Math.floor(index / page.columns) * (page.cardH + page.gapY) + lift
                onActivated: function(item) { page.cardActivated(item); }
            }
        }
    }

    // 滚动条：track (bounds.right+10, bounds.y+6, 5, h-12)@1280
    Rectangle {
        id: scrollTrack
        visible: grid.contentHeight > grid.height + 1
        x: grid.x + grid.width + Theme.px(10)
        y: grid.y + Theme.px(6)
        width: Theme.px(5)
        height: grid.height - Theme.px(12)
        radius: Theme.px(3)
        color: Qt.rgba(1, 1, 1, 0.070)
        Rectangle {
            width: parent.width
            height: Math.max(Theme.px(42), parent.height * grid.height / grid.contentHeight)
            y: (parent.height - height) * (grid.contentY / Math.max(1, grid.contentHeight - grid.height))
            radius: scrollTrack.radius
            color: Qt.rgba(0, 0.941, 1, 0.72)
        }
    }

    // 控制方式信息卡：Rect2(56,596,1168,52)@1280 -> 局部 (36,744,1752,78)，compact 分支
    HmiCard {
        x: Theme.px(56) - 48
        y: Theme.px(596) - 150
        width: Theme.px(1168)
        height: Theme.px(52)
        radius: Theme.px(22)
        fillColor: Qt.rgba(0.067, 0.067, 0.067, 0.56)

        // 标题 baseline 相对 (24,32)@1280，font 20
        Text {
            x: Theme.px(24)
            y: Theme.px(32) - Math.round(Theme.fontPx(20) * 0.78)
            text: "控制方式"
            color: Theme.text
            font.pixelSize: Theme.fontPx(20)
        }
        // 正文起点相对 (24,50)@1280，font 14（Godot 源在此紧贴卡底，照原值放置）
        Text {
            x: Theme.px(24)
            y: Theme.px(50)
            width: Theme.px(1168) - Theme.px(48)
            text: "方向键 / Q/A 左移，R/F 右移；触摸屏左右两侧控制方向；硬件左右击打同步映射。"
            color: Theme.muted
            font.pixelSize: Theme.fontPx(14)
            elide: Text.ElideRight
        }
    }
}
