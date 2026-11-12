pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import dev.yukirawa.activenotch

// TrayMenuSubmenu — トレイメニューのサブメニュー項目
Item {
    id: root
    width: parent ? parent.width : 268
    height: 32

    required property var modelData
    // modelData: {id, text, type: "submenu", children: [...], enabled, visible, icon}

    // サブメニュー判定 (祖先をたどって深さを求める)
    readonly property bool isSubmenu: true
    // 再帰ロードの深さ (循環データによる無限再帰を防ぐ)
    readonly property int depth: ancestorDepth(root)

    function ancestorDepth(item) {
        let d = 0
        let p = item ? item.parent : null
        while (p) {
            if (p["isSubmenu"] === true)
                d++
            p = p.parent
        }
        return d
    }

    property bool hovered: false
    property bool submenuOpen: false

    visible: modelData.visible !== false && modelData.enabled !== false
    opacity: modelData.enabled === false ? 0.4 : 1.0

    readonly property var childrenModel: (modelData.children && root.depth < 8)
        ? modelData.children
        : []

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
            font.weight: Font.DemiBold
            color: Theme.textColor
            elide: Text.ElideRight
        }

        // サブメニュー展開インジケータ (右向き三角形)
        Image {
            id: submenuArrow
            Layout.preferredWidth: 14
            Layout.preferredHeight: 14
            Layout.alignment: Qt.AlignVCenter
            source: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='14' height='14'><path fill='%239FB8B4' d='M8.59 16.59L13.17 12 8.59 7.41 10 6l6 6-6 6-1.41-1.41z'/></svg>"
            fillMode: Image.PreserveAspectFit
            opacity: root.hovered ? 1.0 : 0.7
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
        height: Math.min(root.childrenModel.length * 36, 300)
        visible: root.submenuOpen
        z: 100
        clip: true

        // ポップアップ内ホバー検知 (クリックを奪わない HoverHandler を使用)
        HoverHandler {
            id: popupHover
        }

        GlassCard {
            anchors.fill: parent
            padding: 6
            radius: Theme.cardRadius

            Column {
                anchors.fill: parent
                spacing: 2

                Repeater {
                    // 開いている間だけ子を生成する (未展開時の再帰ロードと CPU を回避)
                    model: root.submenuOpen ? root.childrenModel : []

                    delegate: Loader {
                        // Repeater の modelData を明示的に受ける
                        // (pragma ComponentBehavior: Bound では外側の
                        //  required property modelData に解決されてしまうため)。
                        required property var modelData
                        width: parent.width
                        // 読み込み前でも Column の高さが確定するよう既定 32。
                        // qmllint disable missing-property
                        height: item ? item.height : 32
                        // required property modelData は Loader.source では
                        // 初期化されないため setSource() で明示的に渡す。
                        Component.onCompleted: setSource(
                            getMenuItemComponent(modelData),
                            { "modelData": modelData })
                    }
                }
            }
        }
    }

    // メニューアイテムコンポーネントファクトリ (このファイルと同じディレクトリ)
    function getMenuItemComponent(itemData) {
        if (itemData.type === "separator")
            return Qt.resolvedUrl("TrayMenuSeparator.qml")
        if (itemData.type === "submenu")
            return Qt.resolvedUrl("TrayMenuSubmenu.qml")
        return Qt.resolvedUrl("TrayMenuItem.qml")
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
            if (!root.hovered && !popupHover.hovered)
                root.submenuOpen = false
        }
    }
}
