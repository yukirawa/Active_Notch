#include "FullscreenDetector.h"

#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusReply>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QStandardPaths>

namespace {

constexpr char kServiceName[] = "dev.yukirawa.activenotch";
constexpr char kObjectPath[] = "/notch";
constexpr char kKWinService[] = "org.kde.KWin";
constexpr char kKWinScriptingPath[] = "/Scripting";
constexpr char kKWinScriptingInterface[] = "org.kde.kwin.Scripting";
constexpr char kKWinScriptInterface[] = "org.kde.kwin.Script";
constexpr char kPluginName[] = "activenotchfs";

} // namespace

FullscreenDetector::FullscreenDetector(QObject *parent)
    : QObject(parent)
    , m_pluginName(QString::fromLatin1(kPluginName))
{
    // D-Bus サービスと KWin スクリプトは生成時に初期化する。
    // どちらが失敗しても機能 OFF でアプリは継続する (CONTRACT §0)。
    registerDbusService();
    loadKWinScript();
}

FullscreenDetector::~FullscreenDetector()
{
    teardown();
}

void FullscreenDetector::registerDbusService()
{
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected()) {
        qWarning() << "ActiveNotch: セッション D-Bus に接続できないため全画面検出を無効化します";
        return;
    }

    if (!bus.registerService(QString::fromLatin1(kServiceName))) {
        qWarning() << "ActiveNotch: D-Bus サービス" << kServiceName
                   << "を登録できません (別インスタンスが動作中?):"
                   << bus.lastError().message();
        return;
    }

    // ExportAllSlots はこのオブジェクト (FullscreenDetector) 専用。
    if (!bus.registerObject(QString::fromLatin1(kObjectPath), this,
                            QDBusConnection::ExportAllSlots)) {
        qWarning() << "ActiveNotch: D-Bus オブジェクト" << kObjectPath
                   << "を登録できません:" << bus.lastError().message();
        bus.unregisterService(QString::fromLatin1(kServiceName));
        return;
    }

    m_registered = true;
}

QString FullscreenDetector::kwinScriptSource()
{
    // KWin 6 では workspace.activeWindow が Window ラッパー。
    // アクティブウィンドウの fullScreen を監視し、変化を D-Bus で送る。
    return QStringLiteral(R"JS(
function report() {
    var w = workspace.activeWindow;
    callDBus("dev.yukirawa.activenotch", "/notch", "dev.yukirawa.activenotch",
             "fullscreenChanged", w !== null && w.fullScreen);
}
workspace.windowActivated.connect(report);
workspace.windowAdded.connect(function(w) {
    if (w.fullScreenChanged) { w.fullScreenChanged.connect(report); }
});
report();
)JS");
}

