import QtQuick

// 折りたたみ (Collapsed) 状態のノッチピル。
//
// 構造: 背景 (background) と内容 (content) を分離しており、Phase 1 の
// 開閉アニメーションで
//   - background → 形状モーフ (SpringAnimation)
//   - content    → 時差フェード + 下方向スライド
// を独立して適用できるようにしている。
Item {
    id: root

    // ---- ジオメトリ ----------------------------------------------------
    width: Theme.collapsedWidth
    height: Theme.collapsedHeight

    // 下側のみの角丸半径
    readonly property real cornerRadius: Theme.radiusCollapsed

    // ---- 上端フラット化の仕組み ------------------------------------------
    // QML Rectangle の radius は四隅均一のため、半径 cornerRadius の角丸
    // 矩形を上方向に同量はみ出させて (y: -cornerRadius,
    // height: height + cornerRadius) 配置し、background を clip: true に
    // して上側だけを切り落とす → 見えるのは「上辺フラット・下側角丸」。
    //
    // 好都合な性質: はみ出し矩形の上側コーナー Arc は中心 y = 0 を通る
    // ため、y >= 0 の範囲では矩形は常に全幅 (左右端は直線) になる。
    // このため y = 0 から始まるスペキュラ矩形や上端ボーダー線も、
    // 形状からはみ出さず全幅で重ねられる。
    readonly property real overhang: cornerRadius
    readonly property real shapeHeight: height + overhang
    // 見えている上端 (y = 0) が、はみ出し矩形のグラデ (0..1) のどこか
    readonly property real visibleTopPos: overhang / shapeHeight

    // ---- 時刻 ------------------------------------------------------------
    // ライブ更新。qsTr() 化は Phase 7 (i18n) で実施。
    property string timeText: ""

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.timeText = Qt.formatDateTime(new Date(), "hh:mm")
    }

    // ======================================================================
    // 背景 (Phase 1 のモーフアニメーション対象)
    // ======================================================================
    Item {
        id: background
        anchors.fill: parent
        clip: true  // 上にはみ出した角丸を切り、上辺をフラットにする

        // 1) ベース: 半透明ダーク (#0E1518 α0.72)
        Rectangle {
            width: parent.width
            height: root.shapeHeight
            y: -root.overhang
            radius: root.cornerRadius
            color: Theme.bgSurface
        }

        // 2) くすみ Frutiger Aero: 淡いアクア→くすみグレーの縦グラデを
        //    控えめに重ねる (見える上端 y=0 が最も明るくなるよう調整)
        Rectangle {
            width: parent.width
            height: root.shapeHeight
            y: -root.overhang
            radius: root.cornerRadius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.overlayTop }
                GradientStop { position: root.visibleTopPos; color: Theme.overlayTop }
                GradientStop { position: 1.0; color: Theme.overlayBottom }
            }
        }

        // 3) 上端スペキュラハイライト: 柔らかい白のフェード (上端のみ)
        //    高さを「下側コーナー開始位置 (height - radius)」以内に
        //    クランプするため、全幅矩形でも形状からはみ出さない
        Rectangle {
            width: parent.width
            height: Math.min(Theme.specularHeight,
                             root.height - root.cornerRadius)
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.specular }
                GradientStop { position: 1.0; color: Theme.specularFade }
            }
        }

        // 4) 1px の淡い発光ボーダー: 左右・下側ははみ出し角丸矩形の縁
        Rectangle {
            width: parent.width
            height: root.shapeHeight
            y: -root.overhang
            radius: root.cornerRadius
            color: "transparent"
            border.width: Theme.borderWidth
            border.color: Theme.borderGlow
        }

        // 4b) 上端の水平ボーダー:
        //     はみ出し矩形の上辺は clip で切れてしまうため y = 0 に補完
        Rectangle {
            width: parent.width
            height: Theme.borderWidth
            color: Theme.borderGlow
        }
    }

    // ======================================================================
    // 内容: 中央の時刻 (Phase 1 で背景とは別のアニメーション対象)
    // ======================================================================
    Item {
        id: content
        anchors.fill: parent

        Text {
            anchors.centerIn: parent
            text: root.timeText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontPixelSize
            color: Theme.textColor
        }
    }
}
