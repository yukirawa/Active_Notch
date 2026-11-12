pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import dev.yukirawa.activenotch

// IconButton — アイコンのみのボタン (ホバー/押下アニメーション付き)。
//
// ツールバー、ヘッダーアクション、トグル隣のアクションボタンなどで使用。
// SVG data URI または Breeze アイコンテーマからの読み込みに対応。
Item {
    id: root

    // ---- 公開 API -----------------------------------------------------------
    property string iconSource: ""
    property int iconSize: 20
    property int buttonSize: 36  // 正方形のタッチターゲット
    property string tooltipText: ""
    // enabled は Item 標準プロパティを使用する (再宣言しない)。
    property bool checkable: false
    property bool checked: false
    signal clicked

    // ---- 内部状態 -----------------------------------------------------------
    property bool hovered: false
    property bool pressed: false

    // 固定サイズ
    width: buttonSize
    height: buttonSize

    // ---- 背景: ホバー/押下で反応する円形/角丸矩形 ------------------------------
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: buttonSize / 2
        color: root.pressed
            ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25)
            : (root.hovered
                ? Qt.rgba(Theme.textMutedColor.r, Theme.textMutedColor.g, Theme.textMutedColor.b, 0.12)
                : "transparent")
        border.width: root.checked ? Theme.borderWidth : 0
        border.color: root.checked ? Theme.accent : "transparent"
        opacity: root.enabled ? 1 : 0.4
        Behavior on color {
            ColorAnimation { duration: 100; easing.type: Easing.OutCubic }
        }
        Behavior on border.color {
            ColorAnimation { duration: 100; easing.type: Easing.OutCubic }
        }
    }

    // ---- アイコン -----------------------------------------------------------
    Image {
        id: icon
        source: root.iconSource
        width: root.iconSize
        height: root.iconSize
        anchors.centerIn: parent
        fillMode: Image.PreserveAspectFit
        // Image に color プロパティは存在しない (Qt 6)。
        // SVG の淡色 fill をそのまま使い、状態は opacity で表現する。
        opacity: root.enabled ? (root.checked ? 1.0 : 0.92) : 0.4
        // 押下時の微小スケール
        transform: Scale {
            origin.x: icon.width / 2
            origin.y: icon.height / 2
            xScale: root.pressed ? 0.9 : 1.0
            yScale: root.pressed ? 0.9 : 1.0
        }
    }

    // ---- マウス領域 ---------------------------------------------------------
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        onEntered: root.hovered = true
        onExited: {
            root.hovered = false
            root.pressed = false
        }
        onPressed: root.pressed = true
        onReleased: {
            root.pressed = false
            if (mouseArea.containsMouse) {
                if (root.checkable) {
                    root.checked = !root.checked
                }
                root.clicked()
            }
        }
        onCanceled: root.pressed = false
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    // ---- キーボードフォーカス (Tab ナビゲーション対応) -----------------------
    focusPolicy: root.enabled ? Qt.ClickFocus : Qt.NoFocus
    Keys.onReturnPressed: {
        if (root.checkable) root.checked = !root.checked
        root.clicked()
    }
    Keys.onSpacePressed: {
        if (root.checkable) root.checked = !root.checked
        root.clicked()
    }

    // ---- ツールチップ -------------------------------------------------------
    ToolTip {
        text: root.tooltipText
        visible: root.hovered && root.tooltipText.length > 0
        delay: 500
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontPixelSizeCaption
    }
}