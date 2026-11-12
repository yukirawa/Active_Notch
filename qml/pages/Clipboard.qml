pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import dev.yukirawa.activenotch

// Clipboard — クリップボード履歴管理ページ。
//
// ClipboardService から取得した履歴を検索・表示し、貼付・削除・再コピー・
// 全消去が可能。
// - available=false 時: 「wl-clipboard 未導入: `sudo pacman -S wl-clipboard`」案内表示
// 全文言は qsTr() 化、Theme トークン経由、GlassCard 再利用。
Item {
    id: root
    width: parent ? parent.width : 604
    height: parent ? parent.height : 380

    // ---- 内部状態 -----------------------------------------------------------
    property var itemsModel: []      // [{id, text, ts}] - フィルタ済み
    property var allItems: []        // 全件 (検索用)
    property string searchText: ""   // 検索クエリ
    property bool serviceAvailable: true

    // サービスプロパティの安全な取得 (typeof ガード)
    function getServiceProp(propName, defaultValue) {
        if (typeof ClipboardService !== "undefined" && ClipboardService[propName] !== undefined) {
            return ClipboardService[propName]
        }
        return defaultValue
    }

    function callServiceMethod(methodName, arg) {
        if (typeof ClipboardService !== "undefined" && ClipboardService[methodName]) {
            ClipboardService[methodName](arg)
        }
    }

    // 全件取得・モデル更新
    function refreshItems() {
        if (typeof ClipboardService !== "undefined" && ClipboardService !== null && ClipboardService.items) {
            const items = ClipboardService.items
            if (items) {
                allItems = items
                applyFilter()
            }
        }
    }

    // 検索フィルタ適用 (リアルタイム)
    function applyFilter() {
        const query = searchText.toLowerCase().trim()
        if (query === "") {
            itemsModel = allItems
        } else {
            itemsModel = allItems.filter(function(item) {
                const text = (item.text || "").toLowerCase()
                return text.indexOf(query) !== -1
            })
        }
    }

    // 文字数カウント (改行込み)
    function charCount(text) {
        return (text || "").length
    }

    // 時刻フォーマット
    function formatTime(ts) {
        const date = (typeof ts === "number") ? new Date(ts * 1000) : new Date(ts)
        if (isNaN(date.getTime())) return ""
        // 今日なら HH:mm、それ以外なら MM/dd HH:mm
        const today = new Date()
        if (date.getFullYear() === today.getFullYear() &&
            date.getMonth() === today.getMonth() &&
            date.getDate() === today.getDate()) {
            return Qt.formatDateTime(date, "HH:mm")
        }
        return Qt.formatDateTime(date, "MM/dd HH:mm")
    }

    // プレビュー用テキスト (最初の 1 行、最大 80 文字)
    function previewText(text) {
        const t = (text || "").replace(/\n/g, " ↵ ").trim()
        return t.length > 80 ? t.substring(0, 80) + "…" : t
    }

    // 初期化
    Component.onCompleted: {
        if (typeof ClipboardService !== "undefined") {
            serviceAvailable = getServiceProp("available", false)
            if (serviceAvailable) {
                refreshItems()
            }
        } else {
            serviceAvailable = false
        }
    }

    // プロパティ変更ハンドラ
    Connections {
        target: typeof ClipboardService !== "undefined" ? ClipboardService : null
        onItemsChanged: refreshItems()
        onAvailableChanged: {
            serviceAvailable = ClipboardService.available
            if (serviceAvailable) refreshItems()
        }
    }

    // 検索テキスト変更時のリアルタイムフィルタ
    onSearchTextChanged: applyFilter()

    // ---- レイアウト ---------------------------------------------------------
    Column {
        anchors.fill: parent
        spacing: 12

        // --- ヘッダー: タイトル + 検索バー + 全消去ボタン ----------------------
        Column {
            width: parent.width
            spacing: 8

            Row {
                width: parent.width
                height: 36
                spacing: 12

                Column {
                    spacing: 2
                    Text {
                        text: qsTr("クリップボード履歴")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPixelSizeTitle
                        font.weight: Font.DemiBold
                        color: Theme.textColor
                    }
                    Text {
                        visible: serviceAvailable
                        text: qsTr("履歴 %1 件").arg(itemsModel.length)
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPixelSizeCaption
                        color: Theme.textMuted
                    }
                }

                Item { Layout.fillWidth: true }

                // 全消去ボタン
                IconButton {
                    visible: serviceAvailable && itemsModel.length > 0
                    iconSource: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='20' height='20'><path fill='%23E8F4F2' d='M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12zM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4z'/></svg>"
                    iconSize: 18
                    buttonSize: 36
                    tooltipText: qsTr("履歴を全消去")
                    onClicked: {
                        callServiceMethod("clearAll")
                    }
                }
            }

            // 検索バー
            GlassCard {
                visible: serviceAvailable
                height: 40
                padding: 0
                radius: Theme.cardRadius

                Row {
                    anchors.fill: parent
                    spacing: 8

                    // 検索アイコン
                    Image {
                        width: 20
                        height: 20
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12
                        source: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='20' height='20'><path fill='%239FB8B4' d='M15.5 14h-.79l-.28-.27C15.41 12.59 16 11.11 16 9.5 16 5.91 13.09 3 9.5 3S3 5.91 3 9.5 5.91 16 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z'/></svg>"
                        color: Theme.textMuted
                    }

                    // 検索入力フィールド
                    TextField {
                        id: searchField
                        Layout.fillWidth: true
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: 12
                        placeholderText: qsTr("履歴を検索…")
                        text: root.searchText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPixelSize
                        color: Theme.textColor
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.textColor
                        background: null  // GlassCard 背景を使用
                        onTextChanged: root.searchText = text

                        // クリアボタン (テキストがあるときのみ)
                        clearButtonEnabled: true
                    }
                }
            }
        }

        // --- サービス未配線時のフォールバック表示 ------------------------------
        GlassCard {
            visible: !serviceAvailable
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 56  // ヘッダー分
            height: 100
            padding: 16
            radius: Theme.cardRadius

            Column {
                anchors.fill: parent
                spacing: 8

                Row {
                    spacing: 12

                    Image {
                        source: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24'><path fill='%237FB8B0' d='M19 2H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm0 16H5V4h14v14zM14 10V6.5l-4 4 4 4V13h5c.55 0 1 .45 1 1s-.45 1-1 1H9c-.55 0-1-.45-1-1s.45-1 1-1h5z'/></svg>"
                        width: 24
                        height: 24
                        color: Theme.accentSoft
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: qsTr("wl-clipboard 未導入")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontPixelSize
                            font.weight: Font.DemiBold
                            color: Theme.textColor
                        }

                        Text {
                            text: qsTr("クリップボード履歴には wl-clipboard (wl-paste/wl-copy) が必要です")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontPixelSizeCaption
                            color: Theme.textMuted
                        }
                    }
                }

                // インストールコマンド案内
                Text {
                    text: qsTr("インストール: `sudo pacman -S wl-clipboard` (Arch) / `sudo apt install wl-clipboard` (Debian/Ubuntu)")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPixelSizeCaption
                    color: Theme.accentSoft
                    wrapMode: Text.WordWrap
                }
            }
        }

        // --- 履歴リスト --------------------------------------------------------
        ListView {
            id: historyList
            width: parent.width
            height: serviceAvailable ? (parent.height - 110) : 0  // ヘッダー+検索バー分
            clip: true
            spacing: 4
            model: itemsModel
            visible: serviceAvailable && itemsModel.length > 0

            delegate: ClipboardDelegate {
                required property var modelData
                width: ListView.view.width
                onPasteClicked: {
                    callServiceMethod("paste", modelData.id)
                }
                onRemoveClicked: {
                    callServiceMethod("remove", modelData.id)
                }
                onCopyClicked: {
                    callServiceMethod("paste", modelData.id)  // 再コピー = paste (wl-copy)
                }
            }
        }

        // 空履歴/検索結果なしメッセージ
        GlassCard {
            visible: serviceAvailable && itemsModel.length === 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            padding: 24
            radius: Theme.cardRadius

            Column {
                width: parent.width
                spacing: 8

                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    source: searchText.length > 0
                        ? "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='48' height='48'><path fill='%239FB8B4' d='M15.5 14h-.79l-.28-.27C15.41 12.59 16 11.11 16 9.5 16 5.91 13.09 3 9.5 3S3 5.91 3 9.5 5.91 16 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z'/></svg>"
                        : "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='48' height='48'><path fill='%239FB8B4' d='M19 2H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm0 16H5V4h14v14zM14 10V6.5l-4 4 4 4V13h5c.55 0 1 .45 1 1s-.45 1-1 1H9c-.55 0-1-.45-1-1s.45-1 1-1h5z'/></svg>"
                    width: 48
                    height: 48
                    color: Theme.textMuted
                    opacity: 0.5
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: searchText.length > 0
                        ? qsTr("「%1」に一致する履歴がありません").arg(searchText)
                        : qsTr("クリップボード履歴がありません")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPixelSize
                    font.weight: Font.DemiBold
                    color: Theme.textColor
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: searchText.length > 0
                        ? qsTr("検索キーワードを変更してみてください")
                        : qsTr("テキストをコピーするとここに履歴が蓄積されます")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPixelSizeCaption
                    color: Theme.textMuted
                }
            }
        }
    }
}