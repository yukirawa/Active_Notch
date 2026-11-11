#pragma once

#include <QObject>
#include <QString>

/**
 * KWin 上で「アクティブウィンドウが全画面か」を検出する。
 *
 * ## 仕組み
 *
 * 1. session bus に `dev.yukirawa.activenotch` サービス / パス `/notch` /
 *    インターフェース `dev.yukirawa.activenotch` を登録する
 *    (ExportAllSlots は本オブジェクトのみに適用)。
 * 2. KWin の `/Scripting` にスクリプトをランタイムロードする。スクリプトは
 *    `workspace.activeWindow` の `fullScreen` を監視し、変化のたびに
 *    1. の DBus メソッド `fullscreenChanged(bool)` を callDBus で叩く。
 * 3. 受け取った値を `fullscreenStateChanged(bool)` で通知する。
 *
 * ## 失敗時の挙動 (CONTRACT §0)
 *
 * DBus 登録失敗 (競合含む) / KWin 不在 / スクリプトロード失敗など、あらゆる
 * 失敗は qWarning のみで機能 OFF。`isActive() == false` のまま継続動作し、
 * 例外もクラッシュもしない。
 */
class FullscreenDetector : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "dev.yukirawa.activenotch")

public:
    explicit FullscreenDetector(QObject *parent = nullptr);
    ~FullscreenDetector() override;

    FullscreenDetector(const FullscreenDetector &) = delete;
    FullscreenDetector &operator=(const FullscreenDetector &) = delete;

    /** DBus サービス登録と KWin スクリプトロードの両方に成功したか。 */
    bool isActive() const { return m_registered && m_scriptLoaded; }

public Q_SLOTS:
    /**
     * KWin スクリプトから DBus 経由で呼ばれるスロット。
     * @param fullscreen アクティブウィンドウが全画面なら true。
     */
    void fullscreenChanged(bool fullscreen);

Q_SIGNALS:
    /** 全画面状態が変化した。NotchWindow::setFullscreenActive に接続する。 */
    void fullscreenStateChanged(bool fullscreen);

private:
    /** session bus にサービスとオブジェクトを登録する。 */
    void registerDbusService();
    /** KWin スクリプトを一時ファイルに書き出し、ロード + 実行する。 */
    void loadKWinScript();
    /** スクリプトの停止・アンロードと DBus 登録解除。 */
    void teardown();

    static QString kwinScriptSource();

    bool m_registered = false;
    bool m_scriptLoaded = false;
    bool m_fullscreen = false;
    int m_scriptId = -1;
    QString m_pluginName;
    QString m_scriptPath;
};
