pragma ComponentBehavior: Bound
import QtQuick
import dev.yukirawa.activenotch

// TrayMenuItem — トレイメニューの個別アイテム (通常/チェック/ラジオ)
Item {
    id: root
    width: parent ? parent.width : 268
    height: 32

    required property var modelData
    // modelData: {id, text, type("normal"|"check"|"radio"), checked, enabled, visible, icon, shortcut}

    property bool hovered: false
    property bool isCheckable: modelData.type === "check" || modelData.type === "radio"
    property bool isChecked: modelData.checked === true

    // 無効/非表示時の早期リターン
    visible: modelData.visible !== false && modelData.enabled !== false
    opacity: modelData.enabled === false ? 0.4 : 1.0

    // 背景ハイライト
    Rectangle {
        id: bgRect
        anchors.fill: parent
        anchors.margins: 4
        radius: 6
        color: Theme.accentSoft
        opacity: root.hovered ? 0.2 : 0
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
            color: root.hovered ? Theme.textColor : Theme.textColor
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        // ショートカット表示 (オプション)
        Text {
            id: shortcutText
            text: modelData.shortcut || ""
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontPixelSizeCaption
            color: Theme.textMuted
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: checkIndicator.left
            anchors.rightMargin: 12
            visible: modelData.shortcut && modelData.shortcut.length > 0
        }

        // チェック/ラジオインジケータ
        Item {
            id: checkIndicator
            width: 18
            height: 18
            anchors.verticalCenter: parent.verticalCenter
            visible: root.isCheckable

            // チェックマーク / ラジオドット
            Image {
                anchors.centerIn: parent
                width: root.isChecked ? 16 : 0
                height: root.isChecked ? 16 : 0
                source: modelData.type === "radio"
                    ? "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='16' height='16'><circle cx='12' cy='12' r='6' fill='%237FB8B0'/></svg>"
                    : "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='16' height='16'><path fill='%237FB8B0' d='M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17z'/>"
                fillMode: Image.PreserveAspectFit
                color: Theme.accent
            }

            // 未チェック時の枠
            Rectangle {
                anchors.centerIn: parent
                width: 16
                height: 16
                radius: modelData.type === "radio" ? 8 : 3
                color: "transparent"
                border.width: 1.5
                border.color: root.hovered ? Theme.accent : Theme.textMuted
                visible: !root.isChecked
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: root.hovered = true
        onExited: root.hovered = false
        onClicked: {
            if (modelData.enabled !== false) {
                // ページ側の handleMenuAction を呼び出す
                const page = root.parent.parent.parent.parent // Tray.qml の root
                if (page && page.handleMenuAction) {
                    page.handleMenuAction(modelData.id, { checked: !root.isChecked })
                }
            }
        }
        cursorShape: modelData.enabled === false ? Qt.ForbiddenCursor : Qt.PointingHandCursor
    }
}