# ActiveNotch 引き継ぎドキュメント (2026-11-12 08:00 頃)

## 現在の状態

### 完了済みフェーズ
| Phase | 内容 | コミット | 状態 |
|-------|------|----------|------|
| 0 | CMake 雛形 + LayerShellQt 最小ピル | fd1b42c | ✅ 完了 |
| 1 | ノッチ外殻・テーマ・開閉アニメ・入力/ブラー/全画面検出・scripts/tests | b86be8e | ✅ 完了 |
| 2 | Config/Battery/Audio/Brightness/QuickSettings/Calendar + 4ページ | 63dc554 | ✅ 完了 |
| 3 | Media(MPRIS)/Stats + 2ページ | 4230ce9 | ✅ 完了 |

### 進行中: Phase 4 (Wave 4)
- **C++ 側**: 完了 (NetworkService/BluetoothService/WeatherService 実装済み・テスト緑)
- **QML 側**: ui-designer サブエージェント実行中 (Network.qml / Weather.qml 作成中)

### 次のフェーズ (Phase 5 以降)
| Phase | 内容 | 状態 |
|-------|------|------|
| 5 | Notifications/Clipboard + ページ | 未着手 |
| 6 | Launcher/Tray(SNI) + ページ | 未着手 |
| 7 | 設定UI・永続化・i18n | 未着手 |
| 8 | install.sh・systemd・PKGBUILD・README | 未着手 |

---

## 実装済みアーキテクチャ概要

### C++ サービス一覧 (src/services/)
| サービス | 依存 | 主な仕様 |
|----------|------|----------|
| ConfigService | KF6ConfigCore | ~/.config/activenotch/activenotchrc, PLAN §11 全項目 |
| BatteryService | UPower DBus + sysfs | 30sポール+シグナル, フォールバック |
| AudioService | wpctl | 300msポール, 操作API |
| BrightnessService | sysfs + logind | QFileSystemWatcher + SetBrightness |
| QuickSettingsService | KWin DBus | NightLight |
| CalendarService | KF6Holidays + QLocale | 日本祝日・月間グリッド |
| MediaService | MPRIS DBus | NameOwnerChanged/PropertiesChanged 購読 |
| StatsService | /proc + hwmon + xe | 1sタイマー, GPU フォールバック |
| **NetworkService** | **NetworkManager DBus** | **Wi-Fi/有線/接続操作** ← Phase 4 新規 |
| **BluetoothService** | **KF6BluezQt** | **アダプタ/デバイス/バッテリー** ← Phase 4 新規 |
| **WeatherService** | **Open-Meteo HTTP** | **IP位置検出・15分キャッシュ** ← Phase 4 新規 |

### QML 構成
```
qml/
├── Main.qml              # ルート (Notch 配置)
├── Notch.qml             # 状態機械・モーフ・TabBar・PageLoader
├── Theme.qml             # デザイントークン (singleton)
├── components/
│   ├── GlassCard.qml     # 基本カード
│   ├── TabBar/TabButton  # ナビゲーション
│   ├── SliderControl     # 音量/輝度スライダー
│   ├── ToggleRow/Switch  # トグル
│   ├── GaugeCircle       # 統計ゲージ
│   ├── StatGaugeCard/InfoCard # Statsページ用
│   ├── MarqueeText       # マーキー文字
│   ├── PageLoader        # 遅延ロード
│   ├── DayCell           # カレンダー日付セル
│   ├── ControlSection    # 設定セクション
│   ├── DetailItem        # 詳細行
│   └── IconButton        # アイコンボタン
└── pages/
    ├── Quick.qml         # NightLight
    ├── Battery.qml       # バッテリーゲージ
    ├── Sound.qml         # 音量/輝度
    ├── Calendar.qml      # 月間グリッド
    ├── Media.qml         # MPRIS 再生制御
    ├── Stats.qml         # CPU/GPU/RAM/温度/ファン
    ├── Network.qml       # ← 作成中 (ui-designer)
    └── Weather.qml       # ← 作成中 (ui-designer)
```

