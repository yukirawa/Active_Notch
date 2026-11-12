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
    // 展開パネル内側の余白 (コンテンツ領域)
    readonly property real panelPadding: 28

    // ===== アニメーション: 形状モーフ (SpringAnimation) ==================
    // PLAN §6: mass/spring/damping のスプリング系で物理的な手触りを出す。
    // damping を上げると振動が減り収束が速くなる (0.4 で程よく一回跳ねる)。
    readonly property real springMass: 1.0
    readonly property real springSpring: 3.5
    readonly property real springDamping: 0.4
    // 閉じる方向は振動を抑えて素早く収束させる。
    // 低 damping のままだとスプリングが数秒揺れ続け、ブラー領域の更新や
    // 入力マスクの確定が遅れて「閉じるのが遅い」ように見えるため。
    readonly property real springDampingClose: 0.85
    readonly property real springSpringClose: 4.2

    // ===== アニメーション: 展開内容 (時差フェード / 猶予) =================
    // 展開ブロックを 1 個ずつ遅らせてフェードさせる間隔 (PLAN §6: 20〜40ms)。
    readonly property int staggerMs: 24
    // 展開→折りたたみに移るまでのホバー離脱猶予 (チラつき防止)。
    readonly property int hoverGraceMs: 220
    // 展開内容が下方向へスライドしながら現れる距離 (opacity に連動)。
    readonly property real revealSlideDistance: 14
    // 展開内容 1 ブロックのフェード時間。
    readonly property int revealDurationMs: 220
    // 全画面退避時のフェード時間。
    readonly property int fullscreenFadeMs: 180

    // ===== 線 ===========================================================
    readonly property real borderWidth: 1

    // ===== サーフェス: 生トークン (色 + 不透明度) ========================
    // ベース: 半透明ダーク。
    // 0.72 はブラー越しの壁紙を 28% しか通さず、暗い壁紙では黒一色に
    // 見えたため 0.58 まで下げる (透過 42%)。13px 文字の可読性は維持。
    readonly property color bgBase: "#0E1518"
    readonly property real bgOpacity: 0.58

    // くすみ Frutiger Aero オーバーレイ (縦グラデ):
    // 上 = 淡いアクア → 下 = くすみグレー。ベースを薄くした分だけ色味を増す。
    readonly property color overlayTopColor: "#8FC5BD"
    readonly property real overlayTopOpacity: 0.20
    readonly property color overlayBottomColor: "#3C4A54"
    readonly property real overlayBottomOpacity: 0.14

    // 乳白色のフロスト床。暗い壁紙でも実効輝度が 0 に落ちないようにする
    // (「黒背景で透過なし」対策)。overlay の直後に 1 枚だけ重ねる。
    readonly property color hazeColor: "#E9F5F2"
    readonly property real hazeOpacity: 0.06

    // 上端スペキュラハイライト (白 α0.10〜0.18)
    readonly property color specularColor: "#FFFFFF"
    readonly property real specularOpacity: 0.18
    readonly property real specularHeight: 10     // 上端からフェードする高さ

    // 発光ボーダー (薄いガラスでも輪郭が消えない強さ)
    readonly property color borderColor: "#BFE6E0"
    readonly property real borderOpacity: 0.30

    // ===== シャドウ: 多層ソフトドロップシャドウ ===========================
    // QtQuick 標準のみで描くため、「透過矩形 + 太 border」の角丸リングを
    // 3 層重ねる (spread = border 幅 = ぼかしの広がり)。外層ほど薄く広い。
    // yOffset は shape 下端からの沈み込み (下方向に影を強調)。
    readonly property color shadowColor: "#000000"
    readonly property real shadowOpacity: 1.0   // 全体の強さ係数
    readonly property var shadowLayers: [
        { "spread": 6,  "yOffset": 2, "alpha": 0.16 },
        { "spread": 14, "yOffset": 4, "alpha": 0.08 },
        { "spread": 26, "yOffset": 6, "alpha": 0.04 }
    ]

    // ===== アクセント / 文字色 ===========================================
    readonly property color accent: "#7FB8B0"      // くすみティール/アクア
    readonly property color textColor: "#F2FBF9"   // フロストが明るくなった分を補正
    // セカンダリテキスト (日付 / 説明文など控えめな文字)
    readonly property color textMutedColor: "#B8CFCA"
    readonly property real textMutedOpacity: 0.90

    // ===== タイポグラフィ =================================================
    // fc-match が KR を返すため、JP を明示指定 (PLAN §8)
    readonly property string fontFamily: "Noto Sans CJK JP"
    readonly property int fontPixelSize: 13
    // 展開パネル用のサイズバリエーション
    readonly property int fontPixelSizeClockLarge: 34  // 展開時の大きな時計
    readonly property int fontPixelSizeTitle: 15       // カードタイトル
    readonly property int fontPixelSizeCaption: 12     // 補足・ヒント行

    // ===== 展開パネル: GlassCard ==========================================
    readonly property real cardRadius: 16
    readonly property real cardPadding: 18
    // パネル背景 (すりガラス): 面積が大きいほど「板」に見えるため、
    // ピルより薄くして背景のブラーを活かす。
    readonly property real panelBgOpacity: 0.52
    // カードはパネルより一段暗くして、本文の下だけコントラストを稼ぐ。
    readonly property real cardBgOpacity: 0.30
    // カードの発光ボーダー: アクセント寄りで shape よりわずかに強い
    readonly property real cardBorderOpacity: 0.34
    // ポップアップ / ダイアログ (背後の情報を隠す必要があるため濃いめ)
    readonly property real popupBgOpacity: 0.84

    // ===== 派生トークン (合成済み。QML 側は基本こちらを使う) ==============
    readonly property color bgSurface: Qt.rgba(
        bgBase.r, bgBase.g, bgBase.b, bgOpacity)

    readonly property color overlayTop: Qt.rgba(
        overlayTopColor.r, overlayTopColor.g, overlayTopColor.b,
        overlayTopOpacity)

    readonly property color overlayBottom: Qt.rgba(
        overlayBottomColor.r, overlayBottomColor.g, overlayBottomColor.b,
        overlayBottomOpacity)

    // 乳白色フロスト床
    readonly property color haze: Qt.rgba(
        hazeColor.r, hazeColor.g, hazeColor.b, hazeOpacity)

    readonly property color specular: Qt.rgba(
        specularColor.r, specularColor.g, specularColor.b, specularOpacity)

    // スペキュラのフェード末端: 同色で完全透明にして黒への補間を防ぐ
    readonly property color specularFade: Qt.rgba(
        specularColor.r, specularColor.g, specularColor.b, 0)

    readonly property color borderGlow: Qt.rgba(
        borderColor.r, borderColor.g, borderColor.b, borderOpacity)

    // ===== 展開パネル / GlassCard 用の派生トークン =========================
    // パネル背景 (すりガラス風の半透明ダーク)
    readonly property color panelBg: Qt.rgba(
        bgBase.r, bgBase.g, bgBase.b, panelBgOpacity)

    // GlassCard 背景 (さらに一段浅い半透明)
    readonly property color cardBg: Qt.rgba(
        bgBase.r, bgBase.g, bgBase.b, cardBgOpacity)

    // GlassCard の発光ボーダー (アクセント寄り)
    readonly property color cardBorderGlow: Qt.rgba(
        borderColor.r, borderColor.g, borderColor.b, cardBorderOpacity)

    // ポップアップ背景 (ほぼ不透明)
    readonly property color popupBg: Qt.rgba(
        bgBase.r, bgBase.g, bgBase.b, popupBgOpacity)

    // セカンダリテキスト
    readonly property color textMuted: Qt.rgba(
        textMutedColor.r, textMutedColor.g, textMutedColor.b, textMutedOpacity)

    // アクセントに僅かな透明感を持たせた派生 (ポイントライト用)
    readonly property color accentSoft: Qt.rgba(
        accent.r, accent.g, accent.b, 0.85)

    // アプリバージョン。C++ 側の QCoreApplication::setApplicationVersion()
    // (CMake project(VERSION ...) 由来) を唯一の情報源とする。
    readonly property string appVersion: Qt.application.version
}
