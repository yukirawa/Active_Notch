#include "NotchWindow.h"

#include "BlurHelper.h"
#include "FullscreenDetector.h"
#include "RegionUtils.h"

#include <QDebug>
#include <QGuiApplication>
#include <QMetaObject>
#include <QQmlEngine>
#include <QQmlError>
#include <QQuickItem>
#include <QQuickView>
#include <QScreen>
#include <QSurfaceFormat>
#include <QTextStream>
#include <QTimer>
#include <QWindow>
#include <QtGlobal>

#include <cstdio>

#include <LayerShellQt/window.h>

namespace {

// --- Phase 1 の固定パラメータ群 -------------------------------------------
// Phase 2 以降で ConfigService (~/.config/activenotch/) へ移す前提の定数。

// ウィンドウは最大サイズ固定 (展開パネル 660x440 + 上マージン 8)。
// layer-shell サーフェスのリサイズはジャンクの原因になるため、
// 開閉アニメは QML 内部のみで行う (CONTRACT §1)。
constexpr int kWindowWidth = 660;
constexpr int kWindowHeight = 448;

// ブリッジ用の collapsed ピル形状 (ウィンドウローカル論理px)。
// QML の shapeSettled が未発火でも外側クリック透過を確保するために使う。
constexpr qreal kBridgePillX = 220.0;
constexpr qreal kBridgePillY = 0.0;
constexpr qreal kBridgePillW = 220.0;
constexpr qreal kBridgePillH = 30.0;
constexpr qreal kBridgePillRadius = 16.0;

// 形状デバッグ出力の環境変数 (scripts/verify-ui.sh がパースする)。
constexpr char kGeometryEnvVar[] = "ACTIVENOTCH_PRINT_GEOMETRY";

// wlr-layer-shell の scope 識別子。
constexpr char kLayerScope[] = "dev.yukirawa.activenotch";

// QML モジュール URI とルート型名。CMakeLists.txt の qt_add_qml_module と一致させること。
constexpr char kQmlModuleUri[] = "dev.yukirawa.activenotch";
constexpr char kQmlRootType[] = "Main";

} // namespace

NotchWindow::NotchWindow(QObject *parent)
    : QObject(parent)
    , m_view(std::make_unique<QQuickView>())
{
    m_geometryPrintEnabled = (qgetenv(kGeometryEnvVar) == "1");

    // ピル外のウィンドウ背景を完全透過にする。
    m_view->setColor(Qt::transparent);

    // ARGB サーフェスを確実に要求するため alpha バッファを明示。
    QSurfaceFormat format = m_view->format();
    format.setAlphaBufferSize(8);
    m_view->setFormat(format);

    // QML ルートをウィンドウサイズ (固定 660x448) に追従させる。
    m_view->setResizeMode(QQuickView::SizeRootObjectToView);
    m_view->resize(kWindowWidth, kWindowHeight);

    // ブリッジ: QML の shapeSettled 未発火時でも collapsed ピル形状で
    // 外側クリック透過を確保する (並行作業中の Phase 0 QML 対策)。
    m_shapeRegion = RegionUtils::roundedRectRegion(kBridgePillX, kBridgePillY,
                                                   kBridgePillW, kBridgePillH,
                                                   kBridgePillRadius);
    m_hasShape = true;

    // KWin ブラー (ext_background_effect_v1)。失敗時は半透明フォールバック。
    m_blur = std::make_unique<BlurHelper>(m_view.get(), this);

    // 全画面検出 (KWin スクリプト + DBus)。失敗時は機能 OFF で継続。
    m_fullscreenDetector = std::make_unique<FullscreenDetector>(this);
    connect(m_fullscreenDetector.get(), &FullscreenDetector::fullscreenStateChanged,
            this, &NotchWindow::setFullscreenActive);

    // ジオメトリ変化 (環境変数 ON 時のデバッグ出力用)。
    connect(m_view.get(), &QWindow::screenChanged, this, &NotchWindow::onGeometryChanged);
    connect(m_view.get(), &QWindow::xChanged, this, &NotchWindow::onGeometryChanged);
    connect(m_view.get(), &QWindow::yChanged, this, &NotchWindow::onGeometryChanged);
    connect(m_view.get(), &QWindow::widthChanged, this, &NotchWindow::onGeometryChanged);
    connect(m_view.get(), &QWindow::heightChanged, this, &NotchWindow::onGeometryChanged);
}

NotchWindow::~NotchWindow() = default;

QQmlEngine *NotchWindow::engine() const
{
    return m_view->engine();
}

