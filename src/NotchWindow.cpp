#include "NotchWindow.h"

#include <QDebug>
#include <QQmlError>
#include <QQuickView>
#include <QSurfaceFormat>

#include <LayerShellQt/window.h>

namespace {

// --- Phase 0 の固定パラメータ群 -------------------------------------------
// Phase 1 以降で ConfigService (~/.config/activenotch/) へ移す前提の定数。

// ピル (Collapsed 状態) の初期サイズ。論理 px。
// 実機の画面スケール (1.2) は Qt Wayland QPA が自動処理するため、
// 論理 px での指定のみでよい。
// Phase 1 では「ウィンドウを最大サイズ固定 + QML 内部アニメ」方式へ変更する
// (layer-shell サーフェスのリサイズはジャンクの原因になるため)。
constexpr int kPillWidth = 220;
constexpr int kPillHeight = 30;

// wlr-layer-shell の scope 識別子。コンポジタが同一レイヤー内の
// スタック順などを決めるのに使われる。
constexpr char kLayerScope[] = "dev.yukirawa.activenotch";

// QML モジュール URI とルート型名。
// CMakeLists.txt の qt_add_qml_module(URI ...) と一致させること。
constexpr char kQmlModuleUri[] = "dev.yukirawa.activenotch";
constexpr char kQmlRootType[] = "Main";

} // namespace

NotchWindow::NotchWindow()
    : m_view(std::make_unique<QQuickView>())
{
    // ピル外のウィンドウ背景を完全透過にする。
    m_view->setColor(Qt::transparent);

    // ARGB サーフェスを確実に要求するため alpha バッファを明示
    // (KWin では setColor(transparent) のみでも透過するが、念のため設定)。
    QSurfaceFormat format = m_view->format();
    format.setAlphaBufferSize(8);
    m_view->setFormat(format);

    // ウィンドウサイズ (= ピルサイズ) に QML ルートを追従させる。
    m_view->setResizeMode(QQuickView::SizeRootObjectToView);

    // QML をロードし、成否を記録する。
    m_view->loadFromModule(QLatin1StringView(kQmlModuleUri), QLatin1StringView(kQmlRootType));
    m_qmlLoaded = (m_view->status() != QQuickView::Error);
    if (!m_qmlLoaded) {
        for (const QQmlError &error : m_view->errors()) {
            qWarning() << "ActiveNotch: QML のロードに失敗しました:" << error;
        }
    }

    // 初期サイズ (論理 px 固定)。
    m_view->resize(kPillWidth, kPillHeight);
}

NotchWindow::~NotchWindow() = default;

void NotchWindow::applyLayerShell()
{
    // Window::get() は QWindow に LayerShell 設定オブジェクトを紐付けて返す。
    // 必ず show() の前に呼ぶこと。紐付けると Wayland QPA が liblayer-shell.so を
    // 自動選択する (Shell::useLayerShell() は Qt 6.5 以降不要で非推奨のため呼ばない)。
    LayerShellQt::Window *shell = LayerShellQt::Window::get(m_view.get());

    // AnchorTop のみを立てると、wlr-layer-shell 仕様により
    // 「上端 y=0 密着・水平方向は中央寄せ」になる。
    shell->setAnchors(LayerShellQt::Window::Anchors(LayerShellQt::Window::AnchorTop));

    // PLAN のオーバーレイ方針: パネル (LayerTop) より上に表示する。
    // パネルとスタック順を調整したい場合は LayerTop への変更余地あり。
    shell->setLayer(LayerShellQt::Window::LayerOverlay);

    // -1 = 他サーフェスの排他ゾーンを無視 (画面スペースを確保しない)。
    shell->setExclusiveZone(-1);

    // ノッチはキーボードフォーカスを奪わない。
    shell->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityNone);

    // 上端密着 (Phase 1 の Expanded 時の浮遊感のために上マージンを設定する可能性あり)。
    shell->setMargins(QMargins(0, 0, 0, 0));

    shell->setScope(QLatin1StringView(kLayerScope));

    // スクリーン構成の変化 (出力取り外しなど) で閉じない。
    shell->setCloseOnDismissed(false);
}

void NotchWindow::show()
{
    // wlr-layer-shell の設定は表示前に適用する必要があるため、
    // show() の直前で構造的に適用する。
    applyLayerShell();
    m_view->show();
}
