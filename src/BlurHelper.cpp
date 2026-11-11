#include "BlurHelper.h"

#include <QDebug>
#include <QWindow>

#include <cstring>

extern "C" {
#include <wayland-client.h>
}

#if QT_CONFIG(wayland)
#include <qpa/qplatformwindow_p.h>
#include <QtWaylandClient/private/qwaylanddisplay_p.h>
#include <QtWaylandClient/private/qwaylandwindow_p.h>
#endif

namespace {

// ===========================================================================
// ext_background_effect_v1 の最小プロトコル定義 (手書き)
//
// wayland-protocols staging の ext-background-effect-v1.xml に対応する。
// 生成コード (qtwaylandscanner) への依存とビルド複雑化を避けるため、
// libwayland-client が要求する wl_interface / wl_message のみを手書きする。
//
//  - ext_background_effect_manager_v1 (version 1)
//      0: destroy()
//      1: get_background_effect(id: new_id ext_background_effect_surface_v1,
//                               surface: wl_surface)
//      event 0: capabilities(flags: uint)
//  - ext_background_effect_surface_v1 (version 1)
//      0: destroy()
//      1: set_blur_region(region: wl_region, nullable)
// ===========================================================================

const char kManagerInterfaceName[] = "ext_background_effect_manager_v1";
const char kSurfaceInterfaceName[] = "ext_background_effect_surface_v1";

// set_blur_region のシグネチャ "?o" 用の型テーブル。
const struct wl_interface *ext_bg_surface_set_blur_types[] = {
    &wl_region_interface,
};

const struct wl_message ext_bg_surface_requests[] = {
    {"destroy", "", nullptr},
    {"set_blur_region", "?o", ext_bg_surface_set_blur_types},
};

const struct wl_interface ext_bg_surface_interface = {
    kSurfaceInterfaceName,
    1,
    2,
    ext_bg_surface_requests,
    0,
    nullptr,
};

// get_background_effect のシグネチャ "no" 用の型テーブル。
const struct wl_interface *ext_bg_manager_get_effect_types[] = {
    &ext_bg_surface_interface,
    &wl_surface_interface,
};

const struct wl_message ext_bg_manager_requests[] = {
    {"destroy", "", nullptr},
    {"get_background_effect", "no", ext_bg_manager_get_effect_types},
};

const struct wl_message ext_bg_manager_events[] = {
    {"capabilities", "u", nullptr},
};

const struct wl_interface ext_bg_manager_interface = {
    kManagerInterfaceName,
    1,
    2,
    ext_bg_manager_requests,
    1,
    ext_bg_manager_events,
};

// 要求オペコード (可読性のため名前を付ける)。
constexpr uint32_t kManagerOpGetBackgroundEffect = 1;
constexpr uint32_t kSurfaceOpSetBlurRegion = 1;

// ---------------------------------------------------------------------------
// globals 探索 (専用イベントキュー上で実行)
// ---------------------------------------------------------------------------
struct RegistryProbe {
    uint32_t managerName = 0;
    uint32_t managerVersion = 0;
    bool found = false;
};

void probeGlobal(void *data, struct wl_registry *registry, uint32_t name,
                 const char *interface, uint32_t version)
{
    Q_UNUSED(registry)
    auto *probe = static_cast<RegistryProbe *>(data);
    if (std::strcmp(interface, kManagerInterfaceName) == 0) {
        probe->managerName = name;
        probe->managerVersion = version;
        probe->found = true;
    }
}

void probeGlobalRemove(void *data, struct wl_registry *registry, uint32_t name)
{
    Q_UNUSED(data)
    Q_UNUSED(registry)
    Q_UNUSED(name)
}

const struct wl_registry_listener kRegistryListener = {
    probeGlobal,
    probeGlobalRemove,
};

} // namespace

BlurHelper::BlurHelper(QWindow *window, QObject *parent)
    : QObject(parent)
    , m_window(window)
{
}

BlurHelper::~BlurHelper()
{
    // 逆順で後片付け。ポインタはすべて null 安全に扱う。
    if (m_effect) {
        wl_proxy_marshal_flags(m_effect, 0 /* destroy */, nullptr,
                               wl_proxy_get_version(m_effect), WL_MARSHAL_FLAG_DESTROY);
        m_effect = nullptr;
    }
    if (m_manager) {
        wl_proxy_marshal_flags(m_manager, 0 /* destroy */, nullptr,
                               wl_proxy_get_version(m_manager), WL_MARSHAL_FLAG_DESTROY);
        m_manager = nullptr;
    }
    if (m_registry) {
        wl_registry_destroy(m_registry);
        m_registry = nullptr;
    }
    // 専用キューは、そこに紐付いたプロキシ (registry/manager/effect) を
    // すべて破棄した後に破棄する。順序を誤ると libwayland が abort する。
    if (m_queue) {
        wl_event_queue_destroy(m_queue);
        m_queue = nullptr;
    }
    if (m_display) {
        wl_display_flush(m_display);
    }
}

