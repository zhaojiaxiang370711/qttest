pragma ComponentBehavior: Bound
import QtQuick
import QxznHmi
import QtQuick.Effects


// 娱乐模式页（14 张游戏卡网格）。
// Godot 源：scripts/pages/card_page.gd（selected_nav == "entertainment" 分支）
// + scripts/shell_card_grid.gd draw_grid / _draw_game_image_card。
// 网格 Rect2(56,134,1168,514)@1280，卡 370x208@1280，3 列，gap_y 20@1280。
// 页面局部坐标 = Godot 屏幕坐标 - (48,150)。
Item {
    id: page

    readonly property int cardW: Theme.px(370)      // 555
    readonly property int cardH: Theme.px(208)      // 312
    readonly property int columns: 3
    // Godot: gap_x = (1168 - 3*370) / 2 = 29 @1280
    readonly property real gapX: (Theme.px(1168) - columns * cardW) / (columns - 1)
    readonly property int gapY: Theme.px(20)        // 30
    readonly property int rows: Math.ceil(ShellData.entertainmentCards.length / columns)

    // card.color 为 hex 字符串，Godot 里大量 Color(color, alpha) 用法在此换算。
    function alphaColor(hex, a) {
        var v = Math.max(0, Math.min(255, Math.round(a * 255))).toString(16);
        if (v.length < 2)
            v = "0" + v;
        return "#" + v + String(hex).substring(1);
    }

    function cardActivated(item) {
        if (item.id === "fitness_games")
            AppState.openSubPage("fitness");
        else
            AppState.openSubGame(item);   // opens the subgame placeholder (content ships as standalone Godot later)
    }

    // 游戏封面卡：_draw_game_image_card。除注明外矩形均为 1280 基准。
    component GameCard: Item {
        id: card
        required property var itemData
        signal activated(var item)

        readonly property color cardColor: itemData.color !== undefined ? itemData.color : "#00F0FF"
        readonly property string cardColorHex: itemData.color !== undefined ? String(itemData.color) : "#00F0FF"
        readonly property string cover: ShellData.coverFor(itemData.id !== undefined ? itemData.id : "")
        readonly property string fallbackIcon: itemData.id === "vr_beats_kit" ? "gamepad-2" : "music"
        // Godot hover 时卡上移 3px（非缩放值，运行时原值）
        property real lift: hover.hovered ? -3 : 0
        Behavior on lift { NumberAnimation { duration: 80 } }

        // 卡体 draw_hmi_card Color(0,0,0,0.46)，radius 22@1280
        HmiCard {
            anchors.fill: parent
            radius: Theme.px(22)
            fillColor: Qt.rgba(0, 0, 0, 0.46)
        }

        Item {
            id:imageArea
            x: Theme.px(2)
            y: Theme.px(2)
            width: card.width - Theme.px(2) * 2
            height: card.height - Theme.px(2) * 2

            Item {
                id: coverContent
                anchors.fill: parent
                visible: false

                Image {
                    anchors.fill: parent
                    visible: card.cover !== ""
                    source: card.cover
                    fillMode: Image.PreserveAspectCrop   // Godot _draw_cover_texture 居中裁剪
                    asynchronous: true
                    smooth: true
                }
                // 无封面：渐变占位 + 图标（Godot 走 icon 卡分支，移植按约定统一封面卡样式）
                Rectangle {
                    anchors.fill: parent
                    visible: card.cover === ""
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: page.alphaColor(card.cardColorHex, 0.42) }
                        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.55) }
                    }
                    HmiIcon {
                        anchors.centerIn: parent
                        name: card.fallbackIcon
                        tone: card.itemData.tone !== undefined ? card.itemData.tone : "white"
                        size: Theme.px(64)
                    }
                }
                // 压暗层：全图 0.18 + 下部 58% 0.40 + 左侧 60% 0.22（Godot 源 alpha）
                Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.10) }
                Rectangle {
                    x: 0
                    y: Math.round(imageArea.height * 0.42)
                    width: imageArea.width
                    height: imageArea.height - y
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0) }
                        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.55) }
                    }
                }
            }
            // 蒙版形状：一个看不见的圆角矩形
            Rectangle {
                id: roundMask
                anchors.fill: parent
                radius: Theme.px(20)    // 卡体 radius 22 减去 2px 内缩，角刚好贴合
                visible: false
                layer.enabled: true     // maskSource 要求源先渲染成纹理，必须加这行
            }

            MultiEffect {
                anchors.fill: parent
                source: coverContent    // 把封面内容作为输入
                maskEnabled: true       // 启用蒙版
                maskSource: roundMask   // 用圆角矩形做蒙版
            }

        }


        // 顶部高光线：(24,2) -> (w-24,2)@1280，卡色 alpha 0.24
        Rectangle {
            x: Theme.px(24)
            y: Theme.px(2)
            width: card.width - Theme.px(24) * 2
            height: 1
            color: page.alphaColor(card.cardColorHex, 0.24)
        }
        // 静止边框：rect.grow(-1.5) 白色 alpha 0.10，radius 22@1280
        Rectangle {
            anchors.fill: parent
            anchors.margins: Theme.px(1.5)
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.10)
            border.width: 1
            radius: Theme.px(22) - Theme.px(1.5)
        }
        // 标签 pill：pos (18,16) h 22，宽 clamp(len*7.5+24, 58, w-78)@1280
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
        // 标题：x 20，baseline = h-62@1280，font 24，fit 宽 w-62（baseline->top 取 0.78 倍字号）
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
        // 副标题：baseline = 标题 baseline + 24@1280，font 13，fit 宽 w-66
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
        // 右下箭头：圆心 (w-30, h-24) r 12@1280，卡色 alpha 0.18 + ">" 折线宽 2@1280
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
                    ctx.moveTo(cx - 6, cy - 7.5);    // (-4,-5)@1280 x1.5
                    ctx.lineTo(cx + 4.5, cy);        // (3,0)@1280 x1.5
                    ctx.lineTo(cx - 6, cy + 7.5);    // (-4,5)@1280 x1.5
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

    // 卡网格视口：Rect2(56,134,1168,514)@1280 -> 局部 (36,51,1752,771)
    Flickable {
        id: grid
        x: Theme.px(56) - 48
        y: Theme.px(134) - 150
        width: Theme.px(1168)
        height: Theme.px(514)
        contentWidth: width
        contentHeight: page.rows * page.cardH + (page.rows - 1) * page.gapY
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        Repeater {
            model: ShellData.entertainmentCards
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

    // 滚动条：track (bounds.right+10, bounds.y+6, 5, h-12)@1280，thumb primary alpha 0.72
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
}
