pragma Singleton
// ============================================================
// 【教学导读】全局导航/弹层状态中心（QML 单例）。
// 本文件演示一种值得学习的架构约定："单例充当全局状态管理器"——
// 页面之间绝不直接互相引用，只读写 AppState，类似一个极简版全局 store。
// 本文件演示的 QML 概念：
//   1. 可读写 property（带初始值，变化时自动通知所有绑定处）
//   2. property var — 无类型属性，可存任意 JS 值
//   3. 用 function 集中封装状态修改与校验
// 配套阅读：qml/Main.qml（Loader 根据这里的状态切换页面）
// ============================================================
import QtQuick
import QxznHmi

// Navigation / overlay / callout state shared by the whole shell.
// Page components only talk to this singleton, never to each other.
QtObject {
    id: appState

    // Top-level nav id: home / learning / result / entertainment / device / combat.
    // 可读写属性，带初始值；属性变化会自动通知所有绑定到它的地方
    property string selectedNav: "home"
    // Sub page id stacked above the current nav page: "" / fitness / ai_coach /
    // boxing_knowledge / course_lesson / focus_mitt.
    property string subPage: ""
    // Overlay panel id (device-page panels etc.); "" means no overlay.
    property string overlayPanel: ""

    // Selected video course id for the course_lesson sub page. Validated against
    // CourseCatalog; defaults to 专项练习.
    property string courseId: "special_practice"

    // Selected sub-game card (the whole card object from ShellData / a page
    // model). The SubgamePage reads it; null until a card is opened.
    // Selected sub-game card (the whole card object from ShellData / a page
    // model). The SubgamePage reads it; null until a card is opened.
    // var 是无类型属性，可以存任意 JS 值（这里是整张卡片对象或 null）
    property var subgameCard: null

    // Callout payload shown by CalloutHost; empty message hides the callout.
    property string calloutType: "info"
    property string calloutTitle: ""
    property string calloutMessage: ""

    readonly property var navIds: ["home", "learning", "result", "entertainment", "device", "combat"]
    readonly property var subPageIds: ["fitness", "ai_coach", "boxing_knowledge", "course_lesson", "focus_mitt", "subgame", "fight_flow"]

    // 通过函数集中修改状态并做合法性校验，而不是让页面随便直接改——
    // 这是值得初学者学习的封装习惯
    function selectNav(id) {
        if (navIds.indexOf(id) < 0)
            return;
        selectedNav = id;
        subPage = "";
    }

    function openSubPage(id) {
        if (subPageIds.indexOf(id) < 0)
            return;
        subPage = id;
    }

    // The assistant is a learning workflow even when opened from the global
    // status bar. Anchor it to Learning so Back always returns to a predictable
    // page instead of whichever shell tab happened to be active.
    function openAiAssistant() {
        overlayPanel = "";
        selectedNav = "learning";
        subPage = "ai_coach";
    }

    // Open a placeholder for cards that do not yet have a native or external
    // launcher. VRBeatsKit bypasses this path and uses GameLauncher instead.
    function openSubGame(card) {
        if (card === null || card === undefined || card.id === undefined)
            return false;
        subgameCard = card;
        subPage = "subgame";
        return true;
    }

    // Open a video course: validate the id against CourseCatalog, anchor to the
    // learning section, and reveal the course_lesson player sub page.
    function openCourse(id) {
        if (!CourseCatalog.contains(id))
            return false;
        courseId = id;
        selectedNav = "learning";
        subPage = "course_lesson";
        return true;
    }

    // Open the Fight Flow course: same validation as openCourse, but routed to
    // the dedicated fight_flow player sub page (lessons_test Web 原型复刻).
    function openFightFlow(id) {
        if (!CourseCatalog.contains(id))
            return false;
        courseId = id;
        selectedNav = "learning";
        subPage = "fight_flow";
        return true;
    }

    function openOverlay(id) {
        overlayPanel = id;
    }

    function closeOverlay() {
        overlayPanel = "";
    }

    // ESC semantics: close overlay -> leave sub page -> back to home -> false (may quit).
    // 导航栈语义：ESC 逐层返回（关弹层 → 退出子页 → 回首页），
    // 全部退完返回 false，由调用方决定是否退出程序
    function back() {
        if (overlayPanel !== "") {
            overlayPanel = "";
            return true;
        }
        if (subPage !== "") {
            subPage = "";
            return true;
        }
        if (selectedNav !== "home") {
            selectedNav = "home";
            return true;
        }
        return false;
    }

    // 每次 showCallout 自增：即使文案与上次相同，CalloutHost 也能收到变化通知
    property int calloutSeq: 0

    function showCallout(type, title, msg) {
        calloutType = type;
        calloutTitle = title;
        calloutMessage = msg;
        calloutSeq += 1        // 必然变化，触发 onCalloutSeqChanged
    }

    // Applies --nav / --overlay / --course command line seeds (called once from
    // Main.qml). course_lesson is accepted as a direct deep link; --course is
    // validated through CourseCatalog.
    // Applies --nav / --overlay / --course / --subgame command line seeds
    // (called once from Main.qml). course_lesson is accepted as a direct deep
    // link; --course is validated through CourseCatalog; --subgame looks the
    // card up in ShellData.entertainmentCards.
    function applyInitial(nav, overlay, course, subgameId) {
        if (navIds.indexOf(nav) >= 0) {
            selectedNav = nav;
            subPage = "";
        } else if (nav === "course_lesson" || nav === "focus_mitt") {
            selectedNav = "learning";
            subPage = nav;
        } else if (nav === "ai_coach") {
            selectedNav = "learning";
            subPage = nav;
        } else if (subPageIds.indexOf(nav) >= 0) {
            subPage = nav;
        } else {
            subPage = "";
        }
        overlayPanel = overlay;
        if (course !== undefined && course !== "" && CourseCatalog.contains(course))
            courseId = course;
        if (subgameId !== undefined && subgameId !== "") {
            for (let i = 0; i < ShellData.entertainmentCards.length; ++i) {
                if (ShellData.entertainmentCards[i].id === subgameId) {
                    subgameCard = ShellData.entertainmentCards[i];
                    break;
                }
            }
        }
    }
}
