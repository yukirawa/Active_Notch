#include <QCoreApplication>
#include <QDebug>
#include <QGuiApplication>
#include <QQmlContext>
#include <QQmlEngine>

#ifdef Q_OS_LINUX
#include <QSocketNotifier>

#include <csignal>
#include <sys/signalfd.h>
#include <unistd.h>
#endif

#include "NotchWindow.h"
#include "services/BatteryService.h"
#include "services/AudioService.h"
#include "services/BrightnessService.h"
#include "services/QuickSettingsService.h"
#include "services/ConfigService.h"
#include "services/CalendarService.h"
#include "services/MediaService.h"
#include "services/StatsService.h"

namespace {

#ifdef Q_OS_LINUX
/**
 * SIGTERM / SIGINT を signalfd で受けるための fd を作る。
 *
 * scripts/stop.sh や verify-ui.sh の trap は SIGTERM でアプリを止めるため、
 * シグナルを QSocketNotifier 経由で QCoreApplication::quit() に変換し、
 * KWin スクリプトの unload や D-Bus サービスの解放 (デストラクタ) を
 * 確実に実行させる。
 */
int installTerminationSignalFd()
{
    sigset_t mask;
    sigemptyset(&mask);
    sigaddset(&mask, SIGTERM);
    sigaddset(&mask, SIGINT);
    if (sigprocmask(SIG_BLOCK, &mask, nullptr) != 0)
        return -1;
    return signalfd(-1, &mask, SFD_NONBLOCK | SFD_CLOEXEC);
}
#endif

} // namespace

int main(int argc, char *argv[])
{
#ifdef Q_OS_LINUX
    // 重要: シグナルマスクは QGuiApplication 生成前 (他スレッドができる前) に
    // 設定する。生成後だとシグナルが別スレッドへ配送され既定動作で即終了し、
    // KWin スクリプトの後片付けが走らない。
    const int signalFd = installTerminationSignalFd();
#endif

    QGuiApplication app(argc, argv);

    // アプリ識別情報。Phase 7 の KConfig 永続化
    // (~/.config/activenotch/) の前提となる値。
    QCoreApplication::setApplicationName(QStringLiteral("activenotch"));
    QCoreApplication::setApplicationVersion(QStringLiteral("0.1.0"));
    QCoreApplication::setOrganizationDomain(QStringLiteral("dev.yukirawa"));
    QCoreApplication::setOrganizationName(QStringLiteral("yukirawa"));
    QGuiApplication::setApplicationDisplayName(QStringLiteral("ActiveNotch"));

#ifdef Q_OS_LINUX
    if (signalFd >= 0) {
        auto *signalNotifier = new QSocketNotifier(signalFd, QSocketNotifier::Read, &app);
        QObject::connect(signalNotifier, &QSocketNotifier::activated, &app,
                         [&app, signalFd]() {
                             struct signalfd_siginfo info;
                             while (::read(signalFd, &info, sizeof(info)) == sizeof(info)) {
                                 // pending を読み切る
                             }
                             app.quit();
                         });
    }
#endif

    // layer-shell は Wayland 専用。Wayland 以外で起動された場合は
    // 日本語の警告を stderr に出して続行する。
    const QString platform = QGuiApplication::platformName();
    if (platform != QLatin1String("wayland")) {
        qWarning() << "ActiveNotch: Wayland 以外のプラットフォーム (" << platform
                   << ") で起動されました。layer-shell による配置は Wayland 専用のため、"
                      "ノッチは正しく配置されません。";
    }

    // ---- サービス生成 ----------------------------------------------------
    // NotchWindow 自身が BlurHelper と FullscreenDetector を所有する。
    NotchWindow notch;

    // Phase 2 サービス
    ConfigService configService;
    BatteryService batteryService;
    AudioService audioService;
    BrightnessService brightnessService;
    QuickSettingsService quickSettingsService;
    CalendarService calendarService;

    // Phase 3 サービス
    MediaService mediaService;
    StatsService statsService;

    // ---- コンテキストプロパティ登録 --------------------------------------
    // QML 側は `NotchWindow.fullscreenActive` をガード付きで参照する
    // (CONTRACT §2)。Phase 1 では NotchWindow 自身を公開する。
    // Phase 2 サービスは CONTRACT §3 表の名前で固定: Config, BatteryService, AudioService,
    // BrightnessService, QuickSettingsService, CalendarService
    // Phase 3 サービス: MediaService, StatsService
    if (QQmlEngine *engine = notch.engine()) {
        engine->rootContext()->setContextProperty(QStringLiteral("NotchWindow"), &notch);
        engine->rootContext()->setContextProperty(QStringLiteral("Config"), &configService);
        engine->rootContext()->setContextProperty(QStringLiteral("BatteryService"), &batteryService);
        engine->rootContext()->setContextProperty(QStringLiteral("AudioService"), &audioService);
        engine->rootContext()->setContextProperty(QStringLiteral("BrightnessService"), &brightnessService);
        engine->rootContext()->setContextProperty(QStringLiteral("QuickSettingsService"), &quickSettingsService);
        engine->rootContext()->setContextProperty(QStringLiteral("CalendarService"), &calendarService);
        engine->rootContext()->setContextProperty(QStringLiteral("MediaService"), &mediaService);
        engine->rootContext()->setContextProperty(QStringLiteral("StatsService"), &statsService);
    } else {
        qWarning() << "ActiveNotch: QML エンジンを取得できませんでした。";
    }

    // ---- QML ロード → 表示 ------------------------------------------------
    // 全画面検出 (FullscreenDetector) は NotchWindow が内部で生成し、
    // コンストラクタで D-Bus 登録と KWin スクリプトのロードを行う。
    // 失敗しても機能 OFF で継続する。
    notch.load();
    notch.show();

    return app.exec();
}
