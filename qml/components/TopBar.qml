pragma ComponentBehavior: Bound
import QtQuick
import QxznHmi

// Pixel port of the Godot node-based top bar (scenes/TopBarView.tscn,
// scripts/top_bar_view.gd / shell_top_bar.gd). All geometry below is 1920-base
// taken directly from the .tscn node offsets (top-bar local coordinates).
Rectangle {
    id: bar
    width: 1794
    height: 87
    radius: 44                                   // StyleBoxFlat_lapjp corner_radius 44
    color: Theme.panel                           // Godot bg (0.067,0.067,0.067,0.78); Theme.panel is alpha 0.82
    border.width: 1
    border.color: Theme.cardBorder               // Godot border (1,1,1,0.06)

    function ddsTone(state) {
        if (state === "ready" || state === "receiving")
            return "green";
        if (state === "loading")
            return "yellow";
        if (state === "error")
            return "red";
        return "muted";
    }

    function ddsColor(state) {
        if (state === "ready" || state === "receiving")
            return Theme.success;
        if (state === "loading")
            return Theme.warn;
        if (state === "error")
            return Theme.danger;
        return Theme.muted;
    }

    // -- Avatar ring: AvatarRing (20,16,56x56), dual-color arcs from
    //    shell_top_bar.gd _draw_brand_area (cyan -0.75PI..0.25PI, danger 0.25PI..1.25PI).
    Item {
        x: 20
        y: 16
        width: 56
        height: 56

        Rectangle {
            anchors.fill: parent
            radius: 28
            // Godot StyleBoxFlat_mlbn2 bg (0.052,0.054,0.066,0.96) -- no Theme token.
            color: Qt.rgba(0.052, 0.054, 0.066, 0.96)
        }
        Canvas {
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.lineWidth = 3;               // Godot border_width 3
                ctx.strokeStyle = Theme.cyan;
                ctx.beginPath();
                ctx.arc(28, 28, 26.5, -0.75 * Math.PI, 0.25 * Math.PI);
                ctx.stroke();
                ctx.strokeStyle = Theme.danger;
                ctx.beginPath();
                ctx.arc(28, 28, 26.5, 0.25 * Math.PI, 1.25 * Math.PI);
                ctx.stroke();
            }
        }
        // AvatarIcon (34,30,28x28) user.svg tinted HMI_TEXT.
        HmiIcon {
            x: 14
            y: 14
            name: "user"
            tone: "white"
            size: 28
        }
    }

    // -- BrandTitle (93,17,180x36) font_size 31, brand font, HMI_TEXT.
    Text {
        x: 93
        y: 17
        width: 180
        height: 36
        text: "拳手档案"
        color: Theme.text
        font.family: Theme.brandFamily
        font.pixelSize: 31
        verticalAlignment: Text.AlignVCenter
    }
    // -- BrandSubtitle (93,51,156x24) font_size 16, HMI_PRIMARY.
    Text {
        x: 93
        y: 51
        width: 156
        height: 24
        text: "专业拳手"
        color: Theme.primary
        font.family: Theme.brandFamily
        font.pixelSize: 16
        verticalAlignment: Text.AlignVCenter
    }

    // -- NavShell (468,11,975x72) radius 36, bg (0,0,0,0.24).
    Rectangle {
        x: 468
        y: 11
        width: 975
        height: 72
        radius: 36
        color: Qt.rgba(0, 0, 0, 0.24)            // Godot StyleBoxFlat_k0bo1 -- no Theme token
        border.width: 1
        border.color: Theme.cardBorder           // Godot border (1,1,1,0.055)

        // 4 tabs Nav0..Nav3: x stride 975/4=243.75 starting at 474,
        // y 18, size 231.75x58, radius 29.
        Repeater {
            model: ShellData.navItems
            delegate: Rectangle {
                id: navTab
                required property int index
                required property var modelData
                readonly property bool active: AppState.selectedNav === navTab.modelData.id
                    || (AppState.selectedNav === "combat" && navTab.modelData.id === "learning")

                x: 6 + navTab.index * 243.75
                y: 7
                width: 231.75
                height: 58
                radius: Theme.radiusPill         // Godot tab radius 29
                transformOrigin: Item.Center
                color: navTab.active ? Theme.navSelected : Qt.rgba(1, 1, 1, 0.01)
                border.width: navTab.active ? 1 : 0
                border.color: Qt.rgba(1, 1, 1, 0.28)   // Godot active border -- no Theme token

                Text {
                    anchors.fill: parent
                    text: navTab.modelData.label
                    color: navTab.active ? Theme.text : Theme.muted
                    font.pixelSize: navTab.active ? 21 : 20   // top_bar_view.gd font sizes
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                TapHandler {
                    onTapped: {
                        navFlash.flash();
                        AppState.selectNav(navTab.modelData.id);
                    }
                }
                ClickFlash {
                    id: navFlash
                    radius: Theme.radiusPill
                }
                // 260ms selection pulse.
                SequentialAnimation {
                    id: pulse
                    NumberAnimation { target: navTab; property: "scale"; to: 1.06; duration: 130 }
                    NumberAnimation { target: navTab; property: "scale"; to: 1.0; duration: 130 }
                }
                onActiveChanged: if (navTab.active) pulse.restart()
            }
        }
    }

    // Global AI assistant entry. The right-hand status cluster is intentionally
    // compact so this remains a one-tap action without changing the nav tabs.
    Item {
        id: aiAssistantButton
        x: 1450
        y: 13
        width: 58
        height: 64

        Rectangle {
            anchors.fill: parent
            radius: 24
            color: AppState.subPage === "ai_coach"
                   ? Qt.rgba(0, 0.941, 1, 0.20) : Qt.rgba(1, 1, 1, 0.035)
            border.width: AppState.subPage === "ai_coach" ? 1 : 0
            border.color: Theme.primary
        }
        Text {
            anchors.centerIn: parent
            text: "AI"
            color: AppState.subPage === "ai_coach" ? Theme.primary : Theme.text
            font.family: Theme.brandFamily
            font.pixelSize: 23
        }
        TapHandler {
            onTapped: {
                aiFlash.flash();
                AppState.openAiAssistant();
            }
        }
        ClickFlash {
            id: aiFlash
            radius: 24
        }
    }

    // -- WifiIcon reflects local DDS bridge state. "ready" does not imply a
    //    matched remote writer.
    Item {
        x: 1510
        y: 13
        width: 64
        height: 64
        HmiIcon {
            x: 10
            y: 10
            name: "wifi"
            tone: bar.ddsTone(DdsBridge.state)
            size: 44
            opacity: DdsBridge.state === "disabled" ? 0.55 : 0.96
        }
        Rectangle {
            x: 45
            y: 7
            width: 12
            height: 12
            radius: 6
            color: bar.ddsColor(DdsBridge.state)
            border.width: 2
            border.color: Theme.panel
        }
        TapHandler {
            onTapped: {
                wifiFlash.flash();
                if (DdsBridge.state === "error") {
                    AppState.showCallout("error", "DDS 通信异常",
                                         DdsBridge.lastError.length > 0
                                         ? DdsBridge.lastError : "DDS 后端不可用");
                } else {
                    AppState.selectNav("device");
                }
            }
        }
        ClickFlash {
            id: wifiFlash
            radius: 32
        }
    }

    // -- BatteryIcon (1532,23,44x44) battery-full.svg, muted a=0.96 (no hit area).
    HmiIcon {
        x: 1580
        y: 23
        name: "battery-full"
        tone: "muted"
        size: 44
        opacity: 0.96
    }

    // -- ClockText (1590,21,99x45) brand font_size 31, centered, 1s refresh.
    Text {
        id: clockText
        x: 1630
        y: 21
        width: 78
        height: 45
        color: Theme.text
        font.family: Theme.brandFamily
        font.pixelSize: 31
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        Timer {
            interval: 1000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: clockText.text = Qt.formatDateTime(new Date(), "HH:mm")
        }
    }

    // -- ExitHit (1719,11,75x75) transparent radius 18; ExitIcon (1715,16,52x52)
    //    power.svg, HMI_TEXT a=0.88.
    Item {
        x: 1719
        y: 11
        width: 75
        height: 75
        TapHandler {
            onTapped: {
                exitFlash.flash();
                Qt.quit();
            }
        }
        ClickFlash {
            id: exitFlash
            radius: 18
        }
    }
    HmiIcon {
        x: 1715
        y: 16
        name: "power"
        tone: "white"
        size: 52
        opacity: 0.88
    }
}
