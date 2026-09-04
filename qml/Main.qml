pragma ComponentBehavior: Bound
// ============================================================
// 【教学导读】本文件是整个应用的 QML 入口（由 src/main.cpp 的
// loadFromModule("QxznHmi", "Main") 加载），负责创建顶层窗口、
// 按 1920x1080 设计稿等比缩放的容器，以及页面切换。
// 本文件演示的 QML 概念：
//   1. ApplicationWindow — Qt Quick Controls 提供的顶层窗口类型
//   2. 属性绑定 — 表达式依赖的值一变就自动重算（QML 最核心的特性）
//   3. Loader — 动态加载页面文件，实现页面切换
//   4. 信号处理器（onXxx）、NumberAnimation、Shortcut、键盘焦点
// 配套阅读：qml/AppState.qml（导航状态）、qml/Theme.qml（设计令牌）
// ============================================================
import QtQuick
import QtQuick.Controls
import QxznHmi

// pragma ComponentBehavior: Bound 是 Qt 6 推荐写法，让组件内的绑定行为更可预测
ApplicationWindow {
    // id 是 QML 里引用其他元素的方式，只在当前文件作用域内有效
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
        // 锚点布局：把容器居中到父元素——anchors 是 QML 定位子元素的主要方式之一
        anchors.centerIn: parent
        // 属性绑定：scale 的表达式会在 window.width/height 变化时自动重新求值；
        // 这里用它实现"按 1920x1080 设计稿等比缩放适配任意屏幕"
        scale: Math.min(window.width / 1920, window.height / 1080)

        // source 的 qrc:/ 前缀表示 Qt 资源系统（.qrc）里内嵌的图片
        Image {
            anchors.fill: parent
            source: "qrc:/resources/images/backgrounds/design_shell_background.png"
            fillMode: Image.Stretch
            smooth: true
        }

        TopBar {
            visible: AppState.subPage !== "fight_flow"
            x: Theme.topBarRect.x
            y: Theme.topBarRect.y
            width: Theme.topBarRect.width
            height: Theme.topBarRect.height
        }

        // page container: runtime_layout.gd panel15 shell.main Rect2(48,150,1824,882)
        Rectangle {
            id: pageContainer
            visible: AppState.subPage !== "fight_flow"
            x: Theme.pageRect.x
            y: Theme.pageRect.y
            width: Theme.pageRect.width
            height: Theme.pageRect.height
            radius: Theme.radiusCard
            color: Theme.panelMask
            border.width: 1
            border.color: Theme.cardBorder
            clip: true

            // Loader 动态加载 QML 文件：source 一变就卸载旧页面、加载新页面，
            // 配合下面的 source 绑定表达式就构成了整套页面切换机制
            Loader {
                id: pageLoader
                anchors.fill: parent
                // readonly property var + ({...}) 是 QML 里定义 JS 对象字面量属性的写法，
                // 这里充当"导航 id -> 页面文件"的路由表
                readonly property var navPages: ({
                    "home": "pages/HomePage.qml",
                    "learning": "pages/LearningPage.qml",
                    "result": "pages/ResultPage.qml",
                    "entertainment": "pages/EntertainmentPage.qml",
                    "device": "pages/DevicePage.qml",
                    "combat": "pages/CombatPowerPage.qml"
                })
                // sub pages take precedence over the selected nav page
                readonly property var subPages: ({
                    "fitness": "subpages/FitnessPage.qml",
                    "ai_coach": "subpages/AiCoachPage.qml",
                    "boxing_knowledge": "subpages/BoxingKnowledgePage.qml",
                    "course_lesson": "subpages/CourseLessonPage.qml",
                    "focus_mitt": "subpages/FocusMittPage.qml",
                    "subgame": "subpages/SubgamePage.qml"
                })
                source: {
                    if (AppState.subPage !== "" && pageLoader.subPages[AppState.subPage] !== undefined)
                        return pageLoader.subPages[AppState.subPage];
                    const file = pageLoader.navPages[AppState.selectedNav];
                    return file !== undefined ? file : "pages/HomePage.qml";
                }
                opacity: 0
                // onXxx 是信号处理器：source 变化（页面切换）时自动执行，重启淡入动画
                onSourceChanged: fadeIn.restart()
                // NumberAnimation：对指定属性的数值变化做动画（这里是透明度 0->1）
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

        // Immersive course players bypass the shell card and navigation bar.
        // Loading them only here also prevents two FightFlowPage instances from
        // opening the same CoursePlayer at the same time.
        Loader {
            id: immersivePageLoader
            anchors.fill: parent
            active: AppState.subPage === "fight_flow"
            source: active ? "subpages/FightFlowPage.qml" : ""
            z: 10
            opacity: 0
            onLoaded: immersiveFade.restart()

            NumberAnimation {
                id: immersiveFade
                target: immersivePageLoader
                property: "opacity"
                from: 0
                to: 1
                duration: 160
            }
        }

        CalloutHost {
            anchors.fill: parent
            z: 20
        }
    }

    // Shortcut：全局快捷键，按 Esc 先让 AppState 逐层返回，无可退再退出程序
    Shortcut {
        sequence: "Esc"
        onActivated: {
            if (!AppState.back())
                Qt.quit();
        }
    }

    // 键盘事件（Keys.onPressed）只在元素持有焦点时才会收到，所以这里 focus: true
    Item {
        id: keySink
        anchors.fill: parent
        focus: true
        Keys.onPressed: function(event) { SessionModel.onKey(event.key) }
    }

    // Component.onCompleted：组件创建完成时执行一次的处理器（类似构造完成后的回调）
    Component.onCompleted: {
        AppState.applyInitial(Config.initialNav, Config.initialOverlay, Config.initialCourse, Config.initialSubgame);
        keySink.forceActiveFocus();
    }
}
