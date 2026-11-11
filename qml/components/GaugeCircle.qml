pragma ComponentBehavior: Bound
import QtQuick
import dev.yukirawa.activenotch

// GaugeCircle — 円形プログレスゲージ (Battery ページ等で使用)。
Item {
    id: root

    // ---- 公開 API -----------------------------------------------------------
    property real value: 0
    property real maxValue: 100
    property real thickness: 8
    property color trackColor: Qt.rgba(255, 255, 255, 0.1)
    property color progressColor: Theme.accent
    property bool showText: true
    property string textValue: ""
    property color textColor: Theme.textColor
    property int textPixelSize: 36
    property string subText: ""
    property color subTextColor: Theme.textMuted
    property int subTextPixelSize: 12
    property bool enabled: true

    // 内部: アニメーション用の進捗値
    property real animatedProgress: root.value / root.maxValue
    Behavior on animatedProgress {
        NumberAnimation { duration: 1000; easing.type: Easing.OutCubic }
    }
    onValueChanged: animatedProgress = value / maxValue

    // Canvas で描画
    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true
        onPaint: {
            const ctx = canvas.getContext("2d")
            ctx.clearRect(0, 0, canvas.width, canvas.height)

            const centerX = canvas.width / 2
            const centerY = canvas.height / 2
            const radius = Math.min(centerX, centerY) - root.thickness / 2
            const lineWidth = root.thickness
            const startAngle = -Math.PI / 2  // 12時位置から開始
            const endAngle = startAngle + 2 * Math.PI * root.animatedProgress

            // 背景トラック
            ctx.beginPath()
            ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI)
            ctx.lineWidth = lineWidth
            ctx.strokeStyle = root.trackColor
            ctx.stroke()

            // 進捗アーク
            if (root.animatedProgress > 0) {
                ctx.beginPath()
                ctx.arc(centerX, centerY, radius, startAngle, endAngle)
                ctx.lineWidth = lineWidth
                ctx.lineCap = "round"
                ctx.strokeStyle = root.progressColor
                ctx.stroke()
            }
        }
    }

    // 中央テキスト
    Column {
        anchors.centerIn: parent
        spacing: 2
        visible: root.showText && root.enabled

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.textValue || ("%1%".arg(Math.round(root.value)))
            font.family: Theme.fontFamily
            font.pixelSize: root.textPixelSize
            font.weight: Font.DemiBold
            color: root.textColor
        }

        Text {
            visible: root.subText.length > 0
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.subText
            font.family: Theme.fontFamily
            font.pixelSize: root.subTextPixelSize
            color: root.subTextColor
        }
    }

    // 無効状態オーバーレイ
    Rectangle {
        anchors.fill: parent
        radius: Math.min(width, height) / 2
        color: Qt.rgba(0, 0, 0, 0.1)
        visible: !root.enabled
    }
}