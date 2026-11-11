#include "BluetoothService.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusReply>
#include <QDebug>
#include <QTimer>

namespace {
constexpr char kBlueZService[] = "org.bluez";
constexpr char kBlueZAdapterInterface[] = "org.bluez.Adapter1";
constexpr char kBlueZDeviceInterface[] = "org.bluez.Device1";
constexpr char kPropertiesInterface[] = "org.freedesktop.DBus.Properties";
constexpr int kRefreshIntervalMs = 5000; // 5秒ごとにデバイスリスト更新

} // namespace

class BluetoothService::Private
{
public:
    explicit Private(BluetoothService *q) : q_ptr(q) {}

    BluetoothService *q_ptr;

    QDBusConnection m_bus = QDBusConnection::systemBus();
    QDBusInterface *m_adapterIface = nullptr;
    QString m_adapterPath;
    QTimer m_refreshTimer;

    void setup()
    {
        if (!m_bus.isConnected()) {
            qWarning() << "BluetoothService: System bus not connected";
            return;
        }

        // デフォルトアダプタを探す (/org/bluez/hci0 など)
        QDBusInterface manager(kBlueZService, "/", "org.freedesktop.DBus.ObjectManager", m_bus);
        if (!manager.isValid()) {
            qWarning() << "BluetoothService: BlueZ ObjectManager not available";
            return;
        }

        QDBusReply<QVariantMap> objects = manager.call("GetManagedObjects");
        if (!objects.isValid()) return;

        const QVariantMap &managedObjects = objects.value();
        for (auto it = managedObjects.constBegin(); it != managedObjects.constEnd(); ++it) {
            const QString &path = it.key();
            const QVariantMap &interfaces = it.value().toMap();

            if (interfaces.contains(kBlueZAdapterInterface)) {
                m_adapterPath = path;
                m_adapterIface = new QDBusInterface(kBlueZService, m_adapterPath, kBlueZAdapterInterface, m_bus, q_ptr);
                if (m_adapterIface->isValid()) {
                    // Adapter プロパティ変更監視
                    m_bus.connect(kBlueZService, m_adapterPath,
                                  kPropertiesInterface, "PropertiesChanged",
                                  q_ptr, SLOT(onAdapterPropertiesChanged(QString,QVariantMap)));

                    // インターフェース追加/削除監視 (デバイス検出用)
                    m_bus.connect(kBlueZService, "/",
                                  "org.freedesktop.DBus.ObjectManager", "InterfacesAdded",
                                  q_ptr, SLOT(onInterfacesAdded(QString,QVariantMap)));
                    m_bus.connect(kBlueZService, "/",
                                  "org.freedesktop.DBus.ObjectManager", "InterfacesRemoved",
                                  q_ptr, SLOT(onInterfacesRemoved(QString,QStringList)));

                    // 初期状態
                    q_ptr->m_powered = m_adapterIface->property("Powered").toBool();
                    q_ptr->m_available = true;
                    emit q_ptr->availableChanged();
                    emit q_ptr->poweredChanged();

                    // デバイス一覧初期取得
                    updateDevices();

                    // 定期更新
                    m_refreshTimer.setInterval(kRefreshIntervalMs);
                    connect(&m_refreshTimer, &QTimer::timeout, q_ptr, [this]() { updateDevices(); });
                    m_refreshTimer.start();
                }
                break;
            }
        }

        if (m_adapterPath.isEmpty()) {
            qWarning() << "BluetoothService: No Bluetooth adapter found";
        }
    }

    void updateDevices()
    {
        if (!m_adapterIface || !m_adapterIface->isValid()) return;

        QDBusInterface manager(kBlueZService, "/", "org.freedesktop.DBus.ObjectManager", m_bus);
        if (!manager.isValid()) return;

        QDBusReply<QVariantMap> objects = manager.call("GetManagedObjects");
        if (!objects.isValid()) return;

        const QVariantMap &managedObjects = objects.value();
        QVariantList newDevices;

        for (auto it = managedObjects.constBegin(); it != managedObjects.constEnd(); ++it) {
            const QVariantMap &interfaces = it.value().toMap();
            if (interfaces.contains(kBlueZDeviceInterface)) {
                const QVariantMap &deviceProps = interfaces[kBlueZDeviceInterface].toMap();
                QVariantMap entry = BluetoothService::parseDevice(deviceProps);
                if (!entry.isEmpty()) {
                    newDevices.append(entry);
                }
            }
        }

        // 名前でソート (接続済みを優先)
        std::sort(newDevices.begin(), newDevices.end(), [](const QVariant &a, const QVariant &b) {
            bool aConn = a.toMap().value("connected", false).toBool();
            bool bConn = b.toMap().value("connected", false).toBool();
            if (aConn != bConn) return aConn > bConn;
            return a.toMap().value("name", "").toString() < b.toMap().value("name", "").toString();
        });

        if (q_ptr->m_devices != newDevices) {
            q_ptr->m_devices = newDevices;
            emit q_ptr->devicesChanged();
        }
    }
};

