pragma ComponentBehavior: Bound
import QtQuick
import dev.yukirawa.activenotch

// SliderControl — カスタムスライダー (値表示付き、ホイールステップ対応) (Sound ページ等で使用)。
Item {
    id: root

    // ---- 公開 API -----------------------------------------------------------
    property real value: 50
    property real minValue: 0
    property real maxValue: 100
    property real step: 1
    property bool showValue: true
    property string suffix: ""
    property color accentColor: Theme.accent
    property color trackColor: Qt.rgba(255, 255, 255, 0.1)
    property bool enabled: true
    property int wheelStep: 5
    signal valueChanged(real newValue)

    readonly property real height: 48
    readonly property real trackHeight: 6
    readonly property real thumbSize: 20
    readonly property real valueLabelWidth: 48

    // 内部: ノブ位置 (0.0-1.0)
    property real progress: (root.value - root.minValue) / (root.maxValue - root.minValue)
    onValueChanged: progress = (value - minValue) / (maxValue - minValue)
    onProgressChanged: {
        if (Math.abs(value - (minValue + progress * (maxValue - minValue))) > step / 2) {
            value = minValue + progress * (maxValue - minValue)
            // step に丸める
            value = Math.round(value / step) * step
            value = Math.max(minValue, Math.min(maxValue, value))
            root.valueChanged(value)
        }
    }

    // アニメーション
    Behavior on progress {
        NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
    }

    // 背景トラック
    Rectangle {
        id: trackBg
        y: (parent.height - root.trackHeight) / 2
        height: root.trackHeight
        width: parent.width - root.valueLabelWidth - 16
        anchors.left: parent.left
        anchors.leftMargin: 8
        radius: root.trackHeight / 2
        color: root.trackColor
    }

    // 進捗トラック (アクセント色)
    Rectangle {
        id: progressTrack
        y: trackBg.y
        height: root.trackHeight
        width: trackBg.width * root.progress
        radius: root.trackHeight / 2
        color: root.accentColor
        opacity: root.enabled ? 1 : 0.4
        Behavior on width {
            NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
        }
    }

    // サム (つまみ)
    Rectangle {
        id: thumb
        x: trackBg.x + trackBg.width * root.progress - root.thumbSize / 2
        y: (parent.height - root.thumbSize) / 2
        width: root.thumbSize
        height: root.thumbSize
        radius: root.thumbSize / 2
        color: root.enabled ? root.accentColor : Theme.textMuted
        border.width: 3
        border.color: root.enabled ? "#0E1518" : Theme.textMuted
        // 影
        layer.enabled: true
        layer.effect: DropShadow {
            horizontalOffset: 0
            verticalOffset: 2
            radius: 6
            samples: 8
            color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.4)
        }
        Behavior on x {
            NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
        }
    }

    // 値ラベル
    Text {
        id: valueLabel
        visible: root.showValue
        x: trackBg.x + trackBg.width + 8
        anchors.verticalCenter: parent.verticalCenter
        width: root.valueLabelWidth
        horizontalAlignment: Text.AlignRight
        text: "%1%2".arg(Math.round(root.value)).arg(root.suffix)
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontPixelSize
        font.weight: Font.Medium
        color: root.enabled ? Theme.textColor : Theme.textMuted
    }

    // タッチ/ドラッグ領域 (トラック全体をタッチターゲットに)
    MouseArea {
        id: dragArea
        x: trackBg.x - 10
        y: trackBg.y - 10
        width: trackBg.width + 20
        height: trackBg.height + 20
        enabled: root.enabled
        drag.target: thumb
        drag.axis: Drag.XAxis
        drag.minimumX: trackBg.x - root.thumbSize / 2
        drag.maximumX: trackBg.x + trackBg.width - root.thumbSize / 2
        drag.threshold: 0
        hoverEnabled: true

        onPositionChanged: {
            if (drag.active) {
                const newProgress = (thumb.x + root.thumbSize / 2 - trackBg.x) / trackBg.width
                root.progress = Math.max(0, Math.min(1, newProgress))
            }
        }

        onClicked: {
            if (!drag.active) {
                const clickX = mouse.x - (dragArea.x - trackBg.x)
                const newProgress = clickX / trackBg.width
                root.progress = Math.max(0, Math.min(1, newProgress))
            }
        }

        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    // ホイールステップ対応
    WheelArea {
        anchors.fill: dragArea
        enabled: root.enabled
        onWheel: {
            if (wheel.angleDelta.y > 0) {
                root.value = Math.min(root.maxValue, root.value + root.wheelStep)
            } else if (wheel.angleDelta.y < 0) {
                root.value = Math.max(root.minValue, root.value - root.wheelStep)
            }
            wheel.accepted = true
        }
    }

    // 無効状態オーバーレイ
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.1)
        visible: !root.enabled
    }
}