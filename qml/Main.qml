pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QxznHmi

ApplicationWindow {
    id: window
    width: 1920
    height: 1080
    visible: true
    color: Theme.windowBackground
    title: "QXZN HMI"
    font.family: Theme.bodyFamily

    // All shell content is laid out at the Godot panel15 design size of
    // 1920x1080, then uniformly scaled and centered to fit the actual window
    // (Godot stretch mode canvas_items; aspect kept, so a 16:9 screen of any
    // size is filled exactly with no black borders).
    Item {
        id: shellRoot
        width: 1920
        height: 1080
        anchors.centerIn: parent
        scale: Math.min(window.width / 1920, window.height / 1080)

        Image {
            anchors.fill: parent
            source: "qrc:/resources/images/backgrounds/design_shell_background.png"
            fillMode: Image.Stretch
            smooth: true
        }

        TopBar {
            x: Theme.topBarRect.x
            y: Theme.topBarRect.y
            width: Theme.topBarRect.width
            height: Theme.topBarRect.height
        }

        // page container: runtime_layout.gd panel15 shell.main Rect2(48,150,1824,882)
        Rectangle {
            id: pageContainer
            x: Theme.pageRect.x
            y: Theme.pageRect.y
            width: Theme.pageRect.width
            height: Theme.pageRect.height
            radius: Theme.radiusCard
            color: Theme.panelMask
            border.width: 1
            border.color: Theme.cardBorder
            clip: true

            Loader {
                id: pageLoader
                anchors.fill: parent
                readonly property var navPages: ({
                    "home": "HomePage.qml",
                    "learning": "LearningPage.qml",
                    "result": "ResultPage.qml",
                    "entertainment": "EntertainmentPage.qml",
                    "device": "DevicePage.qml",
                    "combat": "CombatPowerPage.qml"
                })
                // sub pages take precedence over the selected nav page
                readonly property var subPages: ({
                    "fitness": "FitnessPage.qml",
                    "ai_coach": "AiCoachPage.qml",
                    "boxing_knowledge": "BoxingKnowledgePage.qml",
                    "course_lesson": "CourseLessonPage.qml",
                    "focus_mitt": "FocusMittPage.qml",
                    "subgame": "SubgamePage.qml"
                })
                source: {
                    if (AppState.subPage !== "" && pageLoader.subPages[AppState.subPage] !== undefined)
                        return pageLoader.subPages[AppState.subPage];
                    const file = pageLoader.navPages[AppState.selectedNav];
                    return file !== undefined ? file : "HomePage.qml";
                }
                opacity: 0
                onSourceChanged: fadeIn.restart()
                NumberAnimation {
                    id: fadeIn
                    target: pageLoader
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 160
                }
                Component.onCompleted: fadeIn.restart()
            }
        }

        CalloutHost {
            anchors.fill: parent
        }
    }

    Shortcut {
        sequence: "Esc"
        onActivated: {
            if (!AppState.back())
                Qt.quit();
        }
    }

    Item {
        id: keySink
        anchors.fill: parent
        focus: true
        Keys.onPressed: function(event) { SessionModel.onKey(event.key) }
    }

    Component.onCompleted: {
        AppState.applyInitial(Config.initialNav, Config.initialOverlay, Config.initialCourse, Config.initialSubgame);
        keySink.forceActiveFocus();
    }
}
