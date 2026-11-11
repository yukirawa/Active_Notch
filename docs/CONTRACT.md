# ActiveNotch 実装契約書 (CONTRACT)

PLAN.md の計画を実装に落とすための全担当者共通の契約。総監督 (architect) が管理し、
Phase 完了ごとに「実装済み」欄を更新する。**契約の変更は総監督の承認が必要**。

---

## 0. 全体原則

- **論理px** = QML ローカル座標 (実機は scale 1.2, 画面 1920x1200 → 論理 1600x1000)
- C++: `src/services/<Name>Service.{h,cpp}`、クラス名 = `<Name>Service`、すべて QObject
- QML: `qml/pages/<Page>.qml` / `qml/components/<Comp>.qml` (型名 = ファイル名)
- 公開 API には日本語コメント必須。UI 文言は **qsTr() 化** (Phase 2 以降の新規文言から。Phase 7 で全洗い出し)
- 追加してよい依存: Qt6 (Quick/Qml/DBus/Network/Test) + KF6 (WindowSystem/ConfigCore/Service/BluezQt/CalendarCore/KHolidays) + layer-shell-qt
  - **wl-clipboard は未導入** → ClipboardService は `QStandardPaths::findExecutable("wl-paste")` で判定し、無ければ `available=false` で機能停止 (クラッシュ禁止)
- サービスは **コンテキストプロパティ** として QML に公開 (名前は §3 の表で固定)
- パース系ロジック (CLI 出力・/proc・sysfs・JSON 解析) は **static 純関数** に分離し `tests/` で単体テスト可能にすること
- サービスの重い処理は非同期 (QTimer / QProcess async / DBus async)。UI スレッドをブロックしない
- すべての外部リソース (DBus / sysfs / CLI) は**失敗時グラaceful退化** (プロパティを unavailable 状態にして表示を隠す)。例外送出で落とさない

## 1. ウィンドウとレイヤー (Phase 0 実装済み + Phase 1 拡張)

- `QQuickView` を `NotchWindow` (C++, QObject 化する) が所有。QML モジュール URI: `dev.yukirawa.activenotch`、ルート型 `Main`
- LayerShell: **AnchorTop のみ** (水平中央寄せ) / **LayerOverlay** / exclusiveZone -1 / margins 0 / closeOnDismissed false
- **Phase 1 以降: ウィンドウは最大サイズ固定 660x448 論理px** (展開パネル 660x440 + 上マージン 8)。
  layer-shell のリサイズはジャンクの原因のため、**ウィンドウはリサイズしない**。開閉アニメは QML 内部のみ
- 背景透明: `setColor(Qt::transparent)` + `QSurfaceFormat::setAlphaBufferSize(8)`
- キーボード: `notch.wantsKeyboardFocus` (pinned のみ true) に応じて `KeyboardInteractivityNone ⇄ KeyboardInteractivityOnDemand` を切替
- **入力領域**: `QQuickView::setMask()` (rounded region)。`notch.shapeSettled` シグナルで更新。
  **pinned 中は全ウィンドウ領域** (外側クリックで解除するため)。それ以外はノッチ形状のみ = 外側クリック透過
- マスクの座標系: 論理px で渡す。scale 1.2 環境で位置ずれが出た場合は DPR 倍率を調査・調整してコメントで明記

## 2. C++ ⇄ QML 結線 (Phase 1)

- `Main.qml` は `Notch { id: notch }` をルート直下に持つ。C++ は `findChild<QQuickItem*>("notch")` で取得
- **Notch.qml の公開 API (C++ が依存する。変更禁止)**:
  - `property string notchState`: `"collapsed" | "expanded" | "pinned"` (NOTIFY 付き)
  - `property bool wantsKeyboardFocus`: pinned のとき true (NOTIFY 付き)
  - `signal shapeSettled(real x, real y, real w, real h, real radius)`
    (Main ルート基準の論理px。起動時に 1 回 + モーフアニメーション完了ごとに発火)
- コンテキストプロパティ `NotchWindow` (NotchWindow 自身): `Q_PROPERTY bool fullscreenActive NOTIFY fullscreenActiveChanged`
  (全画面検出。true で QML 側はノッチを退避表示)。QML では
  `typeof NotchWindow !== "undefined" ? NotchWindow.fullscreenActive : false` のガード付きで参照すること
- main.cpp の順序: サービス生成 → `setContextProperty(...)` → `notch.load()` → `notch.show()`
  (NotchWindow は ctor で QML をロードせず、`load()` を分離すること)

## 3. サービス API 一覧 (Phase 2+ で実装。名前・プロパティは固定)

