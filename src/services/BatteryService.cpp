#include "BatteryService.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDBusMessage>
#include <QDebug>
#include <QFile>
#include <QTimer>
#include <QRegularExpression>

namespace {
constexpr char kUPowerService[] = "org.freedesktop.UPower";
constexpr char kUPowerPath[] = "/org/freedesktop/UPower";
constexpr char kUPowerInterface[] = "org.freedesktop.UPower";
constexpr char kDeviceInterface[] = "org.freedesktop.UPower.Device";
constexpr int kPollIntervalMs = 30000;
constexpr char kBatPath[] = "/sys/class/power_supply/BAT0";
constexpr char kAcPath[] = "/sys/class/power_supply/AC0";

QString readFile(const QString &path)
{
    QFile f(path);
    if (f.open(QIODevice::ReadOnly | QIODevice::Text))
        return QString::fromUtf8(f.readAll()).trimmed();
    return QString();
}

bool readBoolFile(const QString &path)
{
    return readFile(path) == "1";
}

int readIntFile(const QString &path, int def = 0)
{
    bool ok = false;
    int v = readFile(path).toInt(&ok);
    return ok ? v : def;
}

qreal readDoubleFile(const QString &path, qreal def = 0.0)
{
    bool ok = false;
    qreal v = readFile(path).toDouble(&ok);
    return ok ? v : def;
}

} // namespace

class BatteryService::Private
{
public:
    explicit Private(BatteryService *q) : q_ptr(q) {}

    BatteryService *q_ptr;

    QDBusInterface *deviceIface = nullptr;
    QString devicePath;
    QTimer pollTimer;

    void setupUPower()
    {
        QDBusConnection bus = QDBusConnection::systemBus();
        if (!bus.isConnected()) return;

        // まず UPower デーモンからデバイス一覧を取得
        QDBusInterface upower(kUPowerService, kUPowerPath, kUPowerInterface, bus);
        if (!upower.isValid()) return;

        QDBusReply<QList<QDBusObjectPath>> devices = upower.call("EnumerateDevices");
        if (!devices.isValid()) return;

        for (const QDBusObjectPath &path : devices.value()) {
            QDBusInterface dev(kUPowerService, path.path(), kDeviceInterface, bus);
            if (!dev.isValid()) continue;

            QVariant type = dev.property("Type");
            // 2 = Battery
            if (type.isValid() && type.toUInt() == 2) {
                devicePath = path.path();
                deviceIface = new QDBusInterface(kUPowerService, devicePath, kDeviceInterface, bus, q_ptr);
                if (deviceIface->isValid()) {
                    // PropertiesChanged シグナルを購読
                    bus.connect(kUPowerService, devicePath,
                                "org.freedesktop.DBus.Properties", "PropertiesChanged",
                                q_ptr, SLOT(onUPowerPropertiesChanged(QString,QVariantMap,QStringList)));
                }
                break;
            }
        }
    }

    void applyUPowerProps(const QVariantMap &props)
    {
        if (props.contains("Percentage")) {
            q_ptr->m_percent = qBound(0, props["Percentage"].toInt(), 100);
        }
        if (props.contains("State")) {
            // 1=Charging, 2=Discharging, 3=Empty, 4=FullyCharged, 5=PendingCharge, 6=PendingDischarge
            uint state = props["State"].toUInt();
            q_ptr->m_charging = (state == 1 || state == 5);
        }
        if (props.contains("EnergyRate")) {
            // uW -> W
            q_ptr->m_powerW = props["EnergyRate"].toDouble() / 1'000'000.0;
        }
        if (props.contains("TimeToEmpty") || props.contains("TimeToFull")) {
            qint64 secs = q_ptr->m_charging
                              ? props.value("TimeToFull", 0).toLongLong()
                              : props.value("TimeToEmpty", 0).toLongLong();
            q_ptr->m_timeRemainingText = formatDuration(secs);
        }
        q_ptr->emitAllChanged();
    }

    static QString formatDuration(qint64 seconds)
    {
        if (seconds <= 0) return QString();
        const qint64 h = seconds / 3600;
        const qint64 m = (seconds % 3600) / 60;
        if (h > 0) return QStringLiteral("%1h %2m").arg(h).arg(m, 2, 10, QChar('0'));
        return QStringLiteral("%1m").arg(m);
    }

    void poll()
    {
        if (deviceIface && deviceIface->isValid()) {
            updateFromUPower();
        } else {
            updateFromSysfs();
        }
    }

    void updateFromUPower()
    {
        if (!deviceIface || !deviceIface->isValid()) return;

        QVariant percentage = deviceIface->property("Percentage");
        QVariant state = deviceIface->property("State");
        QVariant energyRate = deviceIface->property("EnergyRate");
        QVariant timeToEmpty = deviceIface->property("TimeToEmpty");
        QVariant timeToFull = deviceIface->property("TimeToFull");
        QVariant isPresent = deviceIface->property("IsPresent");

        if (isPresent.isValid() && isPresent.toBool() == false) {
            q_ptr->m_available = false;
            q_ptr->emitAllChanged();
            return;
        }

        q_ptr->m_available = true;
        if (percentage.isValid()) q_ptr->m_percent = qBound(0, qRound(percentage.toDouble()), 100);
        if (state.isValid()) q_ptr->m_charging = (state.toUInt() == 1 || state.toUInt() == 5);
        if (energyRate.isValid()) q_ptr->m_powerW = energyRate.toDouble() / 1'000'000.0;
        qint64 secs = q_ptr->m_charging ? (timeToFull.isValid() ? timeToFull.toLongLong() : 0)
                                         : (timeToEmpty.isValid() ? timeToEmpty.toLongLong() : 0);
        q_ptr->m_timeRemainingText = formatDuration(secs);

        // AC オンライン確認
        q_ptr->m_plugged = readBoolFile(QString(kAcPath) + "/online");
        q_ptr->emitAllChanged();
    }

