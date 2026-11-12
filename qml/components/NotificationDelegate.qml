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

    // modelData 未設定時も安全に参照するためのローカルエイリアス。
    readonly property var entry: modelData || ({})

    // 緊急度色 (urgent: true -> アクセント色の左ボーダー)
    readonly property bool isUrgent: entry.urgent === true

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
                width: Math.max(0, parent.width - 56)  // 削除ボタン分を確保
                spacing: 4

                Row {
                    spacing: 8

                    // アプリ名
                    Text {
                        text: entry.app || qsTr("不明なアプリ")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPixelSize
                        font.weight: Font.DemiBold
                        color: Theme.textColor
                        elide: Text.ElideRight
                    }

                    // 時刻
                    Text {
                        text: formatTime(entry.ts)
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPixelSizeCaption
                        color: Theme.textMuted
                    }

                    // 緊急度バッジ
                    Rectangle {
                        id: urgentPill
                        visible: isUrgent
                        // 子テキストの実幅 + 左右パディングで幅を決める
                        // (Rectangle は子から自動サイズされないため明示する)。
                        width: urgentLabel.implicitWidth + horizontalPadding * 2
                        height: Math.max(16, urgentLabel.implicitHeight + 4)
                        radius: height / 2
                        property real horizontalPadding: 6

                        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                        border.width: Theme.borderWidth
                        border.color: Theme.accent

                        Text {
                            id: urgentLabel
                            anchors.centerIn: parent
                            text: urgentBadge(true)
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: Theme.accent
                        }
                    }
                }

                // サマリー (太字)
                Text {
                    width: parent.width
                    text: entry.summary || ""
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPixelSize
                    font.weight: Font.Medium
                    color: urgentColor(isUrgent)
                    elide: Text.ElideRight
                    visible: (entry.summary || "").length > 0
                }

                // 本文 (薄い色、2行まで)
                Text {
                    width: parent.width
                    text: entry.body || ""
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPixelSizeCaption
                    color: Theme.textMuted
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    wrapMode: Text.WordWrap
                    visible: (entry.body || "").length > 0
                }
            }

            // 右側: 削除ボタン
            IconButton {
                iconSource: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='18' height='18'><path fill='%23E8F4F2' d='M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12zM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4z'/></svg>"
                iconSize: 18
                buttonSize: 32
                tooltipText: qsTr("この通知を削除")
                onClicked: {
                    delegateRoot.removeClicked(entry.id)
                }
            }
        }
    }
}
