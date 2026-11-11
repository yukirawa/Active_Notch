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
# Phase 1 追加分:
#   - DBus                 : FullscreenDetector (KWin スクリプト通知)
#   - GuiPrivate           : QNativeInterface::Private::QWaylandWindow
#   - WaylandClientPrivate : QWaylandWindow / QWaylandDisplay (BlurHelper)
#   - Test                 : tests/tst_regionutils
#
# プライベートモジュールを使うと Qt バージョン固定の警告が出るが、
# このプロジェクトは実機の Qt 6.12 に固定して使うため抑制する。
set(QT_NO_PRIVATE_MODULE_WARNING ON)
find_package(Qt6 REQUIRED COMPONENTS
    Quick Qml DBus Test GuiPrivate WaylandClientPrivate)

# 注意: リンクターゲットは LayerShellQt::Interface。
# (LayerShellQt::LayerShellQt というターゲットは存在しない)
find_package(LayerShellQt REQUIRED)

# BlurHelper が libwayland-client を直接使う (ext_background_effect_v1)。
find_package(PkgConfig REQUIRED)
pkg_check_modules(WAYLAND_CLIENT REQUIRED IMPORTED_TARGET wayland-client)

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
)

# QML モジュール URI は src/NotchWindow.cpp の kQmlModuleUri と一致させること。
qt_add_qml_module(activenotch
    URI dev.yukirawa.activenotch
    VERSION 1.0
    QML_FILES
        ${ACTIVE_NOTCH_QML_FILES}
)

target_include_directories(activenotch PRIVATE src)

target_link_libraries(activenotch PRIVATE
    Qt6::Quick
    Qt6::DBus
    Qt6::GuiPrivate
    Qt6::WaylandClientPrivate
    LayerShellQt::Interface
    PkgConfig::WAYLAND_CLIENT
)

# ---------------------------------------------------------------------------
# 単体テスト (Phase 1)
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

# ---------------------------------------------------------------------------
# 警告 (Phase 0 の完了条件: -Wall -Wextra で警告ゼロ)
# ---------------------------------------------------------------------------
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(activenotch PRIVATE -Wall -Wextra)
    target_compile_options(tst_regionutils PRIVATE -Wall -Wextra)
endif()

# install 規則は Phase 8 で整備する (Phase 0〜7 は ./build/activenotch の直接実行のみ)。
