pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import dev.yukirawa.activenotch

// Media — メディア再生コントロールページ (Phase 3)。
//
// MediaService (MPRIS over DBus) から取得した現在再生中のトラック情報と
// 再生制御ボタンを表示する。
// - アートワーク表示 (artUrl) + タイトル/アーティスト/アルバム (マーキー対応)
// - 再生/停止/前/次/シークバー/音量スライダー
// - プレイヤー名表示 + 複数プレイヤー時の切替 (将来)
// - available=false 時「再生中なし」表示
Item {
    id: root
    width: parent ? parent.width : 604
    height: parent ? parent.height : 380

    // =========================================================================
    // MediaService プロパティ・メソッド (typeof ガード付き)
    // =========================================================================
    readonly property bool available: (typeof MediaService !== "undefined" && MediaService.available !== undefined)
        ? MediaService.available
        : false
    readonly property string title: (typeof MediaService !== "undefined" && MediaService.title !== undefined)
        ? MediaService.title
        : ""
    readonly property string artist: (typeof MediaService !== "undefined" && MediaService.artist !== undefined)
        ? MediaService.artist
        : ""
    readonly property string album: (typeof MediaService !== "undefined" && MediaService.album !== undefined)
        ? MediaService.album
        : ""
    readonly property url artUrl: (typeof MediaService !== "undefined" && MediaService.artUrl !== undefined)
        ? MediaService.artUrl
        : ""
    readonly property bool playing: (typeof MediaService !== "undefined" && MediaService.playing !== undefined)
        ? MediaService.playing
        : false
    readonly property int positionMs: (typeof MediaService !== "undefined" && MediaService.positionMs !== undefined)
        ? MediaService.positionMs
        : 0
    readonly property int lengthMs: (typeof MediaService !== "undefined" && MediaService.lengthMs !== undefined)
        ? MediaService.lengthMs
        : 0
    readonly property bool canControl: (typeof MediaService !== "undefined" && MediaService.canControl !== undefined)
        ? MediaService.canControl
        : false
    readonly property string playerName: (typeof MediaService !== "undefined" && MediaService.playerName !== undefined)
        ? MediaService.playerName
        : qsTr("不明")

    // MediaService メソッド呼び出しヘルパー
    function mediaPlayPause() {
        if (typeof MediaService !== "undefined" && MediaService.playPause) {
            MediaService.playPause()
        }
    }
    function mediaNext() {
        if (typeof MediaService !== "undefined" && MediaService.next) {
            MediaService.next()
        }
    }
    function mediaPrevious() {
        if (typeof MediaService !== "undefined" && MediaService.previous) {
            MediaService.previous()
        }
    }
    function mediaSeek(ms) {
        if (typeof MediaService !== "undefined" && MediaService.seekMs) {
            MediaService.seekMs(ms)
        }
    }
    function mediaSetVolume(v) {
        if (typeof MediaService !== "undefined" && MediaService.setVolumePct) {
            MediaService.setVolumePct(Math.max(0, Math.min(100, Math.round(v))))
        }
    }

    // =========================================================================
    // 内部アニメーション値 (スムーズ補間用)
    // =========================================================================
    property real animatedPosition: root.positionMs
    Behavior on animatedPosition {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }
    onPositionMsChanged: animatedPosition = positionMs

    property int animatedVolume: 50  // デフォルト値、将来 Volume プロパティ追加時に同期
    Behavior on animatedVolume {
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }

    // 経過時間 / 残り時間のフォーマット用ヘルパー
    function formatMs(ms) {
        if (ms <= 0) return "0:00"
        const totalSec = Math.floor(ms / 1000)
        const min = Math.floor(totalSec / 60)
        const sec = totalSec % 60
        return "%1:%2".arg(min).arg(sec.toString().padStart(2, '0'))
    }

    // シークバー用プログレス (0.0-1.0)
    readonly property real seekProgress: root.lengthMs > 0 ? root.animatedPosition / root.lengthMs : 0

    // =========================================================================
    // レイアウト
    // =========================================================================
    Column {
        anchors.fill: parent
        anchors.margins: Theme.panelPadding
        spacing: 16

        // --- ヘッダー: プレイヤー名 -------------------------------------------
        Row {
            width: parent.width
            height: 36
            spacing: 12

            Image {
                id: playerIcon
                source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24'><path fill='%237FB8B0' d='M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z'/>"
                width: 24
                height: 24
                anchors.verticalCenter: parent.verticalCenter
                fillMode: Image.PreserveAspectFit
                color: root.available ? Theme.accentSoft : Theme.textMuted
                opacity: root.available ? 1 : 0.5
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    text: root.available ? qsTr("メディア再生") : qsTr("再生中のメディアがありません")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPixelSizeTitle
                    font.weight: Font.DemiBold
                    color: root.available ? Theme.textColor : Theme.textMuted
                }

                Text {
                    visible: root.available
                    text: root.playerName
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPixelSizeCaption
                    color: Theme.textMuted
                }
            }
        }

        // --- メインコンテンツ -------------------------------------------------
        Item {
            width: parent.width
            Layout.fillHeight: true

            // 利用可能時: メディア情報 + コントロール
            Item {
                id: mediaContent
                anchors.fill: parent
                visible: root.available

                Column {
                    anchors.fill: parent
                    spacing: 16

                    // アートワーク + トラック情報
                    Row {
                        width: parent.width
                        spacing: 16

                        // アートワーク (正方形、角丸)
                        Item {
                            id: artContainer
                            width: 100
                            height: 100

                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                color: Qt.rgba(Theme.bgBase.r, Theme.bgBase.g, Theme.bgBase.b, 0.5)
                                border.width: Theme.borderWidth
                                border.color: Theme.cardBorderGlow

                                // アートワーク画像
                                Image {
                                    id: artworkImg
                                    anchors.fill: parent
                                    source: root.artUrl
                                    fillMode: Image.PreserveAspectCrop
                                    radius: 8
                                    clip: true
                                    // 読み込み中/失敗時のプレースホルダ
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 8
                                        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2)
                                        visible: !artworkImg.source || artworkImg.status === Image.Error
                                        Image {
                                            anchors.centerIn: parent
                                            source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='48' height='48'><path fill='%237FB8B0' d='M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z'/>"
                                            color: Theme.accentSoft
                                            width: 48
                                            height: 48
                                        }
                                    }
                                }
                            }
                        }

                        // トラック情報 (マーキー対応)
                        Column {
                            width: parent.width - 116
                            spacing: 6
                            anchors.verticalCenter: parent.verticalCenter

                            // タイトル (マーキー)
                            Row {
                                width: parent.width
                                spacing: 8

                                MarqueeText {
                                    id: titleMarquee
                                    Layout.fillWidth: true
                                    text: root.title.length > 0 ? root.title : qsTr("不明なタイトル")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontPixelSizeTitle
                                    font.weight: Font.DemiBold
                                    color: Theme.textColor
                                    marqueeSpeed: 40
                                    pauseDuration: 2000
                                }
                            }

                            // アーティスト (マーキー)
                            Row {
                                width: parent.width
                                spacing: 8
                                visible: root.artist.length > 0

                                MarqueeText {
                                    id: artistMarquee
                                    Layout.fillWidth: true
                                    text: root.artist
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontPixelSize
                                    color: Theme.textMuted
                                    marqueeSpeed: 35
                                    pauseDuration: 2500
                                }
                            }

                            // アルバム (マーキー)
                            Row {
                                width: parent.width
                                spacing: 8
                                visible: root.album.length > 0

                                MarqueeText {
                                    id: albumMarquee
                                    Layout.fillWidth: true
                                    text: root.album
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontPixelSizeCaption
                                    color: Theme.textMuted
                                    marqueeSpeed: 30
                                    pauseDuration: 3000
                                }
                            }
                        }
                    }

                    // 再生コントロール
                    GlassCard {
                        width: parent.width
                        padding: 20
                        radius: Theme.cardRadius

                        Column {
                            width: parent.width
                            spacing: 16

                            // シークバー
                            Column {
                                width: parent.width
                                spacing: 6

                                SliderControl {
                                    id: seekSlider
                                    width: parent.width
                                    value: root.seekProgress * 100
                                    minValue: 0
                                    maxValue: 100
                                    step: 0.1
                                    showValue: true
                                    suffix: ""
                                    accentColor: Theme.accent
                                    trackColor: Qt.rgba(Theme.textMutedColor.r, Theme.textMutedColor.g, Theme.textMutedColor.b, 0.15)
                                    enabled: root.canControl && root.lengthMs > 0
                                    onValueChanged: {
                                        if (root.canControl && root.lengthMs > 0) {
                                            root.mediaSeek(Math.round(value / 100 * root.lengthMs))
                                        }
                                    }
                                }

                                // 経過時間 / 総時間
                                Row {
                                    width: parent.width
                                    Text {
                                        anchors.left: parent.left
                                        text: root.formatMs(root.animatedPosition)
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontPixelSizeCaption
                                        color: Theme.textMuted
                                    }
                                    Text {
                                        anchors.right: parent.right
                                        text: root.formatMs(root.lengthMs)
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontPixelSizeCaption
                                        color: Theme.textMuted
                                    }
                                }
                            }

                            // コントロールボタン行
                            Row {
                                width: parent.width
                                spacing: 16

                                // 音量スライダー (左側、固定幅)
                                Item {
                                    id: volumeContainer
                                    width: 100
                                    height: 48
                                    anchors.verticalCenter: parent.verticalCenter

                                    Row {
                                        anchors.fill: parent
                                        spacing: 8

                                        IconButton {
                                            iconSource: root.animatedVolume === 0
                                                ? "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='20' height='20'><path fill='%23E8F4F2' d='M16.5 12c0-1.77-1.02-3.29-2.5-4.03v2.21l2.45 2.45c.03-.2.05-.41.05-.63zm2.5 0c0 .94-.2 1.82-.54 2.64l1.51 1.51C20.63 14.91 21 13.5 21 12c0-4.28-2.99-7.86-7-8.77v2.06c2.89.86 5 3.54 5 6.71zM4.27 3L3 4.27 7.73 9H3v6h4l5 5v-6.73l4.25 4.25c-.67.52-1.42.93-2.25 1.18v2.06c1.38-.31 2.63-.95 3.69-1.81L19.73 21 21 19.73l-9-9L4.27 3z'/>"
                                                : (root.animatedVolume < 50
                                                    ? "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='20' height='20'><path fill='%23E8F4F2' d='M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z'/>"
                                                    : "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='20' height='20'><path fill='%23E8F4F2' d='M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z'/>")
                                            iconSize: 20
                                            buttonSize: 36
                                            tooltipText: qsTr("ミュート")
                                            enabled: root.canControl
                                            onClicked: root.mediaSetVolume(root.animatedVolume === 0 ? 50 : 0)
                                        }

                                        SliderControl {
                                            id: volumeSlider
                                            Layout.fillWidth: true
                                            value: root.animatedVolume
                                            minValue: 0
                                            maxValue: 100
                                            step: 1
                                            showValue: false
                                            suffix: ""
                                            accentColor: Theme.accent
                                            trackColor: Qt.rgba(Theme.textMutedColor.r, Theme.textMutedColor.g, Theme.textMutedColor.b, 0.15)
                                            enabled: root.canControl
                                            onValueChanged: root.mediaSetVolume(value)
                                            wheelStep: 5
                                        }
                                    }
                                }

                                // 再生制御ボタン群 (中央寄せ)
                                Item {
                                    Layout.fillWidth: true
                                    height: 48
                                    anchors.verticalCenter: parent.verticalCenter

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 16

                                        // 前の曲
                                        IconButton {
                                            iconSource: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='28' height='28'><path fill='%23E8F4F2' d='M6 6h2v12H6zm3.5 6l8.5 6V6z'/>"
                                            iconSize: 28
                                            buttonSize: 48
                                            tooltipText: qsTr("前の曲")
                                            enabled: root.canControl
                                            onClicked: root.mediaPrevious()
                                        }

                                        // 再生/停止
                                        IconButton {
                                            id: playPauseBtn
                                            iconSource: root.playing
                                                ? "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='32' height='32'><path fill='%237FB8B0' d='M6 19h4V5H6v14zm8-14v14h4V5h-4z'/>"
                                                : "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='32' height='32'><path fill='%237FB8B0' d='M8 5v14l11-7z'/>"
                                            iconSize: 32
                                            buttonSize: 56
                                            tooltipText: root.playing ? qsTr("一時停止") : qsTr("再生")
                                            enabled: root.canControl
                                            onClicked: root.mediaPlayPause()
                                        }

                                        // 次の曲
                                        IconButton {
                                            iconSource: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='28' height='28'><path fill='%23E8F4F2' d='M6 18l8.5-6L6 6v12zM16 6v12h2V6h-2z'/>"
                                            iconSize: 28
                                            buttonSize: 48
                                            tooltipText: qsTr("次の曲")
                                            enabled: root.canControl
                                            onClicked: root.mediaNext()
                                        }
                                    }
                                }
                            }
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
                            source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='48' height='48'><path fill='%237FB8B0' d='M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z'/>"
                            color: Theme.accentSoft
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: qsTr("再生中のメディアがありません")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontPixelSize
                            font.weight: Font.DemiBold
                            color: Theme.textColor
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: qsTr("MPRIS 対応プレイヤー (Spotify, VLC, mpv など) で\n再生を開始するとここにコントロールが表示されます。")
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