pragma ComponentBehavior: Bound
import QtQuick
import dev.yukirawa.activenotch

// NetworkListDelegate — ネットワーク一覧の 1 行 (Phase 4: Network ページ用)。
Item {
    id: delegateRoot

    // ---- 公開 API -----------------------------------------------------------
    property string ssid: ""
    property int strength: 0
    property bool secured: false
    property bool isConnected: false
    signal connect(string ssid)
    signal disconnect()

    readonly property real rowHeight: 56
    height: rowHeight

    // ---- ヘルパー関数 (内部) -------------------------------------------------
    function signalBars(strength) {
        if (strength >= 80) return 4
        if (strength >= 55) return 3
        if (strength >= 30) return 2
        if (strength > 0) return 1
        return 0
    }

    function signalColor(strength) {
        // Theme トークンのみ使用 (警告色トークンは Theme に未定義のため
        // 強度はアクセントの濃淡で表現する)。
        if (strength >= 55) return Theme.accent
        if (strength >= 30) return Theme.accentSoft
        return Theme.textMuted
    }

    function securityIcon(secured) {
        return secured
            ? "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='16' height='16'><path fill='%237FB8B0' d='M18 8h-1V7c0-2.76-2.24-5-5-5S7 4.24 7 7v1H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zm-6 9c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2zm3.1-9H8.9V7c0-1.71 1.39-3.1 3.1-3.1 1.71 0 3.1 1.39 3.1 3.1v1z'/></svg>"
            : "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='16' height='16'><path fill='%237FB8B0' d='M12 17c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2zm6-9h-1V7c0-2.76-2.24-5-5-5S7 4.24 7 7v1H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zm-6 9c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2z'/></svg>"
    }

    // 行全体クリック (未接続時のみ)。GlassCard より背面に置き、
    // カード内の IconButton のクリックを奪わないようにする。
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        enabled: !delegateRoot.isConnected
        onClicked: delegateRoot.connect(delegateRoot.ssid)
        cursorShape: delegateRoot.isConnected ? Qt.ArrowCursor : Qt.PointingHandCursor
    }

    GlassCard {
        id: card
        anchors.fill: parent
        padding: 0
        radius: Theme.cardRadius

        // 接続中はアクセントボーダーでハイライト
        Rectangle {
            anchors.fill: parent
            radius: Theme.cardRadius
            color: "transparent"
            border.width: Theme.borderWidth
            border.color: delegateRoot.isConnected ? Theme.accent : "transparent"
            Behavior on border.color { ColorAnimation { duration: 200 } }
        }

        Row {
            anchors.fill: parent
            spacing: 16

            // SSID + 信号強度バー
            Item {
                id: leftSection
                width: Math.max(0, parent.width - 100)
                height: parent.height

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    spacing: 12

                    // Wi-Fi アイコン
                    Image {
                        source: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='20' height='20'><path fill='%23E8F4F2' d='M12 4.5C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5c-1.73-4.39-6-7.5-11-7.5zM12 17c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5zm0-8c-1.66 0-3 1.34-3 3s1.34 3 3 3 3-1.34 3-3-1.34-3-3-3z'/></svg>"
                        width: 20
                        height: 20
                        anchors.verticalCenter: parent.verticalCenter
                        fillMode: Image.PreserveAspectFit
                        // Image に color プロパティは存在しない。接続状態は opacity で示す。
                        opacity: delegateRoot.isConnected ? 1.0 : 0.8
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: delegateRoot.ssid
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontPixelSize
                            font.weight: delegateRoot.isConnected ? Font.DemiBold : Font.Medium
                            color: delegateRoot.isConnected ? Theme.accent : Theme.textColor
                            elide: Text.ElideRight
                        }

                        // 信号強度バー + セキュリティ
                        Row {
                            spacing: 8

                            // 信号バー
                            Item {
                                id: barsItem
                                width: 50
                                height: 12

                                Row {
                                    anchors.centerIn: parent
                                    height: barsItem.height
                                    spacing: 1.5

                                    Repeater {
                                        model: 4
                                        delegate: Rectangle {
                                            width: 3
                                            // 親 Row の暗黙高さとの循環を避け、
                                            // 固定の barsItem.height を基準にする。
                                            height: barsItem.height * (index + 1) / 4
                                            y: barsItem.height - height
                                            radius: 1.5
                                            color: index < delegateRoot.signalBars(delegateRoot.strength)
                                                ? delegateRoot.signalColor(delegateRoot.strength)
                                                : Qt.rgba(Theme.textMutedColor.r, Theme.textMutedColor.g, Theme.textMutedColor.b, 0.15)
                                        }
                                    }
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "%1%".arg(delegateRoot.strength)
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPixelSizeCaption
                                color: Theme.textMuted
                            }

                            // セキュリティアイコン
                            Image {
                                source: delegateRoot.securityIcon(delegateRoot.secured)
                                width: 14
                                height: 14
                                anchors.verticalCenter: parent.verticalCenter
                                fillMode: Image.PreserveAspectFit
                                opacity: 0.85
                            }
                        }
                    }
                }
            }

            // 右側: 接続/切断ボタン
            Item {
                width: 80
                height: parent.height

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    // 接続済み: 切断ボタン
                    IconButton {
                        visible: delegateRoot.isConnected
                        iconSource: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='16' height='16'><path fill='%23E8F4F2' d='M14.59 8L12 10.59 9.41 8 8 9.41 10.59 12 8 14.59 9.41 16 12 13.41 14.59 16 16 14.59 13.41 12 16 9.41 14.59 8zM12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8z'/></svg>"
                        iconSize: 16
                        buttonSize: 32
                        tooltipText: qsTr("切断")
                        onClicked: delegateRoot.disconnect()
                    }

                    // 未接続: 接続ボタン
                    IconButton {
                        visible: !delegateRoot.isConnected
                        iconSource: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='16' height='16'><path fill='%23E8F4F2' d='M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z'/></svg>"
                        iconSize: 16
                        buttonSize: 32
                        tooltipText: qsTr("接続")
                        onClicked: delegateRoot.connect(delegateRoot.ssid)
                    }
                }
            }
        }
    }
}
