pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import dev.yukirawa.activenotch

// Sound — 音量・輝度コントロールページ。
//
// AudioService (wpctl) + BrightnessService (sysfs/logind) を統合。
// - 音量スライダー (0-100%) + ミュートボタン + ホイールステップ
// - 輝度スライダー (0-100%) + ホイールステップ
// サービス未配線時は無効化して graceful に退化。
Item {
    id: root
    width: parent ? parent.width : 604
    height: parent ? parent.height : 380

    // =========================================================================
    // AudioService プロパティ・メソッド (typeof ガード付き)
    // =========================================================================
    readonly property bool audioAvailable: (typeof AudioService !== "undefined" && AudioService.available !== undefined)
        ? AudioService.available
        : false
    readonly property int audioVolume: (typeof AudioService !== "undefined" && AudioService.volume !== undefined)
        ? AudioService.volume
        : 0
    readonly property bool audioMuted: (typeof AudioService !== "undefined" && AudioService.muted !== undefined)
        ? AudioService.muted
        : false
    readonly property string audioSinkName: (typeof AudioService !== "undefined" && AudioService.sinkName !== undefined)
        ? AudioService.sinkName
        : qsTr("デフォルト")

    // AudioService メソッド呼び出しヘルパー
    function audioSetVolume(v) {
        if (typeof AudioService !== "undefined" && AudioService.setVolume) {
            AudioService.setVolume(Math.max(0, Math.min(100, Math.round(v))))
        }
    }
    function audioToggleMute() {
        if (typeof AudioService !== "undefined" && AudioService.toggleMute) {
            AudioService.toggleMute()
        }
    }
    function audioStepVolume(delta) {
        if (typeof AudioService !== "undefined" && AudioService.step) {
            AudioService.step(delta)
        } else {
            audioSetVolume(audioVolume + delta)
        }
    }

    // =========================================================================
    // BrightnessService プロパティ・メソッド (typeof ガード付き)
    // =========================================================================
    readonly property bool brightnessAvailable: (typeof BrightnessService !== "undefined" && BrightnessService.available !== undefined)
        ? BrightnessService.available
        : false
    readonly property real brightnessValue: (typeof BrightnessService !== "undefined" && BrightnessService.brightness !== undefined)
        ? BrightnessService.brightness
        : 0  // 0.0-1.0

    function brightnessSetValue(v) {
        if (typeof BrightnessService !== "undefined" && BrightnessService.setBrightness) {
            BrightnessService.setBrightness(Math.max(0, Math.min(1, v)))
        }
    }
    function brightnessStep(delta) {
        // delta は 0.0-1.0 の範囲で、ステップは約 5% (0.05)
        brightnessSetValue(brightnessValue + delta * 0.05)
    }

    // =========================================================================
    // 内部アニメーション値 (スムーズ補間用)
    // =========================================================================
    property real animatedAudioVolume: root.audioVolume
    Behavior on animatedAudioVolume {
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }
    onAudioVolumeChanged: animatedAudioVolume = audioVolume

    property real animatedBrightness: root.brightnessValue * 100
    Behavior on animatedBrightness {
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }
    onBrightnessValueChanged: animatedBrightness = brightnessValue * 100

    // =========================================================================
    // レイアウト
    // =========================================================================
    Column {
        anchors.fill: parent
        anchors.margins: Theme.panelPadding
        spacing: 20

        // --- 音量セクション ----------------------------------------------------
        ControlSection {
            id: audioSection
            width: parent.width
            title: qsTr("音量")
            subtitle: root.audioAvailable ? root.audioSinkName : qsTr("オーディオデバイスが見つかりません")
            iconSource: root.audioMuted
                ? "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24'><path fill='%237FB8B0' d='M16.5 12c0-1.77-1.02-3.29-2.5-4.03v2.21l2.45 2.45c.03-.2.05-.41.05-.63zm2.5 0c0 .94-.2 1.82-.54 2.64l1.51 1.51C20.63 14.91 21 13.5 21 12c0-4.28-2.99-7.86-7-8.77v2.06c2.89.86 5 3.54 5 6.71zM4.27 3L3 4.27 7.73 9H3v6h4l5 5v-6.73l4.25 4.25c-.67.52-1.42.93-2.25 1.18v2.06c1.38-.31 2.63-.95 3.69-1.81L19.73 21 21 19.73l-9-9L4.27 3z'/>"
                : (root.animatedAudioVolume === 0
                    ? "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24'><path fill='%237FB8B0' d='M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z'/>"
                    : "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24'><path fill='%237FB8B0' d='M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z'/>")
            enabled: root.audioAvailable

            // メインコンテンツ: スライダー + ミュートボタン
            Row {
                anchors.fill: parent
                spacing: 12

                // 音量スライダー (メイン)
                SliderControl {
                    id: volumeSlider
                    Layout.fillWidth: true
                    value: root.animatedAudioVolume
                    minValue: 0
                    maxValue: 100
                    step: 1
                    showValue: true
                    suffix: "%"
                    accentColor: Theme.accent
                    trackColor: Qt.rgba(Theme.textMutedColor.r, Theme.textMutedColor.g, Theme.textMutedColor.b, 0.15)
                    enabled: root.audioAvailable && !root.audioMuted
                    onValueChanged: root.audioSetVolume(value)
                    // ホイールステップ対応
                    wheelStep: 5
                }

                // ミュート切替ボタン
                IconButton {
                    id: muteBtn
                    iconSource: root.audioMuted
                        ? "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='20' height='20'><path fill='%23E8F4F2' d='M16.5 12c0-1.77-1.02-3.29-2.5-4.03v2.21l2.45 2.45c.03-.2.05-.41.05-.63zm2.5 0c0 .94-.2 1.82-.54 2.64l1.51 1.51C20.63 14.91 21 13.5 21 12c0-4.28-2.99-7.86-7-8.77v2.06c2.89.86 5 3.54 5 6.71zM4.27 3L3 4.27 7.73 9H3v6h4l5 5v-6.73l4.25 4.25c-.67.52-1.42.93-2.25 1.18v2.06c1.38-.31 2.63-.95 3.69-1.81L19.73 21 21 19.73l-9-9L4.27 3z'/>"
                        : "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='20' height='20'><path fill='%23E8F4F2' d='M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z'/>"
                    iconSize: 20
                    buttonSize: 40
                    tooltipText: root.audioMuted ? qsTr("ミュート解除") : qsTr("ミュート")
                    enabled: root.audioAvailable
                    onClicked: root.audioToggleMute()
                }
            }
        }

        // --- 輝度セクション ----------------------------------------------------
        ControlSection {
            id: brightnessSection
            width: parent.width
            title: qsTr("画面の明るさ")
            subtitle: root.brightnessAvailable ? qsTr("ディスプレイ輝度を調整") : qsTr("輝度制御が利用できません (sysfs/logind 未対応)")
            iconSource: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24'><path fill='%237FB8B0' d='M12 7c-2.76 0-5 2.24-5 5s2.24 5 5 5 5-2.24 5-5-2.24-5-5-5zM2 13h2c.55 0 1-.45 1-1s-.45-1-1-1H2c-.55 0-1 .45-1 1s.45 1 1 1zm18 0h2c.55 0 1-.45 1-1s-.45-1-1-1h-2c-.55 0-1 .45-1 1s.45 1 1 1zM11 2v2c0 .55.45 1 1 1s1-.45 1-1V2c0-.55-.45-1-1-1s-1 .45-1 1zm0 18v2c0 .55.45 1 1 1s1-.45 1-1v-2c0-.55-.45-1-1-1s-1 .45-1 1zM5.99 4.58a.996.996 0 00-1.41 0 .996.996 0 000 1.41l1.06 1.06c.39.39 1.03.39 1.41 0s.39-1.03 0-1.41L5.99 4.58zm12.37 12.37a.996.996 0 00-1.41 0 .996.996 0 000 1.41l1.06 1.06c.39.39 1.03.39 1.41 0 .39-.39.39-1.03 0-1.41l-1.06-1.06zm1.06-10.96a.996.996 0 000-1.41.996.996 0 00-1.41 0l-1.06 1.06c-.39.39-.39 1.03 0 1.41s1.03.39 1.41 0l1.06-1.06zM7.05 18.36a.996.996 0 000 1.41.996.996 0 001.41 0l1.06-1.06c.39-.39.39-1.03 0-1.41s-1.03-.39-1.41 0l-1.06 1.06z'/>"
            enabled: root.brightnessAvailable

            // 輝度スライダー
            SliderControl {
                id: brightnessSlider
                anchors.fill: parent
                value: root.animatedBrightness
                minValue: 0
                maxValue: 100
                step: 1
                showValue: true
                suffix: "%"
                accentColor: "#FFB300"  // アンバー (太陽色)
                trackColor: Qt.rgba(Theme.textMutedColor.r, Theme.textMutedColor.g, Theme.textMutedColor.b, 0.15)
                enabled: root.brightnessAvailable
                onValueChanged: root.brightnessSetValue(value / 100)
                wheelStep: 5
            }
        }

        // --- どちらも利用不可の場合のフォールバック ---------------------------
        Item {
            id: bothUnavailable
            width: parent.width
            visible: !root.audioAvailable && !root.brightnessAvailable

            GlassCard {
                anchors.fill: parent
                padding: 24
                radius: Theme.cardRadius

                Column {
                    anchors.centerIn: parent
                    spacing: 12

                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='48' height='48'><path fill='%237FB8B0' d='M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-6h2v6zm0-8h-2V7h2v2z'/>"
                        color: Theme.accentSoft
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("音量・輝度の制御が利用できません")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPixelSize
                        font.weight: Font.DemiBold
                        color: Theme.textColor
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("PipeWire (wpctl) または輝度制御 (sysfs/logind) が見つかりません。")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPixelSizeCaption
                        color: Theme.textMuted
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }
}