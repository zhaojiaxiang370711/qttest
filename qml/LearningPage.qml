pragma ComponentBehavior: Bound
import QtQuick
import QxznHmi

// Learning page: pixel port of the Godot course launcher
// (modules/course/internal/course_view.gd, 1280x720 base, screen coords
// converted via Theme.px and shifted by the page origin (48,150)).
//
// Godot's learning nav renders ONLY course_view (the launcher carousel) — the
// launcher panel fills the whole page: _launcher_panel_rect() = Rect2(56,134,
// 1168, 524) -> local (36,51,1752,786). The five shell_data page_cards
// ["learning"] entries are NOT composed onto this page (they live elsewhere in
// Godot). This view also exposes the Movements sub-tab (course_view sub_page).
Item {
    id: root
    anchors.fill: parent

    // -- course model: sourced from CourseCatalog.launchers (six entries
    //    preserving the Godot visual carousel). kind=="video" entries open the
    //    CourseLesson player; the three interactive entries stay as
    //    "not yet ported" callouts. Each launcher carries id/title/cover/kind
    //    and, for video courses, a videoCourseId. --
    readonly property var courses: CourseCatalog.launchers
    // DEFAULT_LAUNCHER_COURSE_IDX overridden to 专项练习 (defaultLauncherIndex),
    // the recommended pure-video course.
    property int courseIndex: CourseCatalog.defaultLauncherIndex
    // Sub-tab view mode, mirroring Godot course_view.gd course_sub_tab:
    // "courses" = launcher carousel, "moves" = COACHING CLASSROOM technique panel.
    property string viewMode: "courses"
    property int selectedMoveIndex: 0

    // -- layout anchors (Godot 1280-base -> page-local px) --
    // Godot course_view.gd _launcher_panel_rect() = Rect2(PAGE_X, PAGE_Y,
    // PAGE_W, PAGE_H - PAGE_BOTTOM_GAP): the launcher fills the whole page
    // minus the bottom gap. No entry cards are composed below (those live
    // elsewhere in Godot, not on the learning page).
    readonly property real panelX: Theme.px(56) - 48    // PAGE_X 56 -> 36
    readonly property real panelY: Theme.px(134) - 150  // PAGE_Y 134 -> 51
    readonly property real panelW: Theme.px(1168)       // PAGE_W -> 1752
    readonly property real bottomGap: Theme.px(30)      // PAGE_BOTTOM_GAP 30 -> 45
    readonly property real panelH: 882 - panelY - bottomGap             // 786 (full height)

    function clampIndex(i) {
        return Math.max(0, Math.min(root.courses.length - 1, i));
    }

    // Course switch with the Godot 0.26s content slide (ease-out cubic).
    function selectCourse(i) {
        const next = clampIndex(i);
        if (next === root.courseIndex) {
            // edge course: snap the rubber-banded drag offset back
            backAnim.restart();
            return;
        }
        const dir = next > root.courseIndex ? 1 : -1;
        root.courseIndex = next;
        slideAnim.from = dir * panel.width;
        slideAnim.restart();
        panelFlash.flash();
    }

    // Video courses launch the CourseLesson player; the focus-mitt trainer
    // launches its own multi-unit page; interactive courses (搏击操/莱美) report
    // that their hardware-driven versions are not yet ported.
    function startCourse() {
        panelFlash.flash();
        const entry = root.courses[root.courseIndex];
        if (entry.kind === "focus_mitt")
            AppState.openSubPage("focus_mitt");
        else if (entry.kind === "video" && entry.videoCourseId !== undefined && entry.videoCourseId !== "")
            AppState.openCourse(entry.videoCourseId);
        else
            AppState.showCallout("info", "互动训练待移植",
                entry.title + "为互动训练课程，将在后续阶段移植");
    }

    // ================= carousel panel =================
    // Godot launcher panel Rect2(56,134,1168,524)@1280; height shortened by
    // the composed card row (see header comment).
    Item {
        id: panel
        visible: root.viewMode === "courses"
        x: root.panelX
        y: root.panelY
        width: root.panelW
        height: root.panelH

        // LAUNCHER_PANEL_BG (0.035,0.039,0.059) -- no Theme token.
        Rectangle {
            anchors.fill: parent
            radius: Theme.px(24)                 // LAUNCHER_PANEL_RADIUS 24 -> 36
            color: Qt.rgba(0.035, 0.039, 0.059, 1.0)
        }

        // Sliding layer: cover + footer + play button move together, matching
        // _begin_course_content_slide / _content_slide_eased (1-(1-t)^3).
        Item {
            id: slideItem
            width: panel.width
            height: panel.height

            NumberAnimation {
                id: slideAnim
                target: slideItem
                property: "x"
                from: 0
                to: 0
                duration: 260                     // COURSE_CONTENT_SLIDE_DURATION 0.26s
                easing.type: Easing.OutCubic
            }

            // hidden source image; Canvas paints it cover-cropped + clipped.
            Image {
                id: coverImg
                visible: false
                source: root.courses[root.courseIndex].cover
                onStatusChanged: if (status === Image.Ready) coverCanvas.requestPaint()
            }

            Canvas {
                id: coverCanvas
                anchors.fill: parent
                renderTarget: Canvas.Image        // software-backend safe
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const w = width, h = height, r = Theme.px(24);
                    ctx.save();
                    ctx.beginPath();
                    ctx.roundedRect(0, 0, w, h, r, r);
                    ctx.clip();
                    // cover-crop the texture exactly like _draw_cover_texture
                    if (coverImg.status === Image.Ready) {
                        const iw = coverImg.sourceSize.width;
                        const ih = coverImg.sourceSize.height;
                        let dw = w, dh = h;
                        if (iw > 0 && ih > 0) {
                            if (iw / ih > w / h)
                                dw = h * iw / ih;
                            else
                                dh = w * ih / iw;
                        }
                        ctx.drawImage(coverImg, (w - dw) * 0.5, (h - dh) * 0.5, dw, dh);
                    }
                    // bottom gradient 176@1280 -> 264: #161616 opaque at the
                    // bottom, 70% at mid, transparent on top (from via to).
                    const gh = Theme.px(176);
                    const g = ctx.createLinearGradient(0, h - gh, 0, h);
                    g.addColorStop(0.0, "rgba(22,22,22,0)");
                    g.addColorStop(0.5, "rgba(22,22,22,0.70)");
                    g.addColorStop(1.0, "rgba(22,22,22,1)");
                    ctx.fillStyle = g;
                    ctx.fillRect(0, h - gh, w, gh);
                    ctx.restore();
                }
            }

            // -- footer stack: hex badge / title / meta, centered, bottom pad
            //    LAUNCHER_FOOTER_BOTTOM_PAD 8@1280 -> 12; line gap 8@1280 -> 12 --
            Text {
                id: metaText
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.px(8)
                // "%s    |    %s    |    %s" % [level, duration, subtitle]
                text: "K1 · 零基础    |    5 分钟    |    从零开始学习拳击基本功"
                color: Qt.rgba(1, 1, 1, 0.90)
                font.pixelSize: Theme.fontPx(27)  // _fs(23)
            }
            Text {
                id: titleText
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: metaText.top
                anchors.bottomMargin: Theme.px(8)
                text: root.courses[root.courseIndex].title
                color: Theme.text
                font.pixelSize: Theme.fontPx(50)  // _fs(46) launcher title cap
            }
            // LAUNCHER_BADGE_W 380 x LAUNCHER_BADGE_H 28 @1280 -> 570x42.
            Item {
                id: badge
                width: Theme.px(380)
                height: Theme.px(28)
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: titleText.top
                anchors.bottomMargin: Theme.px(8)

                Canvas {
                    anchors.fill: parent
                    renderTarget: Canvas.Image
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        const w = width, h = height, cut = Theme.px(10);
                        // LAUNCHER_BADGE_BORDER (0.290,0.290,0.298)
                        ctx.fillStyle = Qt.rgba(0.290, 0.290, 0.298, 1.0);
                        ctx.beginPath();
                        ctx.moveTo(cut, 0);
                        ctx.lineTo(w - cut, 0);
                        ctx.lineTo(w, h * 0.5);
                        ctx.lineTo(w - cut, h);
                        ctx.lineTo(cut, h);
                        ctx.lineTo(0, h * 0.5);
                        ctx.closePath();
                        ctx.fill();
                        // inner hex badge_rect.grow(-1.0), white 0.20
                        const i2 = Theme.px(1);
                        ctx.fillStyle = Qt.rgba(1, 1, 1, 0.20);
                        ctx.beginPath();
                        ctx.moveTo(i2 + cut, i2);
                        ctx.lineTo(w - i2 - cut, i2);
                        ctx.lineTo(w - i2, h * 0.5);
                        ctx.lineTo(w - i2 - cut, h - i2);
                        ctx.lineTo(i2 + cut, h - i2);
                        ctx.lineTo(i2, h * 0.5);
                        ctx.closePath();
                        ctx.fill();
                    }
                }
                // content_w 322@1280 -> 483 centered: icon 14@1280 -> 21 + text.
                HmiIcon {
                    id: badgeIcon
                    x: (badge.width - Theme.px(322)) * 0.5
                    y: (badge.height - height) * 0.5
                    name: "zap"                   // Godot launcher_ai_icon.png (not in qrc)
                    tone: "white"
                    size: Theme.px(14)
                    opacity: 0.90
                }
                Text {
                    x: badgeIcon.x + badgeIcon.width + Theme.px(8)
                    height: badge.height
                    text: "教练教学 → AI动作识别 → AI动作纠正指导"  // LAUNCHER_AI_BADGE
                    color: Theme.text
                    font.pixelSize: Theme.fontPx(15)  // _fs(11)
                    verticalAlignment: Text.AlignVCenter
                }
            }

            // -- swipe + tap zones: prev/next 22% edges, center start;
            //    slop 8@1280 -> 12, threshold 90@1280 -> 135 --
            MouseArea {
                id: swipeArea
                anchors.fill: parent
                preventStealing: true
                property real startX: 0
                property real startY: 0
                property bool swiping: false
                onPressed: function(mouse) {
                    startX = mouse.x;
                    startY = mouse.y;
                    swiping = false;
                }
                onPositionChanged: function(mouse) {
                    if (!pressed)
                        return;
                    const dx = mouse.x - startX;
                    const dy = mouse.y - startY;
                    // LAUNCHER_SWIPE_SLOP_PX 8, horizontal dominance x1.15
                    if (!swiping && Math.abs(dx) >= Theme.px(8)
                            && Math.abs(dx) > Math.abs(dy) * 1.15)
                        swiping = true;
                    if (swiping) {
                        let off = dx;
                        // edge rubber-band 0.28 at first/last course
                        if ((root.courseIndex <= 0 && off > 0)
                                || (root.courseIndex >= root.courses.length - 1 && off < 0))
                            off *= 0.28;
                        slideItem.x = off;
                    }
                }
                onReleased: function(mouse) {
                    const dx = mouse.x - startX;
                    if (swiping) {
                        swiping = false;
                        // LAUNCHER_SWIPE_THRESHOLD_PX 90 -> 135
                        if (Math.abs(dx) >= Theme.px(90))
                            root.selectCourse(root.courseIndex + (dx < 0 ? 1 : -1));
                        else
                            backAnim.restart();
                    } else {
                        const edge = width * 0.22;
                        if (mouse.x < edge)
                            root.selectCourse(root.courseIndex - 1);
                        else if (mouse.x > width - edge)
                            root.selectCourse(root.courseIndex + 1);
                        else
                            root.startCourse();
                    }
                }
                onCanceled: {
                    swiping = false;
                    backAnim.restart();
                }
                NumberAnimation {
                    id: backAnim
                    target: slideItem
                    property: "x"
                    to: 0
                    duration: 160
                    easing.type: Easing.OutCubic
                }
            }

            // -- big play button: PLAY_BTN_SIZE 192@1280 -> 288, centered in
            //    the Godot body right section (~0.76w), vertical center --
            Item {
                id: playBtn
                width: Theme.px(192) + Theme.px(16)   // glow grows 8@1280 -> 12 each side
                height: width
                x: panel.width * 0.76 - width * 0.5
                y: panel.height * 0.5 - height * 0.5

                Rectangle {
                    anchors.fill: parent
                    radius: width * 0.5
                    color: Qt.rgba(0.0, 0.941, 1.0, 0.12)   // ACCENT glow a=0.12
                }
                Rectangle {
                    x: Theme.px(8)
                    y: Theme.px(8)
                    width: Theme.px(192)
                    height: width
                    radius: width * 0.5
                    color: Qt.rgba(0, 0, 0, 0.50)
                    border.width: 2                            // Godot 1.5 @1280
                    border.color: Qt.rgba(0.0, 0.941, 1.0, 0.30)
                }
                Rectangle {
                    // inner arc ring: outer.grow(-14@1280 -> 21)
                    x: Theme.px(8) + Theme.px(14)
                    y: Theme.px(8) + Theme.px(14)
                    width: Theme.px(192) - Theme.px(28)
                    height: width
                    radius: width * 0.5
                    color: "transparent"
                    border.width: 2                            // Godot 1.2 @1280
                    border.color: Qt.rgba(0.0, 0.941, 1.0, 0.22)
                }
                Rectangle {
                    // icon box 48x48 @1280 -> 72, Godot radius 24 -> circle
                    x: (playBtn.width - width) * 0.5
                    y: (playBtn.height - height) * 0.5
                    width: Theme.px(48)
                    height: width
                    radius: width * 0.5
                    color: Qt.rgba(0.0, 0.941, 1.0, 0.10)
                    border.width: 1
                    border.color: Qt.rgba(0.0, 0.941, 1.0, 0.30)
                }
                Canvas {
                    // filled ACCENT play triangle (-5,-9)(-5,9)(11,0) @1280
                    width: Theme.px(16)
                    height: Theme.px(18)
                    x: playBtn.width * 0.5 - Theme.px(5)
                    y: playBtn.height * 0.5 - Theme.px(9)
                    renderTarget: Canvas.Image
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        ctx.fillStyle = Theme.primary;
                        ctx.beginPath();
                        ctx.moveTo(0, 0);
                        ctx.lineTo(0, height);
                        ctx.lineTo(width, height * 0.5);
                        ctx.closePath();
                        ctx.fill();
                    }
                }
                Text {
                    // "START DRILL" centered at button center +20@1280 -> +30
                    width: Theme.px(120)
                    x: playBtn.width * 0.5 - width * 0.5
                    y: playBtn.height * 0.5 + Theme.px(20)
                    text: "START DRILL"
                    color: Theme.primary
                    font.pixelSize: Theme.fontPx(16)  // _fs(12)
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    // "START NOW" centered at button center +36@1280 -> +54
                    width: Theme.px(120)
                    x: playBtn.width * 0.5 - width * 0.5
                    y: playBtn.height * 0.5 + Theme.px(36)
                    text: "START NOW"
                    color: Theme.muted
                    font.pixelSize: Theme.fontPx(14)  // _fs(10)
                    horizontalAlignment: Text.AlignHCenter
                }
                MouseArea {
                    x: Theme.px(8)
                    y: Theme.px(8)
                    width: Theme.px(192)
                    height: width
                    onClicked: root.startCourse()
                }
            }
        }

        // panel border: white 0.05, 1px, LAUNCHER_PANEL_RADIUS
        Rectangle {
            anchors.fill: parent
            radius: Theme.px(24)
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.05)
        }

        ClickFlash {
            id: panelFlash
            radius: Theme.px(24)
            flashColor: Theme.primary
        }

        // -- tab header: ROW_H 34@1280 -> 51 at PANEL_INSET 24@1280 -> 36;
        //    one tab per launcher course, ACCENT underline (Godot 2px -> 3) --
        Item {
            id: tabRow
            x: Theme.px(24)
            y: Theme.px(16)
            width: panel.width - Theme.px(24) * 2
            height: Theme.px(34)

            // tabs centered in the area left of the sensor badge
            // (SENSOR_W 168@1280 -> 252 + 10@1280 -> 15 gap).
            Row {
                id: tabs
                spacing: Theme.px(24)                 // COURSE_TAB_GAP 24 -> 36
                x: Math.max(0, (tabRow.width - Theme.px(168) - Theme.px(10) - width) * 0.5)
                height: tabRow.height

                Repeater {
                    id: tabRepeater
                    model: root.courses
                    delegate: Item {
                        id: tabDelegate
                        required property int index
                        required property var modelData
                        readonly property bool active: root.courseIndex === index
                        width: tabLabel.implicitWidth
                        height: tabs.height

                        Text {
                            id: tabLabel
                            anchors.verticalCenter: parent.verticalCenter
                            text: tabDelegate.modelData.title
                            // COURSE_TAB_ACTIVE_FONT 22 / COURSE_TAB_IDLE_FONT 15
                            font.pixelSize: tabDelegate.active ? Theme.fontPx(22) : Theme.fontPx(15)
                            color: tabDelegate.active ? Theme.primary
                                                      : Qt.rgba(1, 1, 1, 0.40)  // COURSE_TAB_IDLE_COLOR
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.selectCourse(tabDelegate.index)
                        }
                    }
                }
            }

            Rectangle {
                id: underline
                // tabRepeater.itemAt() has no change notification, so the
                // underline position is synced explicitly on count/selection
                // changes (Godot lerps toward the target at speed 18).
                property bool ready: false
                function sync() {
                    const t = tabRepeater.itemAt(root.courseIndex);
                    if (t) {
                        x = tabs.x + t.x;
                        width = t.width;
                    }
                }
                // Godot: baseline + 5@1280 -> just above the separator line
                y: tabRow.height - 2
                height: 3
                radius: 1
                color: Theme.primary
                Behavior on x { NumberAnimation { duration: underline.ready ? 120 : 0 } }
                Behavior on width { NumberAnimation { duration: underline.ready ? 120 : 0 } }
                Component.onCompleted: {
                    sync();
                    ready = true;
                }
                Connections {
                    target: tabRepeater
                    function onCountChanged() { underline.sync(); }
                }
                Connections {
                    target: root
                    function onCourseIndexChanged() { underline.sync(); }
                }
            }

            // sensor badge: Rect2(row right, 168x22)@1280, radius 10 -> 15
            Rectangle {
                x: tabRow.width - Theme.px(168)
                y: Theme.px(6)
                width: Theme.px(168)
                height: Theme.px(22)
                radius: Theme.px(10)
                color: Qt.rgba(1, 1, 1, 0.05)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.10)

                Rectangle {
                    x: Theme.px(11) - width * 0.5
                    y: (parent.height - height) * 0.5
                    width: Theme.px(6)
                    height: width
                    radius: width * 0.5
                    color: Theme.primary
                }
                Text {
                    x: Theme.px(18)
                    width: parent.width - Theme.px(20)
                    height: parent.height
                    text: "6-AXIS PRESSURE SENSORS"
                    color: Qt.rgba(1, 1, 1, 0.70)
                    font.pixelSize: Theme.fontPx(13)  // _fs(9)
                    // Godot draw_center_text shrinks the font until it fits
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: Theme.fontTiny
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            // separator under the tab row: row_top + ROW_H + 4@1280
            Rectangle {
                y: tabRow.height + Theme.px(4)
                width: tabRow.width
                height: 1
                color: Qt.rgba(1, 1, 1, 0.05)
            }
        }
    }

    // ================= Movements view (COACHING CLASSROOM) =================
    // Godot: _draw_page_header (dot + "COACHING CLASSROOM" + separator) and
    // _draw_moves_panel: left move list (MOVES_LIST_W 360@1280) + right detail.
    Item {
        id: movesRoot
        visible: root.viewMode === "moves"
        x: root.panelX
        y: root.panelY
        width: root.panelW
        height: root.panelH

        readonly property real headerH: Theme.px(42)            // HEADER_ROW_H 42 -> 63
        readonly property real gap: Theme.px(14)                // SECTION_GAP 14 -> 21
        readonly property real listW: Theme.px(360)             // MOVES_LIST_W 360 -> 540
        readonly property real bodyY: headerH + gap
        readonly property real bodyH: height - bodyY
        readonly property var currentMove: CourseCatalog.moves[root.selectedMoveIndex] || ({})

        // header: dot + title + separator
        Item {
            id: mvHeader
            height: movesRoot.headerH
            Rectangle {  // ACCENT dot + glow
                x: 14; y: parent.height / 2 - 5
                width: 10; height: 10; radius: 5; color: Theme.primary
                Rectangle {
                    x: -4; y: -4; width: 18; height: 18; radius: 9
                    color: Qt.rgba(0.0, 0.941, 1.0, 0.35)
                }
            }
            Text {
                x: 36
                anchors.verticalCenter: parent.verticalCenter
                text: "COACHING CLASSROOM"
                color: Theme.text
                font.pixelSize: Theme.fontPx(18)
            }
            Rectangle {  // separator under header
                anchors.left: parent.left; anchors.right: parent.right
                y: parent.height - 1; height: 1
                color: Qt.rgba(1, 1, 1, 0.05)
            }
        }

        // ---- left: moves list ----
        Item {
            id: moveList
            x: 0
            y: movesRoot.bodyY
            width: movesRoot.listW
            height: movesRoot.bodyH
            Repeater {
                model: CourseCatalog.moves
                delegate: Rectangle {
                    id: moveCard
                    required property int index
                    required property var modelData
                    y: moveCard.index * (Theme.px(72) + Theme.px(8))
                    x: 0
                    width: moveList.width - Theme.px(6)
                    height: Theme.px(72)
                    radius: Theme.px(16)
                    color: root.selectedMoveIndex === moveCard.index ? Qt.rgba(1, 1, 1, 0.04)
                        : (listMa.containsMouse ? Qt.rgba(1, 1, 1, 0.03) : "transparent")
                    border.width: 1
                    border.color: root.selectedMoveIndex === moveCard.index
                        ? Qt.rgba(0.0, 0.941, 1.0, 0.40) : Qt.rgba(1, 1, 1, 0.05)
                    // thumbnail
                    Item {
                        x: Theme.px(12); y: Theme.px(12)
                        width: Theme.px(48); height: Theme.px(48)
                        Image {
                            anchors.fill: parent
                            source: moveCard.modelData.cover
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                        Rectangle { anchors.fill: parent; color: Qt.rgba(0,0,0,0.50) }
                        Rectangle {
                            anchors.fill: parent; radius: Theme.px(12)
                            color: "transparent"; border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.05)
                        }
                        Text {
                            anchors.centerIn: parent
                            text: (moveCard.index + 1)
                            color: Theme.text
                            font.pixelSize: Theme.fontPx(11)
                        }
                    }
                    Text {
                        x: Theme.px(12) + Theme.px(48) + Theme.px(12)
                        y: Theme.px(18)
                        width: parent.width - x - Theme.px(90)
                        text: moveCard.modelData.title
                        color: root.selectedMoveIndex === moveCard.index ? Theme.primary : Theme.text
                        font.pixelSize: Theme.fontPx(13)
                        elide: Text.ElideRight
                    }
                    Rectangle {  // difficulty pill
                        x: parent.width - Theme.px(84); y: Theme.px(44)
                        width: Theme.px(72); height: Theme.px(18); radius: Theme.px(6)
                        color: Qt.rgba(1, 1, 1, 0.10)
                        Text {
                            anchors.centerIn: parent
                            text: moveCard.modelData.difficulty
                            color: Qt.rgba(1, 1, 1, 0.92)
                            font.pixelSize: Theme.fontPx(9)
                        }
                    }
                    MouseArea {
                        id: listMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.selectedMoveIndex = moveCard.index
                    }
                }
            }
        }

        // ---- right: move detail ----
        Rectangle {
            id: moveDetail
            x: movesRoot.listW + movesRoot.gap
            y: movesRoot.bodyY
            width: movesRoot.width - movesRoot.listW - movesRoot.gap
            height: movesRoot.bodyH
            radius: Theme.px(24)
            color: Qt.rgba(0.055, 0.055, 0.063, 1.0)      // PANEL_DARK
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.05)

            readonly property real pad: Theme.px(20)
            readonly property var mv: movesRoot.currentMove

            // hero image
            Item {
                id: hero
                x: moveDetail.pad; y: moveDetail.pad
                width: Theme.px(96); height: Theme.px(80)
                Image {
                    anchors.fill: parent
                    source: moveDetail.mv.cover || ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                Rectangle {
                    anchors.fill: parent; radius: Theme.px(12)
                    color: "transparent"; border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.05)
                }
            }
            // difficulty + time badges
            Rectangle {
                x: hero.x + hero.width + Theme.px(14); y: hero.y
                width: Theme.px(118); height: Theme.px(16); radius: Theme.px(6)
                color: Qt.rgba(0.0, 0.941, 1.0, 0.15)
                border.width: 1; border.color: Qt.rgba(0.0, 0.941, 1.0, 0.25)
                Text {
                    anchors.centerIn: parent
                    text: (moveDetail.mv.difficulty || "").toUpperCase()
                    color: Theme.primary; font.pixelSize: Theme.fontPx(9)
                }
            }
            Rectangle {
                x: hero.x + hero.width + Theme.px(14) + Theme.px(118) + Theme.px(8); y: hero.y
                width: Theme.px(92); height: Theme.px(16); radius: Theme.px(6)
                color: Qt.rgba(1, 1, 1, 0.05)
                Text {
                    anchors.centerIn: parent
                    text: (moveDetail.mv.timeToLearn || "") + " Study"
                    color: Qt.rgba(1, 1, 1, 0.6); font.pixelSize: Theme.fontPx(9)
                }
            }
            // headline
            Text {
                x: hero.x + hero.width + Theme.px(14)
                y: hero.y + Theme.px(16) + Theme.px(8)
                width: moveDetail.width - x - moveDetail.pad
                text: moveDetail.mv.title || ""
                color: Theme.text
                font.pixelSize: Theme.fontPx(17)
                elide: Text.ElideRight
            }
            // description
            Text {
                x: hero.x + hero.width + Theme.px(14)
                y: hero.y + Theme.px(16) + Theme.px(8) + Theme.px(24) + Theme.px(6)
                width: moveDetail.width - x - moveDetail.pad
                height: Theme.px(36)
                text: moveDetail.mv.desc || ""
                color: Qt.rgba(1, 1, 1, 0.6)
                font.pixelSize: Theme.fontPx(11)
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            // ACTION GUIDE separator + steps
            Rectangle {
                x: moveDetail.pad
                y: Math.max(hero.y + hero.height + Theme.px(12),
                            hero.y + Theme.px(16) + Theme.px(8) + Theme.px(24) + Theme.px(6) + Theme.px(42))
                width: moveDetail.width - moveDetail.pad * 2; height: 1
                color: Qt.rgba(1, 1, 1, 0.05)
            }
            Text {
                x: moveDetail.pad
                y: Math.max(hero.y + hero.height + Theme.px(12),
                            hero.y + Theme.px(16) + Theme.px(8) + Theme.px(24) + Theme.px(6) + Theme.px(42))
                       + Theme.px(10)
                text: "ACTION GUIDE"
                color: Theme.muted
                font.pixelSize: Theme.fontPx(10)
            }
            Column {
                x: moveDetail.pad
                y: Math.max(hero.y + hero.height + Theme.px(12),
                            hero.y + Theme.px(16) + Theme.px(8) + Theme.px(24) + Theme.px(6) + Theme.px(42))
                       + Theme.px(28)
                width: moveDetail.width - moveDetail.pad * 2
                spacing: Theme.px(6)
                Repeater {
                    model: moveDetail.mv.steps || []
                    delegate: Rectangle {
                        id: stepCard
                        required property int index
                        required property string modelData
                        width: parent.width
                        height: Theme.px(38)
                        radius: Theme.px(12)
                        color: Qt.rgba(1, 1, 1, 0.01)
                        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.03)
                        Rectangle {
                            x: Theme.px(8); y: Theme.px(8)
                            width: Theme.px(20); height: Theme.px(20); radius: Theme.px(8)
                            color: Qt.rgba(1, 1, 1, 0.05)
                            Text {
                                anchors.centerIn: parent
                                text: (stepCard.index + 1); color: Theme.primary
                                font.pixelSize: Theme.fontPx(10)
                            }
                        }
                        Text {
                            x: Theme.px(34); y: Theme.px(6)
                            width: parent.width - Theme.px(42); height: parent.height - Theme.px(12)
                            text: stepCard.modelData
                            color: Qt.rgba(1, 1, 1, 0.8)
                            font.pixelSize: Theme.fontPx(11)
                            wrapMode: Text.WordWrap; maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }
                }
            }
            // INTERACTIVE TRY button (not ported -> callout, like other interactive entries)
            Rectangle {
                x: moveDetail.pad
                y: moveDetail.height - moveDetail.pad - Theme.px(42)
                width: moveDetail.width - moveDetail.pad * 2; height: Theme.px(42)
                radius: Theme.px(20)
                color: tryMa.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.04)
                border.width: 1
                border.color: tryMa.containsMouse ? Qt.rgba(0.0, 0.941, 1.0, 0.38) : Qt.rgba(0.0, 0.941, 1.0, 0.12)
                Text {
                    anchors.centerIn: parent
                    text: "INTERACTIVE TRY"
                    color: Theme.primary; font.pixelSize: Theme.fontPx(12)
                }
                MouseArea {
                    id: tryMa
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: AppState.showCallout("info", "互动训练待移植",
                        (moveDetail.mv.title || "该动作") + "的互动训练将在后续阶段移植")
                }
            }
        }
    }
}
