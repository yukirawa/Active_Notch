pragma ComponentBehavior: Bound
import QtQuick
import dev.yukirawa.activenotch

// ColorPalette — アクセント色プリセットパレット。
//
// 事前定義された色見本から選択するグリッド形式の UI。
// 現在選択中の色にはチェックマークで表示する。
// Repeater の delegate は required property で modelData を受け取り、
// 外部 Component / Loader を介さない (AOT コンパイル対応)。
Item {
    id: root

    // ---- 公開 API -----------------------------------------------------------
    property color currentColor: Theme.accent
    property var presets: [
        "#7FB8B0",  // デフォルト: くすみティール/アクア
        "#8FC5BD",  // 淡いアクア
        "#6BA39D",  // 深めのティール
        "#5AA3A0",  // 青緑
        "#4ECDC4",  // 明るいティール
        "#00BFA6",  // 鮮やかなティール
        "#FF6B6B",  // コーラルレッド
        "#FF9F43",  // オレンジ
        "#FFD93D",  // イエロー
        "#6BCB77",  // グリーン
        "#4D96FF",  // ブルー
        "#A55EEA",  // パープル
        "#E84393",  // ピンク
        "#FFFFFF",  // ホワイト
        "#E8F4F2"   // 淡いアクア寄りの白
    ]
    property int columns: 7
    property real swatchSize: 36
    property real spacing: 8
    signal colorSelected(color newColor)

    // ---- レイアウト ---------------------------------------------------------
    Grid {
        id: grid
        anchors.fill: parent
        columns: root.columns
        spacing: root.spacing

        Repeater {
            model: root.presets

            delegate: Item {
                id: swatch
                required property var modelData

                width: root.swatchSize
                height: root.swatchSize

                property color swatchColor: swatch.modelData
                property bool selected: Qt.colorEqual(swatch.modelData, root.currentColor)
                property bool hovered: false
                property bool pressed: false

                // 角丸正方形
                Rectangle {
                    id: bg
                    anchors.fill: parent
                    radius: 8
                    color: swatch.swatchColor
                    border.width: swatch.selected ? 3 : Theme.borderWidth
                    border.color: swatch.selected ? Theme.textColor : Theme.cardBorderGlow
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                    Behavior on border.width { NumberAnimation { duration: 150 } }
                }

                // チェックマーク (選択時)
                Image {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    visible: swatch.selected
                    source: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='20' height='20'><path fill='%230E1518' d='M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17z'/></svg>"
                }

                // ホバー/プレス時のスケール
                transform: Scale {
                    id: scaleTransform
                    origin.x: swatch.width / 2
                    origin.y: swatch.height / 2
                    xScale: swatch.pressed ? 0.92 : (swatch.hovered ? 1.05 : 1.0)
                    yScale: swatch.pressed ? 0.92 : (swatch.hovered ? 1.05 : 1.0)
                    Behavior on xScale {
                        SpringAnimation { mass: 0.3; spring: 4.0; damping: 0.7 }
                    }
                    Behavior on yScale {
                        SpringAnimation { mass: 0.3; spring: 4.0; damping: 0.7 }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    onEntered: swatch.hovered = true
                    onExited: {
                        swatch.hovered = false
                        swatch.pressed = false
                    }
                    onPressed: swatch.pressed = true
                    onReleased: {
                        swatch.pressed = false
                        if (containsMouse)
                            root.colorSelected(swatch.modelData)
                    }
                    onCanceled: swatch.pressed = false
                    cursorShape: Qt.PointingHandCursor
                }

                // 簡易ツールチップ (QtQuick.Controls に依存しない自作版)
                Rectangle {
                    visible: swatch.hovered
                    z: 100
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.bottom
                    anchors.topMargin: 6
                    width: tipText.implicitWidth + 12
                    height: tipText.implicitHeight + 8
                    radius: 6
                    color: Theme.panelBg
                    border.width: Theme.borderWidth
                    border.color: Theme.borderGlow

                    Text {
                        id: tipText
                        anchors.centerIn: parent
                        text: String(swatch.modelData)
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPixelSizeCaption
                        color: Theme.textColor
                    }
                }
            }
        }
    }
}