void BlurHelper::init()
{
    if (m_initDone) {
        return;
    }

#if QT_CONFIG(wayland)
    if (!m_window) {
        return;
    }

    // 公開 native interface 経由で Wayland の wl_surface を取得する。
    auto *nativeWindow =
        m_window->nativeInterface<QNativeInterface::Private::QWaylandWindow>();
    if (!nativeWindow) {
        return; // Wayland 以外 or layer 未対応の QPA。
    }
    m_surface = nativeWindow->surface();
    if (!m_surface) {
        return;
    }

    auto *qwaylandWindow = QtWaylandClient::QWaylandWindow::fromWlSurface(m_surface);
    if (!qwaylandWindow) {
        return;
    }
    m_qwaylandDisplay = qwaylandWindow->display();
    if (!m_qwaylandDisplay) {
        return;
    }
    m_display = m_qwaylandDisplay->wl_display();
    if (!m_display) {
        return;
    }

    // ここまで来れば wl_surface / wl_display は取得済み。以降の失敗
    // (プロトコル未広告など) は環境要因なので再試行せず結果を確定する。
    // 逆に surface 未生成のタイミングで呼ばれた場合は m_initDone を立てず、
    // show() 後の applyBlur() で再試行できるようにする。
    m_initDone = true;

    // 専用のイベントキューを作り、globals 探索を Qt のイベント処理から隔離する。
    // このキューは manager/effect プロキシの寿命と一致させるため、成功時は
    // 保持し、デストラクタでプロキシ破棄後に破棄する。
    m_queue = wl_display_create_queue(m_display);
    if (!m_queue) {
        return;
    }

    m_registry = wl_display_get_registry(m_display);
    if (!m_registry) {
        wl_event_queue_destroy(m_queue);
        m_queue = nullptr;
        return;
    }
    wl_proxy_set_queue(reinterpret_cast<struct wl_proxy *>(m_registry), m_queue);

    RegistryProbe probe;
    wl_registry_add_listener(m_registry, &kRegistryListener, &probe);

    // 専用キュー上で 1 往復し、globals を受け取る (Qt のキューは触らない)。
    if (wl_display_roundtrip_queue(m_display, m_queue) < 0) {
        wl_registry_destroy(m_registry);
        m_registry = nullptr;
        wl_event_queue_destroy(m_queue);
        m_queue = nullptr;
        return;
    }

    if (!probe.found) {
        qWarning() << "BlurHelper: このコンポジタは"
                   << kManagerInterfaceName
                   << "を広告していません。KWin ブラーは無効 (半透明で代替) です。";
        wl_registry_destroy(m_registry);
        m_registry = nullptr;
        wl_event_queue_destroy(m_queue);
        m_queue = nullptr;
        return;
    }

    m_managerName = probe.managerName;
    m_managerVersion = probe.managerVersion;

    m_manager = static_cast<struct wl_proxy *>(
        wl_registry_bind(m_registry, m_managerName, &ext_bg_manager_interface, 1));
    if (!m_manager) {
        wl_registry_destroy(m_registry);
        m_registry = nullptr;
        wl_event_queue_destroy(m_queue);
        m_queue = nullptr;
        return;
    }

    m_supported = true;
    qInfo() << "BlurHelper: 背景ブラーを有効化しました (ext_background_effect_v1,"
            << "manager v" << int(m_managerVersion) << ")";
#endif
}

bool BlurHelper::ensureSurfaceEffect()
{
    if (m_effect) {
        return true;
    }
    if (!m_supported || !m_manager || !m_surface) {
        return false;
    }

    // ext_background_effect_surface_v1 をサーフェスに関連付ける。
    // new_id を返すリクエストでは、可変長引数の先頭に NULL を渡す規約。
    void *created = wl_proxy_marshal_flags(
        m_manager, kManagerOpGetBackgroundEffect, &ext_bg_surface_interface,
        wl_proxy_get_version(m_manager), 0, nullptr, m_surface);
    m_effect = static_cast<struct wl_proxy *>(created);
    return m_effect != nullptr;
}

void BlurHelper::setBlurRegion(const QRegion &region)
{
    init();
    if (!m_supported) {
        return;
    }
    if (!ensureSurfaceEffect()) {
        return;
    }

    // wl_region は Qt が保持する wl_compositor から生成する。
    struct wl_region *wlRegion = nullptr;
    if (!region.isEmpty() && m_qwaylandDisplay) {
        wlRegion = m_qwaylandDisplay->createRegion(region);
    }

    // region は copy セマンティクスのため、送信後すぐ破棄してよい。
    wl_proxy_marshal_flags(m_effect, kSurfaceOpSetBlurRegion, nullptr,
                           wl_proxy_get_version(m_effect), 0, wlRegion);
    if (wlRegion) {
        wl_region_destroy(wlRegion);
    }

    // ブラー領域は次の surface commit で適用される。念のため明示的に flush。
    if (m_display) {
        wl_display_flush(m_display);
    }
}
