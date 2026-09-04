pragma ComponentBehavior: Bound
import QtQuick
import QxznHmi

// Fight Flow 趋势折线图:复刻 lessons_test/app.js drawChart()。
// 双序列(击打频率 max 20 / 击打力度 max 100),Catmull-Rom 转贝塞尔平滑,
// 末端亮点;序列可见性由图例切换。数据由 FightFlowPage 的定时器推进。
Canvas {
    id: chart

    property var frequency: []      // 30 点滑动窗口
    property var power: []
    property real pendingFrequency: 0
    property real pendingPower: 0
    property bool frequencyVisible: true
    property bool powerVisible: true
    // 0..1,一个图表间隔内的滚动进度(对应 app.js scrollProgress)
    property real scrollProgress: 0

    readonly property color colorFrequency: "#cfff2e"
    readonly property color colorPower: "#ff9f2b"

    onFrequencyChanged: requestPaint()
    onPowerChanged: requestPaint()
    onScrollProgressChanged: requestPaint()
    onFrequencyVisibleChanged: requestPaint()
    onPowerVisibleChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    function drawSeries(ctx, data, pendingValue, color, maxValue) {
        if (data.length < 2)
            return;
        const padding = Math.max(10, width * 0.025);
        const usableWidth = width - padding * 2;
        const usableHeight = height - padding * 2;
        const step = usableWidth / (data.length - 1);
        const points = data.map(function(value, index) {
            return {
                x: padding + index * step - chart.scrollProgress * step,
                y: padding + usableHeight - (value / maxValue) * usableHeight
            };
        });
        const latestValue = data[data.length - 1];
        const headValue = latestValue + (pendingValue - latestValue) * chart.scrollProgress;
        points.push({
            x: padding + usableWidth,
            y: padding + usableHeight - (headValue / maxValue) * usableHeight
        });

        ctx.beginPath();
        ctx.moveTo(points[0].x, points[0].y);
        for (let index = 0; index < points.length - 1; ++index) {
            const point = points[index];
            const previous = points[Math.max(0, index - 1)];
            const next = points[index + 1];
            const afterNext = points[Math.min(points.length - 1, index + 2)];
            const controlOneX = point.x + (next.x - previous.x) / 6;
            const controlOneY = point.y + (next.y - previous.y) / 6;
            const controlTwoX = next.x - (afterNext.x - point.x) / 6;
            const controlTwoY = next.y - (afterNext.y - point.y) / 6;
            ctx.bezierCurveTo(controlOneX, controlOneY, controlTwoX, controlTwoY, next.x, next.y);
        }
        ctx.strokeStyle = color;
        ctx.lineWidth = 3;
        ctx.lineJoin = "round";
        ctx.lineCap = "round";
        ctx.stroke();

        ctx.beginPath();
        ctx.arc(padding + usableWidth, padding + usableHeight - (headValue / maxValue) * usableHeight,
                5, 0, Math.PI * 2);
        ctx.fillStyle = color;
        ctx.fill();
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        ctx.clearRect(0, 0, width, height);
        if (frequencyVisible)
            drawSeries(ctx, frequency, pendingFrequency, colorFrequency, 20);
        if (powerVisible)
            drawSeries(ctx, power, pendingPower, colorPower, 100);
    }
}
