pragma Singleton
import QtQuick

// ActiveNotch デザイントークン (PLAN §6「くすみ Frutiger Aero」)。
//
// - 「〜Color / 〜Opacity」のペアは生トークン。Phase 7 の KConfig
//   (~/.config/activenotch/) から色や不透明度だけ差し替えられるよう
//   分解して定義する。
// - 「bgSurface / overlayTop / ...」は色 × 不透明度を合成済みの派生
//   トークン。QML 側は基本こちらを直接使う。
// - ジオメトリは論理 px (画面スケールは Qt Wayland QPA が自動処理)。
QtObject {
    // ===== ジオメトリ: 折りたたみピル (Collapsed) ======================
    readonly property real collapsedWidth: 220
    readonly property real collapsedHeight: 30
    readonly property real radiusCollapsed: 16   // 下側のみの角丸

    // ===== ジオメトリ: 展開パネル (Expanded, Phase 1+) ==================
    readonly property real expandedWidth: 660
    readonly property real expandedHeight: 440
    readonly property real radiusExpanded: 28
    readonly property real expandedTopMargin: 8  // 展開時の浮遊感

    // ===== 線 ===========================================================
    readonly property real borderWidth: 1

    // ===== サーフェス: 生トークン (色 + 不透明度) ========================
    // ベース: 半透明ダーク (PLAN: α 0.62〜0.78 の中央値)
    readonly property color bgBase: "#0E1518"
    readonly property real bgOpacity: 0.72

    // くすみ Frutiger Aero オーバーレイ (縦グラデ):
    // 上 = 淡いアクア → 下 = くすみグレー、控えめな濃度
    readonly property color overlayTopColor: "#8FC5BD"
    readonly property real overlayTopOpacity: 0.16
    readonly property color overlayBottomColor: "#3C4A54"
    readonly property real overlayBottomOpacity: 0.12

    // 上端スペキュラハイライト (白 α0.10〜0.18)
    readonly property color specularColor: "#FFFFFF"
    readonly property real specularOpacity: 0.16
    readonly property real specularHeight: 10     // 上端からフェードする高さ

    // 発光ボーダー
    readonly property color borderColor: "#BFE6E0"
    readonly property real borderOpacity: 0.25

    // ===== アクセント / 文字色 ===========================================
    readonly property color accent: "#7FB8B0"      // くすみティール/アクア
    readonly property color textColor: "#E8F4F2"  // 淡いアクア寄りの白

    // ===== タイポグラフィ =================================================
    // fc-match が KR を返すため、JP を明示指定 (PLAN §8)
    readonly property string fontFamily: "Noto Sans CJK JP"
    readonly property int fontPixelSize: 13

    // ===== 派生トークン (合成済み。QML 側は基本こちらを使う) ==============
    readonly property color bgSurface: Qt.rgba(
        bgBase.r, bgBase.g, bgBase.b, bgOpacity)

    readonly property color overlayTop: Qt.rgba(
        overlayTopColor.r, overlayTopColor.g, overlayTopColor.b,
        overlayTopOpacity)

    readonly property color overlayBottom: Qt.rgba(
        overlayBottomColor.r, overlayBottomColor.g, overlayBottomColor.b,
        overlayBottomOpacity)

    readonly property color specular: Qt.rgba(
        specularColor.r, specularColor.g, specularColor.b, specularOpacity)

    // スペキュラのフェード末端: 同色で完全透明にして黒への補間を防ぐ
    readonly property color specularFade: Qt.rgba(
        specularColor.r, specularColor.g, specularColor.b, 0)

    readonly property color borderGlow: Qt.rgba(
        borderColor.r, borderColor.g, borderColor.b, borderOpacity)
}
