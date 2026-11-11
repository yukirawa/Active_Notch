# ActiveNotch

KDE Plasma 6 (Wayland / KWin) に最適化した、画面上部中央に張り付く Dynamic Island 風の多機能ノッチ。
Qt6 (QML) + LayerShellQt による単体常駐アプリ。日本語 UI 標準対応。

詳細な設計は [PLAN.md](PLAN.md) を参照。

## 現状 (Phase 0 完了)

- CMake ビルド雛形 + LayerShellQt によるウィンドウ配置 + 折りたたみピル UI を実装済み
- 画面上部中央に透過ピル (220x30 論理 px、AnchorTop 中央寄せ、LayerOverlay、
  排他ゾーン無効、キーボードフォーカスなし) が表示される
- ピル内に時計 (HH:mm / Noto Sans CJK JP) を表示 (ライブ更新)
- デザイントークンを `qml/Theme.qml` に singleton として集約
  (くすみ Frutiger Aero: 半透明ダーク + アクアグラデ + スペキュラ + 発光ボーダー)
- 開閉アニメ・ホバー操作・入力/ブラー領域は Phase 1

## ビルド手順

```sh
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
./build/activenotch
```

## テスト手順

### 自動テスト

```sh
# configure + build (警告は表示のみ、エラーは非ゼロ exit)
./scripts/dev.sh

# QtTest 単体テスト (ctest)
./scripts/run-tests.sh

# 自動視覚検証: ビルド → 起動 → スクリーンショット → 配置/サイズ/色を検証
./scripts/verify-ui.sh
```

`verify-ui.sh` は以下を検証し、PASS/FAIL 表を出力します。

- (a) 入力領域マスク (ピル) の中心が画面水平中央 (±3 物理 px)
- (b) マスクサイズが折りたたみピル相当 (幅 250–300 / 高さ 28–50 物理 px, scale 1.2)
- (c) ピル中心の色が真下のデスクトップと異なる (RGB 差合計 > 20)
- (d) ピル外数 px 下がデスクトップと同色 (RGB 差合計 < 30)

成果物 (スクリーンショット / stdout / stderr) は `scripts/artifacts/` に保存されます。
**注意**: 検証中にマウスが画面上部中央にあるとホバー展開して FAIL することがあります。
マウスを画面中央へ移動してから再実行してください。

### 手動テスト

```sh
./scripts/run.sh    # Wayland チェック → 必要ならビルド → 起動
./scripts/stop.sh   # 稼働中インスタンスを停止 (未起動でも成功)
```

- 折りたたみピルが画面上部中央に表示される
- ピル外をクリックしても背後のウィンドウが操作できる (入力透過)
- ピルにホバーで展開 / クリックで固定
- 固定中は `Esc`・外側クリックで解除
- 全画面アプリを前面に出すとノッチが退避する

### デバッグ用環境変数

```sh
ACTIVENOTCH_PRINT_GEOMETRY=1 ./build/activenotch
# → 表示時・ジオメトリ変更時に stdout へ出力
#   GEOMETRY x=<物理x> y=<物理y> w=<物理w> h=<物理h> scale=<DPR> screen=<画面名>
#   MASK x=<物理x> y=<物理y> w=<物理w> h=<物理h>
```

## 依存関係

| 依存 | 用途 |
|---|---|
| Qt6 (Base / Declarative / Wayland) | アプリ本体 (Quick + Qml) |
| `layer-shell-qt` | wlr-layer-shell による配置 (KWin 対応) |
| CMake ≥ 3.25 / Ninja / GCC (C++20) | ビルド |

**注意 (確認済み)**: `extra-cmake-modules` (ECM) は不要。
LayerShellQt の CMakeConfig は `Qt6Gui` にのみ `find_dependency` するため、
ECM を入れなくても `find_package(LayerShellQt REQUIRED)` が通る
(実機: layer-shell-qt 6.8.2-1 / Qt 6.12.0 で確認)。

## 技術メモ

- LayerShellQt の CMake リンクターゲットは `LayerShellQt::Interface`
  (`LayerShellQt::LayerShellQt` ではない)
- QML モジュール URI: `dev.yukirawa.activenotch` (VERSION 1.0)
- `Shell::useLayerShell()` は Qt 6.5 以降不要・非推奨のため呼んでいない
  (QWindow に LayerShellQt::Window を紐付けると Wayland QPA が自動選択する)
