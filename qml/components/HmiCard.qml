pragma ComponentBehavior: Bound
// ============================================================
// 【教学导读】组件组合进阶：带"内容插槽"的卡片容器。
// 本文件演示的 QML 概念：
//   1. default property alias — 使用方写在 HmiCard { ... } 大括号里的
//      子元素，会自动落入卡片内部的内容容器（类似插槽 slot）
//   2. 带默认值的对外属性（使用方可以覆盖）
//   3. 多层简单元素叠加出拟物（neumorph）质感——下方四条 1px 高亮/阴影
//      矩形就是在"画"光从左上角打来的立体感，算法细节见原有英文注释
// 配套阅读：qml/HmiButton.qml（自定义组件入门）、qml/Theme.qml
// ============================================================
import QtQuick
import QxznHmi

// HMI raised card: rounded fill + 1px border + four 1px edge highlight lines
// inset by 1px + neumorph drop shadow. Mirrors shell_controller.gd
// draw_hmi_card / _draw_card_edge (edge strength 0.92).
// Children assigned to the default `content` property land inside the card.
Item {
    id: root
    // default property alias：default 表示"使用方的子元素默认挂到这个属性上"；
    // alias 表示它直接别名到内部 container 的 data（孩子列表），不复制不转发
    default property alias content: container.data
    // 带默认值的对外属性：不写时取 Theme.radiusCard，使用方可以覆盖
    property real radius: Theme.radiusCard
    property color fillColor: Theme.panel
    property bool showShadow: true

    NeumorphShadow {
        anchors.fill: cardBody
        anchors.margins: -Theme.shadowExpand
        visible: root.showShadow
    }

    Rectangle {
        id: cardBody
        anchors.fill: parent
        radius: root.radius
        color: root.fillColor
        border.width: 1
        border.color: Theme.cardBorder
    }

    // top highlight: cardHighlight x 0.32 x 0.92
    Rectangle {
        x: 1 + root.radius + 8
        y: 1
        width: Math.max(0, root.width - 2 * (root.radius + 8) - 2)
        height: 1
        color: Theme.cardHighlight
        opacity: 0.294
    }
    // left highlight: cardHighlight x 0.18 x 0.92
    Rectangle {
        x: 1
        y: 1 + root.radius + 8
        width: 1
        height: Math.max(0, root.height - 2 * (root.radius + 8) - 2)
        color: Theme.cardHighlight
        opacity: 0.166
    }
    // bottom shade: edgeDark x 0.48 x 0.92
    Rectangle {
        x: 1 + root.radius + 8
        y: root.height - 2
        width: Math.max(0, root.width - 2 * (root.radius + 8) - 2)
        height: 1
        color: Theme.edgeDark
        opacity: 0.442
    }
    // right shade: edgeDark x 0.32 x 0.92
    Rectangle {
        x: root.width - 2
        y: 1 + root.radius + 8
        width: 1
        height: Math.max(0, root.height - 2 * (root.radius + 8) - 2)
        color: Theme.edgeDark
        opacity: 0.294
    }

    Item {
        id: container
        anchors.fill: parent
    }
}
