pragma ComponentBehavior: Bound
import QtQuick
import QxznHmi

// 拳击知识子页。
// Godot 源：scripts/pages/boxing_knowledge_page.gd + scripts/shell_page_data.gd。
// 头部 Rect2(56,134,1168,60)，tab 条 (56,208,1168,48)，文章网格 (56,272,1168,398)，
// 卡宽 568 两列，行距 pitch = 120+16 —— 均 1280 基准。
// 页面局部坐标 = Godot 屏幕坐标 - (48,150)。
Item {
    id: page

    property string selectedTab: "basics"

    // BOXING_KNOWLEDGE_TABS / BOXING_KNOWLEDGE_ARTICLES（shell_page_data.gd，照抄）
    readonly property var tabs: [
        { "id": "basics",     "name": "基础动作" },
        { "id": "techniques", "name": "技术技巧" },
        { "id": "tactics",    "name": "战术策略" },
        { "id": "training",   "name": "训练方法" }
    ]
    readonly property var articlesByTab: ({
        "basics": [
            { "title": "正架 / 反架",       "desc": "保持重心稳定，肩胯一致，防守手位始终在线。" },
            { "title": "刺拳（Jab）",       "desc": "用于控制距离、试探节奏，并为后手重拳创造窗口。" },
            { "title": "后手直拳（Cross）", "desc": "后脚蹬地发力，髋部旋转带动肩部直线输出。" }
        ],
        "techniques": [
            { "title": "摆拳（Hook）",      "desc": "注意肘部与拳面轨迹，避免过度摆臂导致失衡。" },
            { "title": "上勾拳（Uppercut）", "desc": "下肢发力上送，近距离破防效果明显。" },
            { "title": "闪躲与下潜",         "desc": "小幅位移优先，闪避后立即准备二次反击。" }
        ],
        "tactics": [
            { "title": "节奏破坏",   "desc": "通过刺拳频率变化打断对手进攻节奏。" },
            { "title": "距离管理",   "desc": "外线控制用直拳，内线缠斗用勾摆与防守反击。" },
            { "title": "组合拳衔接", "desc": "建议从 1-2、1-2-3 开始，逐步增加变化。" }
        ],
        "training": [
            { "title": "热身与激活", "desc": "训练前 8-12 分钟动态热身，激活肩髋核心。" },
            { "title": "强度分配",   "desc": "建议 70% 技术打磨 + 20% 速度爆发 + 10% 对抗模拟。" },
            { "title": "复盘机制",   "desc": "训练后记录命中率、反应时、疲劳度，形成闭环。" }
        ]
    })
    readonly property var articles: articlesByTab[selectedTab]

    readonly property int cardW: Theme.px(568)      // 852
    readonly property int columns: 2
    // Godot: gap_x = (1168 - 2*568) / 1 = 32 @1280
    readonly property real gapX: (Theme.px(1168) - columns * cardW) / (columns - 1)
    // Godot 网格行距用估算高 card_h_est 120 + gap 16 @1280
    readonly property int rowPitch: Theme.px(120) + Theme.px(16)    // 204
    readonly property int rows: Math.ceil(articles.length / columns)
    // tab 宽 = (1168 - 40) / 4 @1280
    readonly property real tabW: (Theme.px(1168) - Theme.px(40)) / tabs.length

    // ---- 文章卡（_draw_articles）----
    // 实高 = padding 22 + 标题行*24 + 8 + 描述行*20 + padding 22 @1280
    component ArticleCard: Item {
        id: articleCard
        required property var article
        width: page.cardW
        height: Theme.px(22) + titleText.paintedHeight + Theme.px(8) + descText.paintedHeight + Theme.px(22)

        HmiCard {
            anchors.fill: parent
            radius: Theme.px(18)
            fillColor: Qt.rgba(0.067, 0.067, 0.067, 0.62)
        }
        // 标题：相对 (22,22)@1280，font 18，fit 一行（Godot draw_text_fit）
        Text {
            id: titleText
            x: Theme.px(22)
            y: Theme.px(22)
            width: articleCard.width - Theme.px(22) * 2
            text: articleCard.article.title !== undefined ? articleCard.article.title : ""
            color: Theme.text
            font.pixelSize: Theme.fontPx(18)
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: Theme.fontPx(13)
            lineHeight: Theme.px(24)
            lineHeightMode: Text.FixedHeight
        }
        // 描述：相对 (22, 22+24+8)@1280，font 14，最多 4 行
        Text {
            id: descText
            x: Theme.px(22)
            y: Theme.px(22) + Theme.px(24) + Theme.px(8)
            width: articleCard.width - Theme.px(22) * 2
            text: articleCard.article.desc !== undefined ? articleCard.article.desc : ""
            color: Theme.muted
            font.pixelSize: Theme.fontPx(14)
            wrapMode: Text.Wrap
            maximumLineCount: 4
            elide: Text.ElideRight
            lineHeight: Theme.px(20)
            lineHeightMode: Text.FixedHeight
        }
        ClickFlash {
            id: cardFlash
            radius: Theme.px(18)
            flashColor: Theme.primary
        }
        TapHandler {
            onTapped: cardFlash.flash()    // Godot 源仅有点击反馈，无跳转
        }
    }

    // ---- 头部：Rect2(56,134,1168,60)@1280 -> 局部 (36,51,1752,90) ----
    HmiCard {
        id: header
        x: Theme.px(56) - 48
        y: Theme.px(134) - 150
        width: Theme.px(1168)
        height: Theme.px(60)
        radius: Theme.px(24)
        fillColor: Qt.rgba(0.067, 0.067, 0.067, 0.68)

        // 返回键：相对头部 (12,12,100,36)@1280，radius 16
        Rectangle {
            id: backButton
            x: Theme.px(12)
            y: Theme.px(12)
            width: Theme.px(100)
            height: Theme.px(36)
            radius: Theme.px(16)
            color: Qt.rgba(0, 0.941, 1, 0.12)
            border.color: Qt.rgba(0, 0.941, 1, 0.40)
            border.width: 2    // Godot 1.0@1280

            Canvas {
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.strokeStyle = "#F8FAFC";
                    ctx.lineWidth = 3.3;
                    ctx.lineCap = "round";
                    ctx.beginPath();
                    ctx.moveTo(30, 27);
                    ctx.lineTo(48, 16.5);
                    ctx.moveTo(30, 27);
                    ctx.lineTo(48, 37.5);
                    ctx.stroke();
                }
            }
            Text {
                x: Theme.px(42)
                y: Theme.px(22) - Math.round(Theme.fontPx(14) * 0.78)
                text: "返回"
                color: Theme.text
                font.pixelSize: Theme.fontPx(14)
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

        // 标题 / 副标题：相对头部 (128,18) / (128,40)@1280 baseline，font 22 / 13
        Text {
            x: Theme.px(128)
            y: Theme.px(18) - Math.round(Theme.fontPx(22) * 0.78)
            text: "拳击知识"
            color: Theme.text
            font.pixelSize: Theme.fontPx(22)
        }
        Text {
            x: Theme.px(128)
            y: Theme.px(40) - Math.round(Theme.fontPx(13) * 0.78)
            text: "按模块查看要点"
            color: Theme.muted
            font.pixelSize: Theme.fontPx(13)
        }
    }

    // ---- tab 条：(56,208,1168,48)@1280 -> 局部 (36,162,1752,72)，glass radius 20 ----
    HmiCard {
        id: tabBar
        x: Theme.px(56) - 48
        y: Theme.px(208) - 150
        width: Theme.px(1168)
        height: Theme.px(48)
        radius: Theme.px(20)
        fillColor: Qt.rgba(0.067, 0.067, 0.067, 0.52)

        Repeater {
            model: page.tabs
            delegate: Rectangle {
                id: tab
                required property int index
                required property var modelData
                readonly property bool active: page.selectedTab === modelData.id
                x: Theme.px(20) + index * page.tabW
                y: Theme.px(6)
                width: page.tabW
                height: Theme.px(36)
                radius: Theme.px(16)
                color: active ? Qt.rgba(0, 0.941, 1, 0.20) : "transparent"
                border.color: Qt.rgba(0, 0.941, 1, 0.40)
                border.width: active ? 2 : 0    // Godot 激活描边 1.2@1280
                Text {
                    anchors.centerIn: parent
                    text: tab.modelData.name
                    color: tab.active ? Theme.primary : Theme.muted
                    font.pixelSize: tab.active ? Theme.fontPx(14) : Theme.fontPx(13)
                }
                ClickFlash {
                    id: tabFlash
                    radius: tab.radius
                    flashColor: Theme.primary
                }
                TapHandler {
                    onTapped: {
                        tabFlash.flash();
                        page.selectedTab = tab.modelData.id;
                        articleView.contentY = 0;
                    }
                }
            }
        }
    }

    // ---- 文章网格：(56,272,1168,398)@1280 -> 局部 (36,258,1752,597) ----
    Flickable {
        id: articleView
        x: Theme.px(56) - 48
        y: Theme.px(272) - 150
        width: Theme.px(1168)
        height: Theme.px(398)
        contentWidth: width
        contentHeight: page.rows * Theme.px(120) + (page.rows - 1) * Theme.px(16)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        Repeater {
            model: page.articles
            delegate: ArticleCard {
                required property int index
                required property var modelData
                article: modelData
                x: (index % page.columns) * (page.cardW + page.gapX)
                y: Math.floor(index / page.columns) * page.rowPitch
            }
        }
    }

    // 滚动条：track (bounds.right+10, bounds.y+6, 5, h-12)@1280（内容不超高时隐藏）
    Rectangle {
        id: scrollTrack
        visible: articleView.contentHeight > articleView.height + 1
        x: articleView.x + articleView.width + Theme.px(10)
        y: articleView.y + Theme.px(6)
        width: Theme.px(5)
        height: articleView.height - Theme.px(12)
        radius: Theme.px(3)
        color: Qt.rgba(1, 1, 1, 0.070)
        Rectangle {
            width: parent.width
            height: Math.max(Theme.px(42), parent.height * articleView.height / articleView.contentHeight)
            y: (parent.height - height) * (articleView.contentY / Math.max(1, articleView.contentHeight - articleView.height))
            radius: scrollTrack.radius
            color: Qt.rgba(0, 0.941, 1, 0.72)
        }
    }
}
