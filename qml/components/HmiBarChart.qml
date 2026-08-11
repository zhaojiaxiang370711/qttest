pragma ComponentBehavior: Bound
import QtQuick
import QxznHmi

// Seven-day bar trend, pure rectangles (sparring_history_page.gd _draw_trend_card).
// Bars are equal width, bottom-anchored; empty days render as a low-alpha stub.
Item {
    id: chart
    property var values: []
    property color barColor: Theme.primary
    property real barSpacing: Theme.px(12)
    property real barRadius: 2
    property real minBarHeight: Theme.px(5)
    property real emptyBarHeight: Theme.px(2)

    property real maxValue: 1
    onValuesChanged: {
        let peak = 1;
        for (let i = 0; i < chart.values.length; ++i)
            peak = Math.max(peak, Number(chart.values[i]) || 0);
        chart.maxValue = peak;
    }

    Row {
        anchors.fill: parent
        spacing: chart.barSpacing
        Repeater {
            model: chart.values
            delegate: Item {
                id: barSlot
                required property real modelData
                width: chart.values.length > 0
                       ? (chart.width - chart.barSpacing * (chart.values.length - 1)) / chart.values.length
                       : 0
                height: chart.height
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: barSlot.width
                    radius: chart.barRadius
                    color: chart.barColor
                    opacity: barSlot.modelData > 0 ? 0.82 : 0.18
                    height: barSlot.modelData > 0
                            ? Math.max(chart.minBarHeight, chart.height * barSlot.modelData / chart.maxValue)
                            : chart.emptyBarHeight
                }
            }
        }
    }
}
