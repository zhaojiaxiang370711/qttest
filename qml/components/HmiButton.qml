pragma ComponentBehavior: Bound
// ============================================================
// 【教学导读】QML 自定义组件的最小完整范本。
// 一个 .qml 文件就是一个组件：文件名（大写开头）就是组件名，
// 别的文件写 HmiButton { text: "确定" } 即可使用本组件。
// 本文件演示的 QML 概念：
//   1. property — 组件对外的"参数"，使用方可赋值
//   2. signal — 组件对外的事件出口，使用方写 onClicked: {...} 响应
//   3. 带条件表达式的属性绑定
//   4. Behavior on — 属性值变化时自动播放过渡动画
//   5. TapHandler — Qt Quick 的输入处理器（比 MouseArea 更新的写法）
// 配套阅读：qml/HmiCard.qml（组件组合进阶）
// ============================================================
import QtQuick
import QxznHmi

// Shell action button. kind: primary (cyan fill, black text),
// ghost (translucent, white border), danger (red fill, white text).
Rectangle {
    id: button
    // 组件对外的"参数"：使用方写 HmiButton { text: "..."; kind: "ghost" } 即可赋值
    property string text: ""
    property string kind: "primary"     // primary | ghost | danger
    // 组件对外的事件出口：使用方写 onClicked: {...} 来响应点击
    signal clicked()

    // implicitWidth/implicitHeight：组件的建议尺寸，供布局系统参考
    implicitWidth: label.implicitWidth + Theme.px(64)
    implicitHeight: Theme.px(37)        // 56
    radius: Theme.radiusButton
    transformOrigin: Item.Center
    // 带条件表达式的属性绑定：kind 一变，颜色自动按三元表达式重算
    color: button.kind === "primary" ? Theme.primary
         : button.kind === "danger" ? Theme.danger
         : Qt.rgba(1, 1, 1, 0.06)
    border.width: button.kind === "ghost" ? 1 : 0
    border.color: Qt.rgba(1, 1, 1, 0.40)
    scale: tap.pressed ? 0.97 : 1.0
    // Behavior on：行为动画——scale 的值每次变化都会自动播放这段过渡动画，无需手动触发
    Behavior on scale { NumberAnimation { duration: 80 } }

    Text {
        id: label
        anchors.centerIn: parent
        text: button.text
        color: button.kind === "primary" ? "#050505" : Theme.text
        font.pixelSize: Theme.fontBody
    }

    // TapHandler：Qt Quick 的输入处理器（比 MouseArea 更新的写法）；
    // 点击时转发成组件自己的 clicked() 信号
    TapHandler {
        id: tap
        onTapped: button.clicked()
    }
}
