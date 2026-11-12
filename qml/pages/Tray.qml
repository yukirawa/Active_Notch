pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import dev.yukirawa.activenotch

// Tray — システムトレイ (SNI/StatusNotifierItem) ページ (Phase 6)
//
// TrayService からトレイアイテムを取得し、水平リストで表示する。
// 左クリック → activate()、右クリック → openMenu() でメニュー表示 (Popup/Menu)
// メニュー項目: テキスト/チェック/ラジオ/サブメニュー/セパレータ
// アイコン: iconSource から SVG/画像読み込み (breeze フォールバック)
// available=false 時「SNI/DBusMenu 未対応」表示
Item {
    id: root
    width: parent ? parent.width : 604
    height: parent ? parent.height : 380

    // ---- 内部状態 ---------------------------------------------------------------
    property var trayItems: []
    property int hoveredIndex: -1
    property int menuOpenIndex: -1
    property var currentMenuModel: []

    // ---- ヘルパー: サービスプロパティ/メソッドの安全な取得 ---------------------
    function getServiceProp(propName, defaultValue) {
        if (typeof TrayService !== "undefined" && TrayService[propName] !== undefined) {
            return TrayService[propName]
        }
        return defaultValue
    }

    function callServiceMethod(methodName, ...args) {
        if (typeof TrayService !== "undefined" && TrayService[methodName]) {
            return TrayService[methodName](...args)
        }
        return undefined
    }

    // ---- 初期化: トレイアイテム取得 ---------------------------------------------
    Component.onCompleted: {
        refreshTrayItems()
    }

    // TrayService の items 変更シグナルに接続 (C++ 側で NOTIFY がある想定)
    Connections {
        target: typeof TrayService !== "undefined" ? TrayService : null
        onItemsChanged: root.refreshTrayItems()
        onMenuReady: function(itemId, menuModel) {
            // menuReady(id, menuModel) シグナルを受け取る
            if (menuModel !== undefined) {
                root.currentMenuModel = menuModel
                root.menuOpenIndex = itemId
            }
        }
    }

    function refreshTrayItems() {
        if (typeof TrayService !== "undefined" && TrayService !== null && TrayService.items) {
            root.trayItems = TrayService.items
        } else {
            root.trayItems = []
        }
    }

    // ---- アクションハンドラ -----------------------------------------------------
    function onItemActivated(index) {
        if (index < 0 || index >= root.trayItems.length) return
        const item = root.trayItems[index]
        callServiceMethod("activate", item.id)
    }

    function onItemMenuRequested(index) {
        if (index < 0 || index >= root.trayItems.length) return
        const item = root.trayItems[index]
        callServiceMethod("openMenu", item.id)
        // menuReady シグナルで currentMenuModel と menuOpenIndex が設定される
    }

    function closeMenu() {
        root.menuOpenIndex = -1
        root.currentMenuModel = []
    }

    function handleMenuAction(actionId, actionData) {
        // メニューアクション実行 (C++ 側で処理)
        callServiceMethod("triggerMenuAction", root.menuOpenIndex, actionId, actionData)
        root.closeMenu()
    }

    // ---- アイコン取得ヘルパー (SVG data URI または breeze フォールバック) ------
    function getIconSource(iconSource) {
        if (!iconSource || iconSource.length === 0) {
            return getDefaultIcon()
        }
        // data URI または file:// ならそのまま
        if (iconSource.startsWith("data:") || iconSource.startsWith("file://")) {
            return iconSource
        }
        // breeze アイコン名の場合 (テーマから解決を試みる)
        // QML ではテーマアイコン解決が限定的なので、data URI 化しておくことを推奨
        // ここでは breeze 存在チェックは C++ 側で行い、data URI を返す想定
        return iconSource
    }

    function getDefaultIcon() {
        return "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='22' height='22'><path fill='%237FB8B0' d='M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8zm-1-13h2v6h-2zm0 8h2v2h-2z'/></svg>"
    }

    // ---- メニューモデルを MenuItem に変換 ---------------------------------------
    function createMenuItem(modelData, menuIndex) {
        const item = modelData
        // item 形式: {id, text, type, checked, enabled, visible, children, icon}
        // type: "normal" | "check" | "radio" | "separator" | "submenu"

        if (item.type === "separator") {
            return null // セパレータは専用デリゲートで処理
        }

        return item
    }

    // ---- レイアウト -------------------------------------------------------------
    Column {
        anchors.fill: parent
        anchors.margins: Theme.panelPadding
        spacing: 8

        // ヘッダー
        Row {
            width: parent.width
            height: 36
            spacing: 12

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("システムトレイ")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPixelSizeTitle
                font.weight: Font.DemiBold
                color: Theme.textColor
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("StatusNotifierItem ホスト (左クリック: 起動, 右クリック: メニュー)")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPixelSizeCaption
                color: Theme.textMuted
            }
        }

        // トレイアイテム水平リスト
        GlassCard {
            width: parent.width
            height: 80
            padding: 12
            radius: Theme.cardRadius

            // サービス未利用時のフォールバック
            Item {
                id: unavailableNotice
                anchors.fill: parent
                visible: !root.getServiceProp("available", false)

                Row {
                    anchors.centerIn: parent
                    spacing: 12

                    Image {
                        width: 32
                        height: 32
                        source: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='32' height='32'><path fill='%237FB8B0' d='M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z'/></svg>"
                        color: Theme.accentSoft
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: qsTr("システムトレイ機能は現在利用できません")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontPixelSize
                            font.weight: Font.DemiBold
                            color: Theme.textColor
                        }

                        Text {
                            text: qsTr("SNI (StatusNotifierWatcher) / DBusMenu が未対応です")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontPixelSizeCaption
                            color: Theme.textMuted
                        }
                    }
                }
            }

            // トレイアイテムリスト (利用可能時)
            ListView {
                id: trayList
                anchors.fill: parent
                visible: root.getServiceProp("available", false)
                orientation: ListView.Horizontal
                model: root.trayItems
                spacing: 8
                clip: true
                boundsBehavior: ListView.StopAtBounds

                // 空状態
                Item {
                    width: parent.width
                    height: parent.height
                    visible: root.trayItems.length === 0

                    Row {
                        anchors.centerIn: parent
                        spacing: 8

                        Image {
                            width: 32
                            height: 32
                            source: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='32' height='32'><path fill='%239FB8B4' d='M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8zm-1-13h2v6h-2zm0 8h2v2h-2z'/></svg>"
                            opacity: 0.4
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("トレイアイテムがありません")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontPixelSize
                            color: Theme.textMuted
                        }
                    }
                }

                delegate: Item {
                    id: trayDelegate
                    width: 64
                    height: parent.height
                    property bool isHovered: root.hoveredIndex === index
                    property bool isMenuOpen: root.menuOpenIndex === index

                    // トレイアイコンボタン
                    MouseArea {
                        id: trayMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onEntered: root.hoveredIndex = index
                        onExited: {
                            if (root.hoveredIndex === index) root.hoveredIndex = -1
                        }
                        onClicked: {
                            if (mouse.button === Qt.LeftButton) {
                                root.onItemActivated(index)
                            } else if (mouse.button === Qt.RightButton) {
                                root.onItemMenuRequested(index)
                            }
                        }
                        cursorShape: Qt.PointingHandCursor
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 4

                        // アイコン
                        // Image.color は Qt 6 に無いため、ホバー時は opacity で
                        // 強調する (SVG の塗り色はそのまま)。
                        Image {
                            id: trayIcon
                            width: 28
                            height: 28
                            anchors.horizontalCenter: parent.horizontalCenter
                            source: root.getIconSource(modelData.iconSource)
                            fillMode: Image.PreserveAspectFit
                            // ステータスに応じた微細な視覚フィードバック
                            opacity: modelData.status === "passive" ? 0.5
                                : (trayDelegate.isHovered || trayDelegate.isMenuOpen ? 1.0 : 0.85)
                            Behavior on opacity {
                                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                            }
                        }

                        // タイトル (ツールチップ用に短縮)
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.title
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontPixelSizeCaption
                            color: trayDelegate.isHovered ? Theme.textColor : Theme.textMuted
                            elide: Text.ElideRight
                            width: 70
                            Behavior on color {
                                ColorAnimation { duration: 120; easing.type: Easing.OutCubic }
                            }
                        }

                        // ステータスインジケータ (小さなドット)
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 6
                            height: 6
                            radius: 3
                            visible: modelData.status === "needs_attention"
                            color: Theme.accent
                            opacity: 0.8
                        }
                    }

                    // ホバー/メニュー開時のハイライト背景
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -4
                        radius: 10
                        color: Theme.accentSoft
                        opacity: (trayDelegate.isHovered || trayDelegate.isMenuOpen) ? 0.15 : 0
                        Behavior on opacity {
                            ColorAnimation { duration: 120; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }
        }

        // メニュー表示エリア (ポップアップ)
        // メニューが開いているときのみ表示
        Item {
            id: menuPopupHost
            width: parent.width
            height: parent.height - 44 - 80 - 8
            visible: root.menuOpenIndex >= 0 && root.currentMenuModel.length > 0

            // メニューをマウス位置付近に表示するため、Popup を使用
            // ただし QML の Menu は Window オーバーレイで表示されるため、
            // ここでは簡易的なインラインメニューを実装
            Column {
                id: menuColumn
                width: Math.min(280, parent.width)
                spacing: 0
                // メニュー位置: 対応するトレイアイテムの下部に配置
                x: root.menuOpenIndex >= 0 && root.menuOpenIndex < trayList.contentItem.children.length
                    ? trayList.contentItem.children[root.menuOpenIndex].x + trayList.contentX + 32 - width / 2
                    : (parent.width - width) / 2
                y: 8 // GlassCard の下端から少し離す

                // 背景カード (メニュー全体を GlassCard で包む)
                GlassCard {
                    width: parent.width
                    padding: 6
                    radius: Theme.cardRadius
                    // 高さは内容に合わせる

                    Column {
                        id: menuItemsColumn
                        width: parent.width
                        spacing: 2

                        // メニューアイテムを動的生成
                        Repeater {
                            model: root.currentMenuModel
                            delegate: Loader {
                                width: parent.width
                                sourceComponent: getMenuItemComponent(modelData)
                            }
                        }
                    }
                }
            }
        }

        // キーボード操作ヒント
        Item {
            id: hintBlock
            width: parent.width
            height: 32
            visible: root.getServiceProp("available", false)

            Row {
                anchors.centerIn: parent
                spacing: 24

                Row {
                    spacing: 6
                    Image {
                        width: 16
                        height: 16
                        source: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='16' height='16'><path fill='%239FB8B4' d='M2 17h20v2H2zm0-7h20v2H2zm0-7h20v2H2z'/></svg>"
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("左クリック: 起動")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPixelSizeCaption
                        color: Theme.textMuted
                    }
                }

                Row {
                    spacing: 6
                    Image {
                        width: 16
                        height: 16
                        source: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='16' height='16'><path fill='%239FB8B4' d='M2 17h20v2H2zm0-7h20v2H2zm0-7h20v2H2z'/></svg>"
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("右クリック: メニュー")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPixelSizeCaption
                        color: Theme.textMuted
                    }
                }
            }
        }
    }

    // ---- メニューアイテムコンポーネントファクトリ ---------------------------------
    function getMenuItemComponent(itemData) {
        // セパレータ
        if (itemData.type === "separator") {
            return Qt.resolvedUrl("components/TrayMenuSeparator.qml")
        }

        // サブメニュー
        if (itemData.type === "submenu") {
            return Qt.resolvedUrl("components/TrayMenuSubmenu.qml")
        }

        // 通常/チェック/ラジオ
        return Qt.resolvedUrl("components/TrayMenuItem.qml")
    }
}