void FullscreenDetector::loadKWinScript()
{
    // スクリプトは一時ファイルに書き出して KWin に読ませる。
    // プロセス終了時に teardown() で削除する。
    const QString tempDir = QStandardPaths::writableLocation(QStandardPaths::TempLocation);
    m_scriptPath = QDir(tempDir).filePath(
        QStringLiteral("activenotch-fullscreen-%1.js")
            .arg(QCoreApplication::applicationPid()));

    QFile file(m_scriptPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qWarning() << "ActiveNotch: KWin スクリプトを書き出せません:" << m_scriptPath;
        m_scriptPath.clear();
        return;
    }
    file.write(kwinScriptSource().toUtf8());
    file.close();

    QDBusInterface scripting(
        QString::fromLatin1(kKWinService),
        QString::fromLatin1(kKWinScriptingPath),
        QString::fromLatin1(kKWinScriptingInterface),
        QDBusConnection::sessionBus());
    if (!scripting.isValid()) {
        qWarning() << "ActiveNotch: KWin Scripting インターフェースに接続できません:"
                   << scripting.lastError().message();
        QFile::remove(m_scriptPath);
        m_scriptPath.clear();
        return;
    }

    // 前回異常終了などで同名プラグインが残っている場合は先にアンロードする
    // (loadScript が「already loaded」で失敗するのを防ぐ)。
    const QDBusReply<bool> alreadyLoaded =
        scripting.call(QStringLiteral("isScriptLoaded"), m_pluginName);
    if (alreadyLoaded.isValid() && alreadyLoaded.value()) {
        scripting.call(QStringLiteral("unloadScript"), m_pluginName);
        qInfo() << "ActiveNotch: 残存していた KWin スクリプト"
                << m_pluginName << "をアンロードしました";
    }

    const QDBusReply<int> reply =
        scripting.call(QStringLiteral("loadScript"), m_scriptPath, m_pluginName);
    if (!reply.isValid()) {
        qWarning() << "ActiveNotch: KWin loadScript に失敗しました:"
                   << reply.error().message();
        QFile::remove(m_scriptPath);
        m_scriptPath.clear();
        return;
    }

    m_scriptId = reply.value();
    if (m_scriptId < 0) {
        qWarning() << "ActiveNotch: KWin がスクリプト ID を返しませんでした"
                      "(KWin スクリプトが無効の可能性)";
        QFile::remove(m_scriptPath);
        m_scriptPath.clear();
        return;
    }

    // KWin 6 で確実にスクリプトを開始する方法は /Scripting の引数なし start()
    // (全ロード済みスクリプトを開始する)。
    //
    // 注意 (実機 KWin 6.8.2 で検証): 個別スクリプトオブジェクト
    // (/Scripting/Script<id>) の run() は呼び出しても開始されない
    // (loadScript の戻り値とオブジェクト番号が一致しないため)。
    // よって start() を最優先し、失敗時のみ KWin 5 系の start(pluginName) を試す。
    bool started = false;
    QDBusMessage startReply = scripting.call(QStringLiteral("start"));
    if (startReply.type() == QDBusMessage::ErrorMessage) {
        startReply = scripting.call(QStringLiteral("start"), m_pluginName);
    }
    started = (startReply.type() != QDBusMessage::ErrorMessage);
    if (!started)
        qWarning() << "ActiveNotch: KWin スクリプトの start に失敗:"
                   << startReply.errorMessage();

    if (!started) {
        scripting.call(QStringLiteral("unloadScript"), m_pluginName);
        QFile::remove(m_scriptPath);
        m_scriptPath.clear();
        m_scriptId = -1;
        return;
    }

    m_scriptLoaded = true;
    qInfo() << "ActiveNotch: 全画面検出用 KWin スクリプトをロードしました (id="
            << m_scriptId << ")";
}

void FullscreenDetector::teardown()
{
    // KWin スクリプトの後片付け。すべて失敗しても継続する。
    if (m_scriptId >= 0) {
        QDBusInterface scriptInterface(
            QString::fromLatin1(kKWinService),
            QStringLiteral("/Scripting/Script%1").arg(m_scriptId),
            QString::fromLatin1(kKWinScriptInterface),
            QDBusConnection::sessionBus());
        if (scriptInterface.isValid())
            scriptInterface.call(QStringLiteral("stop"));
        m_scriptId = -1;
    }

    {
        QDBusInterface scripting(
            QString::fromLatin1(kKWinService),
            QString::fromLatin1(kKWinScriptingPath),
            QString::fromLatin1(kKWinScriptingInterface),
            QDBusConnection::sessionBus());
        if (scripting.isValid())
            scripting.call(QStringLiteral("unloadScript"), m_pluginName);
    }
    m_scriptLoaded = false;

    if (!m_scriptPath.isEmpty()) {
        QFile::remove(m_scriptPath);
        m_scriptPath.clear();
    }

    if (m_registered) {
        QDBusConnection bus = QDBusConnection::sessionBus();
        bus.unregisterObject(QString::fromLatin1(kObjectPath));
        bus.unregisterService(QString::fromLatin1(kServiceName));
        m_registered = false;
    }
}

void FullscreenDetector::fullscreenChanged(bool fullscreen)
{
    if (m_fullscreen == fullscreen)
        return;
    m_fullscreen = fullscreen;
    emit fullscreenStateChanged(fullscreen);
}