void NotchWindow::load()
{
    if (m_qmlLoaded) {
        return;
    }

    m_view->loadFromModule(QLatin1StringView(kQmlModuleUri),
                           QLatin1StringView(kQmlRootType));
    m_qmlLoaded = (m_view->status() != QQuickView::Error);
    if (!m_qmlLoaded) {
        for (const QQmlError &error : m_view->errors()) {
            qWarning() << "ActiveNotch: QML のロードに失敗しました:" << error;
        }
        return;
    }

    connectNotchItem();
}

void NotchWindow::connectNotchItem()
{
    QQuickItem *root = m_view->rootObject();
    m_notch = root ? root->findChild<QQuickItem *>(QStringLiteral("notch")) : nullptr;

    if (!m_notch) {
        // Phase 0 QML (id="notch" 未定義) の場合。ブリッジ形状のまま継続する。
        qWarning() << "ActiveNotch: QML に id=\"notch\" の項目が見つかりません。"
                      "ブリッジの collapsed 形状でマスクします。";
        return;
    }

    // 並行作業中の QML ではシグナルが未定義の場合があるため、
    // 存在チェックしてから接続する (connect 失敗時の警告も避ける)。
    tryConnect("shapeSettled(qreal,qreal,qreal,qreal,qreal)",
               "onShapeSettled(double,double,double,double,double)");
    tryConnect("notchStateChanged()", "onNotchStateChanged()");
    tryConnect("wantsKeyboardFocusChanged()", "onWantsKeyboardFocusChanged()");

    // 初期状態を反映する。
    onNotchStateChanged();
    onWantsKeyboardFocusChanged();
}

bool NotchWindow::tryConnect(const char *signal, const char *slot)
{
    if (!m_notch) {
        return false;
    }
    const QByteArray sig = QMetaObject::normalizedSignature(signal);
    const QByteArray slt = QMetaObject::normalizedSignature(slot);
    if (m_notch->metaObject()->indexOfSignal(sig.constData()) < 0) {
        return false;
    }
    if (metaObject()->indexOfSlot(slt.constData()) < 0) {
        return false;
    }
    // QObject::connect(const char*, const char*) は SIGNAL()/SLOT() マクロと
    // 同様に先頭のコード ('2' = signal, '1' = slot) を要求する。
    const QByteArray codedSignal = QByteArrayLiteral("2") + sig;
    const QByteArray codedSlot = QByteArrayLiteral("1") + slt;
    const bool connected = QObject::connect(m_notch, codedSignal.constData(),
                                            this, codedSlot.constData());
    if (!connected)
        qWarning() << "ActiveNotch: QML シグナル接続に失敗:" << sig;
    return connected;
}

void NotchWindow::onShapeSettled(double x, double y, double w, double h, double radius)
{
    // 座標は Main ルート基準の論理px。ウィンドウは Main ルートと同サイズなので
    // そのままウィンドウローカル論理px として扱える。
    m_shapeRegion = RegionUtils::roundedRectRegion(x, y, w, h, radius);
    m_hasShape = true;

    applyMask();
    applyBlur();
    onGeometryChanged();
}

void NotchWindow::onNotchStateChanged()
{
    if (!m_notch) {
        return;
    }
    m_pinned = (m_notch->property("notchState").toString() == QLatin1String("pinned"));
    applyMask();
}

void NotchWindow::onWantsKeyboardFocusChanged()
{
    if (!m_notch) {
        return;
    }
    m_keyboardOnDemand = m_notch->property("wantsKeyboardFocus").toBool();
    updateKeyboardInteractivity();
}

QRegion NotchWindow::currentMaskRegion() const
{
    // 全画面時: 完全クリック透過 (空領域 = 入力領域なし)。
    if (m_fullscreenActive) {
        return QRegion();
    }
    // pinned 中: 外側クリックで解除できるよう全ウィンドウ領域をマスクする。
    if (m_pinned) {
        return QRegion(QRect(QPoint(0, 0), m_view->size()));
    }
    // 通常: ノッチ形状のみ = 外側クリック透過。
    if (m_hasShape) {
        return m_shapeRegion;
    }
    return QRegion();
}

void NotchWindow::applyMask()
{
    if (!m_view) {
        return;
    }

    // 座標系メモ (CONTRACT §1): QWindow::setMask() はデバイス非依存 (論理px) の
    // QRegion を取る。実機 scale 1.2 でも論理px をそのまま渡すのが正しく、
    // DPR 倍すると位置ずれする (検証済み)。よって論理px の m_shapeRegion を渡す。
    m_view->setMask(currentMaskRegion());
}

void NotchWindow::applyBlur()
{
    if (!m_blur) {
        return;
    }
    // ブラー領域はノッチ形状のみ (pinned でも形状は同じ)。
    // 全画面退避中はノッチが不可視になるため、ブラーも解除する
    // (領域を残すと透明なピル形状だけがぼやけて見える)。
    // BlurHelper 側で未対応環境は内部で無視し、半透明にフォールバックする。
    m_blur->setBlurRegion(m_fullscreenActive ? QRegion() : m_shapeRegion);
}

