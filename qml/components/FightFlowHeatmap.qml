pragma ComponentBehavior: Bound
import QtQuick
import QxznHmi

// Fight Flow 击打区域热力图:上模块 4 区 + 下模块 6 区,几何照搬
// lessons_test/styles.css 的百分比定位与 clip-path 多边形(同 Godot 版
// fight_flow_player_view.gd HEAT_REGIONS)。亮度=击打频率,红框=下一目标。
Canvas {
    id: heatmap

    property var distribution: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property int nextRegion: -1
    property int flashRegion: -1

    readonly property color nextRed: Qt.rgba(1.0, 0.3, 0.27, 0.82)

    // rect/poly 均为所在模块内的相对比例
    readonly property var regions: [
        { module: 0, rect: Qt.rect(0.01, 0.13, 0.27, 0.69), poly: [Qt.point(0, 0.23), Qt.point(1, 0), Qt.point(0.82, 1), Qt.point(0, 0.76)] },
        { module: 0, rect: Qt.rect(0.27, 0.08, 0.46, 0.62), poly: [] },
        { module: 0, rect: Qt.rect(0.72, 0.13, 0.27, 0.69), poly: [Qt.point(0, 0), Qt.point(1, 0.23), Qt.point(1, 0.76), Qt.point(0.18, 1)] },
        { module: 0, rect: Qt.rect(0.29, 0.66, 0.42, 0.31), poly: [Qt.point(0.12, 0), Qt.point(0.88, 0), Qt.point(1, 1), Qt.point(0, 1)] },
        { module: 1, rect: Qt.rect(0.0, 0.08, 0.24, 0.84), poly: [Qt.point(0, 0.08), Qt.point(1, 0), Qt.point(0.76, 1), Qt.point(0, 0.86)] },
        { module: 1, rect: Qt.rect(0.21, 0.06, 0.29, 0.48), poly: [] },
        { module: 1, rect: Qt.rect(0.50, 0.06, 0.29, 0.48), poly: [] },
        { module: 1, rect: Qt.rect(0.76, 0.08, 0.24, 0.84), poly: [Qt.point(0, 0), Qt.point(1, 0.08), Qt.point(1, 0.86), Qt.point(0.24, 1)] },
        { module: 1, rect: Qt.rect(0.21, 0.53, 0.29, 0.43), poly: [] },
        { module: 1, rect: Qt.rect(0.50, 0.53, 0.29, 0.43), poly: [] }
    ]

    // 击打闪烁 280ms(同 app.js/Godot 版)
    property real _flashUntil: 0
    onFlashRegionChanged: {
        if (flashRegion >= 0) {
            _flashUntil = Date.now() + 280;
            flashTimer.restart();
        }
    }
    Timer {
        id: flashTimer
        interval: 300
        onTriggered: heatmap.requestPaint()
    }

    onDistributionChanged: requestPaint()
    onNextRegionChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    // 上模块窄(56%)下模块宽(86%),行高比例照搬 CSS
    function moduleRect(module) {
        const gap = 6;
        const topH = (height - gap) * 0.42;
        if (module === 0) {
            const w = width * 0.56;
            return Qt.rect((width - w) / 2, 0, w, topH);
        }
        const w = width * 0.86;
        return Qt.rect((width - w) / 2, topH + gap, w, height - gap - topH);
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        ctx.clearRect(0, 0, width, height);

        for (let m = 0; m < 2; ++m) {
            const r = moduleRect(m);
            ctx.fillStyle = "#242b28";
            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.12);
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.rect(r.x, r.y, r.width, r.height);
            ctx.fill();
            ctx.stroke();
        }

        let maxCount = 1;
        for (let i = 0; i < distribution.length; ++i)
            maxCount = Math.max(maxCount, distribution[i]);

        const now = Date.now();
        for (let i = 0; i < Math.min(distribution.length, regions.length); ++i) {
            const region = regions[i];
            const mr = moduleRect(region.module);
            const rr = Qt.rect(mr.x + region.rect.x * mr.width,
                               mr.y + region.rect.y * mr.height,
                               region.rect.width * mr.width,
                               region.rect.height * mr.height);
            let points;
            if (region.poly.length === 0) {
                points = [Qt.point(rr.x, rr.y), Qt.point(rr.x + rr.width, rr.y),
                          Qt.point(rr.x + rr.width, rr.y + rr.height), Qt.point(rr.x, rr.y + rr.height)];
            } else {
                points = region.poly.map(function(p) {
                    return Qt.point(rr.x + p.x * rr.width, rr.y + p.y * rr.height);
                });
            }
            let heat = 0.08 + 0.58 * distribution[i] / maxCount;
            if (i === flashRegion && now < _flashUntil)
                heat = Math.min(1.0, heat * 1.55 + 0.2);
            ctx.beginPath();
            ctx.moveTo(points[0].x, points[0].y);
            for (let j = 1; j < points.length; ++j)
                ctx.lineTo(points[j].x, points[j].y);
            ctx.closePath();
            ctx.fillStyle = Qt.rgba(0.86, 0.89, 0.87, heat);
            ctx.fill();
            if (i === nextRegion) {
                ctx.strokeStyle = Qt.rgba(1.0, 0.3, 0.27, 0.18);
                ctx.lineWidth = 7;
                ctx.stroke();
                ctx.strokeStyle = nextRed;
                ctx.lineWidth = 2;
                ctx.stroke();
            } else {
                ctx.strokeStyle = Qt.rgba(0.93, 0.95, 0.94, 0.05 + heat * 0.28);
                ctx.lineWidth = 1.5;
                ctx.stroke();
            }
        }
    }
}
