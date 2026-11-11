# ActiveNotch — 実装計画書

KDE Plasma 6 (Wayland / KWin) に最適化した、画面上部中央に張り付く多機能ノッチ。
Qt6 + QML + LayerShellQt による単体常駐アプリ。日本語UI標準対応。

- ステータス: **計画確定 / 実装未着手**
- 対象: このPC (EndeavourOS / Plasma 6.8.2 / KWin 6.8.2 / Wayland)

---

## 1. ゴールとコンセプト

macOS の Dynamic Island / ノッチのように、**画面上部中央に常駐し、普段は小さく、必要なときだけ大きく展開する**情報ハブ。

- **滑らか**: スプリング系アニメーションで物理的な手触り
- **使いやすい**: ホバーで展開、クリックで固定、全画面時は自動退避
- **日本語対応**: UI・曜日・祝日・フォントまで日本語前提
- **情報量が多い**: メディア / 統計 / 電源 / 音・明るさ / 時計・暦 / 通知 / ネット / 天気 / クイック設定 / クリップボード / ランチャー / トレイ

### デザイン方向性(確定)
- 画面上端に**密着するノッチ**形状(折りたたみ時は上端フラット・下側角丸)
- **くすみ系 Frutiger Aero のやわらかい版**: 淡いアクア〜グレーのグラデーション、柔らかいスペキュラハイライト、控えめな発光ボーダー
- 展開時は**すりガラス越しに背景が透ける**(KWin ブラー)

---

## 2. 対象環境(実機調査済み)

| 項目 | 値 |
|---|---|
| OS | EndeavourOS (Arch系, rolling) |
| セッション | KDE Plasma 6.8.2 / KWin 6.8.2 / Wayland |
| 機材 | ASUS Zenbook 14 UX3405CA |
| CPU | Intel Core Ultra 9 285H (Arrow Lake-H) |
| GPU | Intel Arc (Arrow Lake-P) — `xe` ドライバ系 |
| 画面 | eDP-1 1920x1200 / scale 1.2 → 論理 1600x1000 |
| 電源 | BAT0 + AC0 (UPower あり) |
| 輝度 | `/sys/class/backlight/intel_backlight` |
| 温度/ファン | hwmon: `coretemp`, `acpi_fan`, `asus`, `nvme`, `iwlwifi` |
| フォント | Noto Sans CJK (JP 明示指定が必要) |

### 利用可能なライブラリ/CLI(導入済み)
- Qt6: `qt6-base`, `qt6-declarative`, `qt6-wayland`, `qt6-svg`, `qt6-multimedia`, `qt6-charts`, `qt6-sensors`
- KF6: `kwindowsystem`, `kconfig`, `kcoreaddons`, `ki18n`, `knotifications`, `kservice`, `kpackage`, `KF6BluezQt`, `KF6CalendarCore`, `KF6Declarative`, `KF6ColorScheme`
- `layer-shell-qt`, `plasma-workspace`, `kirigami`
- CLI: `wpctl`, `pactl`, `nmcli`, `bluetoothctl`, `upower`, `sensors`, `gio`, `qdbus6`, `busctl`, `kstart`
- KWin: ブラー有効(BlurStrength=11)、`org_kde_kwin_blur` 利用可、DBus 経由で NightLight 等を操作可

### 未導入(追加候補 → 自動導入でOK)
- `wl-clipboard` (クリップボード履歴に必須)
- `intel-gpu-tools` (Arc GPU 統計のフォールバック用、任意)
- `extra-cmake-modules` (ビルド時、要確認)

---

## 3. 技術スタックと選定理由

| 領域 | 採用 | 理由 |
|---|---|---|
| シェル | Qt6 Quick (QML) | 滑らかな宣言的アニメ、KDE との親和性 |
| 配置 | LayerShellQt | KWin が `wlr-layer-shell` 対応。中央上部のオーバーレイが容易 |
| ブラー | `org_kde_kwin_blur` + `KWindowEffects` | Plasma パネルと同じ背景ブラー |
| メディア | MPRIS over QtDBus | 追加依存なし、全プレイヤー対応 |
| 通知 | 自前 `org.freedesktop.Notifications` サーバ | 履歴/DND/グループ化を完全制御(確定) |
| Bluetooth | `KF6BluezQt` | 自前DBus実装を回避 |
| ネットワーク | NetworkManager DBus(`nmcli` フォールバック) | 確実 |
| 音声 | PipeWire (`wpctl`/`pactl`) | 環境に存在 |
| バッテリー | UPower DBus + sysfs | 確実 |
| 統計 | `/proc` + hwmon + Intel GPU sysfs | 追加依存なし優先 |
| 天気 | Open-Meteo | APIキー不要 |
| クリップボード | `wl-clipboard` (`wl-paste --watch`) | Wayland 標準的手法 |
| ランチャー | KF6Service + XDG スキャン | 既存資産活用 |
| トレイ | StatusNotifierItem ホスト (SNI Watcher + DBusMenu) | 標準規格 |
| 設定 | KConfig (`~/.config/activenotch/`) | KF6 |
| i18n | Qt Linguist (`ja` 既定 / `en`) | 標準 |

