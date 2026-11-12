pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import dev.yukirawa.activenotch

// Notifications — 通知履歴・DND 管理ページ。
//
// NotificationService から取得した通知履歴をリスト表示し、個別削除・全消去・
// DND トグル・テスト通知送信が可能。
// - ownsDaemon=false 時: 「システム通知をミラー中」バッジ表示
// - available=false 時: 「通知デーモン未取得」フォールバック表示
// 全文言は qsTr() 化、Theme トークン経由、GlassCard 再利用。
Item {
    id: root
    width: parent ? parent.width : 604
    height: parent ? parent.height : 380

    // ---- 内部状態 -----------------------------------------------------------
    property var historyModel: []  // [{id, app, summary, body, ts, urgent}]
    property bool dndActive: false
    property bool ownsDaemon: true
    property bool serviceAvailable: true

    // サービスプロパティの安全な取得 (typeof ガード)
    function getServiceProp(propName, defaultValue) {
        if (typeof NotificationService !== "undefined" && NotificationService[propName] !== undefined) {
            return NotificationService[propName]
        }
        return defaultValue
    }

    function callServiceMethod(methodName, arg) {
        if (typeof NotificationService !== "undefined" && NotificationService[methodName]) {
            NotificationService[methodName](arg)
        }
    }

    // 履歴モデル更新 (NotificationService.history 変更シグナルから呼び出し想定)
    function refreshHistory() {
        if (typeof NotificationService !== "undefined" && NotificationService !== null && NotificationService.history) {
            const h = NotificationService.history
            if (h) {
                historyModel = h
            }
        }
    }

    // 初期化
    Component.onCompleted: {
        if (typeof NotificationService !== "undefined") {
            serviceAvailable = getServiceProp("ownsDaemon", true) !== undefined // サービス自体が存在するか
            ownsDaemon = getServiceProp("ownsDaemon", true)
            dndActive = getServiceProp("dnd", false)
            refreshHistory()
        } else {
            serviceAvailable = false
            ownsDaemon = false
        }
    }

    // プロパティ変更ハンドラ (サービス側から NOTIFY される想定)
    Connections {
        target: typeof NotificationService !== "undefined" ? NotificationService : null
        onHistoryChanged: refreshHistory()
        onDndChanged: dndActive = NotificationService.dnd
        onOwnsDaemonChanged: ownsDaemon = NotificationService.ownsDaemon
    }

    // ---- 時刻フォーマットヘルパー -------------------------------------------
    function formatTime(ts) {
        // ts は UNIX 秒 (number) または ISO 文字列を想定
        const date = (typeof ts === "number") ? new Date(ts * 1000) : new Date(ts)
        if (isNaN(date.getTime())) return ""
        return Qt.formatDateTime(date, "HH:mm:ss")
    }

    // 緊急度に応じた色
    function urgentColor(urgent) {
        return urgent ? Theme.accent : Theme.textColor
    }

    // 緊急度バッジテキスト
    function urgentBadge(urgent) {
        return urgent ? qsTr("緊急") : qsTr("通常")
    }

    // ---- レイアウト ---------------------------------------------------------
    Column {
        anchors.fill: parent
        spacing: 12

        // --- ヘッダー: タイトル + DND トグル + アクション -----------------------
        Row {
            width: parent.width
            height: 48
            spacing: 12

            // タイトル部分
            Column {
                spacing: 2
                Text {
                    text: qsTr("通知履歴")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPixelSizeTitle
                    font.weight: Font.DemiBold
                    color: Theme.textColor
                }
                Text {
                    visible: serviceAvailable
                    text: ownsDaemon
                        ? qsTr("履歴 %1 件").arg(historyModel.length)
                        : qsTr("システム通知をミラー中 · 履歴 %1 件").arg(historyModel.length)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPixelSizeCaption
                    color: Theme.textMuted
                }
            }

            // 右寄せアクション群
            Item {
                Layout.fillWidth: true
            }

            // ownsDaemon 状態バッジ
            GlassCard {
                visible: serviceAvailable && !ownsDaemon
                height: 28
                padding: 8
                radius: 14

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    Image {
                        source: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='14' height='14'><path fill='%237FB8B0' d='M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z'/></svg>"
                        width: 14
                        height: 14
                        color: Theme.accentSoft
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("ミラーモード")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPixelSizeCaption
                        color: Theme.accentSoft
                    }
                }
            }

            // DND トグル (QuickSettings と独立、NotificationService.dnd に連動)
            ToggleSwitch {
                id: dndToggle
                anchors.verticalCenter: parent.verticalCenter
                checked: dndActive
                enabled: serviceAvailable
                onToggled: {
                    if (serviceAvailable) {
                        callServiceMethod("setDnd", checked)
                    }
                }
            }

            // DND ラベル
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("通知を非表示")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPixelSizeCaption
                color: serviceAvailable ? Theme.textMuted : Theme.textMuted
                opacity: serviceAvailable ? 1 : 0.5
            }

            // テスト通知ボタン
            IconButton {
                iconSource: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='20' height='20'><path fill='%23E8F4F2' d='M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8zm-1-13h2v6h-2zm0 8h2v2h-2z'/></svg>"
                iconSize: 18
                buttonSize: 36
                tooltipText: qsTr("テスト通知を送信")
                enabled: serviceAvailable
                onClicked: {
                    callServiceMethod("test")
                }
            }

            // 全消去ボタン
            IconButton {
                iconSource: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='20' height='20'><path fill='%23E8F4F2' d='M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12zM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4z'/></svg>"
                iconSize: 18
                buttonSize: 36
                tooltipText: qsTr("履歴を全消去")
                enabled: serviceAvailable && historyModel.length > 0
                onClicked: {
                    callServiceMethod("clearAll")
                }
            }
        }

        // --- サービス未配線時のフォールバック表示 ------------------------------
        GlassCard {
            visible: !serviceAvailable
            anchors.left: parent.left
            anchors.right: parent.right
            height: 80
            padding: 16
            radius: Theme.cardRadius

            Row {
                anchors.fill: parent
                spacing: 12

                Image {
                    source: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24'><path fill='%237FB8B0' d='M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z'/></svg>"
                    width: 24
                    height: 24
                    color: Theme.accentSoft
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text: qsTr("通知デーモン未取得")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPixelSize
                        font.weight: Font.DemiBold
                        color: Theme.textColor
                    }

                    Text {
                        text: qsTr("org.freedesktop.Notifications サーバの登録に失敗しました")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPixelSizeCaption
                        color: Theme.textMuted
                    }
                }
            }
        }

        // --- 通知履歴リスト ----------------------------------------------------
        ListView {
            id: historyList
            width: parent.width
            height: parent.height - 60  // ヘッダー分を除く
            clip: true
            spacing: 4
            model: historyModel
            visible: serviceAvailable && historyModel.length > 0

            delegate: NotificationDelegate {
                required property var modelData
                width: ListView.view.width
                onRemoveClicked: {
                    callServiceMethod("close", modelData.id)
                }
            }
        }

        // 空履歴メッセージ
        GlassCard {
            visible: serviceAvailable && historyModel.length === 0
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
                    source: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='48' height='48'><path fill='%239FB8B4' d='M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8zm-1-13h2v6h-2zm0 8h2v2h-2z'/></svg>"
                    width: 48
                    height: 48
                    color: Theme.textMuted
                    opacity: 0.5
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("通知履歴がありません")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPixelSize
                    font.weight: Font.DemiBold
                    color: Theme.textColor
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: ownsDaemon
                        ? qsTr("通知を受信するとここに表示されます")
                        : qsTr("ミラーモード: システム通知を受信するとここに表示されます")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPixelSizeCaption
                    color: Theme.textMuted
                }
            }
        }
    }
}