void NotchWindow::updateKeyboardInteractivity()
{
    LayerShellQt::Window *shell = LayerShellQt::Window::get(m_view.get());
    if (!shell) {
        return;
    }
    shell->setKeyboardInteractivity(m_keyboardOnDemand
                                        ? LayerShellQt::Window::KeyboardInteractivityOnDemand
                                        : LayerShellQt::Window::KeyboardInteractivityNone);
}

void NotchWindow::setFullscreenActive(bool active)
{
    if (m_fullscreenActive == active) {
        return;
    }
    m_fullscreenActive = active;
    applyMask();
    applyBlur();
    // マスク形状が変わるため、デバッグ出力も更新する (verify-ui.sh 用)。
    printGeometry();
    Q_EMIT fullscreenActiveChanged();
}

void NotchWindow::onGeometryChanged()
{
    printGeometry();
}

void NotchWindow::printGeometry()
{
    if (!m_geometryPrintEnabled || !m_view) {
        return;
    }

    QWindow *window = m_view.get();
    const qreal dpr = window->devicePixelRatio();
    const QRect frame = window->frameGeometry();
    QScreen *screen = window->screen();
    const QString screenName = screen ? screen->name() : QStringLiteral("?");

    // verify-ui.sh がパースするため、行形式は厳守 (半角スペース区切り、"= " なし)。
    QTextStream out(stdout);
    out << "GEOMETRY x=" << qRound(frame.x() * dpr)
        << " y=" << qRound(frame.y() * dpr)
        << " w=" << qRound(frame.width() * dpr)
        << " h=" << qRound(frame.height() * dpr)
        << " scale=" << QString::number(dpr)
        << " screen=" << screenName << Qt::endl;

    // Wayland のクライアントはグローバル座標を知らない (frame.x() は常に 0)。
    // layer-shell の AnchorTop 中央寄せの実際の配置を出力ジオメトリから計算する。
    QPoint surfaceTopLeft = window->position();
    if (screen) {
        const QRect screenGeometry = screen->geometry();
        surfaceTopLeft.setX(screenGeometry.x()
                            + (screenGeometry.width() - frame.width()) / 2);
        surfaceTopLeft.setY(screenGeometry.y()); // AnchorTop + margin 0
    }

    const QRect mask = currentMaskRegion().boundingRect();
    out << "MASK x=" << qRound((surfaceTopLeft.x() + mask.x()) * dpr)
        << " y=" << qRound((surfaceTopLeft.y() + mask.y()) * dpr)
        << " w=" << qRound(mask.width() * dpr)
        << " h=" << qRound(mask.height() * dpr) << Qt::endl;
}

void NotchWindow::applyLayerShell()
{
    // Window::get() は QWindow に LayerShell 設定オブジェクトを紐付けて返す。
    // 必ず show() の前に呼ぶこと。
    LayerShellQt::Window *shell = LayerShellQt::Window::get(m_view.get());

    // AnchorTop のみ → 上端 y=0 密着・水平中央寄せ (wlr-layer-shell 仕様)。
    shell->setAnchors(LayerShellQt::Window::Anchors(LayerShellQt::Window::AnchorTop));

    // パネル (LayerTop) より上に表示する。
    shell->setLayer(LayerShellQt::Window::LayerOverlay);

    // -1 = 他サーフェスの排他ゾーンを無視 (画面スペースを確保しない)。
    shell->setExclusiveZone(-1);

    // 既定はキーボードフォーカスを奪わない。pinned で OnDemand に切り替える。
    shell->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityNone);

    // 上端密着。
    shell->setMargins(QMargins(0, 0, 0, 0));

    shell->setScope(QLatin1StringView(kLayerScope));

    // スクリーン構成の変化 (出力取り外しなど) で閉じない。
    shell->setCloseOnDismissed(false);
}

void NotchWindow::show()
{
    // wlr-layer-shell の設定は表示前に適用する必要がある。
    applyLayerShell();

    // 現在の状態 (pinned / 全画面 / キーボード) を反映してから表示する。
    updateKeyboardInteractivity();
    applyMask();

    m_view->show();

    // wl_surface は show() で生成されるため、ブラー領域の初回適用はここで行う。
    // (QML の Component.onCompleted による初回 shapeSettled は load 中に
    //  発火しており、C++ が接続する前に取りこぼしている。collapsed 形状は
    //  ブリッジ初期値と同一なのでマスクは正しいが、ブラーは未適用のため
    //  明示的に適用する。)
    applyBlur();

    // 表示直後のジオメトリを出力 (環境変数 ON 時)。
    if (m_geometryPrintEnabled) {
        QTimer::singleShot(0, this, &NotchWindow::onGeometryChanged);
    }
}