コンテキストプロパティ名 = 左記の名前。すべて Q_PROPERTY + NOTIFY。

| 名前 (Phase) | クラス / 主プロパティ / メソッド |
|---|---|
| `Config` (2) | ConfigService (KConfig, `~/.config/activenotch/activenotchrc`, PLAN §11 のスキーマ)。`language, anchor, autoHideFullscreen, collapsedWidth, collapsedHeight, expandedWidth, expandedHeight, radiusCollapsed, radiusExpanded, accentColor, opacity, blurEnabled, dnd, statsInterval, batteryInterval, weatherInterval` + `save() load()` |
| `BatteryService` (2) | UPower DBus + `/sys/class/power_supply`。`available, percent, charging, plugged, powerW, timeRemainingText`。バッテリーは 30s + シグナル |
| `AudioService` (2) | `wpctl` (get-volume @DEFAULT_AUDIO_SINK@)。`available, volume, muted, sinkName` + `setVolume(v) toggleMute() step(d)`。UI 表示中 300ms ポール |
| `BrightnessService` (2) | sysfs 読み + logind `org.freedesktop.login1 Session.SetBrightness` 書き。`available, brightness` + `setBrightness(v)` |
| `QuickSettingsService` (2) | `nightLightAvailable, nightLightOn` + `toggleNightLight()`。KWin `org.kde.KWin /org/kde/KWin/NightLight` |
| `CalendarService` (2) | KF6::KHolidays (jp) + QLocale(ja)。`year, monthName, todayText, weekdayLong` + `monthGrid(y, m) → QVariantList {day, inMonth, isToday, isHoliday, holidayName}` |
| `MediaService` (3) | MPRIS over QtDBus (org.mpris.MediaPlayer2.*)。`available, title, artist, album, artUrl, playing, positionMs, lengthMs, canControl, playerName` + `playPause() next() previous() seekMs(ms) setVolumePct(v)`。シグナル駆動 |
| `StatsService` (3) | `/proc/stat` /proc/meminfo, hwmon, Intel GPU sysfs (xe)。`cpuPercent, ramPercent, ramUsedGb, ramTotalGb, tempC, fanRpm, gpuPercent, gpuAvailable`。1s |
| `NetworkService` (4) | NetworkManager DBus。`available, wifiEnabled, state, activeSsid, signalStrength, list` ({ssid,strength,secured,connected,known}) + `setWifiEnabled(b) connectSsid(ssid) disconnect()` |
| `BluetoothService` (4) | KF6::BluezQt。`available, powered, devices` ({name,address,connected,paired,battery}) + `setPowered(b) connectDevice(addr) disconnectDevice(addr)` |
| `WeatherService` (4) | Open-Meteo (API キー不要) + 位置は既定 auto (IP → 緯度経度, キャッシュ)。`available, tempC, code, codeText, windKmh, humidity, locationText, daily` ({date,tmin,tmax,code}) + `refresh() setLocation(s)`。15min |
| `NotificationService` (5) | 自前 `org.freedesktop.Notifications` サーバ。`ownsDaemon, dnd, history` ({id,app,summary,body,ts,urgent}) + `close(id) clearAll() setDnd(b) test()`。登録失敗時 `ownsDaemon=false` で履歴 OFF (ミラーモード) |
| `ClipboardService` (5) | `wl-paste --watch` + `wl-copy`。`available, items` ({id,text,ts}) + `paste(id) remove(id) clearAll() search(s)`。wl-clipboard 無し→available=false |
| `LauncherService` (6) | KF6::Service + XDG。`search(q) → QVariantList` {name, icon, comment, desktopFile, score, type("app"\|"calc")} + `launch(desktopFile)`。あいまい検索 + 簡易計算 (自前パーサ、eval 禁止) |
| `TrayService` (6) | SNI Watcher (org.kde.StatusNotifierWatcher) + dbusmenu。`items` ({id,title,iconSource,status}) + `activate(id) openMenu(id)` + signal `menuReady(id)` → `menuModel(id)` がメニュー構造。失敗時機能 OFF (PLAN の代替案通り) |

## 4. QML ページ構成 (ui-designer 担当)

```
qml/
├── Main.qml        # ルート。Notch { id: notch } を上部中央に配置
├── Notch.qml      # 状態機械 + 外殻 (モーフ対象 background / 時差フェード対象 content)
├── Theme.qml      # デザイントークン singleton
├── components/    # GlassCard, Gauge, IconButton, Marquee, SegmentedList, Toggle ...
└── pages/         # Calendar(2) Quick(2) Battery(2) Sound(2) Media(3) Stats(3)
                   # Network(4) Weather(4) Notifications(5) Clipboard(5)
                   # Launcher(6) Tray(6) Settings(7)
```

