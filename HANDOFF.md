# ActiveNotch 引き継ぎドキュメント (2026-11-12 18:10 頃)

## 現在の状態

**Phase 0〜8 完了 / v1.0.0 リリース**。全機能が実装され、ビルド警告ゼロ、
単体テスト 16/16、視覚検証 5/5 PASS の状態です。

### 完了済みフェーズ
| Phase | 内容 | コミット | 状態 |
|-------|------|----------|------|
| 0 | CMake 雛形 + LayerShellQt 最小ピル | fd1b42c | ✅ 完了 |
| 1 | ノッチ外殻・テーマ・開閉アニメ・入力/ブラー/全画面検出・scripts/tests | b86be8e | ✅ 完了 |
| 2 | Config/Battery/Audio/Brightness/QuickSettings/Calendar + 4ページ | 63dc554 | ✅ 完了 |
| 3 | Media(MPRIS)/Stats + 2ページ | 4230ce9 | ✅ 完了 |
| 4 | Network/Bluetooth/Weather + 2ページ | 3683207 | ✅ 完了 |
| 5 | Notifications/Clipboard + 2ページ | 1157b2d | ✅ 完了 |
| 6 | Launcher/Tray(SNI) + 2ページ | 2e77f11 | ✅ 完了 |
| 7 | 設定UI・永続化・i18n + Settings ページ | 8a2ac78 | ✅ 完了 |
| 8 | install/uninstall/systemd/PKGBUILD/README/ライセンス | (本コミット) | ✅ 完了 |

### リリース
- バージョン: **v1.0.0** (`CMakeLists.txt` の `project(VERSION 1.0.0)` が唯一の情報源)
- `activenotch --version` / `--help` 対応
- リリースノートは日本語で `gh release create v1.0.0`

### 残タスク (リリース後の磨き込み)
- デザインの最終ポリッシュ (ui-designer 担当。`docs/DESIGN_STATUS.md` 参照)
- AUR への実登録 (`packaging/PKGBUILD` は用意済み。`sha256sums` はリリース後に確定)
- Arch 以外 (Debian/Fedora) の実機検証 (install.sh の依存名はベストエフォート)
- CI (GitHub Actions) は未設定
- 通知デーモンのミラーモード (Plasma と共存) は `OwnDaemon=false` の簡易対応のみ

---

## 実装済みアーキテクチャ概要

### C++ サービス一覧 (src/services/)
| サービス | 依存 | 主な仕様 |
|----------|------|----------|
| ConfigService | KF6ConfigCore | `~/.config/activenotch/activenotchrc`, PLAN §11 全項目 + 検証/クランプ |
| BatteryService | UPower DBus + sysfs | 30s ポール + シグナル, フォールバック |
| AudioService | wpctl | 300ms ポール, 操作 API |
| BrightnessService | sysfs + logind | QFileSystemWatcher + SetBrightness |
| QuickSettingsService | KWin DBus | NightLight |
| CalendarService | KF6Holidays + QLocale | 日本祝日・月間グリッド |
| MediaService | MPRIS DBus | NameOwnerChanged / PropertiesChanged 購読, trackid 保持 |
| StatsService | /proc + hwmon + xe | 1s タイマー, GPU フォールバック |
| NetworkService | NetworkManager DBus | Wi-Fi/有線/接続操作, SSID(ay) 対応 |
| BluetoothService | KF6BluezQt | アダプタ/デバイス/バッテリー |
| WeatherService | Open-Meteo HTTP | IP 位置検出・15 分キャッシュ |
| NotificationService | org.freedesktop.Notifications | 自前デーモン, 履歴/DND, 競合時は履歴 OFF |
| ClipboardService | wl-paste/wl-copy | 履歴/検索/貼付, 無い場合は available=false |
| LauncherService | KF6Service + XDG | あいまい検索 + 簡易計算 |
| TrayService | SNI Watcher + DBusMenu | アイコン/メニュー, 複合型シグネチャ対応 |

### QML 構成
```
qml/
├── Main.qml              # ルート (Notch 配置)
├── Notch.qml             # 状態機械・モーフ・TabBar・PageLoader
├── Theme.qml             # デザイントークン (singleton)
├── components/           # GlassCard, TabBar/TabButton, SliderControl,
│                         # ToggleRow/Switch, GaugeCircle, StatGaugeCard,
│                         # StatInfoCard, MarqueeText, PageLoader, DayCell,
│                         # ControlSection, DetailItem, IconButton,
│                         # ComboBox, SpinBox, Button, ColorPalette,
│                         # NotificationDelegate, ClipboardDelegate,
│                         # NetworkListDelegate, ForecastDayCard,
│                         # TrayMenuItem/Submenu/Separator ほか
└── pages/                # Quick, Battery, Sound, Calendar, Media, Stats,
                          # Network, Weather, Notifications, Clipboard,
                          # Launcher, Tray, Settings
```