    void updateFromSysfs()
    {
        // BAT0 が存在するか
        QFile batCap(QString(kBatPath) + "/capacity");
        if (!batCap.exists()) {
            q_ptr->m_available = false;
            q_ptr->emitAllChanged();
            return;
        }

        q_ptr->m_available = true;
        q_ptr->m_percent = readIntFile(QString(kBatPath) + "/capacity");
        const QString status = readFile(QString(kBatPath) + "/status").toLower();
        q_ptr->m_charging = (status == "charging" || status == "full");
        q_ptr->m_plugged = readBoolFile(QString(kAcPath) + "/online");

        // power_now (uW) から概算 W
        qreal powerUW = readDoubleFile(QString(kBatPath) + "/power_now");
        if (powerUW <= 0) {
            // current_now * voltage_now で推定
            powerUW = readDoubleFile(QString(kBatPath) + "/current_now")
                    * readDoubleFile(QString(kBatPath) + "/voltage_now");
        }
        q_ptr->m_powerW = powerUW / 1'000'000.0;

        // time remaining 簡易計算: energy_now / power_now
        qreal energyNow = readDoubleFile(QString(kBatPath) + "/energy_now");
        if (energyNow > 0 && q_ptr->m_powerW > 0) {
            qint64 secs = qint64(energyNow / 1'000'000.0 / q_ptr->m_powerW * 3600);
            q_ptr->m_timeRemainingText = formatDuration(q_ptr->m_charging ? 0 : secs); // 充電中は TimeToFull が必要だが sysfs には無い
        } else {
            q_ptr->m_timeRemainingText.clear();
        }
        q_ptr->emitAllChanged();
    }
};

BatteryService::BatteryService(QObject *parent)
    : QObject(parent), d(std::make_unique<Private>(this))
{
    d->setupUPower();

    // フォールバック・補完用ポーリング
    connect(&d->pollTimer, &QTimer::timeout, this, [this]() { d->poll(); });
    d->pollTimer.setInterval(kPollIntervalMs);
    d->pollTimer.start();

    // 初回即時実行
    QTimer::singleShot(0, this, [this]() { d->poll(); });
}

BatteryService::~BatteryService() = default;

void BatteryService::refresh() { d->poll(); }

void BatteryService::emitAllChanged()
{
    emit availableChanged();
    emit percentChanged();
    emit chargingChanged();
    emit pluggedChanged();
    emit powerWChanged();
    emit timeRemainingTextChanged();
}

QString BatteryService::formatTimeRemaining(qint64 seconds, bool charging)
{
    if (seconds <= 0) {
        if (charging) return QStringLiteral("計算中...");
        return QStringLiteral("不明");
    }
    const qint64 h = seconds / 3600;
    const qint64 m = (seconds % 3600) / 60;
    if (charging) {
        if (h > 0) return QStringLiteral("充電中: %1h %2m").arg(h).arg(m, 2, 10, QChar('0'));
        return QStringLiteral("充電中: %1m").arg(m);
    }
    if (h > 0) return QStringLiteral("%1h %2m").arg(h).arg(m, 2, 10, QChar('0'));
    if (m > 0) return QStringLiteral("%1m").arg(m);
    return QStringLiteral("まもなく空");
}

void BatteryService::onUPowerPropertiesChanged(const QString &interfaceName, const QVariantMap &properties, const QStringList &)
{
    if (interfaceName == QStringLiteral("org.freedesktop.UPower.Device")) {
        // applyUPowerProps is in Private, so we need to call through Private
        // We'll replicate the logic here for simplicity
        if (properties.contains("Percentage")) {
            m_percent = qBound(0, properties["Percentage"].toInt(), 100);
        }
        if (properties.contains("State")) {
            uint state = properties["State"].toUInt();
            m_charging = (state == 1 || state == 5);
        }
        if (properties.contains("EnergyRate")) {
            m_powerW = properties["EnergyRate"].toDouble() / 1'000'000.0;
        }
        if (properties.contains("TimeToEmpty") || properties.contains("TimeToFull")) {
            qint64 secs = m_charging
                              ? properties.value("TimeToFull", 0).toLongLong()
                              : properties.value("TimeToEmpty", 0).toLongLong();
            m_timeRemainingText = formatDuration(secs);
        }
        emitAllChanged();
    }
}

QString BatteryService::formatDuration(qint64 seconds)
{
    if (seconds <= 0) return QString();
    const qint64 h = seconds / 3600;
    const qint64 m = (seconds % 3600) / 60;
    if (h > 0) return QStringLiteral("%1h %2m").arg(h).arg(m, 2, 10, QChar('0'));
    return QStringLiteral("%1m").arg(m);
}