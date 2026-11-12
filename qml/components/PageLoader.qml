pragma ComponentBehavior: Bound
import QtQuick
import dev.yukirawa.activenotch

// PageLoader — ページ動的ロードコンポーネント (Phase 3)。
//
// TabBar から pageId を受け取り、対応する qml/pages/*.qml を Loader で読み込む。
// 事前ロードせず、切り替え時に初回ロードすることで起動を高速化する。
// Loader の sourceComponent または source で動的切り替え。
Item {
    id: root
    width: parent ? parent.width : 604
    height: parent ? parent.height : 320

    // ---- 公開 API -----------------------------------------------------------
    // 現在表示中の pageId (TabBar と双方向バインディング)
    property string currentPage: "quick"

    // ページロード要求 (TabBar から呼び出し)
    function loadPage(pageId) {
        if (root.currentPage !== pageId) {
            root.currentPage = pageId
        }
    }

    // ページ定義マップ: pageId → QML ファイルパス (リソースパス)
    readonly property var pageMap: {
        "quick": "pages/Quick.qml",
        "battery": "pages/Battery.qml",
        "sound": "pages/Sound.qml",
        "calendar": "pages/Calendar.qml",
        "media": "pages/Media.qml",
        "stats": "pages/Stats.qml",
        "network": "pages/Network.qml",
        "weather": "pages/Weather.qml",
        "notifications": "pages/Notifications.qml",
        "clipboard": "pages/Clipboard.qml",
        "launcher": "pages/Launcher.qml",
        "tray": "pages/Tray.qml"
    }

    // ---- Loader: 動的ページ読み込み -----------------------------------------
    Loader {
        id: pageLoader
        anchors.fill: parent
        // sourceComponent で事前定義した Component を切り替える方式
        // (source だと相対パス解決が面倒なため、Component 方式を採用)
        sourceComponent: getPageComponent(root.currentPage)
        asynchronous: true  // 非同期ロードで UI ブロックを避ける

        // ロード完了時の処理
        onStatusChanged: {
            if (pageLoader.status === Loader.Ready) {
                // 必要ならここで初期化コールバックを呼ぶ
            }
        }
    }

    // pageId から Component を取得 (初回アクセス時に Qt.createComponent 相当が走る)
    function getPageComponent(pageId) {
        const path = root.pageMap[pageId]
        if (!path) {
            // 未知の pageId: Quick にフォールバック
            return Qt.resolvedUrl("pages/Quick.qml")
        }
        return Qt.resolvedUrl(path)
    }

    // currentPage 変更時に Loader を切り替え
    onCurrentPageChanged: {
        pageLoader.sourceComponent = getPageComponent(root.currentPage)
    }
}