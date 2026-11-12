cmake_minimum_required(VERSION 3.25)

project(ActiveNotch
    VERSION 0.1.0
    DESCRIPTION "Plasma 6 (Wayland / KWin) 用 Dynamic Island 風ノッチ"
    LANGUAGES CXX
)

# ---------------------------------------------------------------------------
# 言語設定 (C++20)
# ---------------------------------------------------------------------------
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# ---------------------------------------------------------------------------
# 依存関係
# ---------------------------------------------------------------------------
# LayerShellQt の CMakeConfig は Qt6Gui にのみ find_dependency するため、
# extra-cmake-modules (ECM) は不要 (実機 layer-shell-qt 6.8.2-1 で確認済み)。
#
# Phase 7 追加分 (i18n):
#   - KF6I18n            : 翻訳ランタイム (KLocalizedString 等)

set(QT_NO_PRIVATE_MODULE_WARNING ON)
find_package(Qt6 REQUIRED COMPONENTS
    Quick Qml DBus Test GuiPrivate WaylandClientPrivate Network LinguistTools Svg)

# 注意: リンクターゲットは LayerShellQt::Interface。
# (LayerShellQt::LayerShellQt というターゲットは存在しない)
find_package(LayerShellQt REQUIRED)

# BlurHelper が libwayland-client を直接使う (ext_background_effect_v1)。
find_package(PkgConfig REQUIRED)
pkg_check_modules(WAYLAND_CLIENT REQUIRED IMPORTED_TARGET wayland-client)

find_package(KF6Config REQUIRED)
find_package(KF6CalendarCore REQUIRED)
find_package(KF6Holidays REQUIRED)
find_package(KF6BluezQt REQUIRED)
find_package(KF6Service REQUIRED)
find_package(KF6I18n REQUIRED)
# KF6Package は ECM (extra-cmake-modules) を必要とし、環境によって未導入の可能性があるため
# .desktop パースは手動実装 (parseDesktopFileManual) で代替し、KF6Package はオプションとする
# find_package(KF6Package REQUIRED)

# KF6Service 利用可能フラグ
add_compile_definitions(HAVE_KF6_SERVICE=1)

qt_standard_project_setup()

# QML モジュールのリソースプレフィックスを :/qt/qml/ に統一する
# (qt_add_qml_module の author 警告を抑制)。
qt_policy(SET QTP0001 NEW)

# qml/components/ などのサブディレクトリにも qmldir を生成する
# (QTP0004: 追加ディレクトリの qmldir 不足警告を抑制)。
qt_policy(SET QTP0004 NEW)

