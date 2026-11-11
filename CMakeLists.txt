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
find_package(Qt6 REQUIRED COMPONENTS Quick Qml)

# 注意: リンクターゲットは LayerShellQt::Interface。
# (LayerShellQt::LayerShellQt というターゲットは存在しない)
find_package(LayerShellQt REQUIRED)

qt_standard_project_setup()

# QML モジュールのリソースプレフィックスを :/qt/qml/ に統一する
# (qt_add_qml_module の author 警告を抑制)。
qt_policy(SET QTP0001 NEW)

# ---------------------------------------------------------------------------
# 実行ファイル
# ---------------------------------------------------------------------------
qt_add_executable(activenotch
    src/main.cpp
    src/NotchWindow.cpp
)

# qml/ ディレクトリにある QML ファイルをモジュール直下の型として登録するため、
# QT_RESOURCE_ALIAS でソースパスのディレクトリ部分をリソースパスから除去する
# (qml/Main.qml → :/qt/qml/dev/yukirawa/activenotch/Main.qml)。
# Theme.qml は pragma Singleton のため QT_QML_SINGLETON_TYPE を付与する。
# ※ これらのプロパティは qt_add_qml_module より前に設定する必要がある。
set_source_files_properties(qml/Main.qml  PROPERTIES QT_RESOURCE_ALIAS "Main.qml")
set_source_files_properties(qml/Notch.qml PROPERTIES QT_RESOURCE_ALIAS "Notch.qml")
set_source_files_properties(qml/Theme.qml PROPERTIES
    QT_RESOURCE_ALIAS "Theme.qml"
    QT_QML_SINGLETON_TYPE TRUE
)

# QML モジュール URI は src/NotchWindow.cpp の kQmlModuleUri と一致させること。
qt_add_qml_module(activenotch
    URI dev.yukirawa.activenotch
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/Notch.qml
        qml/Theme.qml
)

target_link_libraries(activenotch PRIVATE
    Qt6::Quick
    LayerShellQt::Interface
)

# ---------------------------------------------------------------------------
# 警告 (Phase 0 の完了条件: -Wall -Wextra で警告ゼロ)
# ---------------------------------------------------------------------------
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(activenotch PRIVATE -Wall -Wextra)
endif()

# install 規則は Phase 8 で整備する (Phase 0〜7 は ./build/activenotch の直接実行のみ)。
