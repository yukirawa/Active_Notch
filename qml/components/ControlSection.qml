pragma ComponentBehavior: Bound
import QtQuick
import dev.yukirawa.activenotch

// ControlSection — コントロール用のセクションコンテナ (Sound ページ等で使用)。
Item {
    id: root

    // ---- 公開 API -----------------------------------------------------------
    property string title: ""
    property string subtitle: ""
    property string iconSource: ""
    property bool enabled: true
    default property alias contentData: contentHost.data

    readonly property real headerHeight: 40
    readonly property real spacing: 8

    Column {
        anchors.fill: parent
        spacing: root.spacing

        // ヘッダー
        Row {
            width: parent.width
            height: root.headerHeight
            spacing: 12

            Image {
                source: root.iconSource
                width: 24
                height: 24
                anchors.verticalCenter: parent.verticalCenter
                fillMode: Image.PreserveAspectFit
                color: root.enabled ? Theme.accentSoft : Theme.textMuted
                opacity: root.enabled ? 1 : 0.5
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    text: root.title
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPixelSizeTitle
                    font.weight: Font.DemiBold
                    color: root.enabled ? Theme.textColor : Theme.textMuted
                }

                Text {
                    visible: root.subtitle.length > 0
                    text: root.subtitle
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPixelSizeCaption
                    color: Theme.textMuted
                }
            }
        }

        // コンテンツ領域 (GlassCard で包む)
        GlassCard {
            id: contentCard
            width: parent.width
            padding: 16
            radius: Theme.cardRadius
            opacity: root.enabled ? 1 : 0.5
            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            Item {
                id: contentHost
                anchors.fill: parent
            }
        }
    }
}