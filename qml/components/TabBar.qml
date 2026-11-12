pragma ComponentBehavior: Bound
import QtQuick
import dev.yukirawa.activenotch

// TabBar — 展開パネル上部のナビゲーションタブバー。
//
// 各ページに対応するタブを水平に並べ、現在選択中のタブを強調表示する。
// GlassCard と同様に Theme トークン経由でスタイリングする。
// アイコンは SVG data URI で埋め込み (外部依存なし)。
//
// タブは 12 個あり、利用可能幅は 660 - Theme.panelPadding*2 = 604px。
// アイコンのみのコンパクトタブ (最大 44px) を均等割りで並べることで
// はみ出し・重なりを防ぐ。幅の計算根拠は tabWidth のコメント参照。
Item {
    id: root

    // ---- 公開 API -----------------------------------------------------------
    // tabs: [{ pageId: string, icon: string, label: string, tooltip: string }]
    property var tabs: []

    // 現在選択中の pageId (双方向バインディング想定)
    property string currentPage: ""

    // タブクリック時のコールバック (pageId を引数に受け取る)
    signal tabClicked(string pageId)

    // 内部状態
    property real indicatorX: 0
    property real indicatorWidth: 0

    // ---- レイアウト定数 ------------------------------------------------------
    readonly property real tabHeight: 40
    // 1 タブ内の左右余白 (アイコンは中央寄せなので実質の見た目余白)
    readonly property real tabPadding: 12
    readonly property real iconSize: 18
    readonly property real spacing: 4
    // 1 タブ幅の上限: アイコン 18 + 左右余白 12*2 = 42 → 44 に丸める。
    // 12 タブ時: 44*12 + 4*11 = 528 + 44 = 572px ≤ 604px (余り 32px)。
    readonly property real maxTabWidth: 44
    // 極端に幅が狭い場合の下限 (アイコン 18px は必ず収まる)。
    readonly property real minTabWidth: 30

    // タブ群が使える幅 (左右に tabPadding を確保)
    readonly property real availableWidth: Math.max(0, root.width - root.tabPadding * 2)

    // 1 タブ幅: 均等割りし、[minTabWidth, maxTabWidth] にクランプする。
    // width 未確定 (0) の間は上限幅で計算しておく。
    readonly property real tabWidth: {
        const n = root.tabs ? root.tabs.length : 0
        if (n <= 0 || root.width <= 0)
            return root.maxTabWidth
        const fit = (root.availableWidth - root.spacing * (n - 1)) / n
        return Math.max(root.minTabWidth, Math.min(root.maxTabWidth, fit))
    }

    // タブ群の総幅 (中央寄せのため Row の幅として使用)
    readonly property real contentWidth: {
        const n = root.tabs ? root.tabs.length : 0
        if (n <= 0)
            return 0
        return n * root.tabWidth + (n - 1) * root.spacing
    }

    // 親の ColumnLayout が幅を管理する。ここで width を親幅にバインドすると
    // tabWidth → contentWidth → implicitWidth → width の循環になるため、
    // implicitWidth は固定値 (展開パネルのコンテンツ幅 604px) にする。
    implicitWidth: 604
    implicitHeight: root.tabHeight

    // ---- インディケータアニメーション ---------------------------------------
    Behavior on indicatorX {
        SpringAnimation {
            mass: Theme.springMass
            spring: Theme.springSpring
            damping: Theme.springDamping
        }
    }
    Behavior on indicatorWidth {
        SpringAnimation {
            mass: Theme.springMass
            spring: Theme.springSpring
            damping: Theme.springDamping
        }
    }

    // ---- 背景: 半透明バー (GlassCard より薄い) -------------------------------
    Rectangle {
        anchors.fill: parent
        radius: 0  // パネル上端に密着させるため角丸なし (clip は親側)
        color: Theme.panelBg
        opacity: 0.5
    }

    // ---- 上端スペキュラ (バー上部の微細なハイライト) -------------------------
    Rectangle {
        width: parent.width
        height: Math.min(Theme.specularHeight, parent.height)
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.specular }
            GradientStop { position: 1.0; color: Theme.specularFade }
        }
    }

    // ---- 選択インディケータ (アクセント色のアンダーライン風) ------------------
    Rectangle {
        id: indicator
        y: root.height - 3
        height: 3
        x: root.indicatorX
        width: root.indicatorWidth
        radius: 1.5
        color: Theme.accent
        opacity: 0.9
        z: 1  // タブのホバー背景より前面に出す
    }

    // ---- タブボタン群 --------------------------------------------------------
    Row {
        id: tabRow
        // 12 タブでも 572px に収まるため横スクロールは不要。中央寄せする。
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: root.contentWidth
        height: root.tabHeight
        spacing: root.spacing

        Repeater {
            model: root.tabs
            delegate: TabButton {
                id: tabBtn
                required property var modelData

                width: root.tabWidth
                height: root.tabHeight
                pageId: modelData.pageId
                iconSource: modelData.icon
                labelText: modelData.label
                tooltipText: modelData.tooltip
                isSelected: modelData.pageId === root.currentPage
                iconSize: root.iconSize
                fontPixelSize: Theme.fontPixelSizeCaption
                tabPadding: root.tabPadding
                onClicked: root.tabClicked(pageId)

                // 選択が切り替わったらインジケータを更新する。
                // (Binding の target/property ではなく解決可能な id 経由で同期)
                onIsSelectedChanged: {
                    if (tabBtn.isSelected)
                        root.syncIndicator(tabBtn)
                }
                // 幅・位置は Row のレイアウト確定後に決まるため、
                // 変化時に再同期して初期フレームのズレを防ぐ。
                onWidthChanged: {
                    if (tabBtn.isSelected)
                        root.syncIndicator(tabBtn)
                }
                onXChanged: {
                    if (tabBtn.isSelected)
                        root.syncIndicator(tabBtn)
                }
            }
        }
    }

    // 初期化: 最初のタブにインディケータを合わせる
    Component.onCompleted: {
        if (tabs.length > 0 && currentPage === "") {
            currentPage = tabs[0].pageId
        }
        // 初回レイアウト完了後にインディケータ位置を設定
        Qt.callLater(updateIndicator)
    }

    // レイアウトやタブ構成が変わったらインジケータを追従させる
    onWidthChanged: Qt.callLater(updateIndicator)
    onTabsChanged: Qt.callLater(updateIndicator)
    onCurrentPageChanged: Qt.callLater(updateIndicator)

    // 個別タブの実測ジオメトリからインジケータを同期する
    function syncIndicator(btn) {
        const inset = 8
        const w = Math.max(0, btn.width - inset)
        root.indicatorWidth = w
        root.indicatorX = tabRow.x + btn.x + (btn.width - w) / 2
    }

    function updateIndicator() {
        for (let i = 0; i < tabRow.children.length; ++i) {
            const btn = tabRow.children[i]
            // Repeater 自身は isSelected を持たないため false 判定で除外される
            if (btn && btn.isSelected === true) {
                syncIndicator(btn)
                return
            }
        }
        root.indicatorWidth = 0
    }
}