---

## 4. アーキテクチャ

```
┌─────────────────────────────── QML (UI) ───────────────────────────────┐
│  main.qml → Notch.qml (状態機械) → pages/* (12機能) → components/*      │
│      ↑ Theme.qml (デザイントークン)   ↑ Behavior/SpringAnimation        │
└───────────────────────────────┬────────────────────────────────────────┘
                                │ context property / singleton
┌───────────────────────────────▼────────────────────────────────────────┐
│  C++ バックエンド (src/services/*)                                       │
│  MediaService  SystemStatsService  BatteryService  AudioService          │
│  BrightnessService  NotificationService  NetworkService  BluetoothService│
│  WeatherService  ClipboardService  LauncherService  TrayService          │
│  QuickSettingsService  ConfigService                                     │
└───────────────────────────────┬────────────────────────────────────────┘
                                │
        DBus / sysfs / /proc / CLI / KWin プロトコル / HTTP
```

- **NotchWindow** (`src/NotchWindow.cpp`): LayerShellQt 設定、入領域マスク、ブラー領域、全画面検出、マルチDPR対応
- 各サービスは `QObject` として QML に公開。`Q_PROPERTY` + `NOTIFY` でリアクティブ更新
- 更新間隔はサービスごとに設定可(既定: 統計1s / バッテリー30s / 天気15min / メディアはシグナル駆動)

---

## 5. ディレクトリ構成(予定)

```
Active_Notch/
├── CMakeLists.txt
├── README.md                 # 日本語
├── LICENSE                   # GPL-3.0
├── install.sh / uninstall.sh # 依存自動導入 + ビルド + 配置 + systemd
├── packaging/PKGBUILD        # AUR 用
├── src/
│   ├── main.cpp
│   ├── NotchWindow.{h,cpp}
│   ├── BlurHelper.{h,cpp}
│   ├── ConfigService.{h,cpp}
│   └── services/
│       ├── MediaService.{h,cpp}
│       ├── SystemStatsService.{h,cpp}
│       ├── BatteryService.{h,cpp}
│       ├── AudioService.{h,cpp}
│       ├── BrightnessService.{h,cpp}
│       ├── NotificationService.{h,cpp}
│       ├── NetworkService.{h,cpp}
│       ├── BluetoothService.{h,cpp}
│       ├── WeatherService.{h,cpp}
│       ├── ClipboardService.{h,cpp}
│       ├── LauncherService.{h,cpp}
│       ├── TrayService.{h,cpp}
│       └── QuickSettingsService.{h,cpp}
├── qml/
│   ├── main.qml
│   ├── Notch.qml
│   ├── theme/Theme.qml
│   ├── components/  GlassCard Pill Gauge IconButton Marquee SegmentedList Toggle ...
│   └── pages/       Media Stats Battery Sound Calendar Notifications
│                    Network Weather Quick Clipboard Launcher Tray
├── i18n/{ja,en}.ts
├── config/
│   ├── dev.yukirawa.activenotch.desktop   # 自動起動
│   └── activenotch.service                # systemd --user
└── tests/                                  # サービス単体の最小テスト
```

---

## 6. UI / UX 仕様

### 状態機械
```
        hover
Collapsed ──────► Expanded ──(click)──► Pinned
   ▲   │              │                    │
   │   └──(leave)─────┘                    │
   └──────────(leave / click / Esc)────────┘
```
- **Collapsed**: 上端密着ピル。時刻(HH:MM) + 再生インジケータ(再生中は小さなイコライザ) + 通知バッジ
- **Expanded**: 下方向へ展開。マウスが外れたら収納
- **Pinned**: クリックで固定。`Esc` / 外側クリック / 再クリックで解除
- **Auto-hide on fullscreen**: KWin DBus `queryWindowInfo` で全画面検出 → 自動退避

### ジオメトリ(論理px, 論理画面 1600x1000)
- Collapsed: 幅 ~220 / 高さ ~30、上端 y=0、下側角丸 16
- Expanded: 幅 ~660 / 高さ ~440、角丸 28、上マージン 8(浮遊感)
- DPI スケールに追従。サイズは設定で変更可

