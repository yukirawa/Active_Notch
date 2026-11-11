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
