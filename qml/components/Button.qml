pragma ComponentBehavior: Bound
import QtQuick
import dev.yukirawa.activenotch

// Button — 汎用ボタン (GlassCard 風、アクセント色バリエーション対応)。
//
// enabled は Item 標準プロパティをそのまま使用する。
// height も Item の height を既定値付きで使用する (呼び出し側で上書き可能)。
Item {
    id: root

    // ---- 公開 API -----------------------------------------------------------
    property string text: ""
    property string iconSource: ""
    property bool primary: false        // true: アクセント色背景 / false: アウトライン
    property bool destructive: false    // true: 破壊的操作 (赤系)
    property real radius: Theme.cardRadius
    signal clicked()

    height: 40
    readonly property real horizontalPadding: 20
    readonly property real iconSize: 18
    readonly property real contentSpacing: 8

    // 内部状態
    property bool pressed: false
    property bool hovered: false

    // ---- 背景 ---------------------------------------------------------------
    Rectangle {
        id: bgRect
        anchors.fill: parent
        radius: root.radius
        color: root.primary
            ? (root.destructive ? "#C0392B" : Theme.accent)
            : "transparent"
        opacity: root.enabled
            ? (root.pressed ? 0.85 : (root.hovered ? 0.95 : (root.primary ? 1 : 0)))
            : 0.3
        border.width: root.primary ? 0 : Theme.borderWidth
        border.color: root.enabled
            ? (root.destructive ? "#E74C3C" : (root.primary ? Theme.accent : Theme.cardBorderGlow))
            : Theme.textMuted
        Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
    }

    // アクア縦グラデ (primary 時のみ薄く重ねる)
    Rectangle {
        anchors.fill: bgRect
        radius: root.radius
        visible: root.primary && root.enabled
        opacity: 0.15
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.overlayTop }
            GradientStop { position: 1.0; color: Theme.overlayBottom }
        }
    }

    // 上端スペキュラ (primary 時のみ)
    Rectangle {
        width: parent.width
        height: Math.max(0, Math.min(Theme.specularHeight, parent.height - root.radius))
        visible: root.primary && root.enabled
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.specular }
            GradientStop { position: 1.0; color: Theme.specularFade }
        }
    }

    // 発光ボーダー (primary 時のみ)
    Rectangle {
        anchors.fill: bgRect
        radius: root.radius
        color: "transparent"
        border.width: Theme.borderWidth
        border.color: root.primary && root.enabled ? Theme.accentSoft : "transparent"
        opacity: root.primary && root.enabled ? 0.5 : 0
    }

    // ---- コンテンツ ---------------------------------------------------------
    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: root.contentSpacing

        // Image に color (ティント) プロパティは Qt 6 に存在しないため、
        // アイコン側の SVG 塗り色をそのまま使う。
        Image {
            source: root.iconSource
            width: root.iconSize
            height: root.iconSize
            fillMode: Image.PreserveAspectFit
            visible: root.iconSource.length > 0
        }

        Text {
            text: root.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontPixelSize
            font.weight: Font.Medium
            color: root.primary ? "#0E1518" : (root.enabled ? Theme.textColor : Theme.textMuted)
        }
    }

    // ---- タッチ領域 ---------------------------------------------------------
    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        enabled: root.enabled
        hoverEnabled: true
        onPressed: root.pressed = true
        onReleased: {
            root.pressed = false
            if (containsMouse)
                root.clicked()
        }
        onCanceled: root.pressed = false
        onEntered: root.hovered = true
        onExited: {
            root.hovered = false
            root.pressed = false
        }
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    }
}
