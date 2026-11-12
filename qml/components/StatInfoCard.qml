pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import dev.yukirawa.activenotch

// StatInfoCard — 情報のみの統計カード (Phase 3: Stats ページ用)。
Item {
    id: statInfoCard
    property string title: ""
    property string iconSource: ""
    property string valueText: ""
    property color valueColor: Theme.textColor
    property string subText: ""

    Layout.fillWidth: true
    Layout.preferredHeight: cardHeight
    readonly property real cardHeight: 100
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
                    source: statInfoCard.iconSource
                    width: 20
                    height: 20
                    anchors.verticalCenter: parent.verticalCenter
                    fillMode: Image.PreserveAspectFit
                    // Image に color プロパティは存在しない (SVG の淡色 fill を使う)。
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: statInfoCard.title
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPixelSize
                    font.weight: Font.Medium
                    color: Theme.textColor
                }
            }

            // 数値表示
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4

                Text {
                    text: statInfoCard.valueText
                    font.family: Theme.fontFamily
                    font.pixelSize: 28
                    font.weight: Font.DemiBold
                    color: statInfoCard.valueColor
                }

                Text {
                    visible: statInfoCard.subText.length > 0
                    text: statInfoCard.subText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPixelSizeCaption
                    color: Theme.textMuted
                }
            }
        }
    }
}