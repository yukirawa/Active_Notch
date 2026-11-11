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
    property int fontPixelSize: Theme.fontPixelSize
    property color color: Theme.textColor
    property int marqueeSpeed: 40      // px/sec
    property int pauseDuration: 2000   // ms

    // 内部: テキストが幅を超えるかどうか
    readonly property bool needsMarquee: textItem.implicitWidth > marqueeRoot.width

    // スクロールアニメーション用プロパティ
    property real scrollPos: 0
    property bool scrolling: false

    width: parent ? parent.width : 300
    height: fontPixelSize + 4
    clip: true

    Text {
        id: textItem
        x: marqueeRoot.scrollPos
        text: marqueeRoot.text
        font.family: Theme.fontFamily
        font.pixelSize: marqueeRoot.fontPixelSize
        color: marqueeRoot.color
    }

    // テキスト幅測定用の非表示コピー
    Text {
        id: measureText
        visible: false
        text: marqueeRoot.text
        font.family: Theme.fontFamily
        font.pixelSize: marqueeRoot.fontPixelSize
    }

    // マーキーアニメーション
    SequentialAnimation {
        id: marqueeAnim
        running: marqueeRoot.needsMarquee && marqueeRoot.scrolling

        PauseAnimation { duration: marqueeRoot.pauseDuration }

        PropertyAnimation {
            target: marqueeRoot
            property: "scrollPos"
            from: 0
            to: -measureText.implicitWidth
            duration: measureText.implicitWidth / marqueeRoot.marqueeSpeed * 1000
            easing.type: Easing.Linear
        }

        PauseAnimation { duration: marqueeRoot.pauseDuration }

        ScriptAction {
            script: marqueeRoot.scrollPos = 0
        }
    }

    onWidthChanged: {
        if (marqueeRoot.needsMarquee) {
            marqueeRoot.scrolling = true
            marqueeAnim.restart()
        } else {
            marqueeRoot.scrolling = false
            marqueeRoot.scrollPos = 0
        }
    }

    onTextChanged: {
        if (marqueeRoot.needsMarquee) {
            marqueeRoot.scrolling = true
            marqueeAnim.restart()
        } else {
            marqueeRoot.scrolling = false
            marqueeRoot.scrollPos = 0
        }
    }

    Component.onCompleted: {
        if (marqueeRoot.needsMarquee) {
            marqueeRoot.scrolling = true
            marqueeAnim.start()
        }
    }
}