pragma ComponentBehavior: Bound
import QtQuick
import dev.yukirawa.activenotch

// SpinBox — 数値入力スピンボックス (増減ボタン付き)。
//
// Theme トークンでスタイリング。キーボード入力 / ホイール / ボタン操作に対応。
// value は QML プロパティのため、値変更時は自動生成される
// valueChanged() シグナルで通知される (独自シグナルは定義しない)。
Item {
    id: root

    // ---- 公開 API -----------------------------------------------------------
    property int value: 0
    property int minValue: 0
    property int maxValue: 100
    property int step: 1
    property string suffix: ""

    // Item の height をそのまま使う (呼び出し側で上書き可能)。
    width: 120
    height: 40

    readonly property real buttonSize: 26
    readonly property real inputWidth: Math.max(0, root.width - root.buttonSize * 2)

    // ---- 背景カード ---------------------------------------------------------
    Rectangle {
        id: bgRect
        anchors.fill: parent
        radius: Theme.cardRadius
        color: Theme.cardBg
        border.width: Theme.borderWidth
        border.color: root.enabled ? Theme.cardBorderGlow : Theme.textMuted
        opacity: root.enabled ? 1 : 0.5
    }

    // アクア縦グラデ
    Rectangle {
        anchors.fill: bgRect
        radius: Theme.cardRadius
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.overlayTop }
            GradientStop { position: 1.0; color: Theme.overlayBottom }
        }
    }

    // 上端スペキュラ
    Rectangle {
        width: parent.width
        height: Math.max(0, Math.min(Theme.specularHeight, parent.height - Theme.cardRadius))
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.specular }
            GradientStop { position: 1.0; color: Theme.specularFade }
        }
    }

    // 発光ボーダー
    Rectangle {
        anchors.fill: bgRect
        radius: Theme.cardRadius
        color: "transparent"
        border.width: Theme.borderWidth
        border.color: Theme.cardBorderGlow
    }

    // ---- レイアウト: [Decrement] [Input] [Increment] -----------------------
    Row {
        anchors.fill: parent
        spacing: 0

        // Decrement ボタン
        Button {
            id: decBtn
            width: root.buttonSize
            height: parent.height
            text: "−"
            enabled: root.enabled && root.value > root.minValue
            radius: Theme.cardRadius
            onClicked: root.setValue(root.value - root.step)
        }

        // 入力フィールド
        TextInput {
            id: inputField
            width: root.inputWidth
            height: parent.height
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontPixelSize
            color: root.enabled ? Theme.textColor : Theme.textMuted
            selectByMouse: true
            activeFocusOnPress: true

            // 非フォーカス時のみ value + suffix に追従する。
            // (フォーカス中はユーザーの入力値を優先)
            Binding {
                target: inputField
                property: "text"
                value: root.value + root.suffix
                when: !inputField.activeFocus
                restoreMode: Binding.RestoreNone
            }

            onAccepted: {
                const v = parseInt(text, 10)
                if (!isNaN(v))
                    root.setValue(v)
                focus = false
            }

            onActiveFocusChanged: {
                if (activeFocus)
                    selectAll()
            }
        }

        // Increment ボタン
        Button {
            id: incBtn
            width: root.buttonSize
            height: parent.height
            text: "+"
            enabled: root.enabled && root.value < root.maxValue
            radius: Theme.cardRadius
            onClicked: root.setValue(root.value + root.step)
        }
    }

    // ---- ホイール対応 -------------------------------------------------------
    WheelHandler {
        enabled: root.enabled
        onWheel: function(event) {
            if (event.angleDelta.y > 0)
                root.setValue(root.value + root.step)
            else if (event.angleDelta.y < 0)
                root.setValue(root.value - root.step)
            event.accepted = true
        }
    }

    // ---- メソッド -----------------------------------------------------------
    function setValue(v) {
        const rounded = Math.round(v / root.step) * root.step
        const clamped = Math.max(root.minValue, Math.min(root.maxValue, rounded))
        if (clamped !== root.value)
            root.value = clamped
    }
}
