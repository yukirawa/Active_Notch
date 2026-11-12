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
    property color trackColor: Qt.rgba(Theme.specularColor.r,
                                       Theme.specularColor.g,
                                       Theme.specularColor.b, 0.1)
    // enabled は Item 標準プロパティを使用する (再宣言しない)。
    property int wheelStep: 5

    // height は QQuickItem の final プロパティのため再宣言できない。
    // 既定サイズは width / height へのバインディングで与える。
    readonly property real controlHeight: 48
    readonly property real trackHeight: 6
    readonly property real thumbSize: 20
    readonly property real valueLabelWidth: 48

    implicitWidth: 200
    implicitHeight: controlHeight
    width: implicitWidth
    height: implicitHeight

    // 内部: ノブ位置 (0.0-1.0)。value から一方向に同期する。
    // (value ⇔ progress の双方向バインドによるループを避ける)
    property real progress: 0

    // ドラッグ中は即時追従、外部変更時のみアニメーションする。
    Behavior on progress {
        enabled: !dragArea.pressed
        NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
    }

    function clampProgress(p) {
        return Math.max(0, Math.min(1, p))
    }

    function valueForProgress(p) {
        if (maxValue <= minValue)
            return minValue
        let v = minValue + clampProgress(p) * (maxValue - minValue)
        if (step > 0)
            v = Math.round(v / step) * step
        return Math.max(minValue, Math.min(maxValue, v))
    }

    function setValueFromProgress(p) {
        value = valueForProgress(p)
    }

    function syncProgress() {
        progress = (maxValue > minValue)
            ? clampProgress((value - minValue) / (maxValue - minValue))
            : 0
    }

    onValueChanged: syncProgress()
    onMinValueChanged: syncProgress()
    onMaxValueChanged: syncProgress()
    Component.onCompleted: syncProgress()

    // 背景トラック
    Rectangle {
        id: trackBg
        anchors.left: parent.left
        anchors.leftMargin: 8
        y: (root.height - root.trackHeight) / 2
        width: Math.max(0, parent.width - root.valueLabelWidth - 16)
        height: root.trackHeight
        radius: root.trackHeight / 2
        color: root.trackColor
    }

    // 進捗トラック (アクセント色)
    Rectangle {
        id: progressTrack
        x: trackBg.x
        y: trackBg.y
        width: Math.max(0, trackBg.width * root.progress)
        height: root.trackHeight
        radius: root.trackHeight / 2
        color: root.accentColor
        opacity: root.enabled ? 1 : 0.4
    }

    // サムの影 (DropShadow の代替: 半透明の円を 1 枚重ねる)
    Rectangle {
        x: thumb.x
        y: thumb.y + 2
        width: thumb.width
        height: thumb.height
        radius: width / 2
        color: Qt.rgba(Theme.shadowColor.r, Theme.shadowColor.g,
                       Theme.shadowColor.b, 0.25 * Theme.shadowOpacity)
        opacity: root.enabled ? 1 : 0
    }

    // サム (つまみ)
    Rectangle {
        id: thumb
        x: trackBg.x + trackBg.width * root.progress - root.thumbSize / 2
        y: (root.height - root.thumbSize) / 2
        width: root.thumbSize
        height: root.thumbSize
        radius: root.thumbSize / 2
        color: root.enabled ? root.accentColor : Theme.textMuted
        border.width: 3
        border.color: root.enabled ? Theme.bgBase : Theme.textMuted
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
        width: Math.max(0, trackBg.width + 20)
        height: trackBg.height + 20
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

        // トラック内のローカル座標 (左端 = 10px) から値を求める。
        function progressAt(mouseX) {
            return (mouseX - 10) / Math.max(1, trackBg.width)
        }

        onPressed: function(mouse) {
            root.setValueFromProgress(progressAt(mouse.x))
        }

        onPositionChanged: function(mouse) {
            if (pressed)
                root.setValueFromProgress(progressAt(mouse.x))
        }

        // ホイールステップ対応 (WheelArea は QtQuick に存在しない)
        onWheel: function(wheel) {
            if (wheel.angleDelta.y > 0)
                root.value = Math.min(root.maxValue, root.value + root.wheelStep)
            else if (wheel.angleDelta.y < 0)
                root.value = Math.max(root.minValue, root.value - root.wheelStep)
            wheel.accepted = true
        }
    }

    // 無効状態オーバーレイ
    Rectangle {
        anchors.fill: parent
        // 直値色ではなく Theme の影トークンから生成する。
        color: Qt.rgba(Theme.shadowColor.r, Theme.shadowColor.g,
                       Theme.shadowColor.b, 0.1 * Theme.shadowOpacity)
        visible: !root.enabled
    }
}