### ビルド / テスト
- **CMake**: Qt6 (Quick/Qml/DBus/Test/GuiPrivate/WaylandClientPrivate/Network/Svg)
  + KF6 (ConfigCore/CalendarCore/Holidays/BluezQt/Service/I18n)
  + LayerShellQt::Interface + wayland-client
- **scripts/**: dev.sh, run.sh, stop.sh, verify-ui.sh, run-tests.sh
- **tests/**: 16 スイート全緑
- **verify-ui.sh**: 論理座標の幾何検証 + 自ウィンドウ grab の alpha 検証で 5/5 PASS
- **i18n**: `i18n/ja_JP.ts` / `en_US.ts` 175 メッセージ, unfinished 0
- **qmllint**: 警告ゼロ

### 実機環境
- OS: EndeavourOS / Plasma 6.8.2 / KWin 6.8.2 / Wayland (`WAYLAND_DISPLAY=wayland-1`)
- Qt: 6.12, layer-shell-qt 6.8.2
- 画面: DP-1 1920x1080 @scale 1.0 (0,0), eDP-1 1600x1000 論理 @scale 1.2 (1920,0)
- GPU: Intel Arc (xe ドライバ)
- バッテリー: BAT0 + AC0, 輝度: /sys/class/backlight/intel_backlight
- spectacle の全画面ショットは 7040x2160 (論理 3520x1080 の 2 倍)

---

## 再開時の次のアクション

### 1. デザイン最終ポリッシュ
`docs/DESIGN_STATUS.md` の「途中」項目を ui-designer に渡す。
Theme.qml のトークン経由を維持し、直書きを避ける。

### 2. スクリーンショット更新
```sh
ACTIVENOTCH_START_EXPANDED=1 ./build/activenotch &
sleep 2.5
spectacle -b -n -f -o /tmp/desktop.png
kill %1
# 上部中央を crop して docs/screenshot-expanded.png を更新
```

### 3. AUR 登録
リリース tarball の `sha256sums` を確定してから `packaging/PKGBUILD` を更新する。
```sh
cd packaging
updpkgsums
makepkg -si
```

### 4. リリース確認
```sh
gh release view v1.0.0
```

---

## 重要な技術的知見 (CONTRACT.md §7 にも記録済み)

1. **LayerShellQt リンクターゲット**: `LayerShellQt::Interface`
2. **qt_add_qml_module + QT_RESOURCE_ALIAS**: glob + alias でサブディレクトリ構造を維持
3. **Shell::useLayerShell()**: Qt 6.5+ では不要
4. **ウィンドウは 660x448 固定**: layer-shell リサイズジャンク回避、QML 内部のみアニメ
5. **マスク座標系**: 論理px で渡す (DPR 倍しない)
6. **ブラー**: KWin 6.8 は `org_kde_kwin_blur` 非広告 → `ext_background_effect_v1` を直接バインド
7. **全画面検出**: KWin スクリプト + DBus。`/Scripting` の引数なし `start()` が正
8. **QDBusArgument は const で読む**: 非 const だと書き込み用 overload → SIGABRT
9. **DBusMenu の複合型シグナル**: 署名文字列 overload で接続する
10. **アイコン**: Qt 6.12 の `data:` URL 不具合 → `image://svg/` プロバイダ + `file://` キャッシュ
11. **透過**: `QQuickWindow::setDefaultAlphaBuffer(true)` を最初の QQuickWindow 前に呼ぶ
12. **QML 公開 API 変更禁止**: `objectName "notch"`, `notchState`, `wantsKeyboardFocus`,
    `shapeSettled`, `typeof NotchWindow` ガード
13. **二重起動防止**: D-Bus 名 `dev.yukirawa.activenotch` の所有権で判定
14. **配布**: `config/*.in` を configure_file → `cmake --install --prefix <PREFIX>`

---

## Git 状態
- ブランチ: main
- リモート: https://github.com/yukirawa/Active_Notch (gh CLI 認証済み)
- 最新コミット: Phase 7 = `8a2ac78` / Phase 8 = 本コミット
- タグ: `v1.0.0`
- `build-*/` と `scripts/artifacts/` は `.gitignore` 済み

---

## 作業再開コマンド
```sh
cd /home/yukirawa/Dev/Active_Notch
git status
./scripts/dev.sh              # configure + build
./scripts/run-tests.sh        # 16 スイート
./scripts/verify-ui.sh        # 視覚検証 5 項目
./scripts/run.sh              # 起動
journalctl --user -u activenotch -f
```
