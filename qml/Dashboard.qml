import QtQuick
import QtQuick.Controls
import QxznHmi

Rectangle {
    color: "#0f1115"

    Column {
        anchors.fill: parent
        anchors.margins: 32
        spacing: 24

        Rectangle { // Summary
            width: parent.width; height: 90; radius: 14; color: "#16191f"
            Column { anchors.centerIn: parent; spacing: 4
                Label { text: "对战等级 L" + SessionModel.battleLevel + "   分数 " + SessionModel.score
                        color: "#e6e8eb"; font.pixelSize: 22; font.bold: true }
                Label { text: "Game: " + Config.gameId + "  ·  难度: " + Config.difficulty
                        color: "#8a9099"; font.pixelSize: 13 } } }

        Row { // three stat panels (static seed)
            spacing: 24
            StatPanel { title: "力量"; value: SessionModel.power; caption: "Power" }
            StatPanel { title: "速度"; value: SessionModel.speed; caption: "Speed" }
            StatPanel { title: "耐力"; value: SessionModel.endurance; caption: "Endurance" }
        }

        Row { // five metric pills (input-driven + duration)
            spacing: 16
            MetricPill { icon: "💥"; caption: "Impact"; value: SessionModel.strikes * 3 } // notional impact score (strikes × 3) for this slice
            MetricPill { icon: "⏱"; caption: "Duration"; value: SessionModel.duration + "s" }
            MetricPill { icon: "🔥"; caption: "Calories"; value: Math.round(SessionModel.calories) }
            MetricPill { icon: "👊"; caption: "Strikes"; value: SessionModel.strikes }
            MetricPill { icon: "⚡"; caption: "Freq/min"; value: SessionModel.frequency }
        }

        Rectangle { // Schedule (static)
            width: parent.width; height: 120; radius: 14; color: "#16191f"
            Column { anchors.centerIn: parent; spacing: 4
                Label { text: "今日课程"; color: "#e6e8eb"; font.pixelSize: 18; font.bold: true }
                Label { text: "19:00  Boxing Basic  ·  20:00  HIIT"; color: "#8a9099"; font.pixelSize: 13 } } }

        Label { text: "最近击打: " + (SessionModel.lastSegment || "—"); color: "#5b626b"; font.pixelSize: 14 }
    }
}
