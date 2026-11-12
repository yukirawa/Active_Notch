pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
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

    // 祖先をたどって Tray ページの handleMenuAction を探す。
    // (固定階層の parent 参照は構造変更に弱いため)
    function findActionHandler(item) {
        let p = item
        while (p) {
            if (typeof p["handleMenuAction"] === "function")
                return p
            p = p.parent
        }
        return null
    }

    // 背景ハイライト
    Rectangle {
        id: bgRect
        anchors.fill: parent
        anchors.margins: 4
        radius: 6
        color: Theme.accentSoft
        opacity: root.hovered ? 0.2 : 0
        Behavior on opacity {
            NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 10

        // アイコン (オプション)
        Image {
            id: itemIcon
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            Layout.alignment: Qt.AlignVCenter
            visible: modelData.icon && modelData.icon.length > 0
            source: modelData.icon
            fillMode: Image.PreserveAspectFit
            // Image に color プロパティは存在しない (SVG の淡色 fill を使う)。
            opacity: root.hovered ? 1.0 : 0.85
        }

        // テキスト
        Text {
            id: itemText
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            text: modelData.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontPixelSize
            color: Theme.textColor
            elide: Text.ElideRight
        }

        // ショートカット表示 (オプション)
        Text {
            id: shortcutText
            Layout.alignment: Qt.AlignVCenter
            text: modelData.shortcut || ""
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontPixelSizeCaption
            color: Theme.textMuted
            visible: modelData.shortcut && modelData.shortcut.length > 0
        }

        // チェック/ラジオインジケータ
        Item {
            id: checkIndicator
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            Layout.alignment: Qt.AlignVCenter
            visible: root.isCheckable

            // チェックマーク / ラジオドット
            Image {
                anchors.centerIn: parent
                width: root.isChecked ? 16 : 0
                height: root.isChecked ? 16 : 0
                source: modelData.type === "radio"
                    ? "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='16' height='16'><circle cx='12' cy='12' r='6' fill='%237FB8B0'/></svg>"
                    : "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='16' height='16'><path fill='%237FB8B0' d='M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17z'/></svg>"
                fillMode: Image.PreserveAspectFit
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
            if (modelData.enabled === false)
                return
            const page = findActionHandler(root)
            if (page)
                page["handleMenuAction"](modelData.id, { checked: !root.isChecked })
        }
        cursorShape: modelData.enabled === false ? Qt.ForbiddenCursor : Qt.PointingHandCursor
    }
}
