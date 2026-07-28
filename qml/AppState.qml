pragma Singleton
import QtQuick
import QxznHmi

// Navigation / overlay / callout state shared by the whole shell.
// Page components only talk to this singleton, never to each other.
QtObject {
    id: appState

    // Top-level nav id: home / learning / result / entertainment / device / combat.
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
    property var subgameCard: null

    // Callout payload shown by CalloutHost; empty message hides the callout.
    property string calloutType: "info"
    property string calloutTitle: ""
    property string calloutMessage: ""

    readonly property var navIds: ["home", "learning", "result", "entertainment", "device", "combat"]
    readonly property var subPageIds: ["fitness", "ai_coach", "boxing_knowledge", "course_lesson", "focus_mitt", "subgame"]

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

    // Open a sub-game placeholder page for the given card object (from the
    // entertainment / fitness grids). The games themselves will ship later as
    // standalone Godot apps; this only navigates into a placeholder view.
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

    function openOverlay(id) {
        overlayPanel = id;
    }

    function closeOverlay() {
        overlayPanel = "";
    }

    // ESC semantics: close overlay -> leave sub page -> back to home -> false (may quit).
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

    function showCallout(type, title, msg) {
        calloutType = type;
        calloutTitle = title;
        calloutMessage = msg;
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
