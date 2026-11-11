pragma ComponentBehavior: Bound
import QtQuick

// ActiveNotch ノッチ本体 (Phase 1): 状態機械 + 外殻 + 開閉アニメーション。
//
// 構造契約 (docs/CONTRACT.md §2 / C++ が依存):
//   root Item (objectName "notch", anchors.fill: parent = 全ウィンドウ 660x448)
//   ├── pinCatcher … pinned 中のみ有効な全ウィンドウ MouseArea (shape より下)。
//   │                ノッチ外クリック = unpin → collapse
//   ├── shape       … モーフする本体。x/y/width/height/radius を SpringAnimation
//   │   ├── dropShadow … 多層ソフトシャドウ (Theme.shadowLayers)
//   │   ├── background … Phase 0 の 5 層構造 (上側オーバーハング + clip で
//   │   │                上辺フラット・下側角丸)。shape.radius に追従
//   │   └── content    … collapsed: 時計テキスト / expanded: placeholder パネル
//   │                    (時差フェード + 下方向スライド)
//   └── (shapeArea … shape 内の MouseArea。hover/click で状態機械を駆動)
//
// ウィンドウ自体は C++ 側で 660x448 論理px 固定。QML 内部のジオメトリのみ
// アニメーションする (layer-shell リサイズのジャンク回避)。
Item {
    id: root

    objectName: "notch"  // C++ が findChild<QQuickItem*>("notch") で取得する
    anchors.fill: parent // 全ウィンドウ (660x448) を覆う。pinCatcher のため必須

    // ======================================================================
    // 公開 API (C++ が結線する。名前・シグネチャ変更禁止)
    // ======================================================================

    // 状態機械: "collapsed" | "expanded" | "pinned"
    property string notchState: "collapsed"

    // pinned のみ true。C++ はこれで layer-shell の keyboard interactivity を切替
    readonly property bool wantsKeyboardFocus: notchState === "pinned"

    // 入力領域マスク用シグネチャ。Main ルート基準 (= ルート Item 基準) の論理px。
    // 起動時 1 回 + モーフアニメ完了ごとに、「到達目標」のジオメトリを渡す
    // (アニメ残渣がマスクに混入しないための仕様)。
    signal shapeSettled(real x, real y, real w, real h, real radius)

    // 全画面退避 (C++ の FullscreenDetector / NotchWindow.fullscreenActive)。
    // typeof ガードは C++ 侧の実装が並行中でも起動できるようにするためのもの。
    readonly property bool fullscreenActive: typeof NotchWindow !== "undefined"
        ? NotchWindow.fullscreenActive : false
    // 将来 Config (autoHideFullscreen) 化するため独立プロパティにしてある
    readonly property bool autoHideFullscreen: true
    readonly property bool hiddenByFullscreen: autoHideFullscreen && fullscreenActive

    // ======================================================================
    // 状態機械 (PLAN §6)
    //   Collapsed --hover--> Expanded --click--> Pinned
    //      ▲   └──(leave: 猶予 Theme.hoverGraceMs 後)──┘
    //      └──(leave / 外側クリック / Esc / 再クリック)──┘
    // ======================================================================
    readonly property bool open: notchState !== "collapsed"

    // --- ターゲットジオメトリ (shape の到達目標。shapeSettled もこれを渡す) ---
    readonly property real targetWidth: open ? Theme.expandedWidth : Theme.collapsedWidth
    readonly property real targetHeight: open ? Theme.expandedHeight : Theme.collapsedHeight
    readonly property real targetX: (width - targetWidth) / 2
    readonly property real targetY: open ? Theme.expandedTopMargin : 0
    readonly property real targetRadius: open ? Theme.radiusExpanded : Theme.radiusCollapsed

    // モーフ完了検出: ターゲットが変わったら pending を立て、全スプリングが
    // 停止した時点で shapeSettled を発火する。
    readonly property string targetGeomKey: targetX.toFixed(3) + "," + targetY.toFixed(3)
        + "," + targetWidth.toFixed(3) + "," + targetHeight.toFixed(3)
        + "," + targetRadius.toFixed(3)
    property bool morphPending: false
    onTargetGeomKeyChanged: morphPending = true

    // x/y/width/height/radius の 5 スプリングがすべて停止しているか
    readonly property bool morphing: xSpring.running || ySpring.running
        || wSpring.running || hSpring.running || rSpring.running
    onMorphingChanged: {
        if (!morphing && morphPending) {
            morphPending = false
            root.emitSettled()
        }
    }

    // --- 公開メソッド (日本語コメント必須) ---------------------------------
    function expand() {
        // Collapsed → Expanded (hover 由来)
        if (notchState === "collapsed") notchState = "expanded"
    }

    function pin() {
        // Expanded → Pinned (クリック固定)
        if (notchState !== "pinned") notchState = "pinned"
    }

    function collapse() {
        // Pinned 解除 / 展開収納 → Collapsed
        leaveGraceTimer.stop()
        notchState = "collapsed"
    }

    // マスク更新用の発火 (到達目標ジオメトリを渡す)
    function emitSettled() {
        root.shapeSettled(targetX, targetY, targetWidth, targetHeight, targetRadius)
    }

    Component.onCompleted: emitSettled()  // 起動時 1 回 (collapsed ジオメトリ)

    // ======================================================================
    // 時計 (collapsed: HH:mm / expanded: HH:mm:ss + 日本語の日付)
    // 日付・曜日は qsTr 不要 (QLocale 相当を JS で処理する仕様)
    // ======================================================================
    property string timeText: ""
    property string timeSecondsText: ""
    property string dateText: ""

    function updateClock() {
        const now = new Date()
        root.timeText = Qt.formatDateTime(now, "hh:mm")
        root.timeSecondsText = Qt.formatDateTime(now, "hh:mm:ss")
        const wd = ["日", "月", "火", "水", "木", "金", "土"]
        root.dateText = Qt.formatDate(now, "yyyy年M月d日") + " (" + wd[now.getDay()] + ")"
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.updateClock()
    }

    // ======================================================================
    // ホバー離脱の猶予タイマー (展開 → 折りたたみのチラつき防止)
    // 猶予中に再ホバーしたら onEntered で停止する
    // ======================================================================
    Timer {
        id: leaveGraceTimer
        interval: Theme.hoverGraceMs
        onTriggered: {
            if (root.notchState === "expanded" && !shapeArea.containsMouse)
                root.collapse()
        }
    }

    // ======================================================================
    // pinCatcher: pinned 中の「ノッチ外クリック」を受け取る全面 MouseArea
    // (C++ が pinned 中はマスクを全ウィンドウに広げるため、shape 外の
    //  クリックがここへ届く。z は shape より下)
    // ======================================================================
    MouseArea {
        id: pinCatcher
        anchors.fill: parent
        enabled: root.notchState === "pinned" && !root.hiddenByFullscreen
        visible: enabled
        onClicked: root.collapse()  // unpin → collapse
    }

    // ======================================================================
    // shape: モーフする本体
    // ======================================================================
    Item {
        id: shape
        z: 1  // pinCatcher より上

        x: root.targetX
        y: root.targetY + (root.hiddenByFullscreen ? -height : 0)
        width: root.targetWidth
        height: root.targetHeight

        // 角丸半径 (Rectangle にはないので shape 側で持ち、下層が参照する)
        property real radius: root.targetRadius

        opacity: root.hiddenByFullscreen ? 0 : 1

        // --- 形状モーフ: SpringAnimation (パラメータは Theme トークン) -------
        Behavior on x { SpringAnimation { id: xSpring; mass: Theme.springMass; spring: Theme.springSpring; damping: Theme.springDamping } }
        Behavior on y { SpringAnimation { id: ySpring; mass: Theme.springMass; spring: Theme.springSpring; damping: Theme.springDamping } }
        Behavior on width { SpringAnimation { id: wSpring; mass: Theme.springMass; spring: Theme.springSpring; damping: Theme.springDamping } }
        Behavior on height { SpringAnimation { id: hSpring; mass: Theme.springMass; spring: Theme.springSpring; damping: Theme.springDamping } }
        Behavior on radius { SpringAnimation { id: rSpring; mass: Theme.springMass; spring: Theme.springSpring; damping: Theme.springDamping } }

        // 全画面退避: shape を y 方向に -高さ 分スライド (ウィンドウ外へは出さず
        // クリップで隠れる) + opacity フェード。false で復帰。
        Behavior on opacity {
            NumberAnimation { duration: Theme.fullscreenFadeMs; easing.type: Easing.OutCubic }
        }

        // ------------------------------------------------------------------
        // dropShadow: 多層ソフトシャドウ。
        // QtQuick 標準のみで描くため「透過角丸矩形 + 太 border」のリングを
        // 複数層重ねる (border は外周から内側に spread 分描かれるため、
        // shape 外周に沿った帯になる)。折りたたみ時は余白があるため
        // 全層が見え、展開時はパネルがウィンドウ一杯になるため自然に窓外へ消える。
        // ------------------------------------------------------------------
        Item {
            id: dropShadow
            anchors.fill: parent

            Repeater {
                model: Theme.shadowLayers

                Rectangle {
                    required property var modelData
                    readonly property real spread: modelData.spread

                    x: -spread
                    y: -spread + modelData.yOffset  // 下方向に沈めて影を強調
                    width: parent.width + spread * 2
                    height: parent.height + spread * 2
                    radius: shape.radius + spread
                    color: "transparent"
                    border.width: spread
                    border.color: Qt.rgba(Theme.shadowColor.r, Theme.shadowColor.g,
                                          Theme.shadowColor.b,
                                          modelData.alpha * Theme.shadowOpacity)
                }
            }
        }

        // ------------------------------------------------------------------
        // background: Phase 0 の 5 層構造を shape のターゲットに一般化。
        // 角丸矩形を上方向に radius 分はみ出させて clip で切ることで
        // 「上辺フラット・下側角丸」を実現 (Phase 0 の技法を流用)。
        // radius はアニメするため overhang / グラデ位置も連動して追従する。
        // ------------------------------------------------------------------
        Item {
            id: background
            anchors.fill: parent
            clip: true

            readonly property real overhang: shape.radius
            readonly property real shapeHeight: shape.height + overhang
            readonly property real visibleTopPos: overhang / shapeHeight

            // 1) ベース: 半透明ダーク
            Rectangle {
                width: parent.width
                height: background.shapeHeight
                y: -background.overhang
                radius: shape.radius
                color: Theme.bgSurface
            }

            // 2) くすみ Frutiger Aero: 淡いアクア → くすみグレーの縦グラデ
            Rectangle {
                width: parent.width
                height: background.shapeHeight
                y: -background.overhang
                radius: shape.radius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.overlayTop }
                    GradientStop { position: background.visibleTopPos; color: Theme.overlayTop }
                    GradientStop { position: 1.0; color: Theme.overlayBottom }
                }
            }

            // 3) 上端スペキュラハイライト (下側コーナー開始位置以内にクランプ)
            Rectangle {
                width: parent.width
                height: Math.min(Theme.specularHeight,
                                 shape.height - shape.radius)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.specular }
                    GradientStop { position: 1.0; color: Theme.specularFade }
                }
            }

            // 4) 1px の淡い発光ボーダー (左右・下側)
            Rectangle {
                width: parent.width
                height: background.shapeHeight
                y: -background.overhang
                radius: shape.radius
                color: "transparent"
                border.width: Theme.borderWidth
                border.color: Theme.borderGlow
            }

            // 4b) 上端の水平ボーダー (はみ出し矩形の上辺は clip されるため補完)
            Rectangle {
                width: parent.width
                height: Theme.borderWidth
                color: Theme.borderGlow
            }
        }

        // ------------------------------------------------------------------
        // content: 状態ごとの中身。
        //   collapsed: 時計テキスト (Phase 0 の見た目を維持)
        //   expanded : placeholder パネル (Phase 2+ で pages/ の Loader に差し替え)
        // ------------------------------------------------------------------
        Item {
            id: content
            anchors.fill: parent
            clip: true  // モーフ中に中身が shape の外へはみ出すのを防ぐ

            // Esc 受け取り: pinned になった時点で forceActiveFocus する
            // (実際のキーボードフォーカス取得は C++ が keyboardInteractivity を
            //  切替えて行う)。pinned 解除で focus も自動的に外れる。
            focus: root.wantsKeyboardFocus
            Keys.enabled: root.wantsKeyboardFocus
            Keys.onEscapePressed: function(event) {
                event.accepted = true
                root.collapse()
            }

            // --- collapsed: 時計テキスト -----------------------------------
            Text {
                anchors.centerIn: parent
                text: root.timeText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPixelSize
                color: Theme.textColor
                opacity: root.open ? 0 : 1
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }
            }

            // --- expanded: ページナビゲーション + コンテンツ -------------------
            // Phase 3: TabBar + ページスイッチャ構成
            Item {
                id: expandedContent
                anchors.fill: parent
                visible: root.open

                Column {
                    x: Theme.panelPadding
                    y: Theme.panelPadding
                    width: parent.width - Theme.panelPadding * 2
                    spacing: 12

                    // ブロック 0: 大きな時計 + 日本語の日付 (時差フェード)
                    Column {
                        id: clockBlock
                        width: parent.width
                        spacing: 4
                        opacity: root.open ? 1 : 0
                        Behavior on opacity {
                            enabled: root.open
                            SequentialAnimation {
                                PauseAnimation { duration: 0 * Theme.staggerMs }
                                NumberAnimation {
                                    duration: Theme.revealDurationMs
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                        transform: Translate {
                            y: (1.0 - clockBlock.opacity) * Theme.revealSlideDistance
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.timeSecondsText
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontPixelSizeClockLarge
                            font.weight: Font.DemiBold
                            color: Theme.textColor
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.dateText
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontPixelSize
                            color: Theme.textMuted
                        }
                    }

                    // TabBar: ページ切り替えナビゲーション (時差フェード)
                    TabBar {
                        id: tabBar
                        width: parent.width
                        height: 40
                        currentPage: pageLoader.currentPage
                        tabs: [
                            { pageId: "quick", icon: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='18' height='18'><path fill='%23E8F4F2' d='M19.14 12.94c.04-.31.06-.63.06-.94 0-.31-.02-.63-.06-.94l2.03-1.58c.18-.14.23-.41.12-.61l-1.92-3.32c-.12-.22-.37-.29-.59-.22l-2.39.96c-.5-.38-1.03-.7-1.62-.94l-.36-2.54c-.04-.24-.24-.41-.48-.41h-3.84c-.24 0-.43.17-.47.41l-.36 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96c-.22-.08-.47 0-.59.22L2.74 8.87c-.12.21-.08.47.12.61l2.03 1.58c-.04.31-.06.63-.06.94s.02.63.06.94l-2.03 1.58c-.18.14-.23.41-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32c.12-.22.07-.47-.12-.61l-2.01-1.58zM12 15.6c-1.98 0-3.6-1.62-3.6-3.6s1.62-3.6 3.6-3.6 3.6 1.62 3.6 3.6-1.62 3.6-3.6 3.6z'/>", label: qsTr("クイック"), tooltip: qsTr("クイック設定") },
                            { pageId: "battery", icon: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='18' height='18'><path fill='%23E8F4F2' d='M15.67 4H14V2h-4v2H8.33C7.6 4 7 4.6 7 5.33V21.67C7 22.4 7.6 23 8.33 23h7.33c.74 0 1.34-.6 1.34-1.33V5.33C17 4.6 16.4 4 15.67 4zM13 18.33l-2.47-2.47c-.23-.23-.61-.23-.84 0L7.33 18.34c-.23.23-.23.61 0 .84l2.47 2.47c.23.23.61.23.84 0l3.67-3.67c.23-.23.23-.61 0-.84l-2.47-2.47z'/>", label: qsTr("バッテリー"), tooltip: qsTr("バッテリー情報") },
                            { pageId: "sound", icon: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='18' height='18'><path fill='%23E8F4F2' d='M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z'/>", label: qsTr("音量"), tooltip: qsTr("音量・輝度") },
                            { pageId: "calendar", icon: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='18' height='18'><path fill='%23E8F4F2' d='M19 3h-1V1h-2v2H8V1H6v2H5c-1.11 0-1.99.9-1.99 2L3 19c0 1.1.89 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm0 16H5V8h14v11z'/>", label: qsTr("カレンダー"), tooltip: qsTr("月間カレンダー") },
                            { pageId: "media", icon: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='18' height='18'><path fill='%23E8F4F2' d='M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z'/>", label: qsTr("メディア"), tooltip: qsTr("メディアコントロール") },
                            { pageId: "stats", icon: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='18' height='18'><path fill='%23E8F4F2' d='M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zM9 17H7v-7h2v7zm4 0h-2V7h2v10zm4 0h-2v-4h2v4z'/>", label: qsTr("統計"), tooltip: qsTr("システム統計") },
                            { pageId: "network", icon: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='18' height='18'><path fill='%23E8F4F2' d='M12 4.5C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5c-1.73-4.39-6-7.5-11-7.5zM12 17c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5zm0-8c-1.66 0-3 1.34-3 3s1.34 3 3 3 3-1.34 3-3-1.34-3-3-3z'/>", label: qsTr("ネットワーク"), tooltip: qsTr("Wi-Fi ネットワーク管理") },
                            { pageId: "weather", icon: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='18' height='18'><path fill='%23E8F4F2' d='M12 2.25c-5.385 0-9.75 4.365-9.75 9.75s4.365 9.75 9.75 9.75 9.75-4.365 9.75-9.75S17.385 2.25 12 2.25zm0 18c-4.553 0-8.25-3.697-8.25-8.25S7.447 5.75 12 5.75s8.25 3.697 8.25 8.25-3.697 8.25-8.25 8.25zM12 8.25a3.75 3.75 0 110 7.5 3.75 3.75 0 010-7.5z'/>", label: qsTr("天気"), tooltip: qsTr("現在の天気と予報") },
                            { pageId: "notifications", icon: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='18' height='18'><path fill='%23E8F4F2' d='M12 22c1.1 0 2-.9 2-2h-4c0 1.1.89 2 2 2zm6-6v-5c0-3.07-1.64-5.64-4.5-6.32V4c0-.83-.67-1.5-1.5-1.5s-1.5.67-1.5 1.5v.68C7.63 5.36 6 7.92 6 11v5l-2 2v1h16v-1l-2-2zm-2 1H8v-5c0-2.48 1.51-4.5 3.5-4.5s3.5 2.02 3.5 4.5v5z'/>", label: qsTr("通知"), tooltip: qsTr("通知履歴・DND") },
                            { pageId: "clipboard", icon: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='18' height='18'><path fill='%23E8F4F2' d='M19 2H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm0 16H5V4h14v14zM14 10V6.5l-4 4 4 4V13h5c.55 0 1 .45 1 1s-.45 1-1 1H9c-.55 0-1-.45-1-1s.45-1 1-1h5z'/>", label: qsTr("クリップボード"), tooltip: qsTr("クリップボード履歴") }
                        ]
                        opacity: root.open ? 1 : 0
                        Behavior on opacity {
                            enabled: root.open
                            SequentialAnimation {
                                PauseAnimation { duration: 1 * Theme.staggerMs }
                                NumberAnimation {
                                    duration: Theme.revealDurationMs
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                        transform: Translate {
                            y: (1.0 - tabBar.opacity) * Theme.revealSlideDistance
                        }
                        onTabClicked: pageLoader.loadPage(pageId)
                    }

                    // ページローダー: 選択されたページを動的ロード (時差フェード)
                    PageLoader {
                        id: pageLoader
                        width: parent.width
                        Layout.fillHeight: true
                        opacity: root.open ? 1 : 0
                        Behavior on opacity {
                            enabled: root.open
                            SequentialAnimation {
                                PauseAnimation { duration: 2 * Theme.staggerMs }
                                NumberAnimation {
                                    duration: Theme.revealDurationMs
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                        transform: Translate {
                            y: (1.0 - pageLoader.opacity) * Theme.revealSlideDistance
                        }
                    }

                    // 操作ヒント (時差フェード)
                    Text {
                        id: hintBlock
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: root.notchState === "pinned"
                              ? qsTr("クリックまたは Esc で閉じます")
                              : qsTr("クリックで固定できます")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPixelSizeCaption
                        color: Theme.textMuted
                        opacity: root.open ? 1 : 0
                        Behavior on opacity {
                            enabled: root.open
                            SequentialAnimation {
                                PauseAnimation { duration: 3 * Theme.staggerMs }
                                NumberAnimation {
                                    duration: Theme.revealDurationMs
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                        transform: Translate {
                            y: (1.0 - hintBlock.opacity) * Theme.revealSlideDistance
                        }
                    }
                }
            }
        }

        // ------------------------------------------------------------------
        // shapeArea: shape 全体の hover / click で状態機械を駆動
        // (最上位に置くことで、コンテンツ上でもクリックを受け取る)
        // ------------------------------------------------------------------
        MouseArea {
            id: shapeArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            enabled: !root.hiddenByFullscreen

            onEntered: {
                leaveGraceTimer.stop()  // 猶予中の再ホバーで收纳をキャンセル
                root.expand()
            }

            onExited: {
                // pinned では離脱しても收纳しない。expanded のときだけ猶予付きで
                if (root.notchState === "expanded")
                    leaveGraceTimer.restart()
            }

            onClicked: {
                if (root.notchState === "pinned") {
                    root.collapse()          // 再クリック = 解除
                } else {
                    root.pin()               // collapsed/expanded → 固定
                }
            }
        }
    }
}
