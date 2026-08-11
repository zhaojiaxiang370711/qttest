pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QxznHmi

// 课程播放器子页：三门纯视频课（special_practice / stance / right_straight）
// 的 GStreamer 播放界面。视频由 CourseVideoSurface（自定义 QQuickItem）以
// CPU 拷贝 RGBA 渲染、保持比例 contain 在黑色背景上；播放/暂停、进度拖动、
// 上下一个动作标记、音量/静音、以及加载/缓冲、缺媒体/错误、结束等状态遮罩。
// 本页不引用 DDS / SessionModel / REST / 摄像头 / 电机 / LED 任何接口。
Item {
    id: page
    anchors.fill: parent

    // ---- selected course + lifecycle ----
    readonly property string courseId: AppState.courseId
    readonly property var course: CourseCatalog.course(page.courseId)
    readonly property var markers: page.course && page.course.markers ? page.course.markers : []

    // ---- formatting helpers ----
    function formatTime(ms) {
        if (ms === undefined || ms < 0 || isNaN(ms))
            ms = 0;
        const total = Math.floor(ms / 1000);
        const m = Math.floor(total / 60);
        const s = total % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    function openSelected() {
        CoursePlayer.openCourse(page.courseId);
    }

    Component.onCompleted: Qt.callLater(openSelected)
    // Leaving the page (back / nav change) must stop audio+video in the background.
    Component.onDestruction: CoursePlayer.stop()

    // ================= video stage =================
    // Black backdrop so the aspect-contain letterbox is opaque black.
    Rectangle {
        anchors.fill: parent
        color: "#000000"
    }

    CourseVideoSurface {
        id: surface
        anchors.fill: parent
        controller: CoursePlayer
    }

    // ================= top bar =================
    Rectangle {
        id: topBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 96
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.72) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.0) }
        }

        // back button
        Rectangle {
            id: backButton
            x: 24
            y: (parent.height - height) / 2
            width: 96
            height: 56
            radius: Theme.radiusButton
            color: backMa.containsPress ? Qt.rgba(1, 1, 1, 0.16)
                 : backMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10)
                 : Qt.rgba(1, 1, 1, 0.06)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.12)
            HmiIcon {
                anchors.centerIn: parent
                name: "arrow-right"
                rotation: 180          // no arrow-left asset bundled; reuse arrow-right
                tone: "white"
                size: 30
            }
            MouseArea {
                id: backMa
                anchors.fill: parent
                hoverEnabled: true
                onClicked: AppState.back()
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            text: CoursePlayer.title !== "" ? CoursePlayer.title
                  : (page.course && page.course.title ? page.course.title : "课程教学")
            color: Theme.text
            font.pixelSize: Theme.fontTitle
            elide: Text.ElideRight
            width: parent.width - backButton.width * 2 - 120
            horizontalAlignment: Text.AlignHCenter
        }

        // discreet diagnostics (decoder / renderer)
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            text: {
                const dec = CoursePlayer.decoderName || "—";
                const fps = CoursePlayer.presentedFps > 0 ? CoursePlayer.presentedFps
                                                          : CoursePlayer.decodedFps;
                const fpsText = fps > 0 ? (" · " + Math.round(fps) + " fps") : "";
                return dec + fpsText + " · " + CoursePlayer.rendererMode;
            }
            color: Theme.muted
            font.pixelSize: Theme.fontTiny
        }
    }

    // ================= current marker label =================
    Text {
        anchors.top: topBar.bottom
        anchors.topMargin: 16
        anchors.horizontalCenter: parent.horizontalCenter
        visible: CoursePlayer.currentMarkerLabel !== ""
        text: CoursePlayer.currentMarkerLabel
        color: Theme.primary
        font.pixelSize: Theme.fontHeader
        Rectangle {
            z: -1
            anchors.fill: parent
            anchors.margins: -12
            radius: Theme.radiusPill
            color: Qt.rgba(0, 0, 0, 0.45)
        }
    }

    // ================= bottom control deck =================
    Rectangle {
        id: deck
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 168
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.0) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.80) }
        }

        // ---- seek track + marker ticks ----
        Item {
            id: track
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 40
            anchors.rightMargin: 40
            anchors.top: parent.top
            anchors.topMargin: 22
            height: 40

            readonly property real fraction: CoursePlayer.durationMs > 0
                ? Math.max(0, Math.min(1, CoursePlayer.positionMs / CoursePlayer.durationMs))
                : 0

            Rectangle {  // groove
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                height: 6
                radius: 3
                color: Qt.rgba(1, 1, 1, 0.18)
            }
            Rectangle {  // filled
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                width: parent.width * track.fraction
                height: 6
                radius: 3
                color: Theme.primary
            }
            // marker ticks
            Repeater {
                model: page.markers
                delegate: Rectangle {
                    required property var modelData
                    x: CoursePlayer.durationMs > 0
                       ? (modelData.timeMs / CoursePlayer.durationMs) * track.width - 1
                       : -10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 2
                    height: 14
                    radius: 1
                    color: Qt.rgba(1, 1, 1, 0.45)
                }
            }
            Rectangle {  // knob
                y: (parent.height - height) / 2
                x: parent.width * track.fraction - width / 2
                width: 20
                height: 20
                radius: 10
                color: Theme.text
                border.width: 2
                border.color: Theme.primary
            }
            MouseArea {
                id: seekMa
                anchors.fill: parent
                anchors.topMargin: -10
                anchors.bottomMargin: -10
                preventStealing: true
                property bool dragging: false
                function seekTo(mx) {
                    if (CoursePlayer.durationMs <= 0)
                        return;
                    const f = Math.max(0, Math.min(1, (mx - track.x) / track.width));
                    CoursePlayer.seekMs(Math.round(f * CoursePlayer.durationMs));
                }
                onPressed: function(mouse) { dragging = true; seekTo(mouseX) }
                onPositionChanged: function(mouse) { if (dragging) seekTo(mouseX) }
                onReleased: dragging = false
                onCanceled: dragging = false
            }
        }

        // ---- time labels ----
        Text {
            anchors.left: track.left
            anchors.top: track.bottom
            anchors.topMargin: 6
            text: page.formatTime(CoursePlayer.positionMs)
            color: Theme.text
            font.pixelSize: Theme.fontSmall
        }
        Text {
            anchors.right: track.right
            anchors.top: track.bottom
            anchors.topMargin: 6
            text: page.formatTime(CoursePlayer.durationMs)
            color: Theme.muted
            font.pixelSize: Theme.fontSmall
        }

        // ---- transport buttons ----
        Row {
            id: transport
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 20
            spacing: 28

            IconButton {
                enabled: CoursePlayer.hasPreviousMarker
                opacity: enabled ? 1.0 : 0.35
                iconName: "skip-back"
                onClicked: CoursePlayer.seekPreviousMarker()
            }
            IconButton {
                iconName: CoursePlayer.state === "playing" ? "pause" : "play"
                highlight: true
                onClicked: CoursePlayer.togglePlayback()
            }
            IconButton {
                enabled: CoursePlayer.hasNextMarker
                opacity: enabled ? 1.0 : 0.35
                iconName: "skip-forward"
                onClicked: CoursePlayer.seekNextMarker()
            }
        }

        // ---- volume + mute (right) ----
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 40
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 28
            spacing: 14

            // mute toggle (Canvas-drawn speaker; no bundled volume icon asset)
            Item {
                width: 64
                height: 64
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: muteMa.containsPress ? Qt.rgba(1, 1, 1, 0.16)
                         : muteMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10)
                         : Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.12)
                }
                Canvas {
                    id: speakerCanvas
                    anchors.centerIn: parent
                    width: 34
                    height: 34
                    renderTarget: Canvas.Image
                    readonly property bool muted: CoursePlayer.muted || CoursePlayer.volume <= 0
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        ctx.strokeStyle = muted ? Theme.muted : Theme.text;
                        ctx.fillStyle = muted ? Theme.muted : Theme.text;
                        ctx.lineWidth = 2;
                        // speaker body + cone
                        ctx.beginPath();
                        ctx.moveTo(4, 12);
                        ctx.lineTo(10, 12);
                        ctx.lineTo(18, 5);
                        ctx.lineTo(18, 29);
                        ctx.lineTo(10, 22);
                        ctx.lineTo(4, 22);
                        ctx.closePath();
                        ctx.fill();
                        if (muted) {
                            // slash
                            ctx.beginPath();
                            ctx.moveTo(23, 8);
                            ctx.lineTo(31, 26);
                            ctx.stroke();
                        } else {
                            // waves
                            ctx.beginPath();
                            ctx.arc(18, 17, 7, -0.6, 0.6);
                            ctx.stroke();
                            ctx.beginPath();
                            ctx.arc(18, 17, 11, -0.5, 0.5);
                            ctx.stroke();
                        }
                    }
                    Component.onCompleted: requestPaint()
                    Connections {
                        target: CoursePlayer
                        function onMutedChanged() { speakerCanvas.requestPaint() }
                        function onVolumeChanged() { speakerCanvas.requestPaint() }
                    }
                }
                MouseArea {
                    id: muteMa
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: CoursePlayer.setMuted(!CoursePlayer.muted)
                }
            }
            Item {  // volume bar
                width: 140
                height: 40
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 6
                    radius: 3
                    color: Qt.rgba(1, 1, 1, 0.18)
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    width: parent.width * (CoursePlayer.muted ? 0 : CoursePlayer.volume)
                    height: 6
                    radius: 3
                    color: Theme.primary
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.topMargin: -12
                    anchors.bottomMargin: -12
                    preventStealing: true
                    property bool dragging: false
                    onPressed: function(mouse) { dragging = true; applyVol(mouseX) }
                    onPositionChanged: function(mouse) { if (dragging) applyVol(mouseX) }
                    onReleased: dragging = false
                    onCanceled: dragging = false
                    function applyVol(mx) {
                        const f = Math.max(0, Math.min(1, mx / width));
                        if (CoursePlayer.muted && f > 0)
                            CoursePlayer.setMuted(false);
                        CoursePlayer.setVolume(f);
                    }
                }
            }
        }
    }

    // ================= state overlays =================
    // Loading / buffering.
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
                color: Theme.text
                font.pixelSize: Theme.fontBody
            }
        }
    }

    // Missing media / error.
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
                    onClicked: page.openSelected()
                }
                HmiButton {
                    kind: "ghost"
                    text: "返回"
                    onClicked: AppState.back()
                }
            }
        }
    }

    // End of stream.
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.70)
        visible: CoursePlayer.state === "ended"
        Column {
            anchors.centerIn: parent
            spacing: 22
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "课程结束"
                color: Theme.text
                font.pixelSize: Theme.fontHeader
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 20
                HmiButton {
                    kind: "primary"
                    text: "重新播放"
                    onClicked: CoursePlayer.replay()
                }
                HmiButton {
                    kind: "ghost"
                    text: "结束教学"
                    onClicked: AppState.back()
                }
            }
        }
    }

    // ================= reusable icon button =================
    component IconButton: Item {
        id: iconBtn
        property string iconName: ""
        property bool highlight: false
        signal clicked()
        width: highlight ? 84 : 64
        height: width
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: iconBtn.highlight ? Qt.rgba(0.0, 0.941, 1.0, 0.90)
                 : (iconMouse.containsPress ? Qt.rgba(1, 1, 1, 0.16)
                 : iconMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.10)
                 : Qt.rgba(1, 1, 1, 0.06))
            border.width: 1
            border.color: iconBtn.highlight ? Qt.rgba(1, 1, 1, 0.30)
                                                  : Qt.rgba(1, 1, 1, 0.12)
        }
        HmiIcon {
            anchors.centerIn: parent
            name: iconBtn.iconName
            tone: iconBtn.highlight ? "cyan" : "white"
            size: iconBtn.highlight ? 40 : 30
        }
        MouseArea {
            id: iconMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: iconBtn.enabled
            onClicked: iconBtn.clicked()
        }
    }
}
