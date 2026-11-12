pragma ComponentBehavior: Bound
import QtQuick
import dev.yukirawa.activenotch

// TrayMenuSubmenu — トレイメニューのサブメニュー項目
Item {
    id: root
    width: parent ? parent.width : 268
    height: 32

    required property var modelData
    // modelData: {id, text, type: "submenu", children: [...], enabled, visible, icon}

    property bool hovered: false
    property bool submenuOpen: false

    visible: modelData.visible !== false && modelData.enabled !== false
    opacity: modelData.enabled === false ? 0.4 : 1.0

    // 背景ハイライト
    Rectangle {
        id: bgRect
        anchors.fill: parent
        anchors.margins: 4
        radius: 6
        color: Theme.accentSoft
        opacity: root.hovered || root.submenuOpen ? 0.2 : 0
        Behavior on opacity {
            ColorAnimation { duration: 80; easing.type: Easing.OutCubic }
        }
    }

    Row {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 10

        // アイコン (オプション)
        Image {
            id: itemIcon
            width: 18
            height: 18
            anchors.verticalCenter: parent.verticalCenter
            visible: modelData.icon && modelData.icon.length > 0
            source: modelData.icon
            fillMode: Image.PreserveAspectFit
            color: root.hovered ? Theme.accent : Theme.textColor
        }

        // テキスト
        Text {
            id: itemText
            text: modelData.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontPixelSize
            font.weight: Font.DemiBold
            color: root.hovered ? Theme.textColor : Theme.textColor
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        // サブメニュー展開インジケータ (右向き三角形)
        Image {
            id: submenuArrow
            width: 14
            height: 14
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='14' height='14'><path fill='%239FB8B4' d='M8.59 16.59L13.17 12 8.59 7.41 10 6l6 6-6 6-1.41-1.41z'/>"
            fillMode: Image.PreserveAspectFit
            color: root.hovered ? Theme.accent : Theme.textMuted
            rotation: root.submenuOpen ? 90 : 0
            Behavior on rotation {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
        }
    }

    // サブメニュー ポップアップ (簡易実装: 右側に展開)
    Item {
        id: submenuPopup
        x: root.width - 4
        y: 0
        width: 240
        height: Math.min(root.modelData.children.length * 36, 300)
        visible: root.submenuOpen
        z: 100
        clip: true

        GlassCard {
            anchors.fill: parent
            padding: 6
            radius: Theme.cardRadius

            Column {
                anchors.fill: parent
                spacing: 2

                Repeater {
                    model: root.modelData.children
                    delegate: Loader {
                        width: parent.width
                        sourceComponent: getMenuItemComponent(modelData)
                    }
                }
            }
        }
    }

    // メニューアイテムコンポーネントファクトリ (Tray.qml からコピー)
    function getMenuItemComponent(itemData) {
        if (itemData.type === "separator") {
            return Qt.resolvedUrl("components/TrayMenuSeparator.qml")
        }
        if (itemData.type === "submenu") {
            return Qt.resolvedUrl("components/TrayMenuSubmenu.qml")
        }
        return Qt.resolvedUrl("components/TrayMenuItem.qml")
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: {
            root.hovered = true
            root.submenuOpen = true
        }
        onExited: {
            root.hovered = false
            // サブメニューからマウスが出たら閉じる (少し遅延させる)
            submenuCloseTimer.restart()
        }
        onClicked: {
            // クリックでもサブメニューを開く
            root.submenuOpen = true
        }
        cursorShape: modelData.enabled === false ? Qt.ForbiddenCursor : Qt.PointingHandCursor
    }

    // サブメニューから出た後の遅延クローズ
    Timer {
        id: submenuCloseTimer
        interval: 200
        repeat: false
        onTriggered: {
            if (!root.hovered && !submenuPopup.containsMouse) {
                root.submenuOpen = false
            }
        }
    }

    // サブメニューポップアップ内のマウス検知
    MouseArea {
        anchors.fill: submenuPopup
        hoverEnabled: true
        onEntered: submenuCloseTimer.stop()
        onExited: submenuCloseTimer.restart()
    }
}