#pragma once

#include <QObject>
#include <QPointer>
#include <QRegion>

#include <cstdint>

struct wl_display;
struct wl_event_queue;
struct wl_registry;
struct wl_proxy;
struct wl_surface;
struct wl_region;

class QWindow;

namespace QtWaylandClient {
class QWaylandDisplay;
}

/**
 * KWin (Wayland) の背景ブラーを有効化するヘルパー。
 *
 * ## 実機調査の結論 (KF6 6.31 / KWin 6.8.2 / Qt 6.12)
 *
 * - PLAN 第一候補の `KWindowEffects::enableBlurBehind()` (kwindowsystem) は、
 *   実機の Wayland では `KWindowEffects::isEffectAvailable(BlurBehind) == false`。
 *   理由: KWin 6.8 は旧プロトコル `org_kde_kwin_blur` を **広告していない**
 *   (`wayland-info` で未確認)。したがってこの経路は no-op になる。
 * - 代わりに KWin 6.8 は標準プロトコル `ext_background_effect_manager_v1`
 *   (wayland-protocols staging, version 1) を広告している。これが現行の
 *   正攻法で、Plasma 6.8 自身もこれを使う。
 *
 * ## 本実装の方式
 *
 * `ext_background_effect_manager_v1` を libwayland-client で直接バインドし、
 * layer-shell サーフェスに `ext_background_effect_surface_v1` を関連付けて
 * ブラー領域を設定する。プロトコル定義 (wl_interface) は private な生成物への
 * 依存を避けるため、本ファイル内に最小限だけ手書きする。
 *
 * - wl_surface / wl_display の取得には Qt の公開 native interface
 *   (`QNativeInterface::Private::QWaylandWindow`) と QtWaylandClient の
 *   プライベートヘッダを使う (いずれも実機にインストール済み)。
 * - wl_region は Qt が既に持つ wl_compositor を再利用する
 *   (`QWaylandDisplay::createRegion`)。
 * - 専用の wl_event_queue を切って globals を探すため、Qt のイベント処理と
 *   競合しない。
 *
 * ## 失敗時の挙動 (CONTRACT §0)
 *
 * Wayland 以外 / プロトコル未広告 / wl_surface 取得失敗など、あらゆる失敗は
 * `isSupported() == false` として扱い、呼び出し側は素の半透明へフォールバック
 * する。例外は投げず、クラッシュもしない。
 */
class BlurHelper : public QObject
{
    Q_OBJECT
public:
    explicit BlurHelper(QWindow *window, QObject *parent = nullptr);
    ~BlurHelper() override;

    BlurHelper(const BlurHelper &) = delete;
    BlurHelper &operator=(const BlurHelper &) = delete;

    /** 実機で背景ブラーが利用可能か (プロトコルの広告 + wl_surface 取得に成功)。 */
    bool isSupported() const { return m_supported; }

    /**
     * ブラー領域を設定する。座標はサーフェスローカル論理px。
     * 空の QRegion を渡すとブラーを解除する。isSupported() が false のときは何もしない。
     */
    void setBlurRegion(const QRegion &region);

private:
    /** wl_surface / wl_display / プロトコル広告の検出。失敗しても例外は投げない。 */
    void init();
    /** ブラー対象のサーフェスエフェクトを (未生成なら) 生成する。 */
    bool ensureSurfaceEffect();

    QPointer<QWindow> m_window;

    bool m_supported = false;
    bool m_initDone = false;

    struct wl_display *m_display = nullptr;
    QtWaylandClient::QWaylandDisplay *m_qwaylandDisplay = nullptr;
    struct wl_event_queue *m_queue = nullptr;
    struct wl_registry *m_registry = nullptr;
    struct wl_proxy *m_manager = nullptr;
    struct wl_proxy *m_effect = nullptr;
    struct wl_surface *m_surface = nullptr;
    uint32_t m_managerName = 0;
    uint32_t m_managerVersion = 0;
};
