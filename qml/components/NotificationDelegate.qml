pragma ComponentBehavior: Bound
import QtQuick
import dev.yukirawa.activenotch

// NotificationDelegate — 通知履歴 1 行分のデリゲート (Notifications ページで使用)。
Item {
    id: delegateRoot
    property var modelData
    signal removeClicked(string notificationId)

    readonly property real rowHeight: 72
    height: rowHeight

    // 緊急度色 (urgent: true -> アクセント色の左ボーダー)
    readonly property bool isUrgent: modelData.urgent === true

    // 時刻フォーマットヘルパー
    function formatTime(ts) {
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

    GlassCard {
        id: card
        anchors.fill: parent
        padding: 12
        radius: Theme.cardRadius

        // 緊急度インディケータ (左端の細いバー)
        Rectangle {
            x: 0
            y: 0
            width: 3
            height: parent.height
            radius: 0
            color: isUrgent ? Theme.accent : "transparent"
            visible: isUrgent
        }

        Row {
            anchors.fill: parent
            spacing: 12

            // アプリ名 + 時刻 + 緊急度バッジ
            Column {
                width: parent.width - 56  // 削除ボタン分を確保
                spacing: 4

                Row {
                    spacing: 8

                    // アプリ名
                    Text {
                        text: modelData.app || qsTr("不明なアプリ")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPixelSize
                        font.weight: Font.DemiBold
                        color: Theme.textColor
                        elide: Text.ElideRight
                    }

                    // 時刻
                    Text {
                        text: formatTime(modelData.ts)
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPixelSizeCaption
                        color: Theme.textMuted
                    }

                    // 緊急度バッジ
                    Rectangle {
                        visible: isUrgent
                        height: 16
                        radius: 8
                        padding: 0
                        property real horizontalPadding: 6

                        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                        border.width: Theme.borderWidth
                        border.color: Theme.accent

                        Text {
                            anchors.centerIn: parent
                            text: urgentBadge(true)
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: Theme.accent
                            padding: horizontalPadding
                        }
                    }
                }

                // サマリー (太字)
                Text {
                    width: parent.width
                    text: modelData.summary || ""
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPixelSize
                    font.weight: Font.Medium
                    color: urgentColor(isUrgent)
                    elide: Text.ElideRight
                    visible: (modelData.summary || "").length > 0
                }

                // 本文 (薄い色、2行まで)
                Text {
                    width: parent.width
                    text: modelData.body || ""
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPixelSizeCaption
                    color: Theme.textMuted
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    wrapMode: Text.WordWrap
                    visible: (modelData.body || "").length > 0
                }
            }

            // 右側: 削除ボタン
            IconButton {
                iconSource: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='18' height='18'><path fill='%23E8F4F2' d='M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12zM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4z'/>"
                iconSize: 18
                buttonSize: 32
                tooltipText: qsTr("この通知を削除")
                onClicked: {
                    delegateRoot.removeClicked(modelData.id)
                }
            }
        }
    }
}