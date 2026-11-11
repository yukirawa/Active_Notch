pragma ComponentBehavior: Bound
import QtQuick
import dev.yukirawa.activenotch

// ToggleSwitch — アニメーション付きトグルスイッチ (Quick ページ等で使用)。
Item {
    id: root

    // ---- 公開 API -----------------------------------------------------------
    property bool checked: false
    property bool enabled: true
    signal toggled(bool newState)

    readonly property real width: 52
    readonly property real height: 28
    readonly property real thumbSize: 22
    readonly property real padding: 3

    // アニメーション
    property real thumbX: root.checked ? (root.width - root.thumbSize - root.padding) : root.padding
    Behavior on thumbX {
        SpringAnimation {
            mass: 0.5
            spring: 4.0
            damping: 0.7
        }
    }

    // 背景トラック
    Rectangle {
        anchors.fill: parent
        radius: root.height / 2
        color: root.checked
            ? (root.enabled ? Theme.accent : Theme.textMuted)
            : (root.enabled ? Theme.textMuted : Theme.textMuted)
        opacity: root.enabled ? 1 : 0.4
        border.width: Theme.borderWidth
        border.color: root.checked ? Theme.accent : Theme.borderGlow
        Behavior on color {
            ColorAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
        Behavior on border.color {
            ColorAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
    }

    // サム (つまみ)
    Rectangle {
        id: thumb
        x: root.thumbX
        y: root.padding
        width: root.thumbSize
        height: root.thumbSize
        radius: root.thumbSize / 2
        color: Theme.textColor
        border.width: Theme.borderWidth
        border.color: root.checked ? Theme.accent : Theme.borderGlow
        // 影
        layer.enabled: true
        layer.effect: DropShadow {
            horizontalOffset: 0
            verticalOffset: 1
            radius: 3
            samples: 8
            color: Qt.rgba(0, 0, 0, 0.3)
        }
    }

    // タッチ領域
    MouseArea {
        anchors.fill: parent
        anchors.margins: -4  // タッチターゲット拡大
        enabled: root.enabled
        onClicked: {
            root.checked = !root.checked
            root.toggled(root.checked)
        }
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    }
}