# ActiveNotch デザイン進捗・引き継ぎ資料

> 対象: v1.0.0 時点 (2026-11-12)
> 目的: ロジック優先で実装した UI を、デザイン担当が引き継いで仕上げるための現状整理。
> 方針: **Theme.qml のトークン経由で調整する**。色・サイズの直書きは原則禁止。

関連資料: [PLAN.md](../PLAN.md) §6 (デザイン方針) / [docs/CONTRACT.md](CONTRACT.md) / [README.md](../README.md)

---

## 0. デザインの基本方針 (変更不可の前提)

- **くすみ Frutiger Aero**: 半透明ダーク + 淡いアクアグラデ + スペキュラ + 発光ボーダー
- ノッチ表示時は**黒背景で透過しない** (外側だけ透過)。開いた瞬間から frosted glass。
- 開閉は QML 内部のスプリングモーフのみ。ウィンドウ自体は 660x448 論理px 固定。
- 日本語 UI 標準。文言は必ず `qsTr()`。
- 入力マスクはピル領域のみ (外側クリックは背後のウィンドウへ透過)。

---

## 1. できている (v1.0.0 で完成扱い)

### 1.1 デザイントークン体系 — `qml/Theme.qml`
singleton として全トークンを集約済み。生トークン (色 + 不透明度) と合成済み派生トークンの 2 層構造。

| 分類 | トークン例 |
|---|---|
| ジオメトリ | `collapsedWidth/Height`, `expandedWidth/Height`, `radiusCollapsed/Expanded`, `expandedTopMargin`, `panelPadding`, `cardRadius`, `cardPadding`, `borderWidth` |
| スプリング | `springMass/springSpring/springDamping` (開), `springSpringClose/springDampingClose` (閉) |
| タイミング | `staggerMs`, `hoverGraceMs`, `revealDurationMs`, `revealSlideDistance`, `fullscreenFadeMs` |
| 生カラー | `bgBase/bgOpacity`, `overlayTopColor/Opacity`, `overlayBottomColor/Opacity`, `hazeColor/Opacity`, `specularColor/Opacity`, `borderColor/Opacity`, `shadowColor/shadowLayers`, `accent`, `textColor`, `textMutedColor/Opacity` |
| 合成済み | `bgSurface`, `overlayTop/Bottom`, `haze`, `specular`, `specularFade`, `borderGlow`, `panelBg`, `cardBg`, `cardBorderGlow`, `popupBg`, `textMuted`, `accentSoft` |
| タイポ | `fontFamily` (Noto Sans CJK JP), `fontPixelSize` (13), `fontPixelSizeClockLarge` (34), `fontPixelSizeTitle` (15), `fontPixelSizeCaption` (12) |
| バージョン | `appVersion` (= `Qt.application.version`、CMake が情報源) |

### 1.2 ガラスサーフェス (多層)
`qml/Notch.qml` の背景は以下の多層で構成済み。
1. ベースの暗色矩形
2. アクア→くすみグレーの縦グラデ
3. 乳白色フロスト床 (暗い壁紙でも黒一色に落とさない)
4. スペキュラ (上端ハイライト)
5. 発光ボーダー
6. 多層ドロップシャドウ (`shadowLayers`)

### 1.3 モーション
- 開閉のスプリングモーフ (開: 軽く跳ねる / 閉: 高 damping で高速収束)
- stagger fade (`staggerMs`) でコンテンツを順次表示
- hover grace (`hoverGraceMs`) で離脱時の即時収納を防止
- 全画面時のフェード退避 (`fullscreenFadeMs`)
- ブラー領域はアニメ中の実形状へ毎フレーム追従

### 1.4 ナビゲーション
- `TabBar` / `TabButton` (アイコン + ラベル、選択状態)
- `PageLoader` (非同期 Loader、13 ページ)
- 13 ページ: Quick / Battery / Sound / Calendar / Media / Stats / Network / Weather / Notifications / Clipboard / Launcher / Tray / Settings

### 1.5 共通コンポーネント (29 個)
`GlassCard`, `ControlSection`, `DetailItem`, `IconButton`, `Button`, `ToggleRow`, `ToggleSwitch`, `SliderControl`, `SpinBox`, `ComboBox`, `ColorPalette`, `GaugeCircle`, `StatGaugeCard`, `StatInfoCard`, `MarqueeText`, `DayCell`, `ForecastDayCard`, `NotificationDelegate`, `ClipboardDelegate`, `NetworkListDelegate`, `TrayMenuItem`, `TrayMenuSubmenu`, `TrayMenuSeparator`, `TabBar`, `TabButton`, `PageLoader` ほか。

### 1.6 状態表現
- 空状態 (13 箇所): Clipboard / Launcher / Media / Notifications / Stats / Tray など
- 負荷・バッテリー・Wi-Fi 強度などの意味色
- Settings ページ (アプリ内設定 UI、即時反映)

### 1.7 アセット
- アプリアイコン: `config/dev.yukirawa.activenotch.svg`
- スクリーンショット: `docs/screenshot-expanded.png` / `docs/screenshot-collapsed.png`
- アイコンは全て `image://svg/<percent-encoded-svg>` の独自プロバイダ経由 (Qt 6.12 の `data:` URL 不具合回避)

---

## 2. 途中 / 要ポリッシュ (デザイン担当の作業対象)

優先度: ★★★ = 体験に直結 / ★★ = 品質向上 / ★ = あると良い

