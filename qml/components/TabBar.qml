pragma ComponentBehavior: Bound
import QtQuick
import dev.yukirawa.activenotch

// TabBar — 展開パネル上部のナビゲーションタブバー。
//
// 各ページに対応するタブを水平に並べ、現在選択中のタブを強調表示する。
// GlassCard と同様に Theme トークン経由でスタイリングする。
// アイコンは SVG data URI で埋め込み (外部依存なし)。
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

    // レイアウト定数
    readonly property real tabHeight: 40
    readonly property real tabMinWidth: 80
    readonly property real tabPadding: 16
    readonly property real iconSize: 18
    readonly property real spacing: 4

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
    }

    // ---- タブボタン群 --------------------------------------------------------
    Row {
        id: tabRow
        anchors.fill: parent
        anchors.leftMargin: root.tabPadding
        anchors.rightMargin: root.tabPadding
        spacing: root.spacing

        // タブ幅の自動計算: 等幅またはコンテンツ幅の大きい方
        Repeater {
            model: root.tabs
            delegate: TabButton {
                required property var modelData
                width: Math.max(root.tabMinWidth, labelText.implicitWidth + iconItem.implicitWidth + root.tabPadding * 2 + root.spacing)
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

                // 選択時のインディケータ位置更新 (onClicked では遅いため Binding で追従)
                Binding {
                    target: root
                    property: "indicatorX"
                    value: tabBtn.x + (tabBtn.width - root.indicatorWidth) / 2
                    when: tabBtn.isSelected
                }
                Binding {
                    target: root
                    property: "indicatorWidth"
                    value: tabBtn.width - root.tabPadding
                    when: tabBtn.isSelected
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
        updateIndicator()
    }

    function updateIndicator() {
        for (let i = 0; i < tabRow.children.length; ++i) {
            const btn = tabRow.children[i]
            if (btn.pageId === currentPage) {
                indicatorX = btn.x + (btn.width - indicatorWidth) / 2
                indicatorWidth = btn.width - tabPadding
                break
            }
        }
    }

    onCurrentPageChanged: updateIndicator()
}