### アニメーション
- 形状モーフ: `SpringAnimation`(mass/spring/damping) or `NumberAnimation` + `Easing.OutBack`
- 内容: 時差フェード + 下方向スライド(20–40ms ずつずらす)
- 数値/ゲージ: スムーズ補間(Behavior)
- アイコン: ホバーで微拡大・発光
- **ウィンドウ自体はリサイズしない**(layer-shell のリサイズはジャンクの原因)。最大サイズ固定で QML 内部をアニメし、入力領域/ブラー領域のみ形状に追従させる

### デザイントークン(Theme.qml, くすみ Frutiger Aero)
- ベース: 半透明ダーク (`#0E1518` α 0.62〜0.78) に淡いアクアのグラデ
- アクセント: くすんだティール/アクア (`#7FB8B0` 系) + 設定で変更可
- ハイライト: 上端に柔らかいスペキュラ(白 α 0.10〜0.18)
- ボーダー: 1px の淡い発光 (`#BFE6E0` α 0.25)
- 角丸: collapsed 16 / expanded 28
- 影: 柔らかい多層ドロップシャドウ
- フォント: `Noto Sans CJK JP`(明示)、本文 13–14px

---

## 7. 機能仕様(各ページ / サービス)

| 機能 | 取得元 | 主な操作 | 更新 |
|---|---|---|---|
| メディア (MPRIS) | `org.mpris.MediaPlayer2.*` | 再生/停止/前後/シーク/音量、アートワーク表示 | シグナル駆動 |
| システム統計 | `/proc/stat`, `/proc/meminfo`, hwmon, Intel GPU sysfs | CPU/GPU/RAM/温度/ファンのゲージ、グラフ | 1s |
| バッテリー・電源 | UPower + `/sys/class/power_supply` | 残量/充電状態/消費W/残り時間、省電力切替 | 30s |
| 音量・明るさ | PipeWire(`wpctl`), `intel_backlight` | スライダー、ホイール、ミュート | 変化時 |
| 時計・カレンダー | システム時刻 + `KF6CalendarCore` | 月間カレンダー、曜日/祝日(日本語) | 1s / 日次 |
| 通知センター | 自前 `org.freedesktop.Notifications` | 履歴、削除、全消去、DND 切替 | シグナル |
| ネットワーク | NetworkManager DBus | Wi-Fi 一覧/接続、有線状態、強度 | 変化時 |
| Bluetooth | `KF6BluezQt` | デバイス一覧/接続/切断、ペアリング | 変化時 |
| 天気 | Open-Meteo HTTP | 現在の気温/天気アイコン/週間(任意) | 15min |
| クイック設定 | 各種 | Wi-Fi/BT/夜間モード/機内モード/DND トグル | 変化時 |
| クリップボード履歴 | `wl-paste --watch` + `wl-copy` | 履歴一覧/検索/貼付/削除 | 変化時 |
| アプリランチャー | XDG `.desktop` + KF6Service | 起動、あいまい検索、簡易計算 | オンデマンド |
| トレイ | StatusNotifierItem (SNI) | アイコン表示、左クリック起動、右クリックメニュー | シグナル |

補足:
- 夜間モードは KWin `org.kde.KWin.NightLight` DBus を操作
- 機内モードは rfkill / NetworkManager 経由

---

## 8. 技術的課題と対策

| 課題 | 対策 |
|---|---|
| 背景ブラー | `org_kde_kwin_blur` を Qt Wayland クライアント拡張で実装。`KWindowEffects`(kwindowsystem) を第一候補、失敗時は素の半透明へ自動フォールバック。ブラー領域はノッチ形状のみ |
| 入力透過 | layer-shell サーフェスに `wl_surface.set_input_region`。ノッチ外形のみ操作可能、外側は背後へクリック透過。アニメ中は形状に追従(スロットル) |
| layer-shell リサイズのジャンク | ウィンドウは最大サイズ固定、QML 内部のみアニメ |
| Intel Arc GPU 統計 | `xe` ドライバの sysfs を探索し、無ければ `intel_gpu_top -J`(intel-gpu-tools) をフォールバック。それも無ければ GPU 項目を非表示 |
| 通知デーモン乗っ取り | 自前サーバを提供し、Plasma 標準通知を無効化(設定/スクリプトで案内)。競合時は自前を諦めてミラーへフォールバック可能にする |
| トレイ (SNI) | `org.kde.StatusNotifierWatcher` を実装してアイテムをホスト。右クリックメニューは `com.canonical.dbusmenu` を描画。最も重い実装 → Phase 6 に隔離 |
| マルチ DPI / 複数出力 | アクティブ出力のスケールを取得し QML へ伝播。出力変更に追従 |
| フォント | `Noto Sans CJK JP` を明示指定(既定の fc-match は KR を返すため) |
| 権限 | 輝度は video グループ等が必要な場合あり。install.sh で `usermod -aG video` を案内 |

---

## 9. 依存関係