- 展開パネル内のナビゲーション: ui-designer が設計 (タブバー or サイドレール)。`Config` でページ有効化
- Collapsed ピルの中身 (PLAN §6): 時刻 + 再生インジケータ (3〜) + 通知バッジ (5〜)
- デザイン: くすみ Frutiger Aero (PLAN §6 トークン継続)。Theme.qml のトークンを必ず経由する (直書き禁止)
- アイコン: SVG data URI または /usr/share/icons/breeze 配下 (存在チェック + フォールバック)。新規システム依存追加禁止

## 5. テスト環境 (ユーザーの明示的な要求。最優先で整備)

- `scripts/dev.sh` … configure + build (警告チェック付き)
- `scripts/run.sh` … Wayland チェック → 必要ならビルド → アプリ起動 (フォアグラウンド)
- `scripts/stop.sh` … `pkill -x activenotch`
- `scripts/verify-ui.sh` … 自動視覚検証: ビルド → `ACTIVENOTCH_PRINT_GEOMETRY=1` で起動 →
  stdout の `GEOMETRY x=.. y=.. w=.. h=.. scale=.. screen=..` (物理px) をパース →
  spectacle で全画面スクリーンショット → magick で (a) 中心配置 (|cx-W/2|≤2) (b) サイズ±2px
  (c) ピル内がデスクトップと異なる色 (d) ピル外周はデスクトップ色 — を検証し PASS/FAIL 表を出力。
  成果物は `scripts/artifacts/` に保存、FAIL 時は非ゼロ exit。trap で確実にアプリ停止
- 環境変数 `ACTIVENOTCH_PRINT_GEOMETRY=1` … NotchWindow が表示時 + ジオメトリ変更時に上記行を stdout 出力
- `tests/` … QtTest 単体テスト (パース純関数中心)。CMake: `enable_testing()` + `qt_add_executable` + `add_test`。
  `scripts/run-tests.sh` → `ctest --test-dir build --output-on-failure`
- README に「テスト手順」セクション (手動テスト: ホバー/クリック/Esc と自動テスト: scripts/) を記載

## 6. ウェーブ (Phase) 実行計画と進捗

| Wave | Phase | coder (C++) | ui-designer (QML) | 状態 |
|---|---|---|---|---|
| 1 | 1 | ウィンドウ固定化・マスク・ブラー・全画面検出・scripts・tests | 状態機械・スプリングモーフ・placeholder パネル・GlassCard | **完了** (b86be8e) |
| 2 | 2 | Config/Battery/Audio/Brightness/QuickSettings/Calendar | Calendar/Quick/Battery/Sound ページ + ナビ/コンポーネント | **完了** (63dc554) |
| 3 | 3 | Media(MPRIS)/Stats | Media/Stats ページ + ナビ/コンポーネント | **完了** (4230ce9) |
| 4 | 4 | Network/Bluetooth/Weather | Network/Weather ページ + ナビ/コンポーネント | **完了** (3683207) |
| 5 | 5 | Notifications/Clipboard | Notifications/Clipboard ページ + ナビ/コンポーネント | **完了** (1157b2d) |
| 6 | 6 | Launcher/Tray(SNI) | Launcher/Tray ページ | **実行中** |
| 5 | 5 | Notifications/Clipboard | Notifications/Clipboard ページ | 未 |
| 6 | 6 | Launcher/Tray(SNI) | Launcher/Tray ページ | 未 |
| 7 | 7 | 設定UI・永続化・i18n (qt_add_translations) | Settings ページ | 未 |
| 8 | 8 | install/uninstall/systemd/PKGBUILD/README | 最終ポリッシュ | 未 |

## 7. 実装済みメモ (Phase 0 の知見・必読)

- CMake リンクターゲットは **`LayerShellQt::Interface`** (LayerShellQt::LayerShellQt は存在しない)
- `qt_add_qml_module` に `qml/Main.qml` 形式で渡す場合 **`QT_RESOURCE_ALIAS`** でディレクトリ部分を除去する必要あり
- `Shell::useLayerShell()` は Qt 6.5 以降不要・非推奨 (Window::get() の紐付けで QPA が自動選択)
- `qt_policy(SET QTP0001 NEW)` を `qt_standard_project_setup()` の後に設定 (author 警告対策)
- Theme.qml は `QT_QML_SINGLETON_TYPE TRUE` を set_source_files_properties で付与済み
- KWin: ブラー有効 (BlurStrength=11)。Wayland セッション = WAYLAND_DISPLAY=wayland-1
- git: main ブランチ、Phase 完了ごとに総監督がコミット (fd1b42c = Phase 0)
