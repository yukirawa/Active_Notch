pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import dev.yukirawa.activenotch

// Settings — 設定ページ (Phase 7)。
//
// 4 セクション構成:
//   1. 一般 (言語 / アンカー / 全画面退避 / DND)
//   2. 外観 (アクセント色 / 不透明度 / ブラー / ジオメトリ)
//   3. 動作 (各種更新間隔 / 履歴最大件数)
//   4. 詳細 (リセット / バージョン表示)
// ConfigService プロパティと双方向バインディングし、即時反映する。
Item {
    id: root
    width: parent ? parent.width : 604
    height: parent ? parent.height : 380

    // ---- スクロール可能なコンテンツ -----------------------------------------
    Flickable {
        id: scrollView
        anchors.fill: parent
        contentHeight: Math.max(height, contentColumn.implicitHeight + Theme.panelPadding * 2)
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        // 縦スクロールバー (細いアクセント色)
        ScrollBar.vertical: ScrollBar {
            width: 6
            policy: ScrollBar.AsNeeded
            background: Item { }
            contentItem: Rectangle {
                radius: 3
                color: Theme.accent
                opacity: 0.5
            }
        }

        Column {
            id: contentColumn
            x: Theme.panelPadding
            y: Theme.panelPadding
            width: scrollView.width - Theme.panelPadding * 2
            spacing: 16

            // =================================================================
            // セクション 1: 一般
            // =================================================================
            ControlSection {
                id: generalSection
                width: parent.width
                title: qsTr("一般")
                subtitle: qsTr("基本動作と言語設定")
                iconSource: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24'><path fill='%237FB8B0' d='M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 17h-2v-2h2v2zm2.07-7.75l-.9.92C13.45 12.9 13 13.5 13 15h-2v-.5c0-1.1.45-2.1 1.17-2.83l1.24-1.24c.37-.36.59-.86.59-1.41 0-1.1-.9-2-2-2s-2 .9-2 2H8c0-2.21 1.79-4 4-4s4 1.79 4 4c0 .88-.36 1.68-.93 2.25z'/></svg>"

                Column {
                    width: parent.width
                    spacing: 12

                    // --- 言語 ---
                    Row {
                        width: parent.width
                        spacing: 16

                        // ラベル
                        Column {
                            width: 140
                            spacing: 2

                            Text {
                                text: qsTr("言語")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPixelSize
                                font.weight: Font.Medium
                                color: Theme.textColor
                            }

                            Text {
                                text: qsTr("インターフェースの表示言語")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPixelSizeCaption
                                color: Theme.textMuted
                            }
                        }

                        // コントロール
                        ComboBox {
                            id: languageCombo
                            width: 180
                            model: ["ja", "en"]
                            Binding {
                                target: languageCombo
                                property: "currentText"
                                value: Config.language
                                restoreMode: Binding.RestoreNone
                            }
                            onActivated: function(index, value) {
                                Config.language = String(value)
                                Config.save()
                            }
                        }
                    }

                    // --- アンカー位置 ---
                    Row {
                        width: parent.width
                        spacing: 16

                        Column {
                            width: 140
                            spacing: 2

                            Text {
                                text: qsTr("アンカー位置")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPixelSize
                                font.weight: Font.Medium
                                color: Theme.textColor
                            }

                            Text {
                                text: qsTr("画面上端でのノッチ配置")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPixelSizeCaption
                                color: Theme.textMuted
                            }
                        }

                        ComboBox {
                            id: anchorCombo
                            width: 180
                            model: ["top", "top-left", "top-right"]
                            Binding {
                                target: anchorCombo
                                property: "currentText"
                                value: Config.anchor
                                restoreMode: Binding.RestoreNone
                            }
                            onActivated: function(index, value) {
                                Config.anchor = String(value)
                                Config.save()
                            }
                        }
                    }

                    // --- 全画面時自動退避 ---
                    ToggleRow {
                        width: parent.width
                        iconSource: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24'><path fill='%237FB8B0' d='M5 5h14v14H5V5zm12 12H7V7h10v10z'/></svg>"
                        labelText: qsTr("全画面時自動退避")
                        descriptionText: qsTr("全画面アプリ起動時にノッチを自動で隠す")
                        checked: Config.autoHideFullscreen
                        onToggled: function(newState) {
                            Config.autoHideFullscreen = newState
                            Config.save()
                        }
                    }

                    // --- DND (通知を非表示) ---
                    ToggleRow {
                        width: parent.width
                        iconSource: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24'><path fill='%237FB8B0' d='M12 2C6.5 2 2 6.5 2 12s4.5 10 10 10 10-4.5 10-10S17.5 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8zm5-8h-2.5V8c0-1.93-1.57-3.5-3.5-3.5S8.5 6.07 8.5 8V12H6c-.55 0-1 .45-1 1s.45 1 1 1h1v4c0 .55.45 1 1 1s1-.45 1-1v-4h1c.55 0 1-.45 1-1s-.45-1-1-1zm-5 2c0 .55-.45 1-1 1H8c-.55 0-1-.45-1-1v-4c0-.55.45-1 1-1h3c.55 0 1 .45 1 1v4z'/></svg>"
                        labelText: qsTr("通知を非表示 (DND)")
                        descriptionText: qsTr("すべての通知を一時的にミュートする")
                        checked: Config.dnd
                        onToggled: function(newState) {
                            Config.dnd = newState
                            Config.save()
                            // NotificationService と同期 (Q_INVOKABLE setDnd)
                            if (typeof NotificationService !== "undefined") {
                                NotificationService.setDnd(newState)
                            }
                        }
                    }
                }
            }

            // =================================================================
            // セクション 2: 外観
            // =================================================================
            ControlSection {
                id: appearanceSection
                width: parent.width
                title: qsTr("外観")
                subtitle: qsTr("色・透明度・形状・ブラー効果")
                iconSource: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24'><path fill='%237FB8B0' d='M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 3.84c1.42 0 2.72.54 3.68 1.44L12 10.56 8.32 8.64C9.28 7.74 10.58 7.2 12 7.2zm0 1.92c-1.98 0-3.6 1.62-3.6 3.6s1.62 3.6 3.6 3.6 3.6-1.62 3.6-3.6-1.62-3.6-3.6-3.6zm0 12.48c-3.48 0-6.48-2.4-7.2-5.76h1.44c.72 2.16 2.64 3.84 4.56 3.84s3.84-1.68 4.56-3.84h1.44c-.72 3.36-3.72 5.76-7.2 5.76z'/></svg>"

                Column {
                    width: parent.width
                    spacing: 12

                    // --- アクセント色 ---
                    Column {
                        width: parent.width
                        spacing: 8

                        Row {
                            width: parent.width
                            spacing: 16

                            Column {
                                width: 140
                                spacing: 2

                                Text {
                                    text: qsTr("アクセント色")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontPixelSize
                                    font.weight: Font.Medium
                                    color: Theme.textColor
                                }

                                Text {
                                    text: qsTr("UI の強調色 (プリセットから選択)")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontPixelSizeCaption
                                    color: Theme.textMuted
                                }
                            }

                            // 現在の色プレビュー
                            Rectangle {
                                width: 40
                                height: 36
                                radius: 8
                                color: Config.accentColor
                                border.width: Theme.borderWidth
                                border.color: Theme.cardBorderGlow
                            }
                        }

                        // プリセットパレット
                        ColorPalette {
                            id: colorPalette
                            width: parent.width
                            height: Math.ceil(presets.length / columns) * swatchSize
                                + Math.max(0, Math.ceil(presets.length / columns) - 1) * spacing
                            currentColor: Config.accentColor
                            onColorSelected: function(newColor) {
                                Config.accentColor = newColor
                                Config.save()
                            }
                        }
                    }

                    // --- 不透明度 ---
                    Row {
                        width: parent.width
                        spacing: 16

                        Column {
                            width: 140
                            spacing: 2

                            Text {
                                text: qsTr("不透明度")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPixelSize
                                font.weight: Font.Medium
                                color: Theme.textColor
                            }

                            Text {
                                text: qsTr("ノッチ全体の透明度 (0-1)")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPixelSizeCaption
                                color: Theme.textMuted
                            }
                        }

                        SliderControl {
                            id: opacitySlider
                            width: 280
                            Binding {
                                target: opacitySlider
                                property: "value"
                                value: Config.opacity * 100
                                restoreMode: Binding.RestoreNone
                            }
                            minValue: 30
                            maxValue: 100
                            step: 1
                            suffix: "%"
                            onValueChanged: {
                                if (Math.abs(value - Config.opacity * 100) > 0.5) {
                                    Config.opacity = value / 100
                                    Config.save()
                                }
                            }
                        }
                    }

                    // --- ブラー有効 ---
                    ToggleRow {
                        width: parent.width
                        iconSource: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24'><path fill='%237FB8B0' d='M12 5.5c-3.03 0-5.5 2.47-5.5 5.5s2.47 5.5 5.5 5.5 5.5-2.47 5.5-5.5-2.47-5.5-5.5-5.5zm0 9c-1.93 0-3.5-1.57-3.5-3.5s1.57-3.5 3.5-3.5 3.5 1.57 3.5 3.5-1.57 3.5-3.5 3.5zm0-11c-.83 0-1.5.67-1.5 1.5S11.17 6 12 6s1.5-.67 1.5-1.5S12.83 3 12 3z'/></svg>"
                        labelText: qsTr("ブラー効果")
                        descriptionText: qsTr("背景のすりガラス効果を有効にする (KWin 対応必須)")
                        checked: Config.blurEnabled
                        onToggled: function(newState) {
                            Config.blurEnabled = newState
                            Config.save()
                        }
                    }

                    // --- ジオメトリ: 折りたたみ/展開サイズ ---
                    Column {
                        width: parent.width
                        spacing: 8

                        Row {
                            width: parent.width
                            spacing: 16

                            Column {
                                width: 140
                                spacing: 2

                                Text {
                                    text: qsTr("折りたたみサイズ")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontPixelSize
                                    font.weight: Font.Medium
                                    color: Theme.textColor
                                }

                                Text {
                                    text: qsTr("ピル状態の幅と高さ")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontPixelSizeCaption
                                    color: Theme.textMuted
                                }
                            }

                            Row {
                                spacing: 8
                                SpinBox {
                                    id: collapsedWidthSpin
                                    width: 100
                                    Binding {
                                        target: collapsedWidthSpin
                                        property: "value"
                                        value: Config.collapsedWidth
                                        restoreMode: Binding.RestoreNone
                                    }
                                    minValue: 120
                                    maxValue: 400
                                    step: 10
                                    suffix: "px"
                                    onValueChanged: {
                                        if (value !== Config.collapsedWidth) {
                                            Config.collapsedWidth = value
                                            Config.save()
                                        }
                                    }
                                }
                                SpinBox {
                                    id: collapsedHeightSpin
                                    width: 100
                                    Binding {
                                        target: collapsedHeightSpin
                                        property: "value"
                                        value: Config.collapsedHeight
                                        restoreMode: Binding.RestoreNone
                                    }
                                    minValue: 24
                                    maxValue: 60
                                    step: 1
                                    suffix: "px"
                                    onValueChanged: {
                                        if (value !== Config.collapsedHeight) {
                                            Config.collapsedHeight = value
                                            Config.save()
                                        }
                                    }
                                }
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: 16

                            Column {
                                width: 140
                                spacing: 2

                                Text {
                                    text: qsTr("展開サイズ")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontPixelSize
                                    font.weight: Font.Medium
                                    color: Theme.textColor
                                }

                                Text {
                                    text: qsTr("パネル展開時の幅と高さ")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontPixelSizeCaption
                                    color: Theme.textMuted
                                }
                            }

                            Row {
                                spacing: 8
                                SpinBox {
                                    id: expandedWidthSpin
                                    width: 100
                                    Binding {
                                        target: expandedWidthSpin
                                        property: "value"
                                        value: Config.expandedWidth
                                        restoreMode: Binding.RestoreNone
                                    }
                                    minValue: 400
                                    maxValue: 1000
                                    step: 20
                                    suffix: "px"
                                    onValueChanged: {
                                        if (value !== Config.expandedWidth) {
                                            Config.expandedWidth = value
                                            Config.save()
                                        }
                                    }
                                }
                                SpinBox {
                                    id: expandedHeightSpin
                                    width: 100
                                    Binding {
                                        target: expandedHeightSpin
                                        property: "value"
                                        value: Config.expandedHeight
                                        restoreMode: Binding.RestoreNone
                                    }
                                    minValue: 300
                                    maxValue: 800
                                    step: 20
                                    suffix: "px"
                                    onValueChanged: {
                                        if (value !== Config.expandedHeight) {
                                            Config.expandedHeight = value
                                            Config.save()
                                        }
                                    }
                                }
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: 16

                            Column {
                                width: 140
                                spacing: 2

                                Text {
                                    text: qsTr("折りたたみ角丸")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontPixelSize
                                    font.weight: Font.Medium
                                    color: Theme.textColor
                                }

                                Text {
                                    text: qsTr("ピル状態の下側角丸半径")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontPixelSizeCaption
                                    color: Theme.textMuted
                                }
                            }

                            SpinBox {
                                id: radiusCollapsedSpin
                                width: 100
                                Binding {
                                    target: radiusCollapsedSpin
                                    property: "value"
                                    value: Config.radiusCollapsed
                                    restoreMode: Binding.RestoreNone
                                }
                                minValue: 8
                                maxValue: 40
                                step: 1
                                suffix: "px"
                                onValueChanged: {
                                    if (value !== Config.radiusCollapsed) {
                                        Config.radiusCollapsed = value
                                        Config.save()
                                    }
                                }
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: 16

                            Column {
                                width: 140
                                spacing: 2

                                Text {
                                    text: qsTr("展開角丸")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontPixelSize
                                    font.weight: Font.Medium
                                    color: Theme.textColor
                                }

                                Text {
                                    text: qsTr("展開パネルの角丸半径")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontPixelSizeCaption
                                    color: Theme.textMuted
                                }
                            }

                            SpinBox {
                                id: radiusExpandedSpin
                                width: 100
                                Binding {
                                    target: radiusExpandedSpin
                                    property: "value"
                                    value: Config.radiusExpanded
                                    restoreMode: Binding.RestoreNone
                                }
                                minValue: 12
                                maxValue: 60
                                step: 1
                                suffix: "px"
                                onValueChanged: {
                                    if (value !== Config.radiusExpanded) {
                                        Config.radiusExpanded = value
                                        Config.save()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // =================================================================
            // セクション 3: 動作
            // =================================================================
            ControlSection {
                id: behaviorSection
                width: parent.width
                title: qsTr("動作")
                subtitle: qsTr("更新間隔と履歴設定")
                iconSource: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24'><path fill='%237FB8B0' d='M11.99 2C6.47 2 2 6.48 2 12s4.47 10 9.99 10C17.52 22 22 17.52 22 12S17.52 2 11.99 2zM12 20c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8zm.5-13H11v6l5.25 3.15.75-1.23-4.5-2.67z'/></svg>"

                Column {
                    width: parent.width
                    spacing: 12

                    // --- 統計更新間隔 ---
                    Row {
                        width: parent.width
                        spacing: 16

                        Column {
                            width: 140
                            spacing: 2

                            Text {
                                text: qsTr("統計更新間隔")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPixelSize
                                font.weight: Font.Medium
                                color: Theme.textColor
                            }

                            Text {
                                text: qsTr("CPU/メモリ/GPU 等の取得頻度")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPixelSizeCaption
                                color: Theme.textMuted
                            }
                        }

                        ComboBox {
                            id: statsIntervalCombo
                            width: 180
                            model: [
                                { text: qsTr("500 ms"), value: 500 },
                                { text: qsTr("1 秒"), value: 1000 },
                                { text: qsTr("2 秒"), value: 2000 },
                                { text: qsTr("5 秒"), value: 5000 }
                            ]
                            displayRole: "text"
                            valueRole: "value"
                            Binding {
                                target: statsIntervalCombo
                                property: "currentValue"
                                value: Config.statsInterval
                                restoreMode: Binding.RestoreNone
                            }
                            onActivated: function(index, value) {
                                Config.statsInterval = value
                                Config.save()
                            }
                        }
                    }

                    // --- バッテリー更新間隔 ---
                    Row {
                        width: parent.width
                        spacing: 16

                        Column {
                            width: 140
                            spacing: 2

                            Text {
                                text: qsTr("バッテリー更新間隔")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPixelSize
                                font.weight: Font.Medium
                                color: Theme.textColor
                            }

                            Text {
                                text: qsTr("バッテリー残量・状態の取得頻度")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPixelSizeCaption
                                color: Theme.textMuted
                            }
                        }

                        ComboBox {
                            id: batteryIntervalCombo
                            width: 180
                            model: [
                                { text: qsTr("10 秒"), value: 10000 },
                                { text: qsTr("30 秒"), value: 30000 },
                                { text: qsTr("60 秒"), value: 60000 }
                            ]
                            displayRole: "text"
                            valueRole: "value"
                            Binding {
                                target: batteryIntervalCombo
                                property: "currentValue"
                                value: Config.batteryInterval
                                restoreMode: Binding.RestoreNone
                            }
                            onActivated: function(index, value) {
                                Config.batteryInterval = value
                                Config.save()
                            }
                        }
                    }

                    // --- 天気更新間隔 ---
                    Row {
                        width: parent.width
                        spacing: 16

                        Column {
                            width: 140
                            spacing: 2

                            Text {
                                text: qsTr("天気更新間隔")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPixelSize
                                font.weight: Font.Medium
                                color: Theme.textColor
                            }

                            Text {
                                text: qsTr("天気予報データの取得頻度")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPixelSizeCaption
                                color: Theme.textMuted
                            }
                        }

                        ComboBox {
                            id: weatherIntervalCombo
                            width: 180
                            model: [
                                { text: qsTr("5 分"), value: 300000 },
                                { text: qsTr("15 分"), value: 900000 },
                                { text: qsTr("30 分"), value: 1800000 },
                                { text: qsTr("1 時間"), value: 3600000 }
                            ]
                            displayRole: "text"
                            valueRole: "value"
                            Binding {
                                target: weatherIntervalCombo
                                property: "currentValue"
                                value: Config.weatherInterval
                                restoreMode: Binding.RestoreNone
                            }
                            onActivated: function(index, value) {
                                Config.weatherInterval = value
                                Config.save()
                            }
                        }
                    }

                    // --- 通知履歴最大件数 ---
                    Row {
                        width: parent.width
                        spacing: 16

                        Column {
                            width: 140
                            spacing: 2

                            Text {
                                text: qsTr("通知履歴最大件数")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPixelSize
                                font.weight: Font.Medium
                                color: Theme.textColor
                            }

                            Text {
                                text: qsTr("保持する通知履歴の上限")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPixelSizeCaption
                                color: Theme.textMuted
                            }
                        }

                        SpinBox {
                            id: maxHistorySpin
                            width: 120
                            Binding {
                                target: maxHistorySpin
                                property: "value"
                                value: Config.maxHistory
                                restoreMode: Binding.RestoreNone
                            }
                            minValue: 10
                            maxValue: 500
                            step: 10
                            suffix: qsTr(" 件")
                            onValueChanged: {
                                if (value !== Config.maxHistory) {
                                    Config.maxHistory = value
                                    Config.save()
                                }
                            }
                        }
                    }
                }
            }

            // =================================================================
            // セクション 4: 詳細
            // =================================================================
            ControlSection {
                id: advancedSection
                width: parent.width
                title: qsTr("詳細")
                subtitle: qsTr("リセットとバージョン情報")
                iconSource: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24'><path fill='%237FB8B0' d='M19.14 12.94c.04-.31.06-.63.06-.94 0-.31-.02-.63-.06-.94l2.03-1.58c.18-.14.23-.41.12-.61l-1.92-3.32c-.12-.22-.37-.29-.59-.22l-2.39.96c-.5-.38-1.03-.7-1.62-.94l-.36-2.54c-.04-.24-.24-.41-.48-.41h-3.84c-.24 0-.43.17-.47.41l-.36 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96c-.22-.08-.47 0-.59.22L2.74 8.87c-.12.21-.08.47.12.61l2.03 1.58c-.04.31-.06.63-.06.94s.02.63.06.94l-2.03 1.58c-.18.14-.23.41-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32c.12-.22.07-.47-.12-.61l-2.01-1.58zM12 15.6c-1.98 0-3.6-1.62-3.6-3.6s1.62-3.6 3.6-3.6 3.6 1.62 3.6 3.6-1.62 3.6-3.6 3.6z'/></svg>"

                Column {
                    width: parent.width
                    spacing: 12

                    // --- 設定リセット ---
                    Row {
                        width: parent.width
                        spacing: 16

                        Column {
                            width: 140
                            spacing: 2

                            Text {
                                text: qsTr("設定リセット")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPixelSize
                                font.weight: Font.Medium
                                color: Theme.textColor
                            }

                            Text {
                                text: qsTr("すべての設定を既定値に戻す")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPixelSizeCaption
                                color: Theme.textMuted
                            }
                        }

                        Button {
                            id: resetButton
                            width: 140
                            text: qsTr("リセット")
                            primary: true
                            destructive: true
                            onClicked: root.showResetDialog()
                        }
                    }

                    // --- バージョン表示 ---
                    Row {
                        width: parent.width
                        spacing: 16

                        Column {
                            width: 140
                            spacing: 2

                            Text {
                                text: qsTr("バージョン")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPixelSize
                                font.weight: Font.Medium
                                color: Theme.textColor
                            }

                            Text {
                                text: qsTr("ActiveNotch の現在のバージョン")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPixelSizeCaption
                                color: Theme.textMuted
                            }
                        }

                        Text {
                            id: versionLabel
                            anchors.verticalCenter: parent.verticalCenter
                            text: Theme.appVersion
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontPixelSize
                            font.weight: Font.Medium
                            color: Theme.accentSoft
                        }
                    }
                }
            }

            // 下部余白
            Item { width: parent.width; height: Theme.panelPadding }
        }
    }

    // ---- リセット確認ダイアログ ---------------------------------------------
    function showResetDialog() {
        resetDialog.open()
    }

    Dialog {
        id: resetDialog
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel
        title: qsTr("設定をリセットしますか？")

        // カスタムコンテンツ
        contentItem: Column {
            spacing: 12
            width: 360

            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: qsTr("すべての設定 (一般・外観・動作) が既定値に戻ります。この操作は元に戻せません。")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPixelSize
                color: Theme.textColor
            }

            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: qsTr("続行しますか？")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPixelSize
                font.weight: Font.DemiBold
                color: Theme.accentSoft
            }
        }

        // スタイリング
        background: Rectangle {
            radius: Theme.cardRadius
            color: Theme.panelBg
            border.width: Theme.borderWidth
            border.color: Theme.borderGlow
        }

        onAccepted: {
            Config.resetToDefaults()
            Config.save()
            // UI 即時反映のためプロパティ再読み込みを促す
            // (Binding 経由で自動更新されるため追加コード不要)
        }
    }
}