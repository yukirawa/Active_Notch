pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import dev.yukirawa.activenotch

// Quick — クイック設定トグルページ。
//
// QuickSettingsService から Night Light (夜間モード) の状態を取得し、
// トグル行として表示する。Phase 4/5 で Wi-Fi / BT / DND 等が追加される
// ことを想定し、拡張しやすい ListView + Delegate 構造にしている。
Item {
    id: root
    width: parent ? parent.width : 604
    height: parent ? parent.height : 380

    // ---- 内部状態: トグル項目定義 (サービスプロパティ名で紐付け) ------------
    // 将来追加項目はここにオブジェクトを追加するだけで自動的に行が生成される
    readonly property var toggleItems: [
        {
            id: "nightLight",
            icon: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='20' height='20'><path fill='%23E8F4F2' d='M12 7c-2.76 0-5 2.24-5 5s2.24 5 5 5 5-2.24 5-5-2.24-5-5-5zM2 13h2c.55 0 1-.45 1-1s-.45-1-1-1H2c-.55 0-1 .45-1 1s.45 1 1 1zm18 0h2c.55 0 1-.45 1-1s-.45-1-1-1h-2c-.55 0-1 .45-1 1s.45 1 1 1zM11 2v2c0 .55.45 1 1 1s1-.45 1-1V2c0-.55-.45-1-1-1s-1 .45-1 1zm0 18v2c0 .55.45 1 1 1s1-.45 1-1v-2c0-.55-.45-1-1-1s-1 .45-1 1zM5.99 4.58a.996.996 0 00-1.41 0 .996.996 0 000 1.41l1.06 1.06c.39.39 1.03.39 1.41 0s.39-1.03 0-1.41L5.99 4.58zm12.37 12.37a.996.996 0 00-1.41 0 .996.996 0 000 1.41l1.06 1.06c.39.39 1.03.39 1.41 0 .39-.39.39-1.03 0-1.41l-1.06-1.06zm1.06-10.96a.996.996 0 000-1.41.996.996 0 00-1.41 0l-1.06 1.06c-.39.39-.39 1.03 0 1.41s1.03.39 1.41 0l1.06-1.06zM7.05 18.36a.996.996 0 000 1.41.996.996 0 001.41 0l1.06-1.06c.39-.39.39-1.03 0-1.41s-1.03-.39-1.41 0l-1.06 1.06z'/>",
            label: qsTr("夜間モード"),
            description: qsTr("画面の色温度を暖色系に調整します"),
            serviceAvailable: "nightLightAvailable",
            serviceState: "nightLightOn",
            serviceToggle: "toggleNightLight"
        },
        // Phase 4 以降で追加予定の項目プレースホルダ (コメントアウト)
        // {
        //     id: "wifi",
        //     icon: "wifi-icon-svg",
        //     label: qsTr("Wi-Fi"),
        //     description: qsTr("ワイヤレスネットワークのオン/オフ"),
        //     serviceAvailable: "wifiAvailable",
        //     serviceState: "wifiEnabled",
        //     serviceToggle: "toggleWifi"
        // },
        // {
        //     id: "bluetooth",
        //     icon: "bluetooth-icon-svg",
        //     label: qsTr("Bluetooth"),
        //     description: qsTr("Bluetooth デバイスの接続管理"),
        //     serviceAvailable: "bluetoothAvailable",
        //     serviceState: "bluetoothPowered",
        //     serviceToggle: "toggleBluetooth"
        // },
        // {
        //     id: "dnd",
        //     icon: "dnd-icon-svg",
        //     label: qsTr("通知を非表示"),
        //     description: qsTr("すべての通知を一時的にミュート"),
        //     serviceAvailable: "dndAvailable",
        //     serviceState: "dndActive",
        //     serviceToggle: "toggleDnd"
        // }
    ]

    // ---- ヘルパー: サービスプロパティの安全な取得 -----------------------------
    function getServiceProp(propName, defaultValue) {
        if (typeof QuickSettingsService !== "undefined" && QuickSettingsService[propName] !== undefined) {
            return QuickSettingsService[propName]
        }
        return defaultValue
    }

    function callServiceMethod(methodName) {
        if (typeof QuickSettingsService !== "undefined" && QuickSettingsService[methodName]) {
            QuickSettingsService[methodName]()
        }
    }

    // ---- レイアウト -----------------------------------------------------------
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
                text: qsTr("クイック設定")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPixelSizeTitle
                font.weight: Font.DemiBold
                color: Theme.textColor
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("よく使う機能をすぐに切り替え")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPixelSizeCaption
                color: Theme.textMuted
            }
        }

        // トグル行リスト
        ListView {
            width: parent.width
            height: parent.height - 44  // ヘッダー分を除く
            clip: true
            model: root.toggleItems
            spacing: 4

            delegate: ToggleRow {
                required property var modelData
                width: ListView.view.width

                // サービスから状態を取得 (typeof ガード付き)
                property bool itemAvailable: root.getServiceProp(modelData.serviceAvailable, false)
                property bool itemChecked: root.getServiceProp(modelData.serviceState, false)

                iconSource: modelData.icon
                labelText: modelData.label
                descriptionText: modelData.description
                isAvailable: itemAvailable
                checked: itemChecked

                onToggled: {
                    root.callServiceMethod(modelData.serviceToggle)
                }
            }
        }

        // サービス未配線時のフォールバック表示
        Item {
            id: unavailableNotice
            width: parent.width
            height: 60
            visible: !root.getServiceProp("nightLightAvailable", false) && root.toggleItems.length > 0

            GlassCard {
                anchors.fill: parent
                padding: 16
                radius: Theme.cardRadius

                Row {
                    anchors.fill: parent
                    spacing: 12

                    Image {
                        source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='20' height='20'><path fill='%237FB8B0' d='M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z'/>"
                        width: 24
                        height: 24
                        color: Theme.accentSoft
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: qsTr("夜間モード機能は現在利用できません")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontPixelSize
                            font.weight: Font.DemiBold
                            color: Theme.textColor
                        }

                        Text {
                            text: qsTr("KWin の Night Light DBus インターフェースが見つかりません")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontPixelSizeCaption
                            color: Theme.textMuted
                        }
                    }
                }
            }
        }
    }
}