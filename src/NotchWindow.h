#pragma once

#include <QObject>
#include <QRegion>

#include <memory>

class BlurHelper;
class FullscreenDetector;
class QQmlEngine;
class QQuickItem;
class QQuickView;

/**
 * ActiveNotch のノッチウィンドウ。
 *
 * QQuickView を C++ 側で所有し、layer-shell 配置・入力領域マスク・
 * ブラー領域・全画面検出をまとめる。
 *
 * ライフサイクル:
 *   1. NotchWindow を生成 (QML はまだロードしない)
 *   2. engine()->rootContext()->setContextProperty(...) でサービスを公開
 *   3. load() で QML をロードし、notch 項目とシグナルを結線
 *   4. show() で LayerShell を適用して表示
 */
class NotchWindow : public QObject
{
    Q_OBJECT
    // 全画面検出 (FullscreenDetector から更新)。true で QML 側が退避表示する。
    Q_PROPERTY(bool fullscreenActive READ fullscreenActive NOTIFY fullscreenActiveChanged)

public:
    explicit NotchWindow(QObject *parent = nullptr);
    ~NotchWindow() override;

    NotchWindow(const NotchWindow &) = delete;
    NotchWindow &operator=(const NotchWindow &) = delete;

    /** QML コンテキストプロパティ登録に使うエンジン。load() 前でも有効。 */
    QQmlEngine *engine() const;

    /** QML をロードし、QML 側 notch 項目とのシグナル結線を行う。 */
    void load();

    /** ウィンドウを表示する (表示前に LayerShell 設定を適用する)。 */
    void show();

    /** 全画面アプリがアクティブか。 */
    bool fullscreenActive() const { return m_fullscreenActive; }

public slots:
    /** 全画面検出結果を反映する (QML の NotchWindow.fullscreenActive に伝播)。 */
    void setFullscreenActive(bool active);

signals:
    /** fullscreenActive が変化した (QML へ通知)。 */
    void fullscreenActiveChanged();

private slots:
    /** QML `Notch.shapeSettled(x, y, w, h, radius)` (Main ルート基準の論理 px)。 */
    void onShapeSettled(double x, double y, double w, double h, double radius);
    /** QML `Notch.notchState` の変更。pinned のときは全ウィンドウを入力領域にする。 */
    void onNotchStateChanged();
    /** QML `Notch.wantsKeyboardFocus` の変更。 */
    void onWantsKeyboardFocusChanged();
    /** ウィンドウの位置・サイズ変化。デバッグ出力用。 */
    void onGeometryChanged();

private:
    /** QML の notch 項目を探してシグナル・プロパティ変更を結線する。 */
    void connectNotchItem();
    /** 文字列ベースの connect。QML 側にシグナルが無くても警告を出さない。 */
    bool tryConnect(const char *signal, const char *slot);
    /** 現在適用すべき入力領域 (ウィンドウローカル論理 px)。 */
    QRegion currentMaskRegion() const;
    /** 入力領域マスクを適用する。 */
    void applyMask();
    /** 現在のノッチ形状でブラー領域を適用する。 */
    void applyBlur();
    /** wantsKeyboardFocus に応じて layer-shell のキーボード操作を切替える。 */
    void updateKeyboardInteractivity();
    /** LayerShellQt の配置設定を QQuickView に適用する。show() 前に呼ぶこと。 */
    void applyLayerShell();
    /** ACTIVENOTCH_PRINT_GEOMETRY=1 のとき GEOMETRY / MASK 行を stdout へ出す。 */
    void printGeometry();

    std::unique_ptr<QQuickView> m_view;
    std::unique_ptr<BlurHelper> m_blur;
    std::unique_ptr<FullscreenDetector> m_fullscreenDetector;

    QQuickItem *m_notch = nullptr;

    bool m_qmlLoaded = false;
    bool m_fullscreenActive = false;
    bool m_geometryPrintEnabled = false;

    // 最後に受信したノッチ形状 (ウィンドウローカル論理 px)。
    // shapeSettled 未発火の QML でも操作できるよう collapsed ピル形状を初期値に持つ。
    QRegion m_shapeRegion;
    bool m_hasShape = false;

    bool m_pinned = false;
    bool m_keyboardOnDemand = false;
};