BluetoothService::BluetoothService(QObject *parent)
    : QObject(parent), d(std::make_unique<Private>(this))
{
    d->setup();
}

BluetoothService::~BluetoothService() = default;

void BluetoothService::updateAvailable(bool available)
{
    if (m_available == available) return;
    m_available = available;
    emit availableChanged();
    if (!available) {
        m_powered = false; emit poweredChanged();
        m_devices.clear(); emit devicesChanged();
    }
}

void BluetoothService::updatePowered(bool powered)
{
    if (m_powered == powered) return;
    m_powered = powered;
    emit poweredChanged();
}

void BluetoothService::setPowered(bool powered)
{
    if (!m_available || !d->m_adapterIface || !d->m_adapterIface->isValid()) return;
    if (m_powered == powered) return;

    QDBusReply<void> reply = d->m_adapterIface->call("Set", kBlueZAdapterInterface, "Powered", QVariant::fromValue(powered));
    if (!reply.isValid()) {
        qWarning() << "BluetoothService: Failed to set Powered:" << reply.error().message();
    }
    // 実際の変更は PropertiesChanged シグナルで反映される
}

void BluetoothService::connectDevice(const QString &address)
{
    if (!m_available || address.isEmpty() || d->m_adapterPath.isEmpty()) return;

    // デバイスパスを構築 (MACアドレスから)
    QString formattedAddress = address;
    formattedAddress.replace(':', '_');
    QString devicePath = d->m_adapterPath + "/dev_" + formattedAddress;
    QDBusInterface deviceIface(kBlueZService, devicePath, kBlueZDeviceInterface, d->m_bus);
    if (!deviceIface.isValid()) {
        qWarning() << "BluetoothService: Device not found:" << address;
        return;
    }

    QDBusReply<void> reply = deviceIface.call("Connect");
    if (!reply.isValid()) {
        qWarning() << "BluetoothService: Failed to connect:" << reply.error().message();
    }
}

void BluetoothService::disconnectDevice(const QString &address)
{
    if (!m_available || address.isEmpty() || d->m_adapterPath.isEmpty()) return;

    QString formattedAddress = address;
    formattedAddress.replace(':', '_');
    QString devicePath = d->m_adapterPath + "/dev_" + formattedAddress;
    QDBusInterface deviceIface(kBlueZService, devicePath, kBlueZDeviceInterface, d->m_bus);
    if (!deviceIface.isValid()) {
        qWarning() << "BluetoothService: Device not found:" << address;
        return;
    }

    QDBusReply<void> reply = deviceIface.call("Disconnect");
    if (!reply.isValid()) {
        qWarning() << "BluetoothService: Failed to disconnect:" << reply.error().message();
    }
}

void BluetoothService::refresh()
{
    d->updateDevices();
}

void BluetoothService::onAdapterPropertiesChanged(const QString &interfaceName, const QVariantMap &properties)
{
    if (interfaceName != kBlueZAdapterInterface) return;

    if (properties.contains("Powered")) {
        updatePowered(properties["Powered"].toBool());
    }
}

void BluetoothService::onInterfacesAdded(const QString &, const QVariantMap &interfaces)
{
    if (interfaces.contains(kBlueZDeviceInterface)) {
        d->updateDevices();
    }
}

void BluetoothService::onInterfacesRemoved(const QString &, const QStringList &interfaces)
{
    if (interfaces.contains(kBlueZDeviceInterface)) {
        d->updateDevices();
    }
}

QVariantMap BluetoothService::parseDevice(const QVariantMap &deviceProps)
{
    QVariantMap result;

    QString name = deviceProps.value("Name").toString();
    if (name.isEmpty()) name = deviceProps.value("Alias").toString();
    if (name.isEmpty()) return result;

    result["name"] = name;
    result["address"] = deviceProps.value("Address").toString();
    result["connected"] = deviceProps.value("Connected", false).toBool();
    result["paired"] = deviceProps.value("Paired", false).toBool();

    // BatteryPercentage (BlueZ 5.60+ でサポート)
    if (deviceProps.contains("BatteryPercentage")) {
        result["battery"] = deviceProps.value("BatteryPercentage").toInt();
    } else {
        result["battery"] = -1; // 不明
    }

    return result;
}