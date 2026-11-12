pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import dev.yukirawa.activenotch

// Stats — システム統計ページ (Phase 3)。
//
// StatsService から CPU/GPU/RAM/温度/ファン を取得し、
// GaugeCircle コンポーネントで円形ゲージ表示する。
// - 数値は Behavior でスムーズ補間
// - レイアウト: 2列グリッド (狭いパネル内に収める)
// - gpuAvailable=false 時 GPU ゲージ非表示
Item {
    id: root
    // PageLoader が anchors.fill でサイズを与える。parent 依存は循環の原因。
    implicitWidth: 604
    implicitHeight: 380

    // =========================================================================
    // StatsService プロパティ (typeof ガード付き)
    // =========================================================================
    // 注意: StatsService は Phase 3 実装中のため、存在しない場合は全てフォールバック
    readonly property bool available: (typeof StatsService !== "undefined" && StatsService !== null && StatsService.available !== undefined)
        ? StatsService.available
        : false
    readonly property bool gpuAvailable: (typeof StatsService !== "undefined" && StatsService !== null && StatsService.gpuAvailable !== undefined)
        ? StatsService.gpuAvailable
        : false

    // CPU (0-100%)
    readonly property real cpuUsage: (typeof StatsService !== "undefined" && StatsService !== null && StatsService.cpuUsage !== undefined)
        ? StatsService.cpuUsage
        : 0
    readonly property real cpuTemp: (typeof StatsService !== "undefined" && StatsService !== null && StatsService.cpuTemp !== undefined)
        ? StatsService.cpuTemp
        : 0
    readonly property int cpuFanRpm: (typeof StatsService !== "undefined" && StatsService !== null && StatsService.cpuFanRpm !== undefined)
        ? StatsService.cpuFanRpm
        : 0

    // GPU (0-100%)
    readonly property real gpuUsage: (typeof StatsService !== "undefined" && StatsService !== null && StatsService.gpuUsage !== undefined)
        ? StatsService.gpuUsage
        : 0
    readonly property real gpuTemp: (typeof StatsService !== "undefined" && StatsService !== null && StatsService.gpuTemp !== undefined)
        ? StatsService.gpuTemp
        : 0
    readonly property int gpuFanRpm: (typeof StatsService !== "undefined" && StatsService !== null && StatsService.gpuFanRpm !== undefined)
        ? StatsService.gpuFanRpm
        : 0

    // RAM (0-100%, MB単位)
    readonly property real ramUsage: (typeof StatsService !== "undefined" && StatsService !== null && StatsService.ramUsage !== undefined)
        ? StatsService.ramUsage
        : 0
    readonly property int ramUsedMb: (typeof StatsService !== "undefined" && StatsService !== null && StatsService.ramUsedMb !== undefined)
        ? StatsService.ramUsedMb
        : 0
    readonly property int ramTotalMb: (typeof StatsService !== "undefined" && StatsService !== null && StatsService.ramTotalMb !== undefined)
        ? StatsService.ramTotalMb
        : 0

    // =========================================================================
    // 内部アニメーション値 (スムーズ補間用 Behavior)
    // =========================================================================
    property real animatedCpuUsage: root.cpuUsage
    Behavior on animatedCpuUsage { NumberAnimation { duration: 800; easing.type: Easing.OutCubic } }
    onCpuUsageChanged: animatedCpuUsage = cpuUsage

    property real animatedGpuUsage: root.gpuUsage
    Behavior on animatedGpuUsage { NumberAnimation { duration: 800; easing.type: Easing.OutCubic } }
    onGpuUsageChanged: animatedGpuUsage = gpuUsage

    property real animatedRamUsage: root.ramUsage
    Behavior on animatedRamUsage { NumberAnimation { duration: 800; easing.type: Easing.OutCubic } }
    onRamUsageChanged: animatedRamUsage = ramUsage

    property real animatedCpuTemp: root.cpuTemp
    Behavior on animatedCpuTemp { NumberAnimation { duration: 1000; easing.type: Easing.OutCubic } }
    onCpuTempChanged: animatedCpuTemp = cpuTemp

    property real animatedGpuTemp: root.gpuTemp
    Behavior on animatedGpuTemp { NumberAnimation { duration: 1000; easing.type: Easing.OutCubic } }
    onGpuTempChanged: animatedGpuTemp = gpuTemp

    // 使用率に応じた色 (緑→黄→赤)
    function usageColor(usage) {
        return usage > 80
            ? "#F44336"   // 赤: 高負荷
            : (usage > 50
                ? "#FFB300"  // アンバー: 中負荷
                : "#4CAF50") // 緑: 低負荷
    }

    // 温度に応じた色 (青→緑→黄→赤)
    function tempColor(temp) {
        return temp > 85
            ? "#F44336"   // 赤: 危険
            : (temp > 70
                ? "#FFB300"  // アンバー: 高温
                : (temp > 50
                    ? "#4CAF50"  // 緑: 正常
                    : "#2196F3")) // 青: 低温
    }

    // RPM フォーマット
    function formatRpm(rpm) {
        if (rpm <= 0) return qsTr("停止")
        if (rpm >= 1000) return "%1k RPM".arg((rpm / 1000).toFixed(1))
        return "%1 RPM".arg(rpm)
    }

    // メモリフォーマット
    function formatMemory(used, total) {
        if (total <= 0) return qsTr("不明")
        if (total >= 1024) {
            return "%1 / %2 GB".arg((used / 1024).toFixed(1)).arg((total / 1024).toFixed(1))
        }
        return "%1 / %2 MB".arg(used).arg(total)
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
                source: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24'><path fill='%237FB8B0' d='M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zM9 17H7v-7h2v7zm4 0h-2V7h2v10zm4 0h-2v-4h2v4z'/></svg>"
                width: 24
                height: 24
                anchors.verticalCenter: parent.verticalCenter
                fillMode: Image.PreserveAspectFit
                opacity: root.available ? 1 : 0.5
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    text: root.available ? qsTr("システム統計") : qsTr("統計情報を取得できません")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPixelSizeTitle
                    font.weight: Font.DemiBold
                    color: root.available ? Theme.textColor : Theme.textMuted
                }

                Text {
                    visible: root.available
                    text: qsTr("リアルタイム ハードウェアモニタリング")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPixelSizeCaption
                    color: Theme.textMuted
                }
            }
        }

        // --- メインコンテンツ -------------------------------------------------
        Item {
            width: parent.width
            // Column 直下では Layout.fillHeight は無効。
            // ヘッダー (36) + spacing (16) を差し引いた高さを明示する。
            height: Math.max(0, parent.height - 52)

            // 利用可能時: ゲージグリッド
            Item {
                id: statsContent
                anchors.fill: parent
                visible: root.available

                // スクロール可能なグリッド (縦長になる可能性があるため Flickable)
                Flickable {
                    anchors.fill: parent
                    contentWidth: parent.width
                    contentHeight: gridLayout.implicitHeight + 20
                    clip: true
                    flickableDirection: Flickable.VerticalFlick
                    boundsBehavior: Flickable.DragOverBounds

                    // 2列グリッドレイアウト
                    GridLayout {
                        id: gridLayout
                        width: parent.width
                        columns: 2
                        rowSpacing: 16
                        columnSpacing: 16

                        // ---- CPU 使用率 ---------------------------------------
                        StatGaugeCard {
                            Layout.fillWidth: true
                            title: qsTr("CPU 使用率")
                            iconSource: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24'><path fill='%237FB8B0' d='M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zM9 17H7v-7h2v7zm4 0h-2V7h2v10zm4 0h-2v-4h2v4z'/></svg>"
                            gaugeValue: root.animatedCpuUsage
                            gaugeMax: 100
                            gaugeColor: root.usageColor(root.animatedCpuUsage)
                            valueText: "%1%".arg(root.animatedCpuUsage.toFixed(1))
                            subText: qsTr("プロセッサ負荷")
                        }

                        // ---- RAM 使用率 ---------------------------------------
                        StatGaugeCard {
                            Layout.fillWidth: true
                            title: qsTr("メモリ使用率")
                            iconSource: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24'><path fill='%237FB8B0' d='M18 2H6c-1.1 0-2 .9-2 2v16c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm0 18H6V4h12v16z'/></svg>"
                            gaugeValue: root.animatedRamUsage
                            gaugeMax: 100
                            gaugeColor: root.usageColor(root.animatedRamUsage)
                            valueText: "%1%".arg(root.animatedRamUsage.toFixed(1))
                            subText: root.formatMemory(root.ramUsedMb, root.ramTotalMb)
                        }

                        // ---- CPU 温度 -----------------------------------------
                        StatGaugeCard {
                            Layout.fillWidth: true
                            title: qsTr("CPU 温度")
                            iconSource: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24'><path fill='%237FB8B0' d='M12 21c-2.67 0-8-1.34-8-4v-7c0-3.27 2.89-6 7.16-6.04A5.97 5.97 0 0112 2c2.32 0 4.54 1.26 5.84 3.11.27.15.56.28.87.39V6h6V4h-4V2h-4v2H8v2h10v2h-2.04c-.72 2.88-3.64 5.35-7.16 5.92A7 7 0 004 14v3c0 2.76 5.44 4 8 4z'/></svg>"
                            gaugeValue: root.animatedCpuTemp
                            gaugeMax: 100  // °C スケール
                            gaugeColor: root.tempColor(root.animatedCpuTemp)
                            valueText: "%1°C".arg(root.animatedCpuTemp.toFixed(1))
                            subText: root.cpuFanRpm > 0
                                ? qsTr("ファン: %1").arg(root.formatRpm(root.cpuFanRpm))
                                : qsTr("ファン情報なし")
                        }

                        // ---- GPU 使用率 (gpuAvailable 時のみ) -------------------
                        StatGaugeCard {
                            Layout.fillWidth: true
                            visible: root.gpuAvailable
                            title: qsTr("GPU 使用率")
                            iconSource: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24'><path fill='%237FB8B0' d='M22 14h-8v4h5.17l-3.54 3.54 1.41 1.41L23.41 14H22zm-4-10h2v8h-2V4zm4 12h-8v-4h5.17L12 9.83 13.41 11 22 2.41V12zM2 14h8v4H6.83l3.54 3.54-1.41 1.41L.59 14H2zM4 4v8H2V4h2zm-2 12h2v-8H2v8z'/></svg>"
                            gaugeValue: root.animatedGpuUsage
                            gaugeMax: 100
                            gaugeColor: root.usageColor(root.animatedGpuUsage)
                            valueText: "%1%".arg(root.animatedGpuUsage.toFixed(1))
                            subText: qsTr("グラフィックス負荷")
                        }

                        // ---- GPU 温度 (gpuAvailable 時のみ) ---------------------
                        StatGaugeCard {
                            Layout.fillWidth: true
                            visible: root.gpuAvailable
                            title: qsTr("GPU 温度")
                            iconSource: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24'><path fill='%237FB8B0' d='M12 21c-2.67 0-8-1.34-8-4v-7c0-3.27 2.89-6 7.16-6.04A5.97 5.97 0 0112 2c2.32 0 4.54 1.26 5.84 3.11.27.15.56.28.87.39V6h6V4h-4V2h-4v2H8v2h10v2h-2.04c-.72 2.88-3.64 5.35-7.16 5.92A7 7 0 004 14v3c0 2.76 5.44 4 8 4z'/></svg>"
                            gaugeValue: root.animatedGpuTemp
                            gaugeMax: 100
                            gaugeColor: root.tempColor(root.animatedGpuTemp)
                            valueText: "%1°C".arg(root.animatedGpuTemp.toFixed(1))
                            subText: root.gpuFanRpm > 0
                                ? qsTr("ファン: %1").arg(root.formatRpm(root.gpuFanRpm))
                                : qsTr("ファン情報なし")
                        }

                        // ---- CPU ファン / 空きスロット -------------------------
                        StatInfoCard {
                            Layout.fillWidth: true
                            title: qsTr("CPU ファン")
                            iconSource: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24'><path fill='%237FB8B0' d='M12 4c-4.42 0-8 3.58-8 8s3.58 8 8 8 8-3.58 8-8-3.58-8-8-8zm0 2c3.31 0 6 2.69 6 6s-2.69 6-6 6-6-2.69-6-6 2.69-6 6-6zm0 10c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4z'/></svg>"
                            valueText: root.cpuFanRpm > 0
                                ? root.formatRpm(root.cpuFanRpm)
                                : qsTr("検出されず")
                            valueColor: root.cpuFanRpm > 0 ? Theme.textColor : Theme.textMuted
                            subText: qsTr("回転数")
                        }

                        // ---- 空きスロット (将来拡張用) -------------------------
                        Item {
                            Layout.fillWidth: true
                            height: 0
                        }
                    }
                }
            }

            // 利用不可時: フォールバック表示
            Item {
                id: unavailableContent
                anchors.fill: parent
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
                            source: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='48' height='48'><path fill='%237FB8B0' d='M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-6h2v6zm0-8h-2V7h2v2z'/></svg>"
                            width: 48
                            height: 48
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: qsTr("システム統計を取得できません")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontPixelSize
                            font.weight: Font.DemiBold
                            color: Theme.textColor
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: qsTr("StatsService (libsysstat / lm-sensors 等) が\n実装されていないか、ハードウェア監視に対応していません。")
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
}