### ビルド時
`cmake`, `ninja`, `gcc`/`clang`, `extra-cmake-modules`(要確認), Qt6 (Base/Declarative/Wayland/Svg/Multimedia), `layer-shell-qt`, KF6 (WindowSystem/Config/CoreAddons/I18n/Notifications/Service/BluezQt/CalendarCore)

### 実行時
上記 + `wireplumber`(wpctl), `networkmanager`, `bluez`, `upower`, `lm_sensors`, `wl-clipboard`(追加), `noto-fonts-cjk`, 任意で `intel-gpu-tools`

### 導入方針
`install.sh` が pacman/yay で不足分を自動導入(確定)。`--no-deps` でスキップ可。

---

## 10. 実装フェーズ

| Phase | 内容 | 完了条件 |
|---|---|---|
| **0** | CMake 雛形 + LayerShellQt で上部中央ピル表示 | KWin 上に透過ピルが中央上部に出る |
| **1** | ノッチ外殻・テーマ・開閉アニメ・入力/ブラー領域・ホバー/固定 | 見た目と挙動が完成、外側クリック透過 |
| **2** | 時計/カレンダー・クイックトグル・バッテリー・音量/輝度 | 基本情報が動く |
| **3** | メディア(MPRIS)・システム統計 | 再生制御と統計が動く |
| **4** | ネットワーク/Bluetooth・天気 | 接続操作と天気表示 |
| **5** | 通知センター(自前デーモン)・クリップボード履歴 | 通知受信/履歴/貼付 |
| **6** | アプリランチャー・トレイ(SNI) | 起動とトレイ表示 |
| **7** | 設定UI・永続化・i18n・アニメ磨き込み | 設定が保存され ja/en 切替 |
| **8** | install.sh・systemd --user・自動起動・PKGBUILD・README | ワンコマンド導入、AUR 登録可能 |

各 Phase 完了時に動作確認できる状態でコミット。

---

## 11. 設定項目(config schema 予定)

```ini
[General]
Language=ja
Anchor=top            ; top | top-left | top-right
ReserveSpace=false    ; オーバーレイ既定
AutoHideFullscreen=true

[Geometry]
CollapsedWidth=220
CollapsedHeight=30
ExpandedWidth=660
ExpandedHeight=440
CornerRadiusCollapsed=16
CornerRadiusExpanded=28

[Theme]
AccentColor=#7FB8B0
Opacity=0.72
Blur=true
MutedAero=true        ; くすみ Frutiger Aero

[Pages]
Enabled=media,stats,battery,sound,calendar,notifications,network,weather,quick,clipboard,launcher,tray

[Weather]
Location=auto         ; auto(IP) | 緯度,経度 | 都市名
Unit=metric

[Notifications]
OwnDaemon=true
DoNotDisturb=false
MaxHistory=100

[Intervals]
Stats=1000
Battery=30000
Weather=900000
```

---

## 12. 国際化 (i18n)

- 全 UI 文言を `qsTr()` 化、`i18n/ja.ts`(既定) / `i18n/en.ts` を同梱
- `lrelease` で `.qm` を生成しリソースに埋め込み
- 曜日・祝日は `QLocale(ja_JP)` + 祝日テーブル(任意)

---

## 13. 配布

- `install.sh`: 依存自動導入 → CMake ビルド → `/usr/local`(or `~/.local`)配置 → デスクトップエントリ → systemd `--user` 有効化 → 輝度権限の案内
- `uninstall.sh`: 逆操作
- `packaging/PKGBUILD`: AUR 登録可能なビルド定義
- `README.md`: 日本語で導入手順・設定・トラブルシュート

---

## 14. リスクと代替案

| リスク | 代替 |
|---|---|
| KWin のブラーが layer-shell 面に効かない | 半透明のみ(視認性は維持) / KWin ウィンドウルールでブラー強制 |
| Intel Arc GPU 統計が取れない | GPU 項目を非表示、または `intel-gpu-tools` 依存 |
| SNI トレイが重い/不安定 | Plasma トレイに委譲し、ノッチからは非表示(設定でOFF) |
| 自前通知が Plasma と競合 | 設定でミラー方式へ切替、または通知機能OFF |
| layer-shell 入力領域のちらつき | アニメ完了時にまとめて更新 |

---

## 15. 未確定・今後の決定事項

- ライセンス: 既定 GPL-3.0(変更可)
- アプリID / 逆ドメイン名: 既定 `dev.yukirawa.activenotch`(変更可)
- アクセント色の初期値(くすみアクアで良いか)
- トレイを Phase 6 で実装するか、Plasma に委譲するか
- マルチモニタ時に全出力へ出すか、アクティブ出力のみか

---

_この計画に沿って Phase 0 から実装を開始できます。_
