pragma ComponentBehavior: Bound
// ============================================================
// 【教学导读】首页（导航 id "home"），是页面级 QML 的典型组织范本：
//   - 按视觉区块划分子元素（训练总览 / 训练日程 / 发现课程 三大面板）
//   - 数据全部来自单例：ShellData（静态数据）、AppState（导航/弹层）、
//     SessionModel（硬件会话），页面本身不持有业务状态
//   - 复用组件：HmiIcon、ClickFlash，以及本文件的内联组件 StatPill/ChipCyan
//   - 用 Repeater + model/delegate 做数据驱动渲染，用 Flickable 做横向滑动
// 坐标说明：本页 1:1 移植自 Godot 场景，x/y 均为 1920x1080 设计稿坐标，
// 由 Main.qml 的缩放容器统一适配实际屏幕。
// 配套阅读：qml/Main.qml（页面如何被 Loader 加载）、qml/ShellData.qml
// ============================================================
import QtQuick
import QxznHmi

// Home page (nav "home"), ported 1:1 from the Godot node view
// scenes/pages/HomePageView.tscn (authoritative 1920x1080 layout) and
// scripts/pages/home_page.gd (texts/behavior). The tscn root sits at window
// (72,168), so page-local coords = tscn coords - (48,150) = tscn + (24,18):
// SummaryPanel (24,18,588,522), SchedulePanel (24,567,588,291),
// DiscoverPanel (639,18,1161,840). Panel-local coords below are the raw tscn
// child offsets. tscn inline font sizes are already final 1920-basis values
// and are used directly; palette colors come from Theme.
Item {
    id: page

    // 数据来自 ShellData 单例：绑定之后，数据一变页面自动刷新
    readonly property var summary: ShellData.homeSummary

    // Recommendation rail: Godot HOME_RECOMMEND_IDS order
    // (shell_page_data.gd), titles resolved from page_cards/FITNESS_CARDS,
    // tag/meta from home_page.gd _recommend_meta fallbacks. Covers via
    // ShellData.coverFor. Not clickable into a game yet -> "未移植" callout.
    readonly property var recommendations: [
        { "id": "ai_battle",           "title": "AI 对战",     "tag": "对战训练", "meta": "35 分钟 | 480 千卡" },
        { "id": "performance_jam",     "title": "自由演奏",    "tag": "节奏音乐", "meta": "20 分钟 | 300 千卡" },
        { "id": "agility_challenge",   "title": "敏捷大挑战",  "tag": "步伐反应", "meta": "15 分钟 | 220 千卡" },
        { "id": "tracking_challenge",  "title": "追踪挑战",    "tag": "追踪训练", "meta": "18 分钟 | 260 千卡" },
        { "id": "fruit_slice",         "title": "切水果挑战",  "tag": "反应切击", "meta": "12 分钟 | 180 千卡" },
        { "id": "interstellar_bounce", "title": "星际弹跳",    "tag": "空间敏捷", "meta": "16 分钟 | 240 千卡" }
    ]

    // tscn stat pill style (StatPill/StatWide): translucent white fill + border.
    // 内联组件（Qt 6 语法）：在文件内声明一个只供本文件使用的小组件 StatPill，
    // 下面写 StatPill { ... } 就能复用这套样式
    component StatPill: Rectangle {
        property bool wide: false
        radius: 15
        color: wide ? Qt.rgba(1, 1, 1, 0.048) : Qt.rgba(1, 1, 1, 0.043)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.055)
    }

    // tscn ChipCyan style.
    component ChipCyan: Rectangle {
        radius: 15
        color: Qt.rgba(Theme.cyan.r, Theme.cyan.g, Theme.cyan.b, 0.2)
    }

    // ===================== 训练总览 (SummaryPanel) =====================
    // Godot: Rect2(0,0,588,522) inside HomePageView, PanelSummary style
    // bg (0.067,0.067,0.067,0.69), border white 0.07, radius 36.
    Rectangle {
        id: summaryPanel
        x: 24; y: 18; width: 588; height: 522
        radius: 36
        color: Qt.rgba(Theme.panel.r, Theme.panel.g, Theme.panel.b, 0.69)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.07)

        // SummaryDot (42,40.5,15,15), cyan square.
        Rectangle { x: 42; y: 40.5; width: 15; height: 15; color: Theme.cyan }
        // SummaryTitle (63,34.5,342,33) font 29.
        Text {
            x: 63; y: 34.5; width: 342; height: 33
            text: "训练总览"; color: Theme.text; font.pixelSize: 29
        }
        // SummaryMeta (417,33,144,30) right-aligned font 17.
        Text {
            x: 417; y: 33; width: 144; height: 30
            text: "概览"; color: Theme.muted; font.pixelSize: 17
            horizontalAlignment: Text.AlignRight
        }

        // BattleLevel (27,87,534,57) InnerDark12: black 0.29, radius 18.
        // Godot label fills the bar: "战斗等级" flush left, "专业级" flush
        // right (tscn pads with spaces to right-align at font 23).
        Rectangle {
            x: 27; y: 87; width: 534; height: 57
            radius: 18; color: Qt.rgba(0, 0, 0, 0.29)
            Text {
                x: 18; width: 300; anchors.verticalCenter: parent.verticalCenter
                text: "战斗等级"; color: Theme.text; font.pixelSize: 23
            }
            Text {
                x: 318; width: 534 - 318 - 18; anchors.verticalCenter: parent.verticalCenter
                text: page.summary.battleLevel; color: Theme.text; font.pixelSize: 23
                horizontalAlignment: Text.AlignRight
            }
        }

        // ScorePanel (27,156,534,114) InnerDark13: black 0.24, radius 20.
        // Three 177-wide blocks: value font 45 + caption font 17 muted 0.88.
        Rectangle {
            x: 27; y: 156; width: 534; height: 114
            radius: 20; color: Qt.rgba(0, 0, 0, 0.24)
            // Repeater：数据驱动渲染——model 里有几项，就把 delegate 实例化几份；
            // delegate 里用 required property 声明从模型接收的数据
            Repeater {
                model: [
                    { "v": page.summary.power,     "c": page.summary.powerLabel },
                    { "v": page.summary.speed,     "c": page.summary.speedLabel },
                    { "v": page.summary.endurance, "c": page.summary.enduranceLabel }
                ]
                delegate: Item {
                    id: scoreBlock
                    required property int index
                    required property var modelData
                    // Godot blocks: (3,18,177,51) / (178.5,18,177,51) / (355.5,18,175.5,51)
                    x: 3 + scoreBlock.index * 177; width: 177; height: 114
                    Text {
                        x: 0; y: 18; width: 177; height: 51
                        text: scoreBlock.modelData.v; color: Theme.text; font.pixelSize: 45
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        x: 0; y: 75; width: 177; height: 27
                        text: scoreBlock.modelData.c; font.pixelSize: 17
                        color: Qt.rgba(Theme.muted.r, Theme.muted.g, Theme.muted.b, 0.88)
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }

        // HistoryIcon (27,294,24,24) + HistoryLabel (63,288,477,36) font 20.
        HmiIcon { x: 27; y: 294; size: 24; name: "history"; tone: "cyan" }
        Text {
            x: 63; y: 288; width: 477; height: 36
            text: "过去 7 天数据"; font.pixelSize: 20
            color: Qt.rgba(Theme.muted.r, Theme.muted.g, Theme.muted.b, 0.94)
        }

        // ImpactPill (27,324,534,72) wide pill; hand-fist icon (52.5,345,27).
        StatPill {
            x: 27; y: 324; width: 534; height: 72; wide: true
            HmiIcon { x: 25.5; y: 21; size: 27; name: "hand-fist"; tone: "orange" }
            Text {
                x: 75; y: 10.5; width: 438; height: 31.5
                text: page.summary.impact; color: Theme.orange; font.pixelSize: 24
            }
            Text {
                x: 75; y: 40.5; width: 438; height: 25.5
                text: page.summary.impactLabel; font.pixelSize: 14
                color: Qt.rgba(Theme.orange.r, Theme.orange.g, Theme.orange.b, 0.76)
            }
        }

        // Four mini pills 259.5x54 at (27,405) (298.5,405) (27,463.5) (298.5,463.5):
        // icon 24px at pill-local (25.5,15), value font 23 at (64.5,6),
        // caption font 14 at (64.5,33).
        Repeater {
            model: [
                { "px": 27,    "py": 405,   "icon": "timer",    "tone": "cyan",   "c": Theme.cyan,
                  "v": page.summary.duration,  "l": page.summary.durationLabel },
                { "px": 298.5, "py": 405,   "icon": "flame",    "tone": "red",    "c": Theme.danger,
                  "v": page.summary.calories,  "l": page.summary.caloriesLabel },
                { "px": 27,    "py": 463.5, "icon": "zap",      "tone": "yellow", "c": Theme.warn,
                  "v": page.summary.strikes,   "l": page.summary.strikesLabel },
                { "px": 298.5, "py": 463.5, "icon": "activity", "tone": "green",  "c": Theme.success,
                  "v": page.summary.frequency, "l": page.summary.frequencyLabel }
            ]
            delegate: StatPill {
                id: miniPill
                required property var modelData
                x: miniPill.modelData.px; y: miniPill.modelData.py; width: 259.5; height: 54
                HmiIcon { x: 25.5; y: 15; size: 24; name: miniPill.modelData.icon; tone: miniPill.modelData.tone }
                Text {
                    x: 64.5; y: 6; width: 193.5; height: 27
                    text: miniPill.modelData.v; color: miniPill.modelData.c; font.pixelSize: 23
                }
                Text {
                    x: 64.5; y: 33; width: 193.5; height: 21
                    text: miniPill.modelData.l; font.pixelSize: 14
                    color: Qt.rgba(miniPill.modelData.c.r, miniPill.modelData.c.g, miniPill.modelData.c.b, 0.74)
                }
            }
        }
    }

    // ===================== 训练日程 (SchedulePanel) =====================
    // Godot: Rect2(0,549,588,291), PanelSchedule bg alpha 0.66, radius 36.
    Rectangle {
        id: schedulePanel
        x: 24; y: 567; width: 588; height: 291
        radius: 36
        color: Qt.rgba(Theme.panel.r, Theme.panel.g, Theme.panel.b, 0.66)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.07)

        // ScheduleTitle (63,31.5,312,36) font 29.
        Text {
            x: 63; y: 31.5; width: 312; height: 36
            text: "训练日程"; color: Theme.text; font.pixelSize: 29
        }
        // ScheduleMeta (417,30,144,30) right, cyan, font 17.
        Text {
            x: 417; y: 30; width: 144; height: 30
            text: "即将开始"; color: Theme.cyan; font.pixelSize: 17
            horizontalAlignment: Text.AlignRight
        }

        // WeekStrip (60,75,489,57): HBox separation 24, days 14..20, font 16
        // (Godot default); selected day "16" cyan, others muted
        // (home_page_view.gd _update_schedule).
        Row {
            x: 60; y: 75; height: 57; spacing: 24
            // model 也可以是纯数字：表示重复 7 次，delegate 里用 index 区分每一项
            Repeater {
                model: 7
                delegate: Text {
                    required property int index
                    text: String(14 + index)
                    font.pixelSize: 16
                    color: text === "16" ? Theme.cyan : Theme.muted
                }
            }
        }

        // BookingLabelIcon (28.5,150,24,24) + BookingLabel (63,144,267,33).
        HmiIcon { x: 28.5; y: 150; size: 24; name: "target"; tone: "red" }
        Text {
            x: 63; y: 144; width: 267; height: 33
            text: "课程预约"; font.pixelSize: 20
            color: Qt.rgba(Theme.muted.r, Theme.muted.g, Theme.muted.b, 0.94)
        }
        // BookingStatus (483,162,78,27) right, danger, font 18.
        Text {
            x: 483; y: 162; width: 78; height: 27
            text: page.summary.bookingStatus; color: Theme.danger; font.pixelSize: 18
            horizontalAlignment: Text.AlignRight
        }

        // BookingCard (27,183,534,87): black 0.27, radius 20.
        Rectangle {
            x: 27; y: 183; width: 534; height: 87
            radius: 20; color: Qt.rgba(0, 0, 0, 0.27)
        }
        // BookingImage (42,195,132,63) KEEP_ASPECT_COVERED.
        Image {
            x: 42; y: 195; width: 132; height: 63
            source: "qrc:/resources/images/home/home_course_booking.png"
            fillMode: Image.PreserveAspectCrop
            clip: true
            smooth: true
        }
        // BookingBadge (49.5,237,75,18) cyan 0.78 radius 6, text font 11 dark.
        Rectangle {
            x: 49.5; y: 237; width: 75; height: 18
            radius: 6; color: Qt.rgba(Theme.cyan.r, Theme.cyan.g, Theme.cyan.b, 0.78)
            Text {
                anchors.centerIn: parent
                text: page.summary.bookingBadge; font.pixelSize: 11
                color: Qt.rgba(0.02, 0.05, 0.08, 1)
            }
        }
        // BookingText (189,202.5,288,61.5) font 23, two lines. Split into two
        // Texts at Godot's 30px line pitch (rect 61.5 / 2) -- Qt's default
        // line spacing for Alimama is much taller than Godot's.
        Text {
            x: 189; y: 202.5; width: 288; height: 30
            text: page.summary.bookingTitle
            color: Theme.text; font.pixelSize: 23
        }
        Text {
            x: 189; y: 232.5; width: 288; height: 31.5
            text: page.summary.bookingMeta
            color: Theme.text; font.pixelSize: 23
        }
        // BookingDurationIcon (189,246,18) + BookingDuration (210,240,66,27) font 15.
        HmiIcon { x: 189; y: 246; size: 18; name: "timer"; tone: "cyan" }
        Text {
            x: 210; y: 240; width: 66; height: 27
            text: page.summary.bookingDuration; color: Theme.text; font.pixelSize: 15
        }
        // BookingCaloriesIcon (294,246,18) + BookingCalories (315,240,81,27) font 15.
        HmiIcon { x: 294; y: 246; size: 18; name: "flame"; tone: "red" }
        Text {
            x: 315; y: 240; width: 81; height: 27
            text: page.summary.bookingCalories; color: Theme.text; font.pixelSize: 15
        }
        // BookingDifficultyBadge (459,240,87,19.5) warn 0.2 radius 8, font 11.
        Rectangle {
            x: 459; y: 240; width: 87; height: 19.5
            radius: 8; color: Qt.rgba(Theme.warn.r, Theme.warn.g, Theme.warn.b, 0.2)
            Text {
                anchors.centerIn: parent
                text: page.summary.bookingDifficulty; font.pixelSize: 11
                color: Theme.warn
            }
        }
    }

    // ===================== 发现课程 (DiscoverPanel) =====================
    // Godot: Rect2(615,0,1161,840), PanelDiscover bg alpha 0.61, radius 36.
    Rectangle {
        id: discoverPanel
        x: 639; y: 18; width: 1161; height: 840
        radius: 36
        color: Qt.rgba(Theme.panel.r, Theme.panel.g, Theme.panel.b, 0.61)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.07)

        // DiscoverTitle (66,34.5,534,34.5) font 29.
        Text {
            x: 66; y: 34.5; width: 534; height: 34.5
            text: "发现课程"; color: Theme.text; font.pixelSize: 29
        }

        // Hero (30,93,1101,450): image covered + frame border radius 27
        // white 0.12 + bottom overlay (0,243,1101,207) black 0.45.
        Item {
            id: hero
            x: 30; y: 93; width: 1101; height: 450
            clip: true

            Image {
                anchors.fill: parent
                source: "qrc:/resources/images/home/home_hero_course.png"
                fillMode: Image.PreserveAspectCrop
                smooth: true
            }
            // HeroOverlay (0,243,1101,207).
            Rectangle { x: 0; y: 243; width: 1101; height: 207; color: Qt.rgba(0, 0, 0, 0.45) }
            // HeroFrame: transparent fill, border only (drawn above image).
            Rectangle {
                anchors.fill: parent
                radius: 27; color: "transparent"
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.12)
            }
            // HeroTag (24,30,246,30) ChipDanger: danger 0.2 + border 0.48.
            Rectangle {
                x: 24; y: 30; width: 246; height: 30
                radius: 15
                color: Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.2)
                border.width: 1
                border.color: Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.48)
                Text {
                    anchors.centerIn: parent
                    text: "精选大师课程"; color: Theme.danger; font.pixelSize: 14
                }
            }
            // HeroTitle (33,338,882,57) font 39.
            Text {
                x: 33; y: 338; width: 882; height: 57
                text: page.summary.heroTitle; color: Theme.text; font.pixelSize: 39
            }
            // HeroDurationChip (33,397.5,87,27), text font 14 near-white.
            ChipCyan {
                x: 33; y: 397.5; width: 87; height: 27
                Text {
                    anchors.centerIn: parent
                    text: page.summary.heroDuration; color: Theme.text; font.pixelSize: 14
                }
            }
            // HeroCaloriesChip (132,397.5,99,27), text font 14 cyan.
            ChipCyan {
                x: 132; y: 397.5; width: 99; height: 27
                Text {
                    anchors.centerIn: parent
                    text: page.summary.heroCalories; color: Theme.cyan; font.pixelSize: 14
                }
            }
            // HeroMeta (246,418.5,339,31.5) font 15 muted.
            Text {
                x: 246; y: 418.5; width: 339; height: 31.5
                text: page.summary.heroMeta; color: Theme.muted; font.pixelSize: 15
            }
            // QuickStartButton (996,346.5,84,84): cyan 0.95 circle, radius 42.
            // Dark play triangle as in home_page.gd _draw_discover_panel.
            Rectangle {
                x: 996; y: 346.5; width: 84; height: 84; radius: 42
                color: Qt.rgba(Theme.cyan.r, Theme.cyan.g, Theme.cyan.b, 0.95)
                Text {
                    anchors.centerIn: parent
                    text: "▶"; font.pixelSize: 30
                    color: Qt.rgba(0.02, 0.06, 0.12, 1)
                }
                ClickFlash { id: quickFlash; radius: 42 }
                // 交互信号流范本：TapHandler 捕获点击 -> ClickFlash 播放点击动效
                // -> AppState.showCallout(...) 写入全局状态 -> CalloutHost 弹气泡。
                // 页面不直接操作气泡组件，只改 AppState 单例（见导读第 2 条）。
                TapHandler {
                    onTapped: {
                        quickFlash.flash();
                        AppState.showCallout("info", "未移植",
                            page.summary.heroTitle + "将在后续阶段移植");
                    }
                }
            }
        }

        // RecommendTitle (57,574.5,303,36) font 18 muted.
        Text {
            x: 57; y: 574.5; width: 303; height: 36
            text: "推荐内容"; color: Theme.muted; font.pixelSize: 18
        }

        // RecommendationClip (30,630,1101,180): horizontal rail of 438x177
        // cards with 24px gap (home_page_view.gd RECOMMEND_CARD_SIZE/GAP).
        // Flickable：QML 的可滑动容器。width 是可视窗口宽度，contentWidth
        // 是内容总宽度；内容比窗口宽时即可横向拖动/甩动。
        Flickable {
            id: recFlick
            x: 30; y: 630; width: 1101; height: 180
            clip: true
            contentWidth: recRow.width
            contentHeight: 180
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds

            Row {
                id: recRow
                spacing: 24
                // 推荐卡片列表：model 来自本页数据，封面图经 ShellData.coverFor 查得
                Repeater {
                    model: page.recommendations
                    delegate: Item {
                        id: recCard
                        required property var modelData
                        width: 438; height: 177

                        Image {
                            anchors.fill: parent
                            source: ShellData.coverFor(recCard.modelData.id)
                            fillMode: Image.PreserveAspectCrop
                            clip: true
                            smooth: true
                        }
                        // 底部渐变压暗：从全透明过渡到黑 0.55，避免生硬分界线
                        Rectangle {
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 102
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0) }    // 顶部全透明
                                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.55) } // 底部较暗
                            }
                        }
                        // CardFrame: border white 0.1, radius 24.
                        Rectangle {
                            anchors.fill: parent
                            radius: 24; color: "transparent"
                            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.1)
                        }
                        // CardTag (21,21,135,27) ChipCyan, text font 12 cyan.
                        ChipCyan {
                            x: 21; y: 21; width: 135; height: 27
                            Text {
                                anchors.centerIn: parent
                                text: recCard.modelData.tag; color: Theme.cyan; font.pixelSize: 12
                            }
                        }
                        // CardTitle (21,117,393,36) font 27.
                        Text {
                            x: 21; y: 117; width: 393; height: 36
                            text: recCard.modelData.title; color: Theme.text; font.pixelSize: 27
                        }
                        // CardMeta (21,148.5,393,25.5) font 15 muted.
                        Text {
                            x: 21; y: 148.5; width: 393; height: 25.5
                            text: recCard.modelData.meta; color: Theme.muted; font.pixelSize: 15
                        }
                        ClickFlash { id: cardFlash; radius: 24 }
                        TapHandler {
                            onTapped: {
                                cardFlash.flash();
                                AppState.showCallout("info", "未移植",
                                    recCard.modelData.title + "将在后续阶段移植");
                            }
                        }
                    }
                }
            }
        }

        // RecommendScrollTrack (39,828,1083,6) white 0.16.
        Rectangle { x: 39; y: 828; width: 1083; height: 6; color: Qt.rgba(1, 1, 1, 0.16) }
        // RecommendScrollThumb: 2px at track y+1, white 0.34; width/position
        // follow home_page_view.gd _update_scroll_thumb.
        // 滚动条滑块：宽度和位置都是属性绑定表达式，跟随 recFlick 的滚动自动更新
        Rectangle {
            readonly property real maxScroll: Math.max(0, recFlick.contentWidth - recFlick.width)
            readonly property real thumbWidth: recFlick.contentWidth > 0
                ? Math.min(Math.max(1083 * recFlick.width / recFlick.contentWidth, 78), 1083)
                : 1083
            x: 39 + (maxScroll > 0 ? (recFlick.contentX / maxScroll) * (1083 - thumbWidth) : 0)
            y: 829; width: thumbWidth; height: 2
            color: Qt.rgba(1, 1, 1, 0.34)
        }
    }
}
