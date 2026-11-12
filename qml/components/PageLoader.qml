pragma ComponentBehavior: Bound
import QtQuick
import dev.yukirawa.activenotch

// PageLoader — ページ動的ロードコンポーネント (Phase 3)。
//
// TabBar から pageId を受け取り、対応する qml/pages/*.qml を Loader で読み込む。
// 事前ロードせず、切り替え時に初回ロードすることで起動を高速化する。
//
// 重要 (Qt 6.12):
//   - Loader.sourceComponent は Component 専用。URL を渡す場合は source を使う。
//     以前 sourceComponent に Qt.resolvedUrl(...) を渡していたため
//     "Unable to assign QUrl to QQmlComponent*" となりページが一切表示されなかった。
//   - ルート Item で parent.width/height にバインドすると、親が Column のとき
//     循環参照 (polish loop) を起こす。サイズは呼び出し側の Layout に委ねる。
Item {
    id: root

    // ---- 公開 API -----------------------------------------------------------
    // 現在表示中の pageId (TabBar と双方向バインディング)
    property string currentPage: "quick"

    // レイアウトに参加しない場合の安全な既定サイズ
    implicitWidth: 604
    implicitHeight: 380

    // ページロード要求 (TabBar から呼び出し)
    function loadPage(pageId) {
        if (root.currentPage !== pageId) {
            root.currentPage = pageId
        }
    }

    // ページ定義マップ: pageId → QML ファイルパス
    // (このファイルは components/ 配下にあるため pages/ へは ../pages/)
    // 値は実際のファイル名 (大文字小文字を厳密に一致させる。
    // Linux の qrc は case-sensitive のため)。
    readonly property var pageMap: {
        "quick": "Quick",
        "battery": "Battery",
        "sound": "Sound",
        "calendar": "Calendar",
        "media": "Media",
        "stats": "Stats",
        "network": "Network",
        "weather": "Weather",
        "notifications": "Notifications",
        "clipboard": "Clipboard",
        "launcher": "Launcher",
        "tray": "Tray",
        "settings": "Settings"
    }

    // ---- Loader: 動的ページ読み込み -----------------------------------------
    Loader {
        id: pageLoader
        anchors.fill: parent
        source: root.getPageSource(root.currentPage)
        asynchronous: true  // 非同期ロードで UI ブロックを避ける

        // ロードされたページを Loader のサイズへ追従させる。
        // ページ側が width/height を固定していても、ここで上書きして
        // パネルいっぱいに表示する (循環しないよう Loader の実寸を参照)。
        onLoaded: {
            if (item) {
                item.width = Qt.binding(function() { return pageLoader.width })
                item.height = Qt.binding(function() { return pageLoader.height })
            }
        }
    }

    // pageId から QML の URL を取得する。
    // 未知の pageId は Quick にフォールバックする。
    function getPageSource(pageId) {
        const name = root.pageMap[pageId]
        if (!name) {
            return Qt.resolvedUrl("../pages/Quick.qml")
        }
        return Qt.resolvedUrl("../pages/" + name + ".qml")
    }

    // currentPage 変更時に Loader を切り替え
    onCurrentPageChanged: {
        pageLoader.source = getPageSource(root.currentPage)
    }
}
