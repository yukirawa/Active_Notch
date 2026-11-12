pragma ComponentBehavior: Bound
import QtQuick
// 自己モジュールの明示 import (Theme singleton の解決を確実にする)。
// qt_add_qml_module に登録された時点でこの URI は自己参照として有効。
import dev.yukirawa.activenotch

// GlassCard — 再利用可能な半透明カード (くすみ Frutiger Aero)。
//
// 展開パネル内の情報ブロック用コンポーネント。Phase 2+ の pages/* でも
// 使用する想定。2 通りの使い方ができる:
//
//   1. 宣言的使用 (通常): 子要素を直接書く (default property で中に入る)
//        GlassCard {
//            Text { text: qsTr("こんにちは") }
//        }
//
//   2. プロパティ使用 (Loader 経由の動的ロード時):
//        title / subtitle / body を設定するとビルトインレイアウトで描画する
//
// 背景は 3 層 (半透明ダークベース / 控えめなアクア縦グラデ / 1px 発光
// ボーダー) + 上端スペキュラ。すべて Theme トークン経由 (直値色禁止)。
Item {
    id: card

    // ---- 公開 API -------------------------------------------------------
    // 宣言的使用時に子要素が入る場所 (padding を反映した内側)
    default property alias contentData: contentHost.data

    // プロパティ使用時のビルトインコンテンツ (省略可)
    property string title: ""      // 例: qsTr("ActiveNotch — Phase 1")
    property string subtitle: ""   // 例: "v" + Theme.appVersion
    property string body: ""       // 例: qsTr("展開パネルの中身は ...")

    // 角丸半径 (既定はカード用トークン)
    property real radius: Theme.cardRadius
    // 内側の余白
    property real padding: Theme.cardPadding

    // contentData 使用時の子要素の増減・リサイズを暗黙高さの再計算に反映する
    // ためのリビジョン (childrenRect は変更通知を持たないため)。
    property int contentRevision: 0

    // プロパティ使用時はビルトイン内容から、宣言的使用時は子要素の
    // 外接矩形から暗黙高さを計算する。
    // height 自身を参照すると自己参照ループになるため参照しない。
    implicitHeight: computeImplicitHeight(contentRevision)

    function computeImplicitHeight(revision) {
        if (builtIn.visible)
            return builtIn.implicitHeight + padding * 2
        return measureContent() + padding * 2
    }

    // 子要素の下端 (height と implicitHeight の大きい方) の最大値。
    // anchors.fill された子は height が親由来になるため、implicitHeight も
    // 併用して内容の実寸を失わないようにする。
    function measureContent() {
        let h = 0
        for (let i = 0; i < contentHost.children.length; i++) {
            const child = contentHost.children[i]
            if (!child.visible)
                continue
            const childHeight = Math.max(child.height, child.implicitHeight)
            h = Math.max(h, child.y + childHeight)
        }
        return h
    }

    // ---- 背景: 半透明ダークベース ----------------------------------------
    Rectangle {
        anchors.fill: parent
        radius: card.radius
        color: Theme.cardBg
    }

    // ---- 背景: くすみアクアの控えめな縦グラデ ------------------------------
    // 上端がわずかに明るく、下端へフェードする (Frutiger Aero の光沢感)。
    Rectangle {
        anchors.fill: parent
        radius: card.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.overlayTop }
            GradientStop { position: 1.0; color: Theme.overlayBottom }
        }
    }

    // ---- 上端スペキュラハイライト ----------------------------------------
    // 角丸からはみ出さないよう高さを (height - radius) 以内にクランプ。
    Rectangle {
        width: parent.width
        // 高さが radius 未満でも負値にならないようクランプする。
        height: Math.max(0, Math.min(Theme.specularHeight, parent.height - card.radius))
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.specular }
            GradientStop { position: 1.0; color: Theme.specularFade }
        }
    }

    // ---- 1px 発光ボーダー (アクセント寄り) --------------------------------
    Rectangle {
        anchors.fill: parent
        radius: card.radius
        color: "transparent"
        border.width: Theme.borderWidth
        border.color: Theme.cardBorderGlow
    }

    // ---- コンテンツ配置 ---------------------------------------------------
    // 宣言的使用時の子要素の置き場 (padding を内側余白として反映)
    Item {
        id: contentHost
        anchors.fill: parent
        anchors.margins: card.padding
        // 子の増減・リサイズで暗黙高さを再評価する。
        onChildrenRectChanged: card.contentRevision += 1
    }

    // プロパティ使用時のビルトインレイアウト
    // (title/subtitle/body のいずれかが設定されているときだけ表示)
    Column {
        id: builtIn
        anchors.fill: parent
        anchors.margins: card.padding
        spacing: 6
        visible: card.title.length > 0 || card.subtitle.length > 0 || card.body.length > 0

        Row {
            spacing: 10
            visible: card.title.length > 0 || card.subtitle.length > 0

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: card.title
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPixelSizeTitle
                font.weight: Font.DemiBold
                color: Theme.textColor
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: card.subtitle
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPixelSizeCaption
                color: Theme.accentSoft
            }
        }

        Text {
            width: parent.width
            visible: card.body.length > 0
            text: card.body
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontPixelSize
            color: Theme.textMuted
            wrapMode: Text.WordWrap
        }
    }
}
