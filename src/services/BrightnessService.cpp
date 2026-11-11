#include "BrightnessService.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QFile>
#include <QFileSystemWatcher>
#include <QTimer>
#include <QDebug>
#include <QDir>

namespace {
constexpr char kBacklightBase[] = "/sys/class/backlight/intel_backlight";
constexpr char kLogindService[] = "org.freedesktop.login1";
constexpr char kLogindPath[] = "/org/freedesktop/login1/session/self";
constexpr char kLogindInterface[] = "org.freedesktop.login1.Session";
constexpr int kPollIntervalMs = 500;

int readIntFile(const QString &path, int def = 0)
{
    QFile f(path);
    if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        bool ok = false;
        int v = QString::fromUtf8(f.readAll()).trimmed().toInt(&ok);
        if (ok) return v;
    }
    return def;
}

bool writeIntFile(const QString &path, int value)
{
    QFile f(path);
    if (f.open(QIODevice::WriteOnly | QIODevice::Text)) {
        return f.write(QByteArray::number(value)) > 0;
    }
    return false;
}

} // namespace

class BrightnessService::Private
{
public:
    explicit Private(BrightnessService *q) : q_ptr(q) {}

    BrightnessService *q_ptr;
    QTimer pollTimer;
    QFileSystemWatcher watcher;

    void setup()
    {
        // intel_backlight を探す (存在しない場合は最初の backlight デバイスを使用)
        QDir dir("/sys/class/backlight");
        QStringList entries = dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
        for (const QString &e : entries) {
            QString p = "/sys/class/backlight/" + e + "/max_brightness";
            if (QFile::exists(p)) {
                q_ptr->m_maxBrightnessPath = p;
                q_ptr->m_brightnessPath = "/sys/class/backlight/" + e + "/brightness";
                break;
            }
        }

        if (q_ptr->m_maxBrightnessPath.isEmpty()) {
            q_ptr->m_available = false;
            q_ptr->emitAllChanged();
            return;
        }

        q_ptr->m_maxBrightness = readIntFile(q_ptr->m_maxBrightnessPath);
        if (q_ptr->m_maxBrightness <= 0) {
            q_ptr->m_available = false;
            q_ptr->emitAllChanged();
            return;
        }

        // ファイル監視で即時反映
        watcher.addPath(q_ptr->m_brightnessPath);
        connect(&watcher, &QFileSystemWatcher::fileChanged, q_ptr, [this](const QString&) {
            updateFromSysfs();
        });

        pollTimer.setInterval(kPollIntervalMs);
        connect(&pollTimer, &QTimer::timeout, q_ptr, [this]() { q_ptr->poll(); });
        pollTimer.start();

        updateFromSysfs();
    }

    void updateFromSysfs()
    {
        int cur = readIntFile(q_ptr->m_brightnessPath);
        q_ptr->m_brightness = q_ptr->m_maxBrightness > 0
                                ? qreal(cur) / q_ptr->m_maxBrightness
                                : 0.0;
        q_ptr->m_available = true;
        q_ptr->emitAllChanged();
    }
};

BrightnessService::BrightnessService(QObject *parent)
    : QObject(parent), d(std::make_unique<Private>(this))
{
    d->setup();
}

BrightnessService::~BrightnessService() = default;

void BrightnessService::poll() { d->updateFromSysfs(); }

void BrightnessService::setBrightness(qreal v)
{
    v = qBound<qreal>(0.0, v, 1.0);
    int value = qRound(v * m_maxBrightness);
    if (value < 1) value = 1;
    if (value > m_maxBrightness) value = m_maxBrightness;

    // まず logind 経由を試す
    if (writeViaLogind(value)) {
        m_brightness = v;
        emit brightnessChanged();
        return;
    }
    // フォールバック: sysfs 直接書き込み
    if (writeViaSysfs(value)) {
        m_brightness = v;
        emit brightnessChanged();
        return;
    }
    // どちらも失敗
    qWarning() << "BrightnessService: 書き込み失敗 (logind + sysfs 両方)";
}

bool BrightnessService::writeViaLogind(int value)
{
    QDBusConnection bus = QDBusConnection::systemBus();
    if (!bus.isConnected()) return false;

    QDBusInterface iface(kLogindService, kLogindPath, kLogindInterface, bus);
    if (!iface.isValid()) return false;

    QDBusReply<void> reply = iface.call("SetBrightness", "backlight", "intel_backlight", static_cast<uint32_t>(value));
    return reply.isValid();
}

bool BrightnessService::writeViaSysfs(int value)
{
    return writeIntFile(m_brightnessPath, value);
}

void BrightnessService::emitAllChanged()
{
    emit availableChanged();
    emit brightnessChanged();
}

qreal BrightnessService::parseBrightness(const QString &maxPath, const QString &curPath)
{
    auto readInt = [](const QString &path) -> int {
        QFile f(path);
        if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
            bool ok = false;
            int v = QString::fromUtf8(f.readAll()).trimmed().toInt(&ok);
            if (ok) return v;
        }
        return -1;
    };

    int maxVal = readInt(maxPath);
    int curVal = readInt(curPath);
    if (maxVal <= 0 || curVal < 0) return 0.0;
    return qBound<qreal>(0.0, qreal(curVal) / maxVal, 1.0);
}