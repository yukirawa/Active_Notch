#pragma once

#include <memory>

class QQuickView;

/**
 * ActiveNotch のノッチウィンドウ。
 *
 * QQmlApplicationEngine を使わず QQuickView を C++ 側で所有する。
 * Phase 1 で入力領域マスク (wl_surface.set_input_region) や KWin ブラー領域を
 * QQuickWindow に直接操作するため、QML エンジンではなくウィンドウを握る設計。
 *
 * LayerShellQt による配置は show() の直前に適用される
 * (wlr-layer-shell の設定は surface のコミット前、つまり表示前に完了している必要がある)。
 */
class NotchWindow
{
public:
    NotchWindow();
    ~NotchWindow();

    NotchWindow(const NotchWindow &) = delete;
    NotchWindow &operator=(const NotchWindow &) = delete;

    /** QML のロードに成功したか。false の場合は show() しても何も表示されない。 */
    bool isQmlLoaded() const { return m_qmlLoaded; }

    /** ウィンドウを表示する (表示前に LayerShell 設定を適用する)。 */
    void show();

private:
    /** LayerShellQt の配置設定を QQuickView に適用する。show() 前に呼ぶこと。 */
    void applyLayerShell();

    std::unique_ptr<QQuickView> m_view;
    bool m_qmlLoaded = false;
};
