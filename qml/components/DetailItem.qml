pragma ComponentBehavior: Bound
import QtQuick
import dev.yukirawa.activenotch

// DetailItem — 詳細情報行 (アイコン + ラベル + 値) (Battery ページ等で使用)。
Item {
    id: root

    // ---- 公開 API -----------------------------------------------------------
    property string iconSource: ""
    property string label: ""
    property string value: ""
    property color valueColor: Theme.textColor
    readonly property real itemHeight: 48
    height: itemHeight

    GlassCard {
        anchors.fill: parent
        padding: 12
        radius: Theme.cardRadius

        Row {
            anchors.fill: parent
            spacing: 12

            Image {
                source: root.iconSource
                width: 20
                height: 20
                anchors.verticalCenter: parent.verticalCenter
                fillMode: Image.PreserveAspectFit
                // Image に color プロパティは存在しない (SVG の淡色 fill を使う)。
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    text: root.label
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPixelSizeCaption
                    color: Theme.textMuted
                }

                Text {
                    text: root.value
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPixelSize
                    font.weight: Font.Medium
                    color: root.valueColor
                }
            }
        }
    }
}