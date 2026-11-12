#include <QCoreApplication>
#include <QDebug>
#include <QGuiApplication>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickWindow>
#include <QTranslator>
#include <QLocale>
#include <QLibraryInfo>

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
#include "services/NetworkService.h"
#include "services/BluetoothService.h"
#include "services/WeatherService.h"
#include "services/NotificationService.h"
#include "services/ClipboardService.h"
#include "services/LauncherService.h"
#include "services/TrayService.h"

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

    // Wayland でウィンドウ背景を確実に透過させる。
    // QQuickView 個別の QSurfaceFormat だけでは QPA によっては alpha が
    // 要求されず、ピル外が不透明な黒になることがある。最初の QQuickWindow
    // を生成する前にこれを呼ぶ必要がある (Qt ドキュメント準拠)。
    QQuickWindow::setDefaultAlphaBuffer(true);

    // アプリ識別情報。Phase 7 の KConfig 永続化
    // (~/.config/activenotch/) の前提となる値。
    QCoreApplication::setApplicationName(QStringLiteral("activenotch"));
    QCoreApplication::setApplicationVersion(QStringLiteral("0.1.0"));
    QCoreApplication::setOrganizationDomain(QStringLiteral("dev.yukirawa"));
    QCoreApplication::setOrganizationName(QStringLiteral("yukirawa"));
    QGuiApplication::setApplicationDisplayName(QStringLiteral("ActiveNotch"));

    // ---- i18n: QTranslator 設定 --------------------------------------------
    // Qt 自身の翻訳 + アプリ翻訳 (.qm) をインストール
    // 翻訳ファイルは qt_add_translations で生成され、リソースに埋め込まれる
    QTranslator qtTranslator;
    if (qtTranslator.load(QLocale::system(), QStringLiteral("qtbase"), QStringLiteral("_"),
                          QLibraryInfo::path(QLibraryInfo::TranslationsPath))) {
        app.installTranslator(&qtTranslator);
    }

    QTranslator appTranslator;
    // リソースパス: :/i18n/<locale>.qm (qt_add_translations は TS ファイル名をエイリアスに使用)
    const QString localeName = QLocale::system().name(); // 例: "ja_JP", "en_US"
    if (appTranslator.load(QStringLiteral(":/i18n/") + localeName + QStringLiteral(".qm"))) {
        app.installTranslator(&appTranslator);
    } else {
        // フォールバック: 言語のみ (ja, en)
        const QString langOnly = QLocale::system().language() == QLocale::Japanese
                                     ? QStringLiteral("ja")
                                     : QStringLiteral("en");
        if (appTranslator.load(QStringLiteral(":/i18n/") + langOnly + QStringLiteral(".qm"))) {
            app.installTranslator(&appTranslator);
        }
    }

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

    // Phase 4 サービス
    NetworkService networkService;
    BluetoothService bluetoothService;
    WeatherService weatherService;

    // Phase 5 サービス
    NotificationService notificationService;
    ClipboardService clipboardService;

    // Phase 6 サービス
    LauncherService launcherService;
    TrayService trayService;

    // ---- コンテキストプロパティ登録 --------------------------------------
    // QML 側は `NotchWindow.fullscreenActive` をガード付きで参照する
    // (CONTRACT §2)。Phase 1 では NotchWindow 自身を公開する。
    // Phase 2 サービスは CONTRACT §3 表の名前で固定: Config, BatteryService, AudioService,
    // BrightnessService, QuickSettingsService, CalendarService
    // Phase 3 サービス: MediaService, StatsService
    // Phase 4 サービス: NetworkService, BluetoothService, WeatherService
    // Phase 5 サービス: NotificationService, ClipboardService
    // Phase 6 サービス: LauncherService, TrayService
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
        engine->rootContext()->setContextProperty(QStringLiteral("NetworkService"), &networkService);
        engine->rootContext()->setContextProperty(QStringLiteral("BluetoothService"), &bluetoothService);
        engine->rootContext()->setContextProperty(QStringLiteral("WeatherService"), &weatherService);
        engine->rootContext()->setContextProperty(QStringLiteral("NotificationService"), &notificationService);
        engine->rootContext()->setContextProperty(QStringLiteral("ClipboardService"), &clipboardService);
        engine->rootContext()->setContextProperty(QStringLiteral("LauncherService"), &launcherService);
        engine->rootContext()->setContextProperty(QStringLiteral("TrayService"), &trayService);
    } else {
        qWarning() << "ActiveNotch: QML エンジンを取得できませんでした。";
    }

    // ---- i18n: 言語変更時の翻訳再インストール ---------------------------------
    // ConfigService.language が変わったら QTranslator を入れ替える
    QObject::connect(&configService, &ConfigService::languageChanged, &app, [&app, &appTranslator, &configService]() {
        // 既存のアプリ翻訳を削除
        app.removeTranslator(&appTranslator);

        const QString localeName = configService.language(); // "ja", "ja_JP", "en", "en_US" 等
        // まず完全一致 (ja_JP, en_US) を試す
        if (appTranslator.load(QStringLiteral(":/i18n/") + localeName + QStringLiteral(".qm"))) {
            app.installTranslator(&appTranslator);
            qDebug() << "ActiveNotch: Installed translation for" << localeName;
            return;
        }
        // フォールバック: 言語のみ (ja, en)
        QLocale locale(localeName);
        const QString langOnly = locale.language() == QLocale::Japanese ? QStringLiteral("ja") : QStringLiteral("en");
        if (appTranslator.load(QStringLiteral(":/i18n/") + langOnly + QStringLiteral(".qm"))) {
            app.installTranslator(&appTranslator);
            qDebug() << "ActiveNotch: Installed fallback translation for" << langOnly;
        } else {
            qWarning() << "ActiveNotch: No translation found for" << localeName << "or fallback" << langOnly;
        }
    });

    // ---- QML ロード → 表示 ------------------------------------------------
    // 全画面検出 (FullscreenDetector) は NotchWindow が内部で生成し、
    // コンストラクタで D-Bus 登録と KWin スクリプトのロードを行う。
    // 失敗しても機能 OFF で継続する。
    notch.load();
    notch.show();

    return app.exec();
}
