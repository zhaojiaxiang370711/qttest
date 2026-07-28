pragma ComponentBehavior: Bound
import QtQuick
import QxznHmi

// 实战对练页：Godot scripts/pages/result_page.gd（tab1 启动器）
// + scripts/pages/sparring_history_page.gd（tab2 训练数据）。
// Godot 按 1280x720 基准自绘、运行时 x1.5；页面局部坐标 = Theme.px(v) - (48,150)。
Item {
    id: page

    // Godot result_page.gd: result_tab / DEFAULT_SELECTED_DRILL_INDICES [0, 2]。
    property string resultTab: "result"
    property var selectedDrills: [0, 2]

    // Godot 面板色带不同 alpha，Theme 无对应 token（TopBar.qml 同款惯例）。
    readonly property color panelTabs: Qt.rgba(0.067, 0.067, 0.067, 0.62)   // tab 条 / 指标卡
    readonly property color panelSoft: Qt.rgba(0.067, 0.067, 0.067, 0.58)   // 今日/趋势/记录卡

    // 指标卡矩形（sparring_history_page.gd draw()，1280 基准）。
    readonly property var metricRects: [
        Qt.rect(56, 206, 260, 100),
        Qt.rect(340, 206, 260, 100),
        Qt.rect(624, 206, 260, 100),
        Qt.rect(908, 206, 316, 100)
    ]
    readonly property var drillTitles: ["专业", "漏洞攻击", "防守练习", "猛烈攻击"]

    // draw_text/draw_text_fit 的原点在文字基线；draw_center_text 的
    // baseline = rect 中心 + 字高*0.35。据此把 Godot 基线 y 换算成垂直居中
    // Text 的 item y。parentLocalY 为父项在页面内的局部 y（页面根传 0）。
    function textH(godotSize) {
        return Math.round(Theme.fontPx(godotSize) * 1.4);
    }
    function baselineY(parentLocalY, godotY, godotSize, itemH) {
        return Theme.px(godotY) - 150 - parentLocalY - Math.round(Theme.fontPx(godotSize) * 0.35) - Math.round(itemH / 2);
    }
    function toggleDrill(i) {
        let arr = page.selectedDrills.slice();
        const at = arr.indexOf(i);
        if (at >= 0)
            arr.splice(at, 1);
        else
            arr.push(i);
        page.selectedDrills = arr;
    }

    // ================= tab1 实战对练（result_page.gd 启动器） =================
    Item {
        id: sparringTab
        anchors.fill: parent
        visible: page.resultTab === "result"

        // 预览面板：Godot Rect2(56,134,1168,514)@1280。
        Rectangle {
            x: Theme.px(56) - 48
            y: Theme.px(134) - 150
            width: Theme.px(1168)
            height: Theme.px(514)
            radius: Theme.px(12)
            color: Qt.rgba(0, 0, 0, 0.96)            // Godot 面板底色 (0,0,0,0.96)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.12)     // Godot 外描边 (1,1,1,0.12)

            // 视频帧封面：content = rect.grow(-2)，居中裁剪（_draw_cover_texture）。
            // Godot 播放 sparring_preview_source.mp4；移植版用抽取的静态帧。
            Image {
                x: 3
                y: 3
                width: Theme.px(1164)
                height: Theme.px(510)
                source: "qrc:/resources/images/sparring_preview_frame.jpg"
                fillMode: Image.PreserveAspectCrop
                smooth: true
            }

            // 底部聚焦遮罩（_draw_bottom_focus_mask，高 min(190, h*0.42)=190@1280）。
            // Godot 是逐像素纵向 pow(t,1.55) x 横向中心衰减纹理；按任务约定
            // 用纵向渐变近似（峰值 alpha 0.42，中间两点采样自 pow 曲线）。
            Rectangle {
                x: 3
                y: Theme.px(456) - Theme.px(134)      // content.end.y - 190 -> 面板局部
                width: Theme.px(1164)
                height: Theme.px(190)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0.143) }  // 0.42*0.5^1.55
                    GradientStop { position: 0.8; color: Qt.rgba(0, 0, 0, 0.297) }  // 0.42*0.8^1.55
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.42) }
                }
            }

            // Godot 内描边 rect.grow(-1)，(0,0,0,0.42)，radius 11@1280。
            Rectangle {
                x: Theme.px(57) - Theme.px(56)
                y: Theme.px(135) - Theme.px(134)
                width: Theme.px(1166)
                height: Theme.px(512)
                radius: Theme.px(11)
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.42)
            }
        }

        // 练习标签行：Godot Rect2(71,517,1138,38)，"  |  " 相连居中，字号 24。
        Item {
            x: Theme.px(71) - 48
            y: Theme.px(517) - 150
            width: Theme.px(1138)
            height: Theme.px(38)

            Row {
                anchors.centerIn: parent
                spacing: 0
                Repeater {
                    model: page.drillTitles.length
                    delegate: Item {
                        id: drillLabel
                        required property int index
                        readonly property bool selected: page.selectedDrills.indexOf(drillLabel.index) >= 0
                        width: labelText.implicitWidth + (drillLabel.index < 3 ? sepText.implicitWidth : 0)
                        height: labelText.implicitHeight

                        Text {
                            id: labelText
                            text: page.drillTitles[drillLabel.index]
                            // Godot 标签统一白色 0.96 且无点击；按任务要求选中态上色。
                            color: drillLabel.selected ? Theme.primary : Qt.rgba(1, 1, 1, 0.96)
                            font.pixelSize: Theme.fontPx(24)
                        }
                        Text {
                            id: sepText
                            x: labelText.implicitWidth
                            visible: drillLabel.index < 3
                            text: "  |  "
                            color: Qt.rgba(1, 1, 1, 0.96)
                            font.pixelSize: Theme.fontPx(24)
                        }
                        TapHandler {
                            onTapped: page.toggleDrill(drillLabel.index)
                        }
                    }
                }
            }
        }

        // 开练按钮：Godot Rect2(180,567,920,76)，白色胶囊，radius = h/2。
        Rectangle {
            id: startButton
            x: Theme.px(180) - 48
            y: Theme.px(567) - 150
            width: Theme.px(920)
            height: Theme.px(76)
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.985)           // Godot 按钮填充 (1,1,1,0.985)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.86)     // Godot 描边 (1,1,1,0.86)
            transformOrigin: Item.Center
            scale: startTap.pressed ? 0.98 : 1.0     // Godot 按下时 rect.grow(-2)
            Behavior on scale { NumberAnimation { duration: 80 } }

            // flame 图标：Godot 中心 + (-54,0)，size 36@1280，色 (0.08,0.08,0.08)。
            HmiIcon {
                x: Theme.px(568) - 48 - startButton.x
                y: Theme.px(587) - 150 - startButton.y
                name: "flame"
                tone: "muted"                        // 无深灰烘焙变体，muted 最接近
                size: Theme.px(36)
            }
            // “开练”：Godot draw_center_text Rect2(620,567,124,76)，字号 30，黑色。
            Text {
                x: Theme.px(620) - 48 - startButton.x
                y: 0
                width: Theme.px(124)
                height: startButton.height
                text: "开练"
                color: "#000000"
                font.pixelSize: Theme.fontPx(30)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            TapHandler {
                id: startTap
                onTapped: {
                    startFlash.flash();
                    AppState.showCallout("info", "未移植", "内嵌游戏将在后续阶段移植");
                }
            }
            ClickFlash {
                id: startFlash
                radius: startButton.radius            // Godot 白色点击闪光
            }
        }
    }

    // ================= tab2 训练数据（sparring_history_page.gd） =================
    Item {
        id: historyTab
        anchors.fill: parent
        visible: page.resultTab === "history"

        // -- 4 张指标卡：Rect2(56/340/624/908,206,260/316,100)，radius 20@1280 --
        Repeater {
            model: ShellData.sparringSummary.metricCards
            delegate: HmiCard {
                id: metricCard
                required property int index
                required property var modelData
                readonly property rect godotRect: page.metricRects[metricCard.index]

                x: Theme.px(godotRect.x) - 48
                y: Theme.px(godotRect.y) - 150
                width: Theme.px(godotRect.width)
                height: Theme.px(godotRect.height)
                radius: Theme.px(20)
                fillColor: page.panelTabs

                // 标题：draw_center_text Rect2(pos+(10,16),(w-20,24))，字号 15。
                Text {
                    x: Theme.px(10)
                    y: Theme.px(16)
                    width: metricCard.width - Theme.px(20)
                    height: Theme.px(24)
                    text: metricCard.modelData.title
                    color: Theme.muted
                    font.pixelSize: Theme.fontPx(15)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                // 数值：draw_center_text Rect2(pos+(10,48),(w-20,42))，字号 32。
                Text {
                    x: Theme.px(10)
                    y: Theme.px(48)
                    width: metricCard.width - Theme.px(20)
                    height: Theme.px(42)
                    text: metricCard.modelData.value
                    color: metricCard.modelData.color
                    font.pixelSize: Theme.fontPx(32)
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: Theme.fontPx(10)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                // 装饰圆环：draw_arc 中心 (pos.x+w-26, pos.y+25)，r 12，alpha 0.35。
                Rectangle {
                    x: Theme.px(metricCard.godotRect.width - 38)
                    y: Theme.px(13)
                    width: Theme.px(24)
                    height: Theme.px(24)
                    radius: Theme.px(12)
                    color: "transparent"
                    border.width: Theme.px(2)
                    border.color: metricCard.modelData.color
                    opacity: 0.35
                }
            }
        }

        // -- 今日消耗卡：Godot Rect2(56,342,286,142)，radius 22@1280 --
        HmiCard {
            id: todayCard
            x: Theme.px(56) - 48
            y: Theme.px(342) - 150
            width: Theme.px(286)
            height: Theme.px(142)
            radius: Theme.px(22)
            fillColor: page.panelSoft

            // 标题 draw_text pos+(20,35)，字号 21。
            Text {
                x: Theme.px(20)
                y: page.baselineY(todayCard.y, 342 + 35, 21, height)
                width: todayCard.width - Theme.px(40)
                height: page.textH(21)
                text: "今日消耗估算"
                color: Theme.text
                font.pixelSize: Theme.fontPx(21)
                verticalAlignment: Text.AlignVCenter
            }
            // 汇总 draw_text_fit pos+(20,66)，字号 18，橙色。
            Text {
                x: Theme.px(20)
                y: page.baselineY(todayCard.y, 342 + 66, 18, height)
                width: todayCard.width - Theme.px(40)
                height: page.textH(18)
                text: ShellData.sparringSummary.todayText
                color: Theme.orange
                font.pixelSize: Theme.fontPx(18)
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: Theme.fontPx(12)
                verticalAlignment: Text.AlignVCenter
            }
            // 子行 draw_text_fit pos+(20,96)，字号 13。
            Text {
                x: Theme.px(20)
                y: page.baselineY(todayCard.y, 342 + 96, 13, height)
                width: todayCard.width - Theme.px(40)
                height: page.textH(13)
                text: ShellData.sparringSummary.todaySub
                color: Theme.muted
                font.pixelSize: Theme.fontPx(13)
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: Theme.fontPx(11)
                verticalAlignment: Text.AlignVCenter
            }
        }

        // -- 趋势卡：Godot Rect2(364,342,860,142)，radius 22@1280 --
        HmiCard {
            id: trendCard
            x: Theme.px(364) - 48
            y: Theme.px(342) - 150
            width: Theme.px(860)
            height: Theme.px(142)
            radius: Theme.px(22)
            fillColor: page.panelSoft

            // 标题 draw_text pos+(20,35)，字号 21。
            Text {
                x: Theme.px(20)
                y: page.baselineY(trendCard.y, 342 + 35, 21, height)
                width: trendCard.width - Theme.px(40)
                height: page.textH(21)
                text: "近 7 天训练趋势"
                color: Theme.text
                font.pixelSize: Theme.fontPx(21)
                verticalAlignment: Text.AlignVCenter
            }
            // 绘图区：Godot Rect2(pos+(24,58),(w-48,54))。
            HmiBarChart {
                id: chart
                x: Theme.px(24)
                y: Theme.px(58)
                width: trendCard.width - Theme.px(48)
                height: Theme.px(54)
                values: ShellData.sparringSummary.trendValues
                barSpacing: Theme.px(12)
                barRadius: Theme.px(6)
            }
            // 柱顶数值：draw_center_text (bar.x, plot.y-18, bar.w, 16)，字号 10。
            Repeater {
                model: ShellData.sparringSummary.trendValues
                delegate: Text {
                    id: valueLabel
                    required property int index
                    required property real modelData
                    readonly property real barW: (chart.width - chart.barSpacing * 6) / 7
                    x: chart.x + valueLabel.index * (barW + chart.barSpacing)
                    y: chart.y - Theme.px(18)
                    width: barW
                    height: Theme.px(16)
                    text: valueLabel.modelData
                    color: Theme.text
                    font.pixelSize: Theme.fontPx(10)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
            // 柱底日期：draw_center_text (bar.x, plot.end.y+7, bar.w, 16)，字号 9。
            Repeater {
                model: ShellData.sparringSummary.trendDates
                delegate: Text {
                    id: dateLabel
                    required property int index
                    required property string modelData
                    readonly property real barW: (chart.width - chart.barSpacing * 6) / 7
                    x: chart.x + dateLabel.index * (barW + chart.barSpacing)
                    y: chart.y + chart.height + Theme.px(7)
                    width: barW
                    height: Theme.px(16)
                    text: dateLabel.modelData
                    color: Theme.muted
                    font.pixelSize: Theme.fontPx(9)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        // -- 最近记录卡：Godot Rect2(56,526,1168,122)，radius 22@1280 --
        HmiCard {
            id: recentCard
            x: Theme.px(56) - 48
            y: Theme.px(526) - 150
            width: Theme.px(1168)
            height: Theme.px(122)
            radius: Theme.px(22)
            fillColor: page.panelSoft

            // 标题 draw_text pos+(20,34)，字号 20。
            Text {
                x: Theme.px(20)
                y: page.baselineY(recentCard.y, 526 + 34, 20, height)
                width: recentCard.width - Theme.px(40)
                height: page.textH(20)
                text: "最近训练记录"
                color: Theme.text
                font.pixelSize: Theme.fontPx(20)
                verticalAlignment: Text.AlignVCenter
            }
            // 行：Godot Rect2(pos.x+20, pos.y+54+i*22, w-40, 20)。
            Repeater {
                model: ShellData.sparringSummary.recentRecords
                delegate: Rectangle {
                    id: recordRow
                    required property int index
                    required property var modelData
                    x: Theme.px(20)
                    y: Theme.px(54 + recordRow.index * 22)
                    width: recentCard.width - Theme.px(40)
                    height: Theme.px(20)
                    radius: Theme.px(8)
                    color: Qt.rgba(1, 1, 1, 0.020)     // Godot 行底 (1,1,1,0.02)

                    // 左：draw_text_fit row.pos+(12,15)，宽 388@1280，字号 12。
                    Text {
                        x: Theme.px(12)
                        y: page.baselineY(recentCard.y + recordRow.y, 526 + 54 + recordRow.index * 22 + 15, 12, height)
                        width: Theme.px(388)
                        height: page.textH(12)
                        text: recordRow.modelData.date + "  " + recordRow.modelData.difficulty + "  ·  " + recordRow.modelData.course
                        color: Theme.muted
                        font.pixelSize: Theme.fontPx(12)
                        fontSizeMode: Text.HorizontalFit
                        minimumPixelSize: Theme.fontPx(10)
                        verticalAlignment: Text.AlignVCenter
                    }
                    // 中：draw_center_text Rect2(row.x+430, row.y+2, 130, 17)，字号 12。
                    Text {
                        x: Theme.px(430)
                        y: Theme.px(2)
                        width: Theme.px(130)
                        height: Theme.px(17)
                        text: recordRow.modelData.hits + " 次"
                        color: Theme.text
                        font.pixelSize: Theme.fontPx(12)
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    // 右：draw_text_fit row.pos+(row.w-360, 15)，宽 340@1280，字号 12。
                    Text {
                        x: recordRow.width - Theme.px(360)
                        y: page.baselineY(recentCard.y + recordRow.y, 526 + 54 + recordRow.index * 22 + 15, 12, height)
                        width: Theme.px(340)
                        height: page.textH(12)
                        text: recordRow.modelData.source + " · 最佳连击 " + recordRow.modelData.maxStreak + "  /  最大力量 " + recordRow.modelData.maxPower
                        color: Theme.primary
                        font.pixelSize: Theme.fontPx(12)
                        fontSizeMode: Text.HorizontalFit
                        minimumPixelSize: Theme.fontPx(10)
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }

    // ================= 双 tab 条（result_page.gd _draw_tabs） =================
    // Godot 仅在 history 页画 tab 条；移植版双 tab 常驻，否则训练数据不可达
    //（网页版 TrainingResultPage 同样常驻）。tab1 上它浮在预览面板左上角。
    HmiCard {
        id: tabShell
        x: Theme.px(56) - 48
        y: Theme.px(134) - 150
        width: Theme.px(332)
        height: Theme.px(48)
        radius: Theme.px(18)
        fillColor: page.panelTabs

        // Godot tab rect: shell.pos + (8+i*158, 7)，size (150,34)，radius 14@1280。
        Repeater {
            model: [
                { "id": "result", "label": "实战对练" },
                { "id": "history", "label": "训练数据" }
            ]
            delegate: Rectangle {
                id: tabRect
                required property int index
                required property var modelData
                readonly property bool active: page.resultTab === tabRect.modelData.id

                x: Theme.px(8 + tabRect.index * 158)
                y: Theme.px(7)
                width: Theme.px(150)
                height: Theme.px(34)
                radius: Theme.px(14)
                // Godot：active primary a=0.24，inactive a=0.035（HMI_PRIMARY 无 token）。
                color: tabRect.active ? Qt.rgba(0, 0.941, 1, 0.24) : Qt.rgba(0, 0.941, 1, 0.035)

                Text {
                    anchors.fill: parent
                    text: tabRect.modelData.label
                    color: tabRect.active ? Theme.primary : Theme.muted
                    font.pixelSize: Theme.fontPx(15)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                TapHandler {
                    onTapped: {
                        tabFlash.flash();
                        page.resultTab = tabRect.modelData.id;
                    }
                }
                ClickFlash {
                    id: tabFlash
                    flashColor: Theme.primary          // Godot set_click_flash(HMI_PRIMARY)
                    radius: tabRect.radius
                }
            }
        }
    }

    // Godot _draw_tabs 的注释文字：draw_text (410,165)，字号 15。
    Text {
        x: Theme.px(410) - 48
        y: page.baselineY(0, 165, 15, height)
        width: Theme.px(200)
        height: page.textH(15)
        text: "网页同款双标签切换"
        color: Theme.muted
        font.pixelSize: Theme.fontPx(15)
        verticalAlignment: Text.AlignVCenter
    }
}
