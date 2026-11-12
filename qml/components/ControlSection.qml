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
    // enabled は Item 標準プロパティを使用する (再宣言しない)。
    default property alias contentData: contentHost.data

    readonly property real headerHeight: 40
    readonly property real spacing: 8

    // 内容 (ヘッダー + カード) から高さを求める。
    // layoutColumn の暗黙高さは子の高さのみに依存し、自己参照しない。
    implicitWidth: 320
    implicitHeight: layoutColumn.implicitHeight
    width: implicitWidth
    height: implicitHeight

    // 子要素の増減を高さ計算へ反映するためのリビジョン
    // (children リストは変更通知を高さバインディングへ伝えないため)。
    property int contentRevision: 0

    // 子要素の下端 (height と implicitHeight の大きい方) の最大値。
    // anchors.fill された子は height が親由来になるため、implicitHeight も
    // 併用して内容の実寸を失わないようにする。
    function contentHeight(revision) {
        let h = 0
        for (let i = 0; i < contentHost.children.length; i++) {
            const child = contentHost.children[i]
            if (!child.visible)
                continue
            const childHeight = Math.max(child.height, child.implicitHeight)
            h = Math.max(h, child.y + childHeight)
        }
        return h
    }

    Column {
        id: layoutColumn
        width: parent.width
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
                // Image に color プロパティは存在しない。淡色 fill のまま使う。
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
        // Column を contentHost にすると anchors.fill の子と競合するため、
        // Item + 内容計測でカード高さを決める。
        GlassCard {
            id: contentCard
            width: parent.width
            padding: 16
            radius: Theme.cardRadius
            opacity: root.enabled ? 1 : 0.5
            height: root.contentHeight(root.contentRevision) + padding * 2
            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            Item {
                id: contentHost
                anchors.fill: parent

                // 子の増減・ジオメトリ変更で高さ計算を再評価する。
                onChildrenChanged: root.contentRevision += 1
                onChildrenRectChanged: root.contentRevision += 1
            }
        }
    }
}
