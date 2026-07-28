pragma ComponentBehavior: Bound
import QtQuick
import QxznHmi

// 手靶课训练器子页（Godot modules/course/internal/course_lesson_page.gd 的
// focus_mitt / bodycombat-style 训练器）。多个 unit 顺序播放 16:9 视频，播放期间
// 用户随视频击打（点击视频区=一次击打，计入 touch_count），每 unit 播前 3-2-1
// 倒计时，底部 dashboard 显示触摸次数 + 剩余时间 + 提示。复用 CourseVideoSurface
// + CoursePlayer（GStreamer）。不引用 DDS/SessionModel/REST/摄像头/电机/LED。
Item {
    id: page
    anchors.fill: parent

    readonly property var units: CourseCatalog.focusMittUnits
    property int unitIndex: 0
    // prepare = 3-2-1 倒计时；playing = 视频播放中；completed = 全部 unit 完成
    property string phase: "prepare"
    property int touchCount: 0
    property int prepareCount: 3
    property bool drawerOpen: false
    readonly property var currentUnit: page.units[page.unitIndex] || ({})

    function formatMs(ms) {
        if (ms === undefined || ms < 0 || isNaN(ms))
            ms = 0;
        const total = Math.ceil(ms / 1000);
        const m = Math.floor(total / 60);
        const s = total % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    function startUnit(i) {
        page.unitIndex = i;
        page.touchCount = 0;
        page.phase = "prepare";
        page.prepareCount = 3;
        prepareCountTimer.restart();
        CoursePlayer.stop();
    }

    function beginPlayback() {
        page.phase = "playing";
        CoursePlayer.openMedia(page.currentUnit.mediaKey, page.currentUnit.name);
    }

    function onUnitMediaEnded() {
        if (page.unitIndex < page.units.length - 1)
            page.startUnit(page.unitIndex + 1);
        else
            page.phase = "completed";
    }

    function registerStrike() {
        if (page.phase !== "playing")
            return;
        page.touchCount += 1;
        strikeFlash.flash();
    }

    Component.onCompleted: page.startUnit(0)
    Component.onDestruction: CoursePlayer.stop()

    // EOS of the current unit's media advances to the next unit (or completion).
    Connections {
        target: CoursePlayer
        function onPlaybackChanged() {
            if (CoursePlayer.state === "ended" && page.phase === "playing")
                page.onUnitMediaEnded();
        }
    }

    // prepare countdown: 3 -> 2 -> 1 -> begin
    Timer {
        id: prepareCountTimer
        interval: 1000
        repeat: true
        onTriggered: {
            if (page.prepareCount > 1) {
                page.prepareCount -= 1;
            } else {
                prepareCountTimer.stop();
                page.beginPlayback();
            }
        }
    }

    // ================= video stage =================
    Rectangle { anchors.fill: parent; color: "#000000" }

    CourseVideoSurface {
        id: mittSurface
        anchors.fill: parent
        controller: CoursePlayer
    }

    // strike target: tap the video = one accepted strike (course_lesson_page.gd
    // maps Space/click to a focus-mitt strike). Buttons below sit above this and
    // intercept their own clicks.
    MouseArea {
        anchors.fill: parent
        enabled: page.phase === "playing"
        onClicked: page.registerStrike()
    }

    ClickFlash {
        id: strikeFlash
        anchors.fill: parent
        radius: 0
        flashColor: Theme.primary
    }

    // ================= top: unit progress + back =================
    Item {
        id: topBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 96
        Rectangle {  // gradient scrim
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.72) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.0) }
            }
        }

        // back button
        Rectangle {
            id: backButton
            x: 24; y: (parent.height - height) / 2
            width: 96; height: 56; radius: Theme.radiusButton
            color: backMa.containsPress ? Qt.rgba(1, 1, 1, 0.16)
                 : backMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10)
                 : Qt.rgba(1, 1, 1, 0.06)
            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.12)
            HmiIcon { anchors.centerIn: parent; name: "arrow-right"; rotation: 180; tone: "white"; size: 30 }
            MouseArea { id: backMa; anchors.fill: parent; hoverEnabled: true; onClicked: AppState.back() }
        }

        // unit progress segments (Godot _draw_bodycombat_progress)
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            Repeater {
                model: page.units
                delegate: Item {
                    id: seg
                    required property int index
                    required property var modelData
                    width: 220; height: 12
                    Rectangle {  // track
                        anchors.fill: parent; radius: 6; color: Qt.rgba(1, 1, 1, 0.14)
                    }
                    Rectangle {  // completed / current fill
                        anchors.left: parent.left; anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        radius: 6
                        width: seg.index < page.unitIndex ? parent.width
                              : seg.index === page.unitIndex
                                ? parent.width * (CoursePlayer.durationMs > 0
                                    ? Math.max(0, Math.min(1, CoursePlayer.positionMs / CoursePlayer.durationMs))
                                    : 0)
                                : 0
                        color: seg.index <= page.unitIndex ? Theme.primary : Qt.rgba(1, 1, 1, 0.14)
                    }
                    Rectangle {  // outline on current
                        anchors.fill: parent; radius: 6; color: "transparent"
                        border.width: seg.index === page.unitIndex ? 2 : 0
                        border.color: Theme.primary
                    }
                }
            }
        }

        // drawer toggle
        Rectangle {
            id: drawerBtn
            anchors.right: parent.right; anchors.rightMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            width: 96; height: 56; radius: Theme.radiusButton
            color: drawerMa.containsPress ? Qt.rgba(1, 1, 1, 0.16)
                 : drawerMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10)
                 : Qt.rgba(1, 1, 1, 0.06)
            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.12)
            Canvas {  // hamburger (no list/menu icon bundled)
                anchors.centerIn: parent
                width: 30; height: 22
                renderTarget: Canvas.Image
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.strokeStyle = Theme.text;
                    ctx.lineWidth = 3;
                    ctx.lineCap = "round";
                    for (let i = 0; i < 3; ++i) {
                        const y = 4 + i * 7;
                        ctx.beginPath();
                        ctx.moveTo(2, y);
                        ctx.lineTo(width - 2, y);
                        ctx.stroke();
                    }
                }
            }
            MouseArea {
                id: drawerMa; anchors.fill: parent; hoverEnabled: true
                onClicked: page.drawerOpen = !page.drawerOpen
            }
        }
    }

    // ================= unit drawer =================
    Rectangle {
        id: drawer
        visible: page.drawerOpen
        anchors.right: parent.right
        anchors.top: topBar.bottom
        anchors.rightMargin: 24
        width: 460
        height: Math.min(540, 120 + page.units.length * 96)
        radius: Theme.radiusCard
        color: Qt.rgba(0.03, 0.03, 0.04, 0.96)
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.10)
        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12
            Text {
                text: "训练单元"
                color: Theme.muted; font.pixelSize: Theme.fontSmall
            }
            Repeater {
                model: page.units
                delegate: Rectangle {
                    id: pickCard
                    required property int index
                    required property var modelData
                    width: drawer.width - 40; height: 84; radius: Theme.radiusCardInner
                    color: page.unitIndex === pickCard.index ? Qt.rgba(0.0, 0.941, 1.0, 0.12)
                         : (pickMa.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.03))
                    border.width: 1
                    border.color: page.unitIndex === pickCard.index ? Qt.rgba(0.0, 0.941, 1.0, 0.40)
                                                                 : Qt.rgba(1, 1, 1, 0.06)
                    Text {
                        x: 18; y: 14
                        text: (pickCard.index + 1) + ". " + pickCard.modelData.name
                        color: page.unitIndex === pickCard.index ? Theme.primary : Theme.text
                        font.pixelSize: Theme.fontBody
                        elide: Text.ElideRight; width: parent.width - 36
                    }
                    Text {
                        x: 18; y: 50
                        text: page.formatMs(pickCard.modelData.durationMs) + "    触摸：" + (page.unitIndex === pickCard.index ? page.touchCount : 0)
                        color: Theme.muted; font.pixelSize: Theme.fontTiny
                    }
                    MouseArea {
                        id: pickMa; anchors.fill: parent; hoverEnabled: true
                        onClicked: { page.drawerOpen = false; page.startUnit(pickCard.index) }
                    }
                }
            }
        }
    }

    // ================= bottom dashboard =================
    Rectangle {
        id: deck
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: 150
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.0) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.82) }
        }
        // absorb clicks so taps on the HUD are not counted as strikes
        MouseArea { anchors.fill: parent; onClicked: {} }

        // current unit name + demo tip
        Text {
            anchors.left: parent.left; anchors.leftMargin: 40
            anchors.top: parent.top; anchors.topMargin: 18
            text: page.currentUnit.name || ""
            color: Theme.text; font.pixelSize: Theme.fontBody
        }
        Text {
            anchors.left: parent.left; anchors.leftMargin: 40
            anchors.top: parent.top; anchors.topMargin: 52
            width: parent.width / 2
            text: page.currentUnit.tip || ""
            color: Theme.warn; font.pixelSize: Theme.fontTiny
            wrapMode: Text.WordWrap; maximumLineCount: 2
        }

        // big touch count (dashboard_metrics: touch_count)
        Column {
            anchors.right: parent.right; anchors.rightMargin: 40
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("触摸次数")
                color: Theme.muted; font.pixelSize: Theme.fontTiny
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: page.touchCount
                color: Theme.primary; font.pixelSize: 64
                font.family: Theme.brandFamily
            }
        }

        // remaining time countdown (countdown_seconds, urgent at 5s)
        Item {
            id: remainBox
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 26
            width: remainRow.width + 80; height: 56
            readonly property int remainSec: page.phase === "playing" && CoursePlayer.durationMs > 0
                ? Math.max(0, Math.ceil((CoursePlayer.durationMs - CoursePlayer.positionMs) / 1000))
                : (page.currentUnit.durationMs ? Math.ceil(page.currentUnit.durationMs / 1000) : 0)
            readonly property bool urgent: page.phase === "playing" && remainSec > 0 && remainSec <= 5
            Rectangle {
                anchors.fill: parent; radius: Theme.radiusPill
                color: remainBox.urgent ? Qt.rgba(1.0, 0.0, 0.235, 0.22) : Qt.rgba(1, 1, 1, 0.06)
                border.width: 1
                border.color: remainBox.urgent ? Theme.danger : Qt.rgba(1, 1, 1, 0.12)
            }
            Row {
                id: remainRow
                anchors.centerIn: parent
                spacing: 10
                HmiIcon { name: "timer"; tone: "white"; size: 24; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: page.formatMs(page.phase === "playing" && CoursePlayer.durationMs > 0
                        ? Math.max(0, CoursePlayer.durationMs - CoursePlayer.positionMs)
                        : (page.currentUnit.durationMs || 0))
                    color: remainBox.urgent ? Theme.danger : Theme.text
                    font.pixelSize: Theme.fontHeader
                    font.family: Theme.brandFamily
                }
            }
        }
    }

    // ================= prepare overlay (3-2-1) =================
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.015, 0.015, 0.02, 0.92)   // 近似 Godot 磨砂背景（软渲染安全）
        visible: page.phase === "prepare"
        Column {
            anchors.centerIn: parent
            spacing: 18
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: page.currentUnit.name || ""
                color: Theme.text; font.pixelSize: Theme.fontTitle
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: page.phase === "prepare" ? page.prepareCount : ""
                color: Theme.primary; font.pixelSize: 180
                font.family: Theme.brandFamily
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "准备开始"
                color: Theme.muted; font.pixelSize: Theme.fontBody
            }
        }
    }

    // ================= loading / missing-media / error =================
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.78)
        visible: page.phase === "playing" && (CoursePlayer.state === "error")
        Column {
            anchors.centerIn: parent; spacing: 18
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: CoursePlayer.errorMessage !== "" ? CoursePlayer.errorMessage : "课程视频播放失败"
                color: Theme.danger; font.pixelSize: Theme.fontBody
                width: parent.parent.width - 200; wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter; spacing: 16
                HmiButton { kind: "primary"; text: "重试"; onClicked: page.beginPlayback() }
                HmiButton { kind: "ghost"; text: "返回"; onClicked: AppState.back() }
            }
        }
    }

    // ================= completed overlay =================
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.80)
        visible: page.phase === "completed"
        Column {
            anchors.centerIn: parent; spacing: 22
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "训练完成"
                color: Theme.success; font.pixelSize: Theme.fontHeader
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "辛苦了！手靶课全部单元已完成。"
                color: Theme.text; font.pixelSize: Theme.fontBody
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter; spacing: 16
                HmiButton { kind: "primary"; text: "再来一轮"; onClicked: page.startUnit(0) }
                HmiButton { kind: "ghost"; text: "返回"; onClicked: AppState.back() }
            }
        }
    }
}
