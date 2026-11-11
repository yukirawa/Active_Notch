#include "QuickSettingsService.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QTimer>
#include <QDebug>

namespace {
constexpr char kKWinService[] = "org.kde.KWin";
constexpr char kNightLightPath[] = "/org/kde/KWin/NightLight";
constexpr char kNightLightInterface[] = "org.kde.kwin.NightLight";
constexpr int kPollIntervalMs = 2000;
} // namespace

class QuickSettingsService::Private
{
public:
    explicit Private(QuickSettingsService *q) : q_ptr(q) {}

    QuickSettingsService *q_ptr;
    QTimer pollTimer;

    void setup()
    {
        pollTimer.setInterval(kPollIntervalMs);
        connect(&pollTimer, &QTimer::timeout, q_ptr, [this]() { q_ptr->updateFromDBus(); });
        pollTimer.start();

        // 初回即時
        QTimer::singleShot(0, q_ptr, [this]() { q_ptr->updateFromDBus(); });
    }
};

QuickSettingsService::QuickSettingsService(QObject *parent)
    : QObject(parent), d(std::make_unique<Private>(this))
{
    d->setup();
}

QuickSettingsService::~QuickSettingsService() = default;

void QuickSettingsService::refresh() { updateFromDBus(); }

void QuickSettingsService::updateFromDBus()
{
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected()) {
        if (m_available) {
            m_available = false;
            emit nightLightAvailableChanged();
        }
        return;
    }

    QDBusInterface iface(kKWinService, kNightLightPath, kNightLightInterface, bus);
    if (!iface.isValid()) {
        if (m_available) {
            m_available = false;
            emit nightLightAvailableChanged();
        }
        return;
    }

    QVariant enabledVar = iface.property("enabled");
    if (!enabledVar.isValid()) {
        if (m_available) {
            m_available = false;
            emit nightLightAvailableChanged();
        }
        return;
    }

    bool wasAvailable = m_available;
    m_available = true;
    m_nightLightOn = enabledVar.toBool();

    if (!wasAvailable) emit nightLightAvailableChanged();
    emit nightLightOnChanged();
}

void QuickSettingsService::toggleNightLight()
{
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected()) return;

    QDBusInterface iface(kKWinService, kNightLightPath, kNightLightInterface, bus);
    if (!iface.isValid()) return;

    QDBusReply<void> reply = iface.call("SetEnabled", !m_nightLightOn);
    if (reply.isValid()) {
        m_nightLightOn = !m_nightLightOn;
        emit nightLightOnChanged();
    }
}