pragma ComponentBehavior: Bound
import QtQuick
import dev.yukirawa.activenotch

// TabButton — TabBar 内部で使用する個別タブボタン。
//
// 12 タブを 604px (660 - panelPadding*2) に収めるため、アイコンのみの
// コンパクト表示にしている。ラベルは tooltip で補完する
// (labelText は呼び出し側 API との互換のため保持)。
//
// アイコンは SVG data URI (fill='#E8F4F2') をそのまま表示する。
// Qt 6 の Image に color プロパティは無く、インライン GLSL の
// ShaderEffect も .qsb 以外は無効なため tint は行わない。
// 選択中 / ホバーは opacity と TabBar 側のアンダーラインで表現する。
Item {
    id: root

    // ---- 公開プロパティ ------------------------------------------------------
    required property string pageId
    required property string iconSource
    required property string labelText
    required property string tooltipText
    required property bool isSelected
    required property real iconSize
    required property int fontPixelSize
    required property real tabPadding
    signal clicked

    // 推奨幅: アイコン + 左右余白。TabBar はこの値を尊重しつつ、
    // 全体幅に収まるよう 1 タブ幅を縮める。
    readonly property real contentWidth: root.iconSize + root.tabPadding * 2
    implicitWidth: root.contentWidth
    implicitHeight: root.iconSize + root.tabPadding

    // ホバー状態は MouseArea から直接導出する (外部から参照可能)。
    readonly property bool hovered: mouseArea.containsMouse

    // ---- ホバー / 選択背景 ---------------------------------------------------
    // 選択中はアクセントを薄く敷き、ホバー時はカード色でわずかに持ち上げる。
    Rectangle {
        anchors.fill: parent
        radius: 8
        color: root.isSelected ? Theme.accentSoft : Theme.cardBg
        opacity: root.isSelected ? 0.18 : (root.hovered ? 1.0 : 0.0)
        Behavior on opacity {
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }
    }

    // ---- アイコン (SVG data URI をそのまま表示) ------------------------------
    Image {
        id: iconItem
        source: root.iconSource
        width: root.iconSize
        height: root.iconSize
        anchors.centerIn: parent
        fillMode: Image.PreserveAspectFit
        smooth: true
        // 選択中は不透明、非選択は淡く、ホバーで中間まで戻す。
        opacity: root.isSelected ? 1.0 : (root.hovered ? 0.9 : 0.55)
        Behavior on opacity {
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }
    }

    // ---- ホバー/クリック領域 -------------------------------------------------
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
        cursorShape: root.isSelected ? Qt.ArrowCursor : Qt.PointingHandCursor
    }

    // ---- カスタムツールチップ -------------------------------------------------
    // QtQuick.Controls を import しないため自作実装。
    // アイコンのみ表示のため、ラベルはここで補完する。
    Loader {
        id: tooltipLoader
        sourceComponent: tooltipComponent
        active: root.hovered
                && (root.tooltipText.length > 0 || root.labelText.length > 0)
    }

    Component {
        id: tooltipComponent
        Item {
            id: tooltip
            x: root.width / 2 - tooltipTextItem.implicitWidth / 2 - 8
            y: -tooltipTextItem.implicitHeight - 12
            z: 1000

            Rectangle {
                anchors.fill: tooltipTextItem
                anchors.margins: -8
                radius: 6
                color: Theme.bgSurface
                border.width: 1
                border.color: Theme.cardBorderGlow
            }

            Text {
                id: tooltipTextItem
                text: root.tooltipText.length > 0 ? root.tooltipText
                                                  : root.labelText
                font.family: Theme.fontFamily
                font.pixelSize: root.fontPixelSize
                color: Theme.textColor
                padding: 8
            }

            // フェードイン
            opacity: 0
            Behavior on opacity {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }
            Component.onCompleted: tooltip.opacity = 1
        }
    }
}
