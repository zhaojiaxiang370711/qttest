pragma ComponentBehavior: Bound
import QtQuick
import QxznHmi

// 子游戏占位页：娱乐/健身网格里的游戏卡点击后进入此页。子游戏本身以后作为
// 独立的 Godot 游戏实现，本页只展示封面/标题/说明 + 「即将作为独立游戏运行」
// 占位 + 返回。不实现任何游戏内容，也不引用 DDS/电机/LED 等。
Item {
    id: page
    anchors.fill: parent

    readonly property var card: AppState.subgameCard || ({})
    readonly property bool isGodot: page.card.tag === "Godot"
    readonly property string cover: ShellData.coverFor(page.card.id !== undefined ? page.card.id : "")
    readonly property color accent: page.card.color !== undefined ? page.card.color : Theme.primary

    // background tint
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.02, 0.02, 0.025, 1.0)
    }

    // ================= top bar =================
    Item {
        id: topBar
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        height: 110

        Rectangle {
            id: backButton
            x: 40; y: (parent.height - height) / 2
            width: 110; height: 64; radius: Theme.radiusButton
            color: backMa.containsPress ? Qt.rgba(1, 1, 1, 0.16)
                 : backMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10)
                 : Qt.rgba(1, 1, 1, 0.06)
            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.12)
            HmiIcon { anchors.centerIn: parent; name: "arrow-right"; rotation: 180; tone: "white"; size: 32 }
            MouseArea { id: backMa; anchors.fill: parent; hoverEnabled: true; onClicked: AppState.back() }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: backButton.right; anchors.leftMargin: 28
            text: page.card.title !== undefined ? page.card.title : "子游戏"
            color: Theme.text
            font.pixelSize: Theme.fontHeader
            elide: Text.ElideRight
            width: parent.width - backButton.width - 200
        }

        // tag pill
        Rectangle {
            anchors.right: parent.right; anchors.rightMargin: 40
            anchors.verticalCenter: parent.verticalCenter
            width: tagLabel.implicitWidth + 48; height: 44; radius: Theme.radiusPill
            color: Qt.rgba(page.accent.r, page.accent.g, page.accent.b, 0.16)
            border.width: 1
            border.color: Qt.rgba(page.accent.r, page.accent.g, page.accent.b, 0.30)
            Text {
                id: tagLabel
                anchors.centerIn: parent
                text: page.card.tag !== undefined ? page.card.tag : ""
                color: page.accent
                font.pixelSize: Theme.fontSmall
            }
        }

        Rectangle { // divider
            anchors.left: parent.left; anchors.right: parent.right
            y: parent.height - 1; height: 1
            color: Qt.rgba(1, 1, 1, 0.05)
        }
    }

    // ================= hero + description =================
    Item {
        id: hero
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: topBar.bottom; anchors.topMargin: 60
        width: 920; height: 420

        Rectangle {
            anchors.fill: parent; radius: Theme.radiusCard
            color: Qt.rgba(1, 1, 1, 0.03)
            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08)
        }
        Image {
            anchors.fill: parent
            anchors.margins: 24
            source: page.cover
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: page.cover !== ""
        }
        // dim + title overlay on the cover
        Rectangle {
            anchors.fill: parent; radius: Theme.radiusCard
            color: "transparent"
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.55; color: Qt.rgba(0, 0, 0, 0.0) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.80) }
            }
        }
        Text {
            anchors.left: parent.left; anchors.leftMargin: 40
            anchors.right: parent.right; anchors.rightMargin: 40
            anchors.bottom: parent.bottom; anchors.bottomMargin: 60
            text: page.card.subtitle !== undefined ? page.card.subtitle : ""
            color: Qt.rgba(1, 1, 1, 0.92)
            font.pixelSize: Theme.fontBody
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
        }
    }

    // ================= coming-soon panel =================
    Rectangle {
        id: panel
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: hero.bottom; anchors.topMargin: 40
        width: 920; height: 170
        radius: Theme.radiusCard
        color: Qt.rgba(0.045, 0.045, 0.05, 1.0)
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.06)

        Column {
            anchors.centerIn: parent
            spacing: 18

            HmiIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: page.isGodot ? "gamepad-2" : "monitor-play"
                tone: "white"
                size: 44
                opacity: 0.85
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: page.isGodot
                    ? "该子游戏将作为独立的 Godot 应用运行"
                    : "该功能尚未移植"
                color: Theme.text
                font.pixelSize: Theme.fontTitle
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: page.isGodot
                    ? "后续会以外挂 Godot 游戏的方式接入，敬请期待。"
                    : "将在后续阶段移植。"
                color: Theme.muted
                font.pixelSize: Theme.fontSmall
            }
        }
    }
}