| # | 項目 | 現状 | 優先度 | 対象ファイル |
|---|---|---|---|---|
| 1 | ページ遷移アニメ | `PageLoader` は即時切替。フェード/スライドなし | ★★★ | `qml/components/PageLoader.qml` |
| 2 | 意味色の直書き | 赤/アンバー/緑/青が 16 箇所に直書き | ★★★ | `Stats.qml` (8), `Button.qml` (3), `Network.qml` (2), `Battery.qml` (3), `Sound.qml` (1) |
| 3 | アイコンの統一 | 手書き SVG が中心。統一アイコンファミリーでない | ★★ | 各ページ / `image://svg` 文字列 |
| 4 | タイポグラフィ階層 | 実質 10 / 12 / 13 / 15 / 22 / 28 / 34 / 48 のみ。見出し・本文・ラベルの体系が粗い | ★★ | `qml/Theme.qml` + 各ページ |
| 5 | ライトテーマ | ダークのみ | ★★ | `qml/Theme.qml` |
| 6 | アクセシビリティ | reduced-motion / 高コントラスト / フォーカスリング未対応 (`Esc` のみ) | ★★ | `qml/Theme.qml`, `Notch.qml`, 各コンポーネント |
| 7 | 混合 DPI の実機確認 | DP-1 (scale 1.0) + eDP-1 (scale 1.2) で論理座標検証は済。見た目の微調整は未 | ★★ | 実機確認 |
| 8 | ブラーフォールバック | ブラー無効環境では半透明に退化。見た目は未調整 | ★★ | `qml/Notch.qml`, `src/BlurHelper.*` |
| 9 | トレイメニュー | 機能は動作。階層・区切り・チェック状態の見た目が素朴 | ★ | `TrayMenu*.qml`, `Tray.qml` |
| 10 | 通知トースト | 履歴表示は実装。ポップアップの磨き込みが未 | ★ | `NotificationDelegate.qml`, `Notifications.qml` |
| 11 | 天気アイコン | 天気コード→アイコン対応は簡易 | ★ | `Weather.qml` |
| 12 | 小画面・多言語 | 660x448 前提。長い英語文言・小さい画面での折返し未検証 | ★ | 各ページ |
| 13 | マイクロインタラクション | ボタン/トグルの押下感・ホバーは最低限 | ★ | `Button.qml`, `IconButton.qml`, `ToggleSwitch.qml` |

### 補足: 意味色の直書き箇所 (具体的な行)
```
qml/components/Button.qml:35,42,102   # 破壊的ボタン / primary
qml/pages/Stats.qml:89,91,92,98,100,102,103   # 負荷・温度
qml/pages/Network.qml:60,61            # Wi-Fi 強度
qml/pages/Sound.qml:168                # 輝度アイコン (アンバー)
qml/pages/Battery.qml:50,52,53         # バッテリー残量
```
→ 推奨: `Theme.colorDanger` / `Theme.colorWarning` / `Theme.colorSuccess` / `Theme.colorInfo`
   のようなセマンティックトークンを追加し、上記を置換する。

---

## 3. デザイン変更時のルール

1. **色・寸法は `qml/Theme.qml` に追加してから使う**。ページへの直書きはレビューで差し戻し。
2. **開閉アニメの公開 API を壊さない** (`docs/CONTRACT.md` §1)。
   `objectName "notch"` / `notchState` / `wantsKeyboardFocus` / `shapeSettled(x,y,w,h,radius)` /
   `expand()` / `pin()` / `collapse()` は凍結。
3. **ウィンドウサイズを変えない** (660x448 固定)。はみ出す場合はページ内スクロールで対応。
4. **文言は `qsTr()`**。追加したら `i18n/*.ts` を更新する。
5. **ブラーと不透明度の関係を維持**: 表示中は黒背景で透過しない。外側のみ透過。
6. **アニメは控えめに**: スプリングの mass/spring/damping を変える場合は
   開閉の体感 (跳ね・収束) を実機で確認する。

---

## 4. 確認方法

```sh
# ビルド
./scripts/dev.sh

# 単体テスト (16 スイート)
./scripts/run-tests.sh

# 視覚検証 (幾何 + 自ウィンドウ grab の alpha) — 5/5 PASS が基準
./scripts/verify-ui.sh

# 展開状態のスクリーンショット
ACTIVENOTCH_START_EXPANDED=1 ./build/activenotch &
sleep 2.5
spectacle -b -n -f -o /tmp/desktop.png
kill %1
# 上部中央を crop して docs/screenshot-*.png を更新

# 手動起動 / 停止
./scripts/run.sh
./scripts/stop.sh
```

- ログ: `journalctl --user -u activenotch -f` または `QT_FORCE_STDERR_LOGGING=1 ./build/activenotch`
- qmllint 警告ゼロを維持すること。

---

## 5. 参考: 実機環境 (視覚確認の前提)

| 項目 | 値 |
|---|---|
| OS / DE | EndeavourOS / Plasma 6.8.2 / KWin 6.8.2 (Wayland) |
| Qt | 6.12 |
| 画面 | DP-1 1920x1080 @scale 1.0 (0,0) / eDP-1 1600x1000 論理 @scale 1.2 (1920,0) |
| GPU | Intel Arc (xe) |
| KWin ブラー | 有効 (BlurStrength=11) |
| spectacle | 全画面 7040x2160 (論理の 2 倍) |

---

## 6. 引き継ぎサマリ

- **ロジック・機能・配布は v1.0.0 で完成**。壊さずにデザインだけ磨ける状態。
- 最優先は **#1 ページ遷移アニメ** と **#2 セマンティックカラーのトークン化**。
- 次点で **#3 アイコン統一**、**#4 タイポ階層**、**#6 アクセシビリティ**。
- 変更は `Theme.qml` 経由。公開 API と 660x448 固定は維持。
- 各変更後に `./scripts/run-tests.sh` と `./scripts/verify-ui.sh` を必ず通す。
