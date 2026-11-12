pragma ComponentBehavior: Bound
import QtQuick
import dev.yukirawa.activenotch

// ClipboardDelegate — クリップボード履歴 1 行分のデリゲート (Clipboard ページで使用)。
Item {
    id: delegateRoot
    property var modelData
    signal pasteClicked(string itemId)
    signal removeClicked(string itemId)
    signal copyClicked(string itemId)

    readonly property real rowHeight: 68
    height: rowHeight

    // modelData 未設定時も安全に参照するためのローカルエイリアス。
    readonly property var entry: modelData || ({})

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

    // 文字数カウント (改行込み)
    function charCount(text) {
        return (text || "").length
    }

    GlassCard {
        id: card
        anchors.fill: parent
        padding: 12
        radius: Theme.cardRadius

        Row {
            anchors.fill: parent
            spacing: 12

            // コンテンツ部分
            Column {
                width: Math.max(0, parent.width - 120)  // アクションボタン分を確保
                spacing: 4

                // プレビュー (最初の 1 行)
                Text {
                    width: parent.width
                    text: previewText(entry.text)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPixelSize
                    color: Theme.textColor
                    elide: Text.ElideRight
                }

                // メタ情報: 時刻 + 文字数
                Row {
                    spacing: 12

                    Text {
                        text: formatTime(entry.ts)
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPixelSizeCaption
                        color: Theme.textMuted
                    }

                    Text {
                        text: qsTr("%1 文字").arg(charCount(entry.text))
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPixelSizeCaption
                        color: Theme.textMuted
                    }
                }
            }

            // 右側: アクションボタン群
            Row {
                spacing: 4

                // 貼付 (ペースト)
                IconButton {
                    iconSource: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='18' height='18'><path fill='%23E8F4F2' d='M19 2H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm0 16H5V4h14v14zM14 10V6.5l-4 4 4 4V13h5c.55 0 1 .45 1 1s-.45 1-1 1H9c-.55 0-1-.45-1-1s.45-1 1-1h5z'/></svg>"
                    iconSize: 18
                    buttonSize: 32
                    tooltipText: qsTr("貼り付け (ペースト)")
                    onClicked: {
                        delegateRoot.pasteClicked(entry.id)
                    }
                }

                // 再コピー (クリップボードに再設定)
                IconButton {
                    iconSource: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='18' height='18'><path fill='%23E8F4F2' d='M16 1H4c-1.1 0-2 .9-2 2v14h2V3h12V1zm3 4H8c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h11c1.1 0 2-.9 2-2V7c0-1.1-.9-2-2-2zm0 16H8V7h11v14z'/></svg>"
                    iconSize: 18
                    buttonSize: 32
                    tooltipText: qsTr("再コピー (クリップボードに設定)")
                    onClicked: {
                        delegateRoot.copyClicked(entry.id)
                    }
                }

                // 削除
                IconButton {
                    iconSource: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='18' height='18'><path fill='%23E8F4F2' d='M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12zM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4z'/></svg>"
                    iconSize: 18
                    buttonSize: 32
                    tooltipText: qsTr("履歴から削除")
                    onClicked: {
                        delegateRoot.removeClicked(entry.id)
                    }
                }
            }
        }
    }
}
