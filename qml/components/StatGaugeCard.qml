pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import dev.yukirawa.activenotch

// StatGaugeCard — ゲージ付き統計カード (Phase 3: Stats ページ用)。
Item {
    id: statGaugeCard
    property string title: ""
    property string iconSource: ""
    property real gaugeValue: 0
    property real gaugeMax: 100
    property color gaugeColor: Theme.accent
    property string valueText: ""
    property string subText: ""

    Layout.fillWidth: true
    Layout.preferredHeight: cardHeight
    readonly property real cardHeight: 140
    implicitHeight: cardHeight
    height: cardHeight

    GlassCard {
        anchors.fill: parent
        padding: 16
        radius: Theme.cardRadius

        Column {
            width: parent.width
            spacing: 10

            // ヘッダー: アイコン + タイトル
            Row {
                width: parent.width
                spacing: 10

                Image {
                    source: statGaugeCard.iconSource
                    width: 20
                    height: 20
                    anchors.verticalCenter: parent.verticalCenter
                    fillMode: Image.PreserveAspectFit
                    // Image に color プロパティは存在しない (SVG の淡色 fill を使う)。
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: statGaugeCard.title
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPixelSize
                    font.weight: Font.Medium
                    color: Theme.textColor
                }
            }

            // ゲージ + 数値
            Row {
                width: parent.width
                spacing: 16

                // 円形ゲージ
                GaugeCircle {
                    id: gauge
                    width: 72
                    height: 72
                    value: statGaugeCard.gaugeValue
                    maxValue: statGaugeCard.gaugeMax
                    thickness: 6
                    trackColor: Qt.rgba(Theme.textMutedColor.r, Theme.textMutedColor.g, Theme.textMutedColor.b, 0.15)
                    progressColor: statGaugeCard.gaugeColor
                    showText: true
                    textValue: statGaugeCard.valueText
                    textColor: Theme.textColor
                    textPixelSize: 16
                    subText: ""
                    subTextPixelSize: 10
                    enabled: true
                }

                // 数値詳細
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Text {
                        text: statGaugeCard.valueText
                        font.family: Theme.fontFamily
                        font.pixelSize: 22
                        font.weight: Font.DemiBold
                        color: Theme.textColor
                    }

                    Text {
                        visible: statGaugeCard.subText.length > 0
                        text: statGaugeCard.subText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPixelSizeCaption
                        color: Theme.textMuted
                    }
                }
            }
        }
    }
}