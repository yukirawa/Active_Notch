pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import dev.yukirawa.activenotch

// Network — ネットワーク管理ページ (Phase 4)。
//
// NetworkService から Wi-Fi 状態・一覧を取得し、接続操作を提供する。
// - Wi-Fi 有効/無効トグル
// - 現在の接続: SSID/信号強度/セキュリティ/状態
// - ネットワーク一覧: SSID/強度/ロック表示/接続済みマーク
// - 接続操作: クリックで connectSsid、切断ボタン
// - available=false 時「NetworkManager 未検出」表示
Item {
    id: root
    width: parent ? parent.width : 604
    height: parent ? parent.height : 380

    // =========================================================================
    // NetworkService プロパティ (typeof ガード付き)
    // =========================================================================
    readonly property bool available: (typeof NetworkService !== "undefined" && NetworkService !== null && NetworkService.available !== undefined)
        ? NetworkService.available
        : false
    readonly property bool wifiEnabled: (typeof NetworkService !== "undefined" && NetworkService !== null && NetworkService.wifiEnabled !== undefined)
        ? NetworkService.wifiEnabled
        : false
    readonly property string state: (typeof NetworkService !== "undefined" && NetworkService !== null && NetworkService.state !== undefined)
        ? NetworkService.state
        : qsTr("不明")
    readonly property string activeSsid: (typeof NetworkService !== "undefined" && NetworkService !== null && NetworkService.activeSsid !== undefined)
        ? NetworkService.activeSsid
        : ""
    readonly property int signalStrength: (typeof NetworkService !== "undefined" && NetworkService !== null && NetworkService.signalStrength !== undefined)
        ? NetworkService.signalStrength
        : 0
    readonly property var networkList: (typeof NetworkService !== "undefined" && NetworkService !== null && NetworkService.list !== undefined)
        ? NetworkService.list
        : []

    // =========================================================================
    // 内部状態
    // =========================================================================
    property bool scanning: false

    // =========================================================================
    // ヘルパー関数
    // =========================================================================
    // 信号強度からアイコン・色を決定 (0-100 → 0-4 バー)
    function signalBars(strength) {
        if (strength >= 80) return 4
        if (strength >= 55) return 3
        if (strength >= 30) return 2
        if (strength > 0) return 1
        return 0
    }

    function signalColor(strength) {
        if (strength >= 55) return Theme.accent
        if (strength >= 30) return "#FFB300"
        if (strength > 0) return "#F44336"
        return Theme.textMuted
    }

    // 状態文字列の日本語化
    function stateText(stateStr) {
        switch (stateStr) {
            case "connected": return qsTr("接続済み")
            case "connecting": return qsTr("接続中...")
            case "disconnected": return qsTr("未接続")
            case "unavailable": return qsTr("利用不可")
            default: return stateStr
        }
    }

    // セキュリティタイプからアイコン
    function securityIcon(secured) {
        return secured
            ? "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='16' height='16'><path fill='%237FB8B0' d='M18 8h-1V7c0-2.76-2.24-5-5-5S7 4.24 7 7v1H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zm-6 9c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2zm3.1-9H8.9V7c0-1.71 1.39-3.1 3.1-3.1 1.71 0 3.1 1.39 3.1 3.1v1z'/></svg>"
            : "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='16' height='16'><path fill='%237FB8B0' d='M12 17c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2zm6-9h-1V7c0-2.76-2.24-5-5-5S7 4.24 7 7v1H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zm-6 9c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2z'/></svg>"
    }

    // 接続操作
    function onConnectSsid(ssid) {
        if (typeof NetworkService !== "undefined" && NetworkService !== null && NetworkService.connectSsid) {
            NetworkService.connectSsid(ssid)
        }
    }

    function onDisconnect() {
        if (typeof NetworkService !== "undefined" && NetworkService !== null && NetworkService.disconnect) {
            NetworkService.disconnect()
        }
    }

    function onToggleWifi() {
        if (typeof NetworkService !== "undefined" && NetworkService !== null && NetworkService.setWifiEnabled) {
            NetworkService.setWifiEnabled(!root.wifiEnabled)
        }
    }

    function onRefresh() {
        // NetworkService に refresh があれば呼ぶ (将来実装)
        if (typeof NetworkService !== "undefined" && NetworkService !== null && NetworkService.refresh) {
            NetworkService.refresh()
        }
    }

    // =========================================================================
    // レイアウト
    // =========================================================================
    Column {
        anchors.fill: parent
        anchors.margins: Theme.panelPadding
        spacing: 16

        // --- ヘッダー ---------------------------------------------------------
        Row {
            width: parent.width
            height: 36
            spacing: 12

            Image {
                source: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24'><path fill='%237FB8B0' d='M12 4.5C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5c-1.73-4.39-6-7.5-11-7.5zM12 17c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5zm0-8c-1.66 0-3 1.34-3 3s1.34 3 3 3 3-1.34 3-3-1.34-3-3-3z'/></svg>"
                width: 24
                height: 24
                anchors.verticalCenter: parent.verticalCenter
                fillMode: Image.PreserveAspectFit
                color: root.available ? Theme.accentSoft : Theme.textMuted
                opacity: root.available ? 1 : 0.5
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    text: root.available ? qsTr("ネットワーク") : qsTr("NetworkManager 未検出")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPixelSizeTitle
                    font.weight: Font.DemiBold
                    color: root.available ? Theme.textColor : Theme.textMuted
                }

                Text {
                    visible: root.available
                    text: qsTr("Wi-Fi ネットワークの管理と接続")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPixelSizeCaption
                    color: Theme.textMuted
                }
            }

            // Wi-Fi トグル + 更新ボタン
            Item {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 36

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    // 更新ボタン
                    IconButton {
                        iconSource: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='20' height='20'><path fill='%23E8F4F2' d='M17.65 6.35A7.958 7.958 0 0012 4C7.42 4 3.73 7.02 2.47 10.93l2.14 2.14A5.942 5.942 0 0112 6c2.48 0 4.56 1.48 5.51 3.49l1.64-1.64zm-11.3 11.3A7.958 7.958 0 0012 20c4.58 0 8.27-3.02 9.53-6.93l-2.14-2.14A5.942 5.942 0 0112 18c-2.48 0-4.56-1.48-5.51-3.49L2.35 17.65zM12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8z'/></svg>"
                        iconSize: 20
                        buttonSize: 36
                        tooltipText: qsTr("ネットワーク一覧を更新")
                        enabled: root.available
                        onClicked: root.onRefresh()
                    }

                    // Wi-Fi トグル
                    ToggleSwitch {
                        id: wifiToggle
                        anchors.verticalCenter: parent.verticalCenter
                        checked: root.wifiEnabled
                        enabled: root.available
                        onToggled: root.onToggleWifi()
                    }
                }
            }
        }

        // --- 現在の接続カード -------------------------------------------------
        Item {
            id: currentConnectionCard
            width: parent.width
            visible: root.available && root.wifiEnabled

            GlassCard {
                anchors.fill: parent
                padding: 16
                radius: Theme.cardRadius

                Column {
                    width: parent.width
                    spacing: 12

                    // ヘッダー行: ラベル + 状態バッジ
                    Row {
                        width: parent.width
                        spacing: 12

                        Text {
                            text: qsTr("現在の接続")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontPixelSize
                            font.weight: Font.Medium
                            color: Theme.textColor
                        }

                        // 状態バッジ
                        Rectangle {
                            id: stateBadge
                            height: 22
                            radius: 11
                            color: root.activeSsid ? Theme.accent : Theme.textMuted
                            opacity: 0.2
                            padding: 0

                            Text {
                                anchors.centerIn: parent
                                text: root.stateText(root.state)
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPixelSizeCaption
                                color: root.activeSsid ? Theme.accent : Theme.textMuted
                                padding: 0
                                leftPadding: 10
                                rightPadding: 10
                            }
                        }
                    }

                    // 接続情報 (接続中の場合)
                    Item {
                        id: connectionInfo
                        width: parent.width
                        visible: root.activeSsid.length > 0

                        Column {
                            width: parent.width
                            spacing: 8

                            // SSID 行
                            Row {
                                width: parent.width
                                spacing: 12

                                Image {
                                    source: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24'><path fill='%237FB8B0' d='M12 4.5C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5c-1.73-4.39-6-7.5-11-7.5zM12 17c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5zm0-8c-1.66 0-3 1.34-3 3s1.34 3 3 3 3-1.34 3-3-1.34-3-3-3z'/></svg>"
                                    width: 24
                                    height: 24
                                    fillMode: Image.PreserveAspectFit
                                    color: Theme.accentSoft
                                }

                                Column {
                                    width: parent.width - 36
                                    spacing: 2

                                    Text {
                                        text: root.activeSsid
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontPixelSizeTitle
                                        font.weight: Font.DemiBold
                                        color: Theme.textColor
                                        elide: Text.ElideRight
                                    }

                                    Row {
                                        spacing: 12

                                        // 信号強度バー
                                        Item {
                                            id: signalBarsItem
                                            width: 60
                                            height: 16

                                            Row {
                                                anchors.centerIn: parent
                                                spacing: 2

                                                Repeater {
                                                    model: 4
                                                    delegate: Rectangle {
                                                        width: 4
                                                        height: parent.height * (index + 1) / 4
                                                        radius: 2
                                                        color: index < root.signalBars(root.signalStrength)
                                                            ? root.signalColor(root.signalStrength)
                                                            : Qt.rgba(Theme.textMutedColor.r, Theme.textMutedColor.g, Theme.textMutedColor.b, 0.15)
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            text: "%1%".arg(root.signalStrength)
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontPixelSizeCaption
                                            color: Theme.textMuted
                                        }

                                        // セキュリティアイコン (既知ネットワークの場合は lock 表示)
                                        Image {
                                            source: root.securityIcon(
                                                (function() {
                                                    for (let i = 0; i < root.networkList.length; ++i) {
                                                        if (root.networkList[i].ssid === root.activeSsid) {
                                                            return root.networkList[i].secured
                                                        }
                                                    }
                                                    return false
                                                })()
                                            )
                                            width: 16
                                            height: 16
                                            fillMode: Image.PreserveAspectFit
                                            color: Theme.textMuted
                                        }
                                    }
                                }
                            }

                            // 切断ボタン
                            Row {
                                width: parent.width
                                spacing: 8

                                IconButton {
                                    iconSource: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='18' height='18'><path fill='%23E8F4F2' d='M14.59 8L12 10.59 9.41 8 8 9.41 10.59 12 8 14.59 9.41 16 12 13.41 14.59 16 16 14.59 13.41 12 16 9.41 14.59 8zM12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8z'/></svg>"
                                    iconSize: 18
                                    buttonSize: 36
                                    tooltipText: qsTr("切断")
                                    enabled: root.available
                                    onClicked: root.onDisconnect()
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: qsTr("このネットワークから切断")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontPixelSizeCaption
                                    color: Theme.textMuted
                                }
                            }
                        }
                    }

                    // 未接続時のメッセージ
                    Item {
                        width: parent.width
                        visible: root.activeSsid.length === 0 && root.wifiEnabled

                        GlassCard {
                            anchors.fill: parent
                            padding: 16
                            radius: Theme.cardRadius

                            Row {
                                anchors.centerIn: parent
                                spacing: 12

                                Image {
                                    source: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24'><path fill='%237FB8B0' d='M12 4.5C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5c-1.73-4.39-6-7.5-11-7.5zM12 17c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5zm0-8c-1.66 0-3 1.34-3 3s1.34 3 3 3 3-1.34 3-3-1.34-3-3-3z'/></svg>"
                                    width: 24
                                    height: 24
                                    fillMode: Image.PreserveAspectFit
                                    color: Theme.textMuted
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: qsTr("Wi-Fi ネットワークに接続されていません")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontPixelSize
                                    color: Theme.textMuted
                                }
                            }
                        }
                    }

                    // Wi-Fi 無効時のメッセージ
                    Item {
                        width: parent.width
                        visible: !root.wifiEnabled

                        GlassCard {
                            anchors.fill: parent
                            padding: 16
                            radius: Theme.cardRadius

                            Row {
                                anchors.centerIn: parent
                                spacing: 12

                                Image {
                                    source: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24'><path fill='%237FB8B0' d='M12 4.5C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5c-1.73-4.39-6-7.5-11-7.5zM12 17c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5zm0-8c-1.66 0-3 1.34-3 3s1.34 3 3 3 3-1.34 3-3-1.34-3-3-3zm0 14c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5z'/></svg>"
                                    width: 24
                                    height: 24
                                    fillMode: Image.PreserveAspectFit
                                    color: Theme.textMuted
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: qsTr("Wi-Fi が無効です。上部のトグルで有効にしてください。")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontPixelSize
                                    color: Theme.textMuted
                                }
                            }
                        }
                    }
                }
            }
        }

        // --- ネットワーク一覧 -------------------------------------------------
        Item {
            id: networkListSection
            width: parent.width
            Layout.fillHeight: true
            visible: root.available && root.wifiEnabled

            Column {
                width: parent.width
                spacing: 8

                // セクションヘッダー
                Row {
                    width: parent.width
                    height: 28
                    spacing: 12

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("利用可能なネットワーク")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPixelSize
                        font.weight: Font.Medium
                        color: Theme.textColor
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("%1 件").arg(root.networkList.length)
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPixelSizeCaption
                        color: Theme.textMuted
                    }
                }

                // リスト (スクロール可能)
                Flickable {
                    width: parent.width
                    height: parent.height - 36
                    clip: true
                    flickableDirection: Flickable.VerticalFlick
                    boundsBehavior: Flickable.DragOverBounds
                    contentHeight: networkListView.implicitHeight + 8

                    ListView {
                        id: networkListView
                        width: parent.width
                        spacing: 4
                        model: root.networkList
                        clip: true

                        delegate: NetworkListDelegate {
                            required property var modelData
                            width: ListView.view.width

                            // このアイテムが現在接続中か
                            property bool isConnected: modelData.ssid === root.activeSsid

                            ssid: modelData.ssid
                            strength: modelData.strength
                            secured: modelData.secured
                            onConnect: root.onConnectSsid(modelData.ssid)
                            onDisconnect: root.onDisconnect()
                        }
                    }
                }
            }
        }

        // --- 利用不可時のフォールバックカード ---------------------------------
        Item {
            id: unavailableCard
            width: parent.width
            Layout.fillHeight: true
            visible: !root.available || !root.wifiEnabled

            GlassCard {
                anchors.fill: parent
                padding: 24
                radius: Theme.cardRadius

                Column {
                    anchors.centerIn: parent
                    spacing: 12

                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        source: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='48' height='48'><path fill='%237FB8B0' d='M12 4.5C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5c-1.73-4.39-6-7.5-11-7.5zM12 17c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5zm0-8c-1.66 0-3 1.34-3 3s1.34 3 3 3 3-1.34 3-3-1.34-3-3-3z'/></svg>"
                        color: Theme.accentSoft
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: !root.available
                            ? qsTr("NetworkManager 未検出")
                            : qsTr("Wi-Fi が無効です")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPixelSize
                        font.weight: Font.DemiBold
                        color: Theme.textColor
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: !root.available
                            ? qsTr("NetworkManager DBus インターフェースが見つかりません。\nNetworkManager がインストール・実行されているか確認してください。")
                            : qsTr("上部のトグルで Wi-Fi を有効にするとネットワーク一覧が表示されます。")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPixelSizeCaption
                        color: Theme.textMuted
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }
}