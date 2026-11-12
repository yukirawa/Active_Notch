pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import dev.yukirawa.activenotch

// Launcher — アプリランチャー & 簡易計算ページ (Phase 6)
//
// LauncherService から検索結果を取得し、リスト表示する。
// 入力ごとに search() を呼出 (デバウンス 100ms)。
// 結果: アイコン/名前/コメント/スコア/タイプ(アプリ/計算)
// 計算結果の場合: "= 42" 形式で表示、Enter でコピー
// アプリ選択で launch()
// available=false 時「KService 未検出」表示
Item {
    id: root
    width: parent ? parent.width : 604
    height: parent ? parent.height : 380

    // ---- 内部状態 ---------------------------------------------------------------
    property string searchText: ""
    property var results: []
    property bool loading: false
    property int selectedIndex: -1
    property bool showCalculation: false
    property string calculationResult: ""

    // デバウンスタイマー (100ms)
    Timer {
        id: debounceTimer
        interval: 100
        repeat: false
        onTriggered: performSearch()
    }

    // ---- ヘルパー: サービスプロパティ/メソッドの安全な取得 ---------------------
    function getServiceProp(propName, defaultValue) {
        if (typeof LauncherService !== "undefined" && LauncherService[propName] !== undefined) {
            return LauncherService[propName]
        }
        return defaultValue
    }

    function callServiceMethod(methodName, ...args) {
        if (typeof LauncherService !== "undefined" && LauncherService[methodName]) {
            return LauncherService[methodName](...args)
        }
        return undefined
    }

    // ---- 検索実行 ---------------------------------------------------------------
    function performSearch() {
        const query = root.searchText.trim()
        if (query.length === 0) {
            root.results = []
            root.showCalculation = false
            root.calculationResult = ""
            root.selectedIndex = -1
            return
        }

        root.loading = true
        // LauncherService.search(query) は同期的に結果を返す想定
        // (C++ 側で非同期ならシグナル経由で結果が来る)
        const result = callServiceMethod("search", query)
        if (result !== undefined) {
            // 結果は QVariantList: [{name, icon, comment, desktopFile, score, type}]
            root.results = result
        } else {
            root.results = []
        }
        root.loading = false

        // 計算結果の検出 (type === "calc")
        root.showCalculation = false
        root.calculationResult = ""
        for (let i = 0; i < root.results.length; ++i) {
            if (root.results[i].type === "calc") {
                root.showCalculation = true
                root.calculationResult = root.results[i].comment // "= 42" 形式想定
                break
            }
        }
        root.selectedIndex = 0
    }

    // ---- 検索テキスト変更ハンドラ -----------------------------------------------
    function onSearchTextChanged(text) {
        root.searchText = text
        root.debounceTimer.restart()
    }

    // ---- 結果選択/起動 ----------------------------------------------------------
    function activateSelected() {
        if (root.selectedIndex < 0 || root.selectedIndex >= root.results.length) return
        const item = root.results[root.selectedIndex]
        if (item.type === "calc") {
            // 計算結果をクリップボードにコピー
            if (typeof ClipboardService !== "undefined" && ClipboardService.copy) {
                ClipboardService.copy(item.comment.replace(/^=\s*/, ""))
            }
        } else if (item.type === "app" && item.desktopFile) {
            callServiceMethod("launch", item.desktopFile)
            // アプリ起動後はユーザーが Esc または外側クリックで閉じる想定
            // (Notch への直接アクセスは C++ 側で管理されるためここでは呼ばない)
        }
    }

    // ---- キーボードナビゲーション ------------------------------------------------
    function handleKeyEvent(key, modifiers) {
        switch (key) {
        case Qt.Key_Down:
            if (root.selectedIndex < root.results.length - 1) {
                root.selectedIndex++
            }
            return true
        case Qt.Key_Up:
            if (root.selectedIndex > 0) {
                root.selectedIndex--
            }
            return true
        case Qt.Key_Return:
        case Qt.Key_Enter:
            root.activateSelected()
            return true
        case Qt.Key_Escape:
            root.searchText = ""
            root.results = []
            root.selectedIndex = -1
            return true
        }
        return false
    }

    // ---- レイアウト -------------------------------------------------------------
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
                text: qsTr("アプリランチャー")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPixelSizeTitle
                font.weight: Font.DemiBold
                color: Theme.textColor
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("アプリ検索・簡易計算 (Esc で閉じる)")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPixelSizeCaption
                color: Theme.textMuted
            }
        }

        // 検索バー
        GlassCard {
            width: parent.width
            padding: 12
            radius: Theme.cardRadius

            Row {
                anchors.fill: parent
                spacing: 10

                // 検索アイコン
                Image {
                    width: 20
                    height: 20
                    anchors.verticalCenter: parent.verticalCenter
                    source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='20' height='20'><path fill='%239FB8B4' d='M15.5 14h-.79l-.28-.27C15.41 12.59 16 11.11 16 9.5 16 5.91 13.09 3 9.5 3S3 5.91 3 9.5 5.91 16 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z'/>"
                }

                // 入力フィールド
                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    anchors.leftMargin: 0
                    anchors.rightMargin: 0
                    anchors.verticalCenter: parent.verticalCenter
                    focus: true
                    color: Theme.textColor
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPixelSize
                    placeholderText: qsTr("アプリ名を入力、または計算式 (例: 2+3*4)")
                    selectionColor: Theme.accentSoft
                    selectedTextColor: Theme.textColor
                    onTextChanged: root.onSearchTextChanged(text)
                    Keys.onPressed: {
                        if (!root.handleKeyEvent(event.key, event.modifiers)) {
                            event.accepted = false
                        }
                    }
                }

                // クリアボタン (入力があるときのみ)
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.searchText.length > 0
                    iconSource: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='18' height='18'><path fill='%239FB8B4' d='M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z'/>"
                    iconSize: 18
                    tooltipText: qsTr("クリア")
                    onClicked: {
                        searchInput.text = ""
                        searchInput.forceActiveFocus()
                    }
                }
            }
        }

        // ローディング表示
        Item {
            id: loadingIndicator
            width: parent.width
            height: 40
            visible: root.loading && root.results.length === 0

            Row {
                anchors.centerIn: parent
                spacing: 8

                // 簡易スピナー (回転アニメ)
                Image {
                    id: spinner
                    width: 20
                    height: 20
                    source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='20' height='20'><path fill='%237FB8B0' d='M12 4V1L8 5l4 4V6c3.31 0 6 2.69 6 6 0 1.01-.25 1.97-.7 2.8L17.85 21 16.31 19.31C17.24 18.13 17.79 16.68 18 15.18 18 11.03 14.67 7.5 11 7.5c-2.51 0-4.68 1.35-5.77 3.32L6.48 8.4C7.2 6.83 8.46 5.76 10 5.76 11.66 5.76 13 7.1 13 8.76 13 10.03 12.21 11.08 11.03 11.91l-1.42 1.42C9.92 12.98 9.41 12.5 8.85 12.13 7.28 11.19 6 9.38 6 7.5 6 4.46 8.46 2 11.5 2 12.37 2 13.15 2.31 13.84 2.79L13.31 8 11.85 6.5l-.62-.56C10.28 5.57 9.45 5.25 8.56 5.25 5.02 5.25 2 8.27 2 11.81c0 1.63.58 3.12 1.55 4.26L1.48 18 4.13 20.65 6.39 17.4c.44.56.96 1.05 1.54 1.47C8.16 19.8 9.38 20.5 10.71 20.5c1.75 0 3.32-.7 4.5-1.81l2.55 2.55 3.47-3.47-4.72-4.72c-.83.44-1.72.7-2.65.7-3.87 0-7-3.13-7-7s3.13-7 7-7c1.4 0 2.66.52 3.63 1.38L16.74 6.27 18 4.99 16 3l-4 4z'/>"
                    RotationAnimation on rotation {
                        running: loadingIndicator.visible
                        from: 0
                        to: 360
                        duration: 800
                        loops: Animation.Infinite
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("検索中...")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPixelSize
                    color: Theme.textMuted
                }
            }
        }

        // 結果リスト
        ListView {
            id: resultList
            width: parent.width
            height: parent.height - 44 - 60 - 8 // ヘッダー + 検索バー + 余白
            clip: true
            model: root.results
            spacing: 2
            visible: !root.loading || root.results.length > 0
            currentIndex: root.selectedIndex
            highlightFollowsCurrentItem: true
            highlight: Rectangle {
                color: Theme.accentSoft
                opacity: 0.15
                radius: 8
                y: resultList.currentItem ? resultList.currentItem.y : 0
                height: resultList.currentItem ? resultList.currentItem.height : 0
                width: parent.width
                Behavior on y { SpringAnimation { mass: Theme.springMass; spring: Theme.springSpring; damping: Theme.springDamping } }
            }

            delegate: Item {
                id: delegateItem
                width: ListView.view.width
                height: 56
                property bool isSelected: ListView.isCurrentItem

                GlassCard {
                    anchors.fill: parent
                    anchors.margins: 4
                    padding: 10
                    radius: 8

                    Row {
                        anchors.fill: parent
                        spacing: 12

                        // アイコン
                        Image {
                            id: itemIcon
                            width: 36
                            height: 36
                            anchors.verticalCenter: parent.verticalCenter
                            source: modelData.icon || "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='36' height='36'><path fill='%237FB8B0' d='M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z'/>"
                            fillMode: Image.PreserveAspectFit
                            color: modelData.type === "calc" ? Theme.accent : Theme.textColor
                        }

                        // テキスト情報
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 36 - 12 - 80 // アイコン + スペース + スコア幅
                            spacing: 2

                            Text {
                                width: parent.width
                                text: modelData.name
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPixelSize
                                font.weight: Font.DemiBold
                                color: delegateItem.isSelected ? Theme.textColor : Theme.textColor
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: modelData.comment || ""
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPixelSizeCaption
                                color: modelData.type === "calc" ? Theme.accent : Theme.textMuted
                                elide: Text.ElideRight
                            }
                        }

                        // スコア/タイプ表示
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            spacing: 2

                            Text {
                                text: modelData.type === "calc" ? qsTr("計算") : qsTr("アプリ")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPixelSizeCaption
                                color: modelData.type === "calc" ? Theme.accent : Theme.textMuted
                                horizontalAlignment: Text.AlignRight
                            }

                            Text {
                                visible: modelData.score !== undefined && modelData.type === "app"
                                text: (modelData.score * 100).toFixed(0) + "%"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPixelSizeCaption
                                color: Theme.textMuted
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: resultList.currentIndex = index
                    onClicked: {
                        resultList.currentIndex = index
                        root.activateSelected()
                    }
                }
            }
        }

        // 空状態 / エラー表示
        Item {
            id: emptyState
            width: parent.width
            height: parent.height - 44 - 60 - 8
            visible: !root.loading && root.results.length === 0 && root.searchText.length > 0

            GlassCard {
                anchors.fill: parent
                anchors.margins: 4
                padding: 24
                radius: Theme.cardRadius

                Column {
                    anchors.centerIn: parent
                    spacing: 8

                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 48
                        height: 48
                        source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='48' height='48'><path fill='%237FB8B0' d='M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z'/>"
                        opacity: 0.5
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("一致する結果がありません")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPixelSize
                        font.weight: Font.DemiBold
                        color: Theme.textColor
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("別のキーワードで検索してみてください")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPixelSizeCaption
                        color: Theme.textMuted
                    }
                }
            }
        }

        // 初期状態 (検索前)
        Item {
            id: initialState
            width: parent.width
            height: parent.height - 44 - 60 - 8
            visible: !root.loading && root.results.length === 0 && root.searchText.length === 0

            GlassCard {
                anchors.fill: parent
                anchors.margins: 4
                padding: 24
                radius: Theme.cardRadius

                Column {
                    anchors.centerIn: parent
                    spacing: 12

                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 64
                        height: 64
                        source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%237FB8B0' d='M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8zm-1-13h2v6h-2zm0 8h2v2h-2z'/>"
                        opacity: 0.4
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("アプリを検索、または計算式を入力")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPixelSize
                        font.weight: Font.DemiBold
                        color: Theme.textColor
                    }

                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 6

                        Row {
                            spacing: 8
                            Text { text: qsTr("例:"); font.family: Theme.fontFamily; font.pixelSize: Theme.fontPixelSizeCaption; color: Theme.textMuted }
                            Text { text: "firefox"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontPixelSizeCaption; color: Theme.accent; font.weight: Font.DemiBold }
                        }
                        Row {
                            spacing: 8
                            Text { text: qsTr("例:"); font.family: Theme.fontFamily; font.pixelSize: Theme.fontPixelSizeCaption; color: Theme.textMuted }
                            Text { text: "2 + 3 * 4"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontPixelSizeCaption; color: Theme.accent; font.weight: Font.DemiBold }
                        }
                        Row {
                            spacing: 8
                            Text { text: qsTr("例:"); font.family: Theme.fontFamily; font.pixelSize: Theme.fontPixelSizeCaption; color: Theme.textMuted }
                            Text { text: "sqrt(16)"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontPixelSizeCaption; color: Theme.accent; font.weight: Font.DemiBold }
                        }
                    }
                }
            }
        }

        // サービス未利用時のフォールバック
        Item {
            id: unavailableNotice
            width: parent.width
            height: parent.height - 44 - 60 - 8
            visible: !root.getServiceProp("available", false)

            GlassCard {
                anchors.fill: parent
                anchors.margins: 4
                padding: 24
                radius: Theme.cardRadius

                Row {
                    anchors.centerIn: parent
                    spacing: 12

                    Image {
                        width: 32
                        height: 32
                        source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='32' height='32'><path fill='%237FB8B0' d='M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z'/>"
                        color: Theme.accentSoft
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: qsTr("アプリランチャー機能は現在利用できません")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontPixelSize
                            font.weight: Font.DemiBold
                            color: Theme.textColor
                        }

                        Text {
                            text: qsTr("KService (KF6::Service) が検出されませんでした")
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