# ---------------------------------------------------------------------------
# QML ファイル
# ---------------------------------------------------------------------------
# qml/ 配下は ui-designer が並行して追加するため、明示列挙ではなく
# 再帰 glob + QT_RESOURCE_ALIAS で登録する (サブディレクトリ構造は維持)。
# CONFIGURE_DEPENDS により新規ファイル追加時は次回ビルドで再 configure される。
file(GLOB_RECURSE ACTIVE_NOTCH_QML_FILES CONFIGURE_DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/qml/*.qml"
)
list(SORT ACTIVE_NOTCH_QML_FILES)

foreach(qml_file IN LISTS ACTIVE_NOTCH_QML_FILES)
    file(RELATIVE_PATH qml_relative
        "${CMAKE_CURRENT_SOURCE_DIR}/qml" "${qml_file}")
    # qml/Main.qml → Main.qml / qml/components/GlassCard.qml →
    # components/GlassCard.qml (qml/ のみ除去する)。
    set_source_files_properties("${qml_file}" PROPERTIES
        QT_RESOURCE_ALIAS "${qml_relative}")
endforeach()

# Theme.qml は pragma Singleton のため QT_QML_SINGLETON_TYPE を付与する。
set_source_files_properties("${CMAKE_CURRENT_SOURCE_DIR}/qml/Theme.qml"
    PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

# ---------------------------------------------------------------------------
# 実行ファイル
# ---------------------------------------------------------------------------
qt_add_executable(activenotch
    src/main.cpp
    src/NotchWindow.cpp
    src/RegionUtils.cpp
    src/BlurHelper.cpp
    src/FullscreenDetector.cpp
    src/SvgIconProvider.cpp
    src/services/ConfigService.cpp
    src/services/BatteryService.cpp
    src/services/AudioService.cpp
    src/services/BrightnessService.cpp
    src/services/QuickSettingsService.cpp
    src/services/CalendarService.cpp
    src/services/MediaService.cpp
    src/services/StatsService.cpp
    src/services/NetworkService.cpp
    src/services/BluetoothService.cpp
    src/services/WeatherService.cpp
    src/services/NotificationService.cpp
    src/services/ClipboardService.cpp
    src/services/LauncherService.cpp
    src/services/TrayService.cpp
)

# QML モジュール URI は src/NotchWindow.cpp の kQmlModuleUri と一致させること。
qt_add_qml_module(activenotch
    URI dev.yukirawa.activenotch
    VERSION 1.0
    QML_FILES
        ${ACTIVE_NOTCH_QML_FILES}
)

# ---- i18n: 翻訳ファイル生成 (Phase 7) --------------------------------------
# ソース内の qsTr() を抽出して .ts を更新し、ビルド時に .qm を生成・リソースに埋め込む
# 翻訳ファイルは i18n/ 配下に配置 (ja_JP.ts, en_US.ts)
# 注意: オプションは LUPDATE_OPTIONS / LRELEASE_OPTIONS で渡す。
# 以前 `OPTIONS -no-obsolete` と書いたため lupdate が引数を TS ファイル名として
# 解釈し、リポジトリ直下に空の TS ファイル (-no-obsolete / OPTIONS /
# QM_FILES_INSTALL_DIR) が生成されていた。
qt_add_translations(activenotch
    TS_FILES
        i18n/ja_JP.ts
        i18n/en_US.ts
    LUPDATE_OPTIONS -no-obsolete
)

target_include_directories(activenotch PRIVATE src)

target_link_libraries(activenotch PRIVATE
    Qt6::Quick
    Qt6::Svg
    Qt6::DBus
    Qt6::Network
    Qt6::GuiPrivate
    Qt6::WaylandClientPrivate
    LayerShellQt::Interface
    PkgConfig::WAYLAND_CLIENT
    KF6::ConfigCore
    KF6::CalendarCore
    KF6::Holidays
    KF6::BluezQt
    KF6::Service
    KF6::I18n
)

# ---------------------------------------------------------------------------
# 単体テスト (Phase 1 + Phase 2)
# ---------------------------------------------------------------------------
enable_testing()

qt_add_executable(tst_regionutils
    tests/tst_regionutils.cpp
    src/RegionUtils.cpp
)
target_include_directories(tst_regionutils PRIVATE src)
target_link_libraries(tst_regionutils PRIVATE
    Qt6::Test
    Qt6::Gui
)
set_target_properties(tst_regionutils PROPERTIES AUTOMOC ON)

add_test(NAME tst_regionutils COMMAND tst_regionutils)

# Phase 2 サービスの純粋関数テスト
qt_add_executable(tst_batteryservice
    tests/tst_batteryservice.cpp
    src/services/BatteryService.cpp
)
target_include_directories(tst_batteryservice PRIVATE src)
target_link_libraries(tst_batteryservice PRIVATE
    Qt6::Test
    Qt6::Core
    Qt6::DBus
)
set_target_properties(tst_batteryservice PROPERTIES AUTOMOC ON)
add_test(NAME tst_batteryservice COMMAND tst_batteryservice)

qt_add_executable(tst_audioservice
    tests/tst_audioservice.cpp
    src/services/AudioService.cpp
)
target_include_directories(tst_audioservice PRIVATE src)
target_link_libraries(tst_audioservice PRIVATE
    Qt6::Test
    Qt6::Core
)
set_target_properties(tst_audioservice PROPERTIES AUTOMOC ON)
add_test(NAME tst_audioservice COMMAND tst_audioservice)

qt_add_executable(tst_brightnessservice
    tests/tst_brightnessservice.cpp
    src/services/BrightnessService.cpp
)
target_include_directories(tst_brightnessservice PRIVATE src)
target_link_libraries(tst_brightnessservice PRIVATE
    Qt6::Test
    Qt6::Core
    Qt6::DBus
)
set_target_properties(tst_brightnessservice PROPERTIES AUTOMOC ON)
add_test(NAME tst_brightnessservice COMMAND tst_brightnessservice)

qt_add_executable(tst_calendarservice
    tests/tst_calendarservice.cpp
    src/services/CalendarService.cpp
)
target_include_directories(tst_calendarservice PRIVATE src)
target_link_libraries(tst_calendarservice PRIVATE
    Qt6::Test
    Qt6::Core
    KF6::Holidays
)
set_target_properties(tst_calendarservice PROPERTIES AUTOMOC ON)
add_test(NAME tst_calendarservice COMMAND tst_calendarservice)

qt_add_executable(tst_configservice
    tests/tst_configservice.cpp
    src/services/ConfigService.cpp
)
target_include_directories(tst_configservice PRIVATE src)
target_link_libraries(tst_configservice PRIVATE
    Qt6::Test
    Qt6::Core
    Qt6::Gui
    KF6::ConfigCore
)
set_target_properties(tst_configservice PROPERTIES AUTOMOC ON)
add_test(NAME tst_configservice COMMAND tst_configservice)

qt_add_executable(tst_quicksettingsservice
    tests/tst_quicksettingsservice.cpp
    src/services/QuickSettingsService.cpp
)
target_include_directories(tst_quicksettingsservice PRIVATE src)
target_link_libraries(tst_quicksettingsservice PRIVATE
    Qt6::Test
    Qt6::Core
    Qt6::DBus
)
set_target_properties(tst_quicksettingsservice PROPERTIES AUTOMOC ON)
add_test(NAME tst_quicksettingsservice COMMAND tst_quicksettingsservice)

# Phase 3 サービスの純粋関数テスト
qt_add_executable(tst_mediaservice
    tests/tst_mediaservice.cpp
    src/services/MediaService.cpp
)
target_include_directories(tst_mediaservice PRIVATE src)
target_link_libraries(tst_mediaservice PRIVATE
    Qt6::Test
    Qt6::Core
    Qt6::DBus
)
set_target_properties(tst_mediaservice PROPERTIES AUTOMOC ON)
add_test(NAME tst_mediaservice COMMAND tst_mediaservice)

qt_add_executable(tst_statsservice
    tests/tst_statsservice.cpp
    src/services/StatsService.cpp
)
target_include_directories(tst_statsservice PRIVATE src)
target_link_libraries(tst_statsservice PRIVATE
    Qt6::Test
    Qt6::Core
)
set_target_properties(tst_statsservice PROPERTIES AUTOMOC ON)
add_test(NAME tst_statsservice COMMAND tst_statsservice)

# Phase 4 サービスの純粋関数テスト
qt_add_executable(tst_networkservice
    tests/tst_networkservice.cpp
    src/services/NetworkService.cpp
)
target_include_directories(tst_networkservice PRIVATE src)
target_link_libraries(tst_networkservice PRIVATE
    Qt6::Test
    Qt6::Core
    Qt6::DBus
)
set_target_properties(tst_networkservice PROPERTIES AUTOMOC ON)
add_test(NAME tst_networkservice COMMAND tst_networkservice)

qt_add_executable(tst_bluetoothservice
    tests/tst_bluetoothservice.cpp
    src/services/BluetoothService.cpp
)
target_include_directories(tst_bluetoothservice PRIVATE src)
target_link_libraries(tst_bluetoothservice PRIVATE
    Qt6::Test
    Qt6::Core
    Qt6::DBus
)
set_target_properties(tst_bluetoothservice PROPERTIES AUTOMOC ON)
add_test(NAME tst_bluetoothservice COMMAND tst_bluetoothservice)

qt_add_executable(tst_weatherservice
    tests/tst_weatherservice.cpp
    src/services/WeatherService.cpp
)
target_include_directories(tst_weatherservice PRIVATE src)
target_link_libraries(tst_weatherservice PRIVATE
    Qt6::Test
    Qt6::Core
    Qt6::Network
)
set_target_properties(tst_weatherservice PROPERTIES AUTOMOC ON)
add_test(NAME tst_weatherservice COMMAND tst_weatherservice)

# Phase 5 サービスの純粋関数テスト
qt_add_executable(tst_notificationservice
    tests/tst_notificationservice.cpp
    src/services/NotificationService.cpp
)
target_include_directories(tst_notificationservice PRIVATE src)
target_link_libraries(tst_notificationservice PRIVATE
    Qt6::Test
    Qt6::Core
    Qt6::DBus
)
set_target_properties(tst_notificationservice PROPERTIES AUTOMOC ON)
add_test(NAME tst_notificationservice COMMAND tst_notificationservice)

qt_add_executable(tst_clipboardservice
    tests/tst_clipboardservice.cpp
    src/services/ClipboardService.cpp
)
target_include_directories(tst_clipboardservice PRIVATE src)
target_link_libraries(tst_clipboardservice PRIVATE
    Qt6::Test
    Qt6::Core
)
set_target_properties(tst_clipboardservice PROPERTIES AUTOMOC ON)
add_test(NAME tst_clipboardservice COMMAND tst_clipboardservice)

# Phase 6 サービスの純粋関数テスト
qt_add_executable(tst_launcherservice
    tests/tst_launcherservice.cpp
    src/services/LauncherService.cpp
)
target_include_directories(tst_launcherservice PRIVATE src)
target_link_libraries(tst_launcherservice PRIVATE
    Qt6::Test
    Qt6::Core
    KF6::Service
    KF6::ConfigCore
)
set_target_properties(tst_launcherservice PROPERTIES AUTOMOC ON)
add_test(NAME tst_launcherservice COMMAND tst_launcherservice)

qt_add_executable(tst_trayservice
    tests/tst_trayservice.cpp
    src/services/TrayService.cpp
)
target_include_directories(tst_trayservice PRIVATE src)
target_link_libraries(tst_trayservice PRIVATE
    Qt6::Test
    Qt6::Core
    Qt6::DBus
    Qt6::Gui
)
set_target_properties(tst_trayservice PROPERTIES AUTOMOC ON)
add_test(NAME tst_trayservice COMMAND tst_trayservice)

# ---------------------------------------------------------------------------
# 警告 (Phase 0 の完了条件: -Wall -Wextra で警告ゼロ)
# ---------------------------------------------------------------------------
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(activenotch PRIVATE -Wall -Wextra)
    target_compile_options(tst_regionutils PRIVATE -Wall -Wextra)
    target_compile_options(tst_batteryservice PRIVATE -Wall -Wextra)
    target_compile_options(tst_audioservice PRIVATE -Wall -Wextra)
    target_compile_options(tst_brightnessservice PRIVATE -Wall -Wextra)
    target_compile_options(tst_calendarservice PRIVATE -Wall -Wextra)
    target_compile_options(tst_configservice PRIVATE -Wall -Wextra)
    target_compile_options(tst_quicksettingsservice PRIVATE -Wall -Wextra)
    target_compile_options(tst_mediaservice PRIVATE -Wall -Wextra)
    target_compile_options(tst_statsservice PRIVATE -Wall -Wextra)
    target_compile_options(tst_networkservice PRIVATE -Wall -Wextra)
    target_compile_options(tst_bluetoothservice PRIVATE -Wall -Wextra)
    target_compile_options(tst_weatherservice PRIVATE -Wall -Wextra)
    target_compile_options(tst_notificationservice PRIVATE -Wall -Wextra)
    target_compile_options(tst_clipboardservice PRIVATE -Wall -Wextra)
    target_compile_options(tst_launcherservice PRIVATE -Wall -Wextra)
    target_compile_options(tst_trayservice PRIVATE -Wall -Wextra)
endif()

# install 規則は Phase 8 で整備する (Phase 0〜7 は ./build/activenotch の直接実行のみ)。