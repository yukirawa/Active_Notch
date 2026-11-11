pragma ComponentBehavior: Bound
import QtQuick
import dev.yukirawa.activenotch

// TabButton — TabBar 内部で使用する個別タブボタン。
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

    // 内部状態
    property bool hovered: false

    // ---- アイコン (SVG data URI) --------------------------------------------
    Image {
        id: iconItem
        source: root.iconSource
        width: root.iconSize
        height: root.iconSize
        anchors.verticalCenter: parent.verticalCenter
        x: root.tabPadding / 2
        fillMode: Image.PreserveAspectFit
        color: root.isSelected ? Theme.accent : (root.hovered ? Theme.textColor : Theme.textMuted)
        Behavior on color {
            ColorAnimation { duration: 120; easing.type: Easing.OutCubic }
        }
    }

    // ---- ラベル -------------------------------------------------------------
    Text {
        id: labelTextItem
        text: root.labelText
        font.family: Theme.fontFamily
        font.pixelSize: root.fontPixelSize
        font.weight: root.isSelected ? Font.DemiBold : Font.Normal
        color: root.isSelected ? Theme.textColor : (root.hovered ? Theme.textColor : Theme.textMuted)
        anchors.left: iconItem.right
        anchors.leftMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: root.tabPadding / 2
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
        Behavior on color {
            ColorAnimation { duration: 120; easing.type: Easing.OutCubic }
        }
        Behavior on font.weight {
            PropertyAnimation { duration: 120 }
        }
    }

    // ---- ホバー/クリック領域 -------------------------------------------------
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: root.hovered = true
        onExited: root.hovered = false
        onClicked: root.clicked()
        cursorShape: root.isSelected ? Qt.ArrowCursor : Qt.PointingHandCursor
    }

    // ---- ツールチップ -------------------------------------------------------
    ToolTip {
        text: root.tooltipText
        visible: root.hovered && root.tooltipText.length > 0
        delay: 500
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontPixelSizeCaption
    }
}