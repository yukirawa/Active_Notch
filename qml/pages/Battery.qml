pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import dev.yukirawa.activenotch

// Battery — バッテリー・電源情報ページ。
//
// BatteryService から取得した残量・充電状態・消費電力・残り時間を表示。
// サービス未配線 (available=false) の場合は「利用不可」表示で graceful に退化。
Item {
    id: root
    width: parent ? parent.width : 604
    height: parent ? parent.height : 380

    // ---- サービスプロパティの安全な取得 (typeof ガード) ----------------------
    readonly property bool available: (typeof BatteryService !== "undefined" && BatteryService.available !== undefined)
        ? BatteryService.available
        : false
    readonly property int percent: (typeof BatteryService !== "undefined" && BatteryService.percent !== undefined)
        ? BatteryService.percent
        : 0
    readonly property bool charging: (typeof BatteryService !== "undefined" && BatteryService.charging !== undefined)
        ? BatteryService.charging
        : false
    readonly property bool plugged: (typeof BatteryService !== "undefined" && BatteryService.plugged !== undefined)
        ? BatteryService.plugged
        : false
    readonly property real powerW: (typeof BatteryService !== "undefined" && BatteryService.powerW !== undefined)
        ? BatteryService.powerW
        : 0
    readonly property string timeRemainingText: (typeof BatteryService !== "undefined" && BatteryService.timeRemainingText !== undefined)
        ? BatteryService.timeRemainingText
        : qsTr("計算中…")

    // ---- 内部状態 ------------------------------------------------------------
    // ゲージアニメーション用の内部値 (スムーズ補間)
    property real animatedPercent: root.percent
    Behavior on animatedPercent {
        NumberAnimation {
            duration: 800
            easing.type: Easing.OutCubic
        }
    }
    onPercentChanged: animatedPercent = percent

    // ---- 計算プロパティ ------------------------------------------------------
    // 残量に応じた色 (緑→黄→赤のグラデーション)
    readonly property color gaugeColor: root.animatedPercent > 60
        ? "#4CAF50"   // 緑
        : (root.animatedPercent > 20
            ? "#FFB300"  // アンバー/黄
            : "#F44336") // 赤
    // アクセント寄りの色 (充電中など)
    readonly property color chargingColor: Theme.accent

    // ---- レイアウト ----------------------------------------------------------
    Column {
        anchors.fill: parent
        anchors.margins: Theme.panelPadding
        spacing: 16

        // --- ヘッダー ---------------------------------------------------------
        Row {
            width: parent.width
            height: 36
            spacing: 12

            // バッテリーアイコン + 状態バッジ
            Item {
                id: headerIcon
                width: 40
                height: 40

                // バッテリー本体アイコン (SVG)
                Image {
                    id: batteryIcon
                    anchors.centerIn: parent
                    width: 36
                    height: 36
                    source: root.charging
                        ? "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='36' height='36'><path fill='%237FB8B0' d='M15.67 4H14V2h-4v2H8.33C7.6 4 7 4.6 7 5.33V21.67C7 22.4 7.6 23 8.33 23h7.33c.74 0 1.34-.6 1.34-1.33V5.33C17 4.6 16.4 4 15.67 4zm-2.67 15.33c-.23.23-.23.61 0 .84l2.47 2.47c.23.23.61.23.84 0l3.67-3.67c.23-.23.23-.61 0-.84l-2.47-2.47c-.23-.23-.61-.23-.84 0L13 17.33z'/>"
                        : "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='36' height='36'><path fill='%23E8F4F2' d='M15.67 4H14V2h-4v2H8.33C7.6 4 7 4.6 7 5.33V21.67C7 22.4 7.6 23 8.33 23h7.33c.74 0 1.34-.6 1.34-1.33V5.33C17 4.6 16.4 4 15.67 4zM13 18.33l-2.47-2.47c-.23-.23-.61-.23-.84 0L7.33 18.34c-.23.23-.23.61 0 .84l2.47 2.47c.23.23.61.23.84 0l3.67-3.67c.23-.23.23-.61 0-.84l-2.47-2.47z'/>"
                    color: root.charging ? Theme.accent : (root.available ? Theme.textColor : Theme.textMuted)
                }

                // 充電中バッジ (小さな稲妻)
                Image {
                    visible: root.charging && root.available
                    anchors.top: parent.top
                    anchors.right: parent.right
                    width: 16
                    height: 16
                    source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='16' height='16'><path fill='%237FB8B0' d='M13 2L3 14h9l-1 8 10-12h-9l1-8z'/>"
                }
            }

            // テキスト情報
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: root.available
                        ? (root.charging ? qsTr("充電中") : qsTr("バッテリー駆動"))
                        : qsTr("バッテリー情報を取得できません")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPixelSizeTitle
                    font.weight: Font.DemiBold
                    color: root.available ? Theme.textColor : Theme.textMuted
                }

                Text {
                    visible: root.available
                    text: root.plugged
                        ? (root.charging
                            ? qsTr("AC 接続中 · %1%").arg(root.percent)
                            : qsTr("AC 接続中 (充電完了) · %1%").arg(root.percent))
                        : qsTr("バッテリー駆動 · %1%").arg(root.percent)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPixelSizeCaption
                    color: Theme.textMuted
                }
            }
        }

        // --- メインゲージ (大型円形プログレス) ---------------------------------
        GaugeCircle {
            id: mainGauge
            width: Math.min(parent.width, 200)
            height: mainGauge.width
            anchors.horizontalCenter: parent.horizontalCenter
            value: root.animatedPercent
            maxValue: 100
            thickness: 10
            trackColor: Qt.rgba(Theme.textMutedColor.r, Theme.textMutedColor.g, Theme.textMutedColor.b, 0.15)
            progressColor: root.charging ? root.chargingColor : root.gaugeColor
            showText: true
            textValue: "%1%".arg(Math.round(root.animatedPercent))
            textColor: Theme.textColor
            textPixelSize: 42
            subText: root.charging
                ? qsTr("充電中")
                : (root.timeRemainingText && root.timeRemainingText !== qsTr("計算中…")
                    ? qsTr("残り %1").arg(root.timeRemainingText)
                    : qsTr("放電中"))
            subTextColor: Theme.textMuted
            subTextPixelSize: Theme.fontPixelSizeCaption
            enabled: root.available
        }

        // --- 詳細情報グリッド (2列) -------------------------------------------
        GridLayout {
            width: parent.width
            columns: 2
            rowSpacing: 12
            columnSpacing: 16

            // 項目 1: 状態
            DetailItem {
                Layout.columnSpan: 1
                Layout.fillWidth: true
                iconSource: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='20' height='20'><path fill='%237FB8B0' d='M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-6h2v6zm0-8h-2V7h2v2z'/>"
                label: qsTr("状態")
                value: root.available
                    ? (root.charging ? qsTr("充電中") : (root.plugged ? qsTr("充電完了 (AC接続)") : qsTr("放電中")))
                    : qsTr("不明")
                valueColor: root.available
                    ? (root.charging ? Theme.accent : (root.plugged ? Theme.textColor : Theme.textMuted))
                    : Theme.textMuted
            }

            // 項目 2: 消費電力
            DetailItem {
                Layout.columnSpan: 1
                Layout.fillWidth: true
                iconSource: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='20' height='20'><path fill='%237FB8B0' d='M13 2L3 14h9l-1 8 10-12h-9l1-8z'/>"
                label: qsTr("消費電力")
                value: root.available && root.powerW > 0
                    ? "%1 W".arg(root.powerW.toFixed(1))
                    : qsTr("測定中…")
                valueColor: root.available ? Theme.textColor : Theme.textMuted
            }

            // 項目 3: 残量
            DetailItem {
                Layout.columnSpan: 1
                Layout.fillWidth: true
                iconSource: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='20' height='20'><path fill='%237FB8B0' d='M15.67 4H14V2h-4v2H8.33C7.6 4 7 4.6 7 5.33V21.67C7 22.4 7.6 23 8.33 23h7.33c.74 0 1.34-.6 1.34-1.33V5.33C17 4.6 16.4 4 15.67 4zM13 18.33l-2.47-2.47c-.23-.23-.61-.23-.84 0L7.33 18.34c-.23.23-.23.61 0 .84l2.47 2.47c.23.23.61.23.84 0l3.67-3.67c.23-.23.23-.61 0-.84l-2.47-2.47z'/>"
                label: qsTr("残量")
                value: root.available ? "%1%".arg(root.percent) : qsTr("不明")
                valueColor: root.available ? Theme.textColor : Theme.textMuted
            }

            // 項目 4: 推定残り時間
            DetailItem {
                Layout.columnSpan: 1
                Layout.fillWidth: true
                iconSource: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='20' height='20'><path fill='%237FB8B0' d='M11.99 2C6.47 2 2 6.48 2 12s4.47 10 9.99 10C17.52 22 22 17.52 22 12S17.52 2 11.99 2zM12 20c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8zm.5-13H11v6l5.25 3.15.75-1.23-4.5-2.67z'/>"
                label: qsTr("推定残り時間")
                value: root.available && root.timeRemainingText
                    ? root.timeRemainingText
                    : qsTr("計算中…")
                valueColor: root.available ? Theme.textColor : Theme.textMuted
            }
        }

        // --- 利用不可時のフォールバックカード ---------------------------------
        Item {
            id: unavailableCard
            width: parent.width
            Layout.fillWidth: true
            visible: !root.available

            GlassCard {
                anchors.fill: parent
                padding: 24
                radius: Theme.cardRadius

                Column {
                    anchors.centerIn: parent
                    spacing: 12

                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='48' height='48'><path fill='%237FB8B0' d='M15.67 4H14V2h-4v2H8.33C7.6 4 7 4.6 7 5.33V21.67C7 22.4 7.6 23 8.33 23h7.33c.74 0 1.34-.6 1.34-1.33V5.33C17 4.6 16.4 4 15.67 4zM13 18.33l-2.47-2.47c-.23-.23-.61-.23-.84 0L7.33 18.34c-.23.23-.23.61 0 .84l2.47 2.47c.23.23.61.23.84 0l3.67-3.67c.23-.23.23-.61 0-.84l-2.47-2.47z'/>"
                        color: Theme.accentSoft
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("バッテリー情報を取得できません")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPixelSize
                        font.weight: Font.DemiBold
                        color: Theme.textColor
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("UPower または /sys/class/power_supply が見つかりません。\nノートPC でない場合、この機能は利用できません。")
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