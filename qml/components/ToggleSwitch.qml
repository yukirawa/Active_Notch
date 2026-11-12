pragma ComponentBehavior: Bound
import QtQuick
import dev.yukirawa.activenotch

// ToggleSwitch — アニメーション付きトグルスイッチ (Quick ページ等で使用)。
Item {
    id: root

    // ---- 公開 API -----------------------------------------------------------
    property bool checked: false
    // enabled は Item 標準プロパティを使用する (再宣言しない)。
    signal toggled(bool newState)

    // width / height は QQuickItem の final プロパティのため再宣言できない。
    // 既定サイズは width / height へのバインディングで与える。
    readonly property real switchWidth: 52
    readonly property real switchHeight: 28
    readonly property real thumbSize: 22
    readonly property real padding: 3

    implicitWidth: switchWidth
    implicitHeight: switchHeight
    width: implicitWidth
    height: implicitHeight

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

    // サムの影 (DropShadow の代替: 半透明の円を 1 枚重ねる)
    Rectangle {
        x: root.thumbX
        y: root.padding + 1
        width: root.thumbSize
        height: root.thumbSize
        radius: root.thumbSize / 2
        color: Qt.rgba(Theme.shadowColor.r, Theme.shadowColor.g,
                       Theme.shadowColor.b, 0.3 * Theme.shadowOpacity)
        opacity: root.enabled ? 1 : 0
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
