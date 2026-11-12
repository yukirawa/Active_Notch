pragma ComponentBehavior: Bound
import QtQuick
import dev.yukirawa.activenotch

// MarqueeText — 長いテキストを水平スクロール (マーキー) 表示するヘルパー (Phase 3)。
//
// Media ページのタイトル/アーティスト/アルバム表示で使用。
// テキストが幅を超える場合のみ自動でスクロールアニメーションする。
Item {
    id: marqueeRoot
    property string text: ""
    // Text と同じ font グループを受け付ける (呼び出し側の font.* 指定に対応)。
    property font font: Qt.font({
        family: Theme.fontFamily,
        pixelSize: Theme.fontPixelSize
    })
    property color color: Theme.textColor
    property int marqueeSpeed: 40      // px/sec
    property int pauseDuration: 2000   // ms

    // 旧 API との互換: font.pixelSize と同期する。
    property int fontPixelSize: font.pixelSize
    onFontPixelSizeChanged: {
        if (font.pixelSize !== fontPixelSize) {
            const f = font
            f.pixelSize = fontPixelSize
            font = f
        }
    }

    // 内部: テキストが幅を超えるかどうか
    readonly property bool needsMarquee: marqueeRoot.width > 0
        && textItem.implicitWidth > marqueeRoot.width

    // スクロールアニメーション用プロパティ
    property real scrollPos: 0
    property bool scrolling: false

    width: parent ? parent.width : 300
    implicitHeight: font.pixelSize + 4
    height: implicitHeight
    clip: true

    Text {
        id: textItem
        x: marqueeRoot.scrollPos
        text: marqueeRoot.text
        font: marqueeRoot.font
        color: marqueeRoot.color
    }

    // マーキーアニメーション
    // running は直接バインドせず、状態変化時だけ start/stop する
    // (restart と running バインディングの競合を避ける)。
    SequentialAnimation {
        id: marqueeAnim
        loops: Animation.Infinite
        running: false

        PauseAnimation { duration: Math.max(0, marqueeRoot.pauseDuration) }

        PropertyAnimation {
            target: marqueeRoot
            property: "scrollPos"
            from: 0
            to: -Math.max(1, textItem.implicitWidth)
            duration: Math.max(1000,
                textItem.implicitWidth / Math.max(1, marqueeRoot.marqueeSpeed) * 1000)
            easing.type: Easing.Linear
        }

        PauseAnimation { duration: Math.max(0, marqueeRoot.pauseDuration) }

        ScriptAction {
            script: marqueeRoot.scrollPos = 0
        }
    }

    function startMarquee() {
        if (!needsMarquee || !visible) {
            stopMarquee()
            return
        }
        scrolling = true
        marqueeAnim.restart()
    }

    function stopMarquee() {
        scrolling = false
        marqueeAnim.stop()
        scrollPos = 0
    }

    function refreshMarquee() {
        if (needsMarquee && visible)
            startMarquee()
        else
            stopMarquee()
    }

    onWidthChanged: refreshMarquee()
    onTextChanged: refreshMarquee()
    onFontChanged: refreshMarquee()
    onVisibleChanged: refreshMarquee()
    Component.onCompleted: refreshMarquee()
}
