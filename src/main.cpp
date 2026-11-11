#include <QCoreApplication>
#include <QGuiApplication>

#include "NotchWindow.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    // アプリ識別情報。Phase 7 の KConfig 永続化
    // (~/.config/activenotch/) の前提となる値。
    QCoreApplication::setApplicationName(QStringLiteral("activenotch"));
    QCoreApplication::setApplicationVersion(QStringLiteral("0.1.0"));
    QCoreApplication::setOrganizationDomain(QStringLiteral("dev.yukirawa"));
    QCoreApplication::setOrganizationName(QStringLiteral("yukirawa"));
    QGuiApplication::setApplicationDisplayName(QStringLiteral("ActiveNotch"));

    // layer-shell は Wayland 専用。Wayland 以外で起動された場合は
    // 日本語の警告を stderr に出して続行する
    // (誤起動でも状況をログから把握できるようにするため)。
    const QString platform = QGuiApplication::platformName();
    if (platform != QLatin1String("wayland")) {
        qWarning() << "ActiveNotch: Wayland 以外のプラットフォーム (" << platform
                  << ") で起動されました。layer-shell による配置は Wayland 専用のため、"
                     "ノッチは正しく配置されません。";
    }

    NotchWindow notch;
    notch.show();

    return app.exec();
}