### ビルド/テスト環境
- **CMake**: Qt6 (Quick/Qml/DBus/Test/GuiPrivate/WaylandClientPrivate/Network) + KF6 (ConfigCore/CalendarCore/Holidays/BluezQt) + LayerShellQt::Interface + wayland-client
- **scripts/**: dev.sh, run.sh, stop.sh, verify-ui.sh, run-tests.sh
- **tests/**: 12テストスイート全緑 (RegionUtils, Battery, Audio, Brightness, Calendar, Config, QuickSettings, Media, Stats, Network, Bluetooth, Weather)
- **verify-ui.sh**: 自動視覚検証 (中心±2px/サイズ±2px/色差分) 4項目 PASS

### 実機環境
- OS: EndeavourOS / Plasma 6.8.2 / KWin 6.8.2 / Wayland (WAYLAND_DISPLAY=wayland-1)
- Qt: 6.12, layer-shell-qt 6.8.2
- 画面: DP-2 1920x1080 @scale 1.0 (当初想定 eDP-1 1920x1200@1.2 と異なる)
- GPU: Intel Arc (xe ドライバ)
- バッテリー: BAT0 + AC0, 輝度: /sys/class/backlight/intel_backlight

---

## 再開時の次のアクション

### 1. ui-designer 完了待ち・レビュー
- `Network.qml` / `Weather.qml` の完成確認
- qmllint / ビルド / 視覚検証実行

### 2. Phase 4 コミット・push
```bash
git add -A
git commit -m "Phase 4: ネットワーク/Bluetooth/天気"
git push origin main
```

### 3. Phase 5 着手 (並列投入)
**C++ (coder):**
- NotificationService (自前 org.freedesktop.Notifications サーバ, 履歴/DND/ミラー)
- ClipboardService (wl-paste --watch + wl-copy, available=false グレースフル)

**QML (ui-designer):**
- Notifications.qml (履歴/削除/全消去/DNDトグル)
- Clipboard.qml (履歴一覧/検索/貼付/削除)

### 4. 以降同様に Phase 6→8 まで自動進行

---

## 重要な技術的知見 (CONTRACT.md §7 にも記録済み)

1. **LayerShellQt リンクターゲット**: `LayerShellQt::Interface` (LayerShellQt::LayerShellQt は存在しない)
2. **qt_add_qml_module + QT_RESOURCE_ALIAS**: サブディレクトリ構造維持のため glob + alias で登録
3. **Shell::useLayerShell()**: Qt 6.5+ では不要
4. **ウィンドウは 660x448 固定**: layer-shell リサイズジャンク回避、QML 内部のみアニメ
5. **マスク座標系**: 論理px で渡す (DPR 倍しない、実機で中央一致確認済み)
6. **ブラー**: KWin 6.8 は `org_kde_kwin_blur` 非広告、`ext_background_effect_v1` を直接バインド (BlurHelper)
7. **全画面検出**: KWin スクリプト + DBus (dev.yukirawa.activenotch), `/Scripting/Script<id>` の `run()` ではなく `/Scripting` の引数なし `start()` が正
8. **QML 公開 API 変更禁止**: `Notch.qml` の `objectName "notch"`, `notchState`, `wantsKeyboardFocus`, `shapeSettled`, `typeof NotchWindow` ガード

---

## Git 状態
- ブランチ: main
- リモート: https://github.com/yukirawa/Active_Notch (gh CLI 認証済み)
- 最新コミット: 4230ce9 (Phase 3)

---

## 作業再開コマンド
```bash
cd /home/yukirawa/Dev/Active_Notch
git status                    # 変更確認
./scripts/run-tests.sh        # 全テスト実行
./scripts/verify-ui.sh        # 視覚検証
# ui-designer 完了後:
# git add -A && git commit -m "Phase 4: ..." && git push origin main
```

---

**注意**: ユーザーは就寝→登校中。朝の 1 限目授業で PC 使用時に再開予定。