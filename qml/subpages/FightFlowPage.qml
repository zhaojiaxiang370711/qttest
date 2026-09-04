pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QxznHmi

// Fight Flow 搏击燃脂课程播放页:复刻 lessons_test Web 原型(与 Godot 版
// modules/course/internal/fight_flow_page.gd + fight_flow_player_view.gd 同构)。
// 布局常量沿用 Godot 版 1280×720 设计坐标,经 Theme.px() 放大到 1920×1080。
// 视频走 CoursePlayer(GStreamer);击打/热量/趋势为模拟数据(移植 app.js),
// 后续可替换为 DDS 真实击打事件。
Item {
    id: page
    anchors.fill: parent

    // ---- 原型配色(styles.css)----
    readonly property color canvasBg: "#080b0c"
    readonly property color textColor: "#f5f7f4"
    readonly property color mutedColor: "#b4bcb8"
    readonly property color faintColor: "#7e8883"
    readonly property color accent: "#cfff2e"
    readonly property color accentSoft: Qt.rgba(0.812, 1.0, 0.18, 0.16)
    readonly property color forceColor: "#ff9f2b"
    readonly property color panelBg: Qt.rgba(0.031, 0.047, 0.051, 0.6)
    readonly property color panelBorder: Qt.rgba(0.91, 0.94, 0.92, 0.17)
    readonly property color nextRed: Qt.rgba(1.0, 0.3, 0.27, 0.82)

    // ---- 章节配置(lesson_assets/fight_flow/sisi_bodycombat_01.json)----
    readonly property var chapters: [
        { name: "右勾拳x2 + 左摇闪 + 左摆拳", start: 0.0, end: 44.0, target: 20,
          nextHit: "头部右侧", nextStrike: "准备右勾拳" },
        { name: "直拳冲刺", start: 44.0, end: 80.0, target: 30,
          nextHit: "头部中间", nextStrike: "准备连续直拳" },
        { name: "【重击】右勾拳x2 + 左摇闪 + 左摆拳", start: 80.0, end: 122.0, target: 20,
          nextHit: "头部右侧", nextStrike: "准备重击右勾拳" }
    ]
    // 与 app.js zoneByTarget 一致:下一击打部位文案 → 热力图区域索引
    readonly property var zoneByTarget: [
        ["头部左", 0], ["头部中", 1], ["准备姿势", 3], ["头部右", 2],
        ["腹部左", 5], ["腹部中", 8], ["腹部右", 6]
    ]

    // ---- 演示状态(app.js / fight_flow_page.gd 初值)----
    property int chapterIndex: 0
    property int currentHits: 14
    property int totalHits: 245
    property real calories: 128.0
    property int maxPower: 130
    property var hitDistribution: [8, 15, 22, 6, 4, 17, 20, 5, 13, 11]
    property var frequency: [6, 6.6, 7.4, 8.5, 9.7, 10.8, 11.5, 11.7, 11.3, 10.6, 10.1, 10.3, 11.2, 12.6, 14.1, 15.2, 15.6, 15.1, 14.2, 13.7, 14, 15, 16.4, 17.6, 18.1, 17.8, 17.2, 17.5, 18.4, 19.2]
    property var power: [48, 52, 57, 63, 68, 72, 74, 73, 69, 64, 61, 62, 67, 74, 82, 88, 91, 89, 84, 80, 81, 86, 93, 98, 96, 91, 88, 90, 95, 99]
    property real pendingFrequency: 18.8
    property real pendingPower: 96.0
    property real chartPhase: 0.0
    property bool frequencyVisible: true
    property bool powerVisible: true
    property bool drawerOpen: false

    readonly property bool playing: CoursePlayer.state === "playing"
    readonly property bool ended: CoursePlayer.state === "ended"
    readonly property var chapter: chapters[chapterIndex]
    readonly property real videoDurationSec: CoursePlayer.durationMs > 0 ? CoursePlayer.durationMs / 1000.0 : 121.154

    Component.onCompleted: Qt.callLater(function() { CoursePlayer.openCourse("fight_flow") })
    Component.onDestruction: CoursePlayer.stop()

    function formatClock(totalSeconds) {
        const seconds = Math.max(0, Math.floor(totalSeconds));
        const h = Math.floor(seconds / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        const s = seconds % 60;
        return (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m + ":"
                + (s < 10 ? "0" : "") + s;
    }

    function elapsedSec() {
        return CoursePlayer.positionMs > 0 ? CoursePlayer.positionMs / 1000.0 : 0;
    }

    function chapterEnd(index) {
        if (index >= chapters.length - 1)
            return videoDurationSec;
        return Math.min(chapters[index].end, videoDurationSec);
    }

    function chapterIndexAt(time) {
        const safe = Math.max(0, Math.min(videoDurationSec, time));
        for (let i = 0; i < chapters.length; ++i) {
            if (safe < chapterEnd(i))
                return i;
        }
        return chapters.length - 1;
    }

    function nextRegionIndex() {
        const nextHit = chapter.nextHit;
        for (let i = 0; i < zoneByTarget.length; ++i) {
            if (nextHit.indexOf(zoneByTarget[i][0]) >= 0)
                return zoneByTarget[i][1];
        }
        return 2;
    }

    function switchChapter(index) {
        const next = Math.max(0, Math.min(chapters.length - 1, index));
        chapterIndex = next;
        currentHits = 0;
        CoursePlayer.seekMs(Math.round(Math.min(chapters[next].start, videoDurationSec) * 1000));
        drawerOpen = false;
        showToast("已切换:" + chapters[next].name);
    }

    function togglePlayback() {
        if (ended) {
            CoursePlayer.replay();
        } else {
            CoursePlayer.togglePlayback();
        }
        showToast(playing ? "训练继续" : "训练已暂停");
    }

    // 移植 app.js simulateHit():65% 命中下一目标区域,否则随机区域
    function simulateHit() {
        if (currentHits >= chapter.target)
            return;
        currentHits += 1;
        totalHits += 1;
        const force = 68 + Math.floor(Math.random() * 68);
        maxPower = Math.max(maxPower, force);
        const target = nextRegionIndex();
        const region = (Math.random() < 0.65 && target >= 0)
                ? target : Math.floor(Math.random() * hitDistribution.length);
        const next = hitDistribution.slice();
        next[region] += 1;
        hitDistribution = next;
        heatmap.flashRegion = -1;
        heatmap.flashRegion = region;
    }

    // 移植 app.js updateChartData():固定长度滑动窗口 + 正弦缓动
    function chartTick() {
        frequency = frequency.slice(1).concat([pendingFrequency]);
        power = power.slice(1).concat([pendingPower]);
        chartPhase += 0.42;
        const frequencyTarget = 15 + Math.sin(chartPhase) * 3.4 + Math.sin(chartPhase * 0.43) * 1.2;
        const powerTarget = 80 + Math.sin(chartPhase * 0.86 + 0.7) * 14 + Math.sin(chartPhase * 0.31) * 5;
        pendingFrequency = Math.max(2, Math.min(20, pendingFrequency * 0.7 + frequencyTarget * 0.3));
        pendingPower = Math.max(20, Math.min(100, pendingPower * 0.72 + powerTarget * 0.28));
        let peak = 0;
        for (let i = 0; i < frequency.length; ++i)
            peak = Math.max(peak, frequency[i]);
        let sum = 0;
        for (let i = 0; i < power.length; ++i)
            sum += power[i];
        summaryLabel.text = "峰值频率 " + Math.round(peak) + " 次/秒 · 平均力量 "
                + Math.round(sum / power.length) + " kgf";
    }

    function showToast(text) {
        toastLabel.text = text;
        toast.visible = true;
        toast.opacity = 1;
        toastAnimation.restart();
    }

    // 图表数据无论是否播放都持续滚动(同 app.js frame())
    Timer {
        interval: 550
        running: page.visible
        repeat: true
        onTriggered: page.chartTick()
    }
    // 图表平滑滚动进度(scrollProgress = accumulator / interval)
    FrameAnimation {
        running: page.visible
        property real accumulator: 0
        onTriggered: {
            accumulator = (accumulator + frameTime * 1000) % 550;
            trendChart.scrollProgress = accumulator / 550;
        }
    }
    // 模拟击打:2.4s 一次,仅播放时
    Timer {
        interval: 2400
        running: page.playing && page.visible
        repeat: true
        onTriggered: page.simulateHit()
    }
    // 热量:0.3 kcal/s,仅播放时
    FrameAnimation {
        running: page.playing && page.visible
        onTriggered: page.calories += 0.3 * frameTime
    }
    // 播放进度驱动章节自动切换(syncVideoTimeline)
    Connections {
        target: CoursePlayer
        function onPlaybackChanged() {
            if (!page.playing)
                return;
            const index = page.chapterIndexAt(CoursePlayer.positionMs / 1000.0);
            if (index !== page.chapterIndex) {
                page.chapterIndex = index;
                page.currentHits = 0;
            }
        }
    }

    // ================= 视频层 =================
    Rectangle {
        anchors.fill: parent
        color: "#090c0d"
    }
    CourseVideoSurface {
        anchors.fill: parent
        controller: CoursePlayer
    }
    // 压暗 scrim:与 styles.css .video-scrim 两向渐变一致
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.rgba(0.016, 0.027, 0.031, 0.74) }
            GradientStop { position: 0.3; color: Qt.rgba(0.016, 0.027, 0.031, 0.12) }
            GradientStop { position: 0.68; color: Qt.rgba(0.016, 0.027, 0.031, 0.04) }
            GradientStop { position: 1.0; color: Qt.rgba(0.016, 0.027, 0.031, 0.78) }
        }
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Qt.rgba(0.008, 0.016, 0.02, 0.76) }
            GradientStop { position: 0.2; color: Qt.rgba(0.008, 0.016, 0.02, 0.0) }
            GradientStop { position: 0.56; color: Qt.rgba(0.008, 0.016, 0.02, 0.0) }
            GradientStop { position: 1.0; color: Qt.rgba(0.008, 0.016, 0.02, 0.84) }
        }
    }

    // ================= 顶栏 =================
    Item {
        id: topBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Theme.px(92)

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: Qt.rgba(0.016, 0.027, 0.031, 0.72) }
                GradientStop { position: 0.72; color: Qt.rgba(0.016, 0.027, 0.031, 0.3) }
                GradientStop { position: 1.0; color: Qt.rgba(0.016, 0.027, 0.031, 0.0) }
            }
        }

        IconButton {
            id: backButton
            x: Theme.px(26)
            y: Theme.px(26)
            icon: "back"
            onClicked: AppState.back()
        }
        IconButton {
            id: menuButton
            x: Theme.px(74)
            y: Theme.px(26)
            icon: "menu"
            onClicked: page.drawerOpen = true
        }

        Column {
            x: Theme.px(122)
            y: Theme.px(18)
            spacing: Theme.px(2)
            Text {
                text: "搏击燃脂 · 进阶"
                color: page.mutedColor
                font.pixelSize: Theme.fontPx(11)
            }
            Text {
                text: page.chapter.name
                color: page.textColor
                font.pixelSize: Theme.fontPx(16)
                font.family: Theme.bodyFamily
                width: Theme.px(210)
                elide: Text.ElideRight
            }
        }

        // 时钟 + 播放控制(右侧)
        Row {
            anchors.right: parent.right
            anchors.rightMargin: Theme.px(26)
            y: Theme.px(14)
            spacing: Theme.px(6)
            Text {
                text: page.formatClock(page.elapsedSec())
                color: page.accent
                font.pixelSize: Theme.fontPx(19)
                font.family: Theme.bodyFamily
            }
            Text {
                text: "/"
                color: page.faintColor
                font.pixelSize: Theme.fontPx(15)
                anchors.baseline: parent.children[0].baseline
            }
            Text {
                text: page.formatClock(Math.ceil(page.videoDurationSec))
                color: page.mutedColor
                font.pixelSize: Theme.fontPx(15)
                anchors.baseline: parent.children[0].baseline
            }
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: Theme.px(26)
            y: Theme.px(44)
            spacing: Theme.px(6)
            IconButton {
                icon: "skip-back"
                buttonSize: Theme.px(34)
                enabled: page.chapterIndex > 0
                onClicked: page.switchChapter(page.chapterIndex - 1)
            }
            IconButton {
                icon: page.playing ? "pause" : "play"
                buttonSize: Theme.px(38)
                accentBorder: true
                onClicked: page.togglePlayback()
            }
            IconButton {
                icon: "skip-forward"
                buttonSize: Theme.px(34)
                enabled: page.chapterIndex < page.chapters.length - 1
                onClicked: page.switchChapter(page.chapterIndex + 1)
            }
        }

        // 章节段(时长比例,等价 CSS grid fr)
        Row {
            id: segmentRow
            x: Theme.px(266)
            y: Theme.px(28)
            width: Theme.px(768)
            height: Theme.px(36)
            spacing: Theme.px(6)
            Repeater {
                model: page.chapters
                delegate: Rectangle {
                    id: segmentBar
                    required property int index
                    required property var modelData
                    readonly property real totalDuration: 44 + 36 + 41.154
                    width: (segmentRow.width - segmentRow.spacing * (page.chapters.length - 1))
                           * (page.chapterEnd(index) - modelData.start) / totalDuration
                    height: segmentRow.height
                    color: "transparent"
                    readonly property int segState: index < page.chapterIndex ? 2
                                                    : index === page.chapterIndex ? 1 : 0
                    readonly property real segProgress: index === page.chapterIndex
                        ? Math.max(0, Math.min(1, (page.elapsedSec() - modelData.start)
                           / Math.max(0.001, page.chapterEnd(index) - modelData.start)))
                        : 0
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: segmentBar.segState === 1 ? Theme.px(12) : Theme.px(8)
                        radius: height / 2
                        color: segmentBar.segState === 2 ? page.accent
                               : segmentBar.segState === 1 ? page.accentSoft
                               : Qt.rgba(1, 1, 1, 0.2)
                    }
                    Rectangle {
                        visible: segmentBar.segState === 1
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width * segmentBar.segProgress
                        height: Theme.px(12)
                        radius: height / 2
                        color: page.accent
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: page.switchChapter(segmentBar.index)
                    }
                }
            }
        }
    }

    // ================= 左侧:棍靶提示面板 =================
    Rectangle {
        id: promptPanel
        x: Theme.px(26)
        y: Theme.px(356)
        width: Theme.px(172)
        height: Theme.px(348)
        radius: Theme.px(5)
        color: page.panelBg
        border.width: 1
        border.color: page.panelBorder

        Column {
            anchors.fill: parent
            anchors.margins: Theme.px(10)
            anchors.leftMargin: Theme.px(12)
            anchors.rightMargin: Theme.px(12)
            spacing: Theme.px(6)

            Text {
                text: "棍靶提示"
                color: page.mutedColor
                font.pixelSize: Theme.fontPx(11)
            }
            FightFlowMotionCue {
                width: parent.width
                height: Theme.px(124)
                playing: page.playing
            }
            Column {
                spacing: Theme.px(2)
                Text {
                    text: "下一击打部位"
                    color: page.mutedColor
                    font.pixelSize: Theme.fontPx(10)
                }
                Text {
                    text: page.chapter.nextHit
                    color: page.accent
                    font.pixelSize: Theme.fontPx(17)
                    font.family: Theme.bodyFamily
                }
                Text {
                    text: page.chapter.nextStrike
                    color: page.mutedColor
                    font.pixelSize: Theme.fontPx(10)
                }
            }
            Text {
                text: "击打区域分布"
                color: page.textColor
                font.pixelSize: Theme.fontPx(11)
            }
            FightFlowHeatmap {
                id: heatmap
                width: parent.width
                height: Theme.px(76)
                distribution: page.hitDistribution
                nextRegion: page.nextRegionIndex()
            }
            Row {
                width: parent.width
                spacing: Theme.px(6)
                Text {
                    text: "少"
                    color: page.mutedColor
                    font.pixelSize: Theme.fontPx(9)
                    anchors.verticalCenter: parent.verticalCenter
                }
                Rectangle {
                    width: parent.width - Theme.px(42)
                    height: Theme.px(4)
                    color: "#686f6c"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "多"
                    color: page.mutedColor
                    font.pixelSize: Theme.fontPx(9)
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    // ================= 底部:实时指标条 =================
    Rectangle {
        id: metricsPanel
        x: Theme.px(210)
        y: Theme.px(642)
        width: Theme.px(830)
        height: Theme.px(62)
        radius: Theme.px(5)
        color: page.panelBg
        border.width: 1
        border.color: page.panelBorder

        Row {
            anchors.fill: parent
            anchors.margins: Theme.px(10)
            anchors.leftMargin: Theme.px(12)
            anchors.rightMargin: Theme.px(12)

            Row {
                width: parent.width - Theme.px(190)
                height: parent.height
                MetricCell {
                    width: parent.width / 4
                    title: "训练时长"
                    value: page.formatClock(page.elapsedSec())
                    unit: ""
                }
                MetricCell {
                    width: parent.width / 4
                    title: "消耗热量"
                    value: Math.floor(page.calories)
                    unit: "kcal"
                }
                MetricCell {
                    width: parent.width / 4
                    title: "总击打数"
                    value: page.totalHits
                    unit: "次"
                }
                MetricCell {
                    width: parent.width / 4
                    title: "最大力量"
                    value: page.maxPower
                    unit: "kgf"
                }
            }
            Column {
                width: Theme.px(190)
                height: parent.height
                spacing: Theme.px(4)
                Row {
                    width: parent.width
                    spacing: Theme.px(6)
                    Text {
                        width: parent.width - Theme.px(60)
                        text: "击打数 / 击打目标"
                        color: page.mutedColor
                        font.pixelSize: Theme.fontPx(10)
                        anchors.baseline: parent.children[1].baseline
                    }
                    Text {
                        text: page.currentHits
                        color: page.textColor
                        font.pixelSize: Theme.fontPx(18)
                        font.family: Theme.bodyFamily
                    }
                    Text {
                        text: "/"
                        color: page.faintColor
                        font.pixelSize: Theme.fontPx(11)
                        anchors.baseline: parent.children[1].baseline
                    }
                    Text {
                        text: page.chapter.target
                        color: page.accent
                        font.pixelSize: Theme.fontPx(12)
                        anchors.baseline: parent.children[1].baseline
                    }
                }
                Rectangle {
                    width: parent.width
                    height: Theme.px(3)
                    color: Qt.rgba(1, 1, 1, 0.16)
                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, page.currentHits / Math.max(1, page.chapter.target)))
                        height: parent.height
                        color: page.accent
                    }
                }
            }
        }
    }

    // ================= 右侧:趋势面板 =================
    Rectangle {
        id: trendPanel
        x: Theme.px(1062)
        y: Theme.px(546)
        width: Theme.px(192)
        height: Theme.px(158)
        radius: Theme.px(5)
        color: page.panelBg
        border.width: 1
        border.color: page.panelBorder

        Column {
            anchors.fill: parent
            anchors.margins: Theme.px(10)
            anchors.leftMargin: Theme.px(12)
            anchors.rightMargin: Theme.px(12)
            spacing: Theme.px(4)

            Row {
                spacing: Theme.px(10)
                LegendButton {
                    label: "击打频率"
                    seriesColor: page.accent
                    active: page.frequencyVisible
                    onClicked: page.frequencyVisible = !page.frequencyVisible
                }
                LegendButton {
                    label: "击打力度"
                    seriesColor: page.forceColor
                    active: page.powerVisible
                    onClicked: page.powerVisible = !page.powerVisible
                }
            }
            FightFlowTrendChart {
                id: trendChart
                width: parent.width
                height: parent.height - Theme.px(56)
                frequency: page.frequency
                power: page.power
                pendingFrequency: page.pendingFrequency
                pendingPower: page.pendingPower
                frequencyVisible: page.frequencyVisible
                powerVisible: page.powerVisible
            }
            Text {
                id: summaryLabel
                color: page.mutedColor
                font.pixelSize: Theme.fontPx(9)
            }
        }
    }

    // ================= 章节抽屉 =================
    Rectangle {
        id: drawerScrim
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.62)
        visible: page.drawerOpen
        MouseArea {
            anchors.fill: parent
            onClicked: page.drawerOpen = false
        }
    }
    Rectangle {
        id: drawer
        x: page.drawerOpen ? 0 : -width - Theme.px(4)
        width: Theme.px(300)
        height: parent.height
        color: Qt.rgba(0.043, 0.059, 0.063, 0.94)
        visible: x > -width
        Behavior on x {
            NumberAnimation {
                duration: 260
                easing.type: Easing.OutCubic
            }
        }
        Column {
            anchors.fill: parent
            anchors.margins: Theme.px(20)
            spacing: Theme.px(12)
            Row {
                width: parent.width
                Column {
                    width: parent.width - Theme.px(36)
                    spacing: Theme.px(2)
                    Text {
                        text: "课程动作"
                        color: page.mutedColor
                        font.pixelSize: Theme.fontPx(11)
                    }
                    Text {
                        text: "组合拳与闪躲训练"
                        color: page.textColor
                        font.pixelSize: Theme.fontPx(16)
                        font.family: Theme.bodyFamily
                    }
                }
                IconButton {
                    icon: "x"
                    buttonSize: Theme.px(36)
                    onClicked: page.drawerOpen = false
                }
            }
            Repeater {
                model: page.chapters
                delegate: Rectangle {
                    required property int index
                    required property var modelData
                    width: parent.width
                    height: Theme.px(48)
                    radius: Theme.px(5)
                    color: index === page.chapterIndex ? page.accentSoft : "transparent"
                    border.width: index === page.chapterIndex ? 1 : 0
                    border.color: Qt.rgba(0.812, 1.0, 0.18, 0.48)
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.px(10)
                        anchors.rightMargin: Theme.px(10)
                        spacing: Theme.px(10)
                        Text {
                            text: "0" + (index + 1)
                            color: page.mutedColor
                            font.pixelSize: Theme.fontPx(12)
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            width: parent.width - Theme.px(80)
                            text: modelData.name
                            color: page.textColor
                            font.pixelSize: Theme.fontPx(13)
                            elide: Text.ElideRight
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Rectangle {
                            width: Theme.px(7)
                            height: Theme.px(7)
                            color: index < page.chapterIndex ? page.accent : page.faintColor
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: page.switchChapter(index)
                    }
                }
            }
        }
    }

    // ================= toast =================
    Rectangle {
        id: toast
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.px(720 - 30) - height
        width: toastLabel.width + Theme.px(28)
        height: toastLabel.height + Theme.px(18)
        radius: Theme.px(5)
        color: Qt.rgba(0.082, 0.102, 0.106, 0.85)
        border.width: 1
        border.color: Qt.rgba(0.91, 0.94, 0.92, 0.3)
        visible: false
        Text {
            id: toastLabel
            anchors.centerIn: parent
            color: page.textColor
            font.pixelSize: Theme.fontPx(11)
        }
        SequentialAnimation {
            id: toastAnimation
            PauseAnimation { duration: 2200 }
            NumberAnimation {
                target: toast
                property: "opacity"
                to: 0
                duration: 200
            }
            PropertyAction {
                target: toast
                property: "visible"
                value: false
            }
        }
    }

    // ================= 加载/错误/结束遮罩(沿用 CourseLessonPage 模式)=====
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
        visible: CoursePlayer.state === "loading" || CoursePlayer.state === "buffering"
        Column {
            anchors.centerIn: parent
            spacing: 18
            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                running: true
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: CoursePlayer.state === "buffering" ? "缓冲中…" : "加载中…"
                color: page.textColor
                font.pixelSize: Theme.fontBody
            }
        }
    }
    // End of stream: make the stopped last frame explicit instead of looking
    // like a frozen player. The top play button also replays while ended.
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.72)
        visible: page.ended
        z: 30

        Column {
            anchors.centerIn: parent
            spacing: Theme.px(16)

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "训练完成"
                color: page.textColor
                font.pixelSize: Theme.fontPx(28)
                font.family: Theme.bodyFamily
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "本次训练 " + page.formatClock(page.videoDurationSec)
                      + " · 完成击打 " + page.totalHits + " 次"
                color: page.mutedColor
                font.pixelSize: Theme.fontPx(13)
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.px(14)

                HmiButton {
                    kind: "primary"
                    text: "重新播放"
                    onClicked: CoursePlayer.replay()
                }
                HmiButton {
                    kind: "ghost"
                    text: "结束训练"
                    onClicked: AppState.back()
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.78)
        visible: CoursePlayer.state === "error"
        Column {
            anchors.centerIn: parent
            spacing: 22
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: CoursePlayer.errorMessage !== "" ? CoursePlayer.errorMessage
                                                      : "课程视频播放失败，请重试"
                color: Theme.danger
                font.pixelSize: Theme.fontTitle
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 20
                HmiButton {
                    kind: "primary"
                    text: "重试"
                    onClicked: CoursePlayer.openCourse("fight_flow")
                }
                HmiButton {
                    kind: "ghost"
                    text: "返回"
                    onClicked: AppState.back()
                }
            }
        }
    }

    // ================= 内联组件 =================
    // 线条图标按钮(白描边风格;menu/x/back 无 lucide 烘焙资产,Canvas 绘制)
    component IconButton: Item {
        id: iconButton
        property string icon: "play"
        property real buttonSize: Theme.px(40)
        property bool accentBorder: false
        signal clicked()
        width: buttonSize
        height: buttonSize
        opacity: enabled ? 1.0 : 0.3
        onIconChanged: iconCanvas.requestPaint()
        Rectangle {
            anchors.fill: parent
            radius: Theme.px(5)
            color: iconMouse.containsPress ? Qt.rgba(1, 1, 1, 0.16)
                 : iconMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.10)
                 : Qt.rgba(0.027, 0.039, 0.043, 0.56)
            border.width: iconButton.accentBorder ? 2 : 0
            border.color: page.accent
        }
        Canvas {
            id: iconCanvas
            anchors.centerIn: parent
            width: parent.width * 0.6
            height: width
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const c = width / 2;
                const s = width / 20;
                ctx.strokeStyle = iconButton.accentBorder ? page.accent : page.textColor;
                ctx.fillStyle = ctx.strokeStyle;
                ctx.lineWidth = Math.max(2, 2 * s);
                ctx.lineCap = "round";
                ctx.lineJoin = "round";
                switch (iconButton.icon) {
                case "menu":
                    for (let i = 0; i < 3; ++i) {
                        const y = c + (i - 1) * 6.5 * s;
                        ctx.beginPath();
                        ctx.moveTo(c - 8 * s, y);
                        ctx.lineTo(c + 8 * s, y);
                        ctx.stroke();
                    }
                    break;
                case "play":
                    ctx.beginPath();
                    ctx.moveTo(c - 5 * s, c - 8 * s);
                    ctx.lineTo(c - 5 * s, c + 8 * s);
                    ctx.lineTo(c + 8.5 * s, c);
                    ctx.closePath();
                    ctx.fill();
                    break;
                case "pause":
                    ctx.beginPath();
                    ctx.moveTo(c - 4 * s, c - 7 * s);
                    ctx.lineTo(c - 4 * s, c + 7 * s);
                    ctx.moveTo(c + 4 * s, c - 7 * s);
                    ctx.lineTo(c + 4 * s, c + 7 * s);
                    ctx.stroke();
                    break;
                case "skip-back":
                    ctx.beginPath();
                    ctx.moveTo(c + 6 * s, c - 7 * s);
                    ctx.lineTo(c + 6 * s, c + 7 * s);
                    ctx.lineTo(c - 5.5 * s, c);
                    ctx.closePath();
                    ctx.fill();
                    ctx.beginPath();
                    ctx.moveTo(c - 7 * s, c - 7 * s);
                    ctx.lineTo(c - 7 * s, c + 7 * s);
                    ctx.stroke();
                    break;
                case "skip-forward":
                    ctx.beginPath();
                    ctx.moveTo(c - 6 * s, c - 7 * s);
                    ctx.lineTo(c - 6 * s, c + 7 * s);
                    ctx.lineTo(c + 5.5 * s, c);
                    ctx.closePath();
                    ctx.fill();
                    ctx.beginPath();
                    ctx.moveTo(c + 7 * s, c - 7 * s);
                    ctx.lineTo(c + 7 * s, c + 7 * s);
                    ctx.stroke();
                    break;
                case "x":
                    ctx.beginPath();
                    ctx.moveTo(c - 6 * s, c - 6 * s);
                    ctx.lineTo(c + 6 * s, c + 6 * s);
                    ctx.moveTo(c - 6 * s, c + 6 * s);
                    ctx.lineTo(c + 6 * s, c - 6 * s);
                    ctx.stroke();
                    break;
                case "back":
                    ctx.beginPath();
                    ctx.moveTo(c + 6 * s, c - 7 * s);
                    ctx.lineTo(c - 4 * s, c);
                    ctx.lineTo(c + 6 * s, c + 7 * s);
                    ctx.moveTo(c - 4 * s, c);
                    ctx.lineTo(c + 8 * s, c);
                    ctx.stroke();
                    break;
                }
            }
        }
        MouseArea {
            id: iconMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: iconButton.enabled
            onClicked: iconButton.clicked()
        }
    }

    // 指标单元格:标题 + 数值 + 单位
    component MetricCell: Column {
        property string title: ""
        property var value: ""
        property string unit: ""
        spacing: Theme.px(2)
        Text {
            text: parent.title
            color: page.mutedColor
            font.pixelSize: Theme.fontPx(10)
        }
        Row {
            spacing: Theme.px(3)
            Text {
                id: metricValue
                text: parent.parent.value
                color: page.textColor
                font.pixelSize: Theme.fontPx(15)
                font.family: Theme.bodyFamily
            }
            Text {
                visible: parent.parent.unit !== ""
                text: parent.parent.unit
                color: page.mutedColor
                font.pixelSize: Theme.fontPx(9)
                anchors.baseline: metricValue.baseline
            }
        }
    }

    // 图例切换按钮:彩色短线 + 文案,未激活降透明度
    component LegendButton: Item {
        id: legendButton
        property string label: ""
        property color seriesColor: "white"
        property bool active: true
        signal clicked()
        width: Theme.px(84)
        height: Theme.px(24)
        opacity: active ? 1.0 : 0.45
        Rectangle {
            x: 0
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.px(16)
            height: Theme.px(3)
            color: legendButton.seriesColor
        }
        Text {
            x: Theme.px(22)
            anchors.verticalCenter: parent.verticalCenter
            text: legendButton.label
            color: legendButton.active ? page.textColor : page.mutedColor
            font.pixelSize: Theme.fontPx(11)
        }
        MouseArea {
            anchors.fill: parent
            onClicked: legendButton.clicked()
        }
    }
}
