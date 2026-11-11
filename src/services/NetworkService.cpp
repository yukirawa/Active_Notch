#include "NetworkService.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusReply>
#include <QDBusObjectPath>
#include <QDebug>
#include <QTimer>

namespace {
constexpr char kNmService[] = "org.freedesktop.NetworkManager";
constexpr char kNmPath[] = "/org/freedesktop/NetworkManager";
constexpr char kNmInterface[] = "org.freedesktop.NetworkManager";
constexpr char kNmDeviceInterface[] = "org.freedesktop.NetworkManager.Device";
constexpr char kNmDeviceWifiInterface[] = "org.freedesktop.NetworkManager.Device.Wireless";
constexpr char kNmActiveConnectionInterface[] = "org.freedesktop.NetworkManager.Connection.Active";
constexpr char kNmAccessPointInterface[] = "org.freedesktop.NetworkManager.AccessPoint";
constexpr char kPropertiesInterface[] = "org.freedesktop.DBus.Properties";
constexpr int kScanIntervalMs = 30000; // 30秒ごとにスキャン

// NM Device.State 値
// 10=unmanaged, 20=unavailable, 30=disconnected, 40=prepare, 50=config, 60=need-auth, 70=ip-config, 80=ip-check, 90=secondaries, 100=activated, 110=deactivating, 120=failed
QString deviceStateToStringStatic(uint state)
{
    switch (state) {
    case 10: return "unmanaged";
    case 20: return "unavailable";
    case 30: return "disconnected";
    case 40: return "prepare";
    case 50: return "config";
    case 60: return "need-auth";
    case 70: return "ip-config";
    case 80: return "ip-check";
    case 90: return "secondaries";
    case 100: return "connected";
    case 110: return "deactivating";
    case 120: return "failed";
    default: return "unknown";
    }
}

} // namespace

class NetworkService::Private
{
public:
    explicit Private(NetworkService *q) : q_ptr(q) {}

    NetworkService *q_ptr;

    QDBusConnection m_bus = QDBusConnection::systemBus();
    QDBusInterface *m_nmIface = nullptr;
    QDBusInterface *m_wifiDeviceIface = nullptr;
    QString m_wifiDevicePath;
    QTimer m_scanTimer;

    void setup()
    {
        if (!m_bus.isConnected()) {
            qWarning() << "NetworkService: System bus not connected";
            return;
        }

        m_nmIface = new QDBusInterface(kNmService, kNmPath, kNmInterface, m_bus, q_ptr);
        if (!m_nmIface->isValid()) {
            qWarning() << "NetworkService: Failed to connect to NetworkManager";
            return;
        }

        // NetworkManager プロパティ変更監視 (WirelessEnabled, ActiveConnections 等)
        m_bus.connect(kNmService, kNmPath,
                      kPropertiesInterface, "PropertiesChanged",
                      q_ptr, SLOT(onNmPropertiesChanged(QString,QVariantMap,QStringList)));

        // 初期状態取得
        q_ptr->m_wifiEnabled = m_nmIface->property("WirelessEnabled").toBool();
        q_ptr->m_available = true;
        emit q_ptr->availableChanged();
        emit q_ptr->wifiEnabledChanged();

        // Wi-Fi デバイスを探す
        findWifiDevice();

        // アクティブ接続監視
        refreshActiveConnection();

        // 定期スキャン
        m_scanTimer.setInterval(kScanIntervalMs);
        connect(&m_scanTimer, &QTimer::timeout, q_ptr, [this]() { refreshWifiList(); });
        m_scanTimer.start();

        // 初回スキャン
        QTimer::singleShot(0, q_ptr, [this]() { refreshWifiList(); });
    }

    void findWifiDevice()
    {
        QVariant devicesVariant = m_nmIface->property("Devices");
        if (!devicesVariant.isValid() || !devicesVariant.canConvert<QList<QDBusObjectPath>>()) return;

        auto devices = devicesVariant.value<QList<QDBusObjectPath>>();
        for (const QDBusObjectPath &path : devices) {
            QDBusInterface devIface(kNmService, path.path(), kNmDeviceInterface, m_bus);
            if (!devIface.isValid()) continue;

            // DeviceType: 2 = Wi-Fi (802-11-wireless)
            QVariant type = devIface.property("DeviceType");
            if (type.isValid() && type.toUInt() == 2) {
                m_wifiDevicePath = path.path();
                m_wifiDeviceIface = new QDBusInterface(kNmService, m_wifiDevicePath, kNmDeviceWifiInterface, m_bus, q_ptr);
                if (m_wifiDeviceIface->isValid()) {
                    // Wi-Fi デバイスのプロパティ変更監視
                    m_bus.connect(kNmService, m_wifiDevicePath,
                                  kPropertiesInterface, "PropertiesChanged",
                                  q_ptr, SLOT(onDevicePropertiesChanged(QString,QVariantMap,QStringList)));
                    // 初期状態
                    q_ptr->m_state = deviceStateToStringStatic(devIface.property("State").toUInt());
                    emit q_ptr->stateChanged();
                }
                break;
            }
        }

        if (m_wifiDevicePath.isEmpty()) {
            qWarning() << "NetworkService: No Wi-Fi device found";
        }
    }

    void refreshWifiList()
    {
        if (!m_wifiDeviceIface || !m_wifiDeviceIface->isValid()) return;

        // アクセスポイント一覧を取得
        QVariant apsVariant = m_wifiDeviceIface->property("AccessPoints");
        if (!apsVariant.isValid() || !apsVariant.canConvert<QList<QDBusObjectPath>>()) return;

        auto apPaths = apsVariant.value<QList<QDBusObjectPath>>();
        QVariantList newList;

        for (const QDBusObjectPath &apPath : apPaths) {
            QDBusInterface apIface(kNmService, apPath.path(), kNmAccessPointInterface, m_bus);
            if (!apIface.isValid()) continue;

            QVariantMap apProps;
            apProps["Ssid"] = apIface.property("Ssid");
            apProps["Strength"] = apIface.property("Strength");        // 0-100
            apProps["Flags"] = apIface.property("Flags");              // セキュリティフラグ
            apProps["WpaFlags"] = apIface.property("WpaFlags");
            apProps["RsnFlags"] = apIface.property("RsnFlags");

            QVariantMap entry = NetworkService::parseAccessPoint(apProps, q_ptr->m_activeSsid);
            if (!entry.isEmpty()) {
                newList.append(entry);
            }
        }

        // 強度降順でソート
        std::sort(newList.begin(), newList.end(), [](const QVariant &a, const QVariant &b) {
            return a.toMap().value("strength", 0).toInt() > b.toMap().value("strength", 0).toInt();
        });

        if (q_ptr->m_list != newList) {
            q_ptr->m_list = newList;
            emit q_ptr->listChanged();
        }
    }

    void refreshActiveConnection()
    {
        if (!m_nmIface || !m_nmIface->isValid()) return;

        QVariant activeConsVariant = m_nmIface->property("ActiveConnections");
        if (!activeConsVariant.isValid() || !activeConsVariant.canConvert<QList<QDBusObjectPath>>()) {
            q_ptr->m_activeSsid.clear();
            q_ptr->m_signalStrength = 0;
            emit q_ptr->activeSsidChanged();
            emit q_ptr->signalStrengthChanged();
            return;
        }

        auto activeCons = activeConsVariant.value<QList<QDBusObjectPath>>();
        QString newSsid;
        int newStrength = 0;

        for (const QDBusObjectPath &acPath : activeCons) {
            QDBusInterface acIface(kNmService, acPath.path(), kNmActiveConnectionInterface, m_bus);
            if (!acIface.isValid()) continue;

            QString ssid = NetworkService::extractSsidFromActiveConnection(acIface.property("SpecificObject").toMap());
            if (!ssid.isEmpty()) {
                newSsid = ssid;
                // 強度はアクセスポイントから取得を試みる
                QVariant specificObj = acIface.property("SpecificObject");
                if (specificObj.isValid() && specificObj.canConvert<QDBusObjectPath>()) {
                    QDBusObjectPath apPath = specificObj.value<QDBusObjectPath>();
                    QDBusInterface apIface(kNmService, apPath.path(), kNmAccessPointInterface, m_bus);
                    if (apIface.isValid()) {
                        newStrength = apIface.property("Strength").toInt();
                    }
                }
                break; // 最初の Wi-Fi 接続を使用
            }
        }

        if (q_ptr->m_activeSsid != newSsid) {
            q_ptr->m_activeSsid = newSsid;
            emit q_ptr->activeSsidChanged();
        }
        if (q_ptr->m_signalStrength != newStrength) {
            q_ptr->m_signalStrength = newStrength;
            emit q_ptr->signalStrengthChanged();
        }

        // 状態更新
        if (!m_wifiDevicePath.isEmpty()) {
            QDBusInterface devIface(kNmService, m_wifiDevicePath, kNmDeviceInterface, m_bus);
            if (devIface.isValid()) {
                QString newState = deviceStateToStringStatic(devIface.property("State").toUInt());
                if (q_ptr->m_state != newState) {
                    q_ptr->m_state = newState;
                    emit q_ptr->stateChanged();
                }
            }
        }
    }
};

NetworkService::NetworkService(QObject *parent)
    : QObject(parent), d(std::make_unique<Private>(this))
{
    d->setup();
}

NetworkService::~NetworkService() = default;

void NetworkService::updateAvailable(bool available)
{
    if (m_available == available) return;
    m_available = available;
    emit availableChanged();
    if (!available) {
        m_wifiEnabled = false; emit wifiEnabledChanged();
        m_state = "unavailable"; emit stateChanged();
        m_activeSsid.clear(); emit activeSsidChanged();
        m_signalStrength = 0; emit signalStrengthChanged();
        m_list.clear(); emit listChanged();
    }
}

void NetworkService::setWifiEnabled(bool enabled)
{
    if (!m_available || !d->m_nmIface || !d->m_nmIface->isValid()) return;
    if (m_wifiEnabled == enabled) return;

    QDBusReply<void> reply = d->m_nmIface->call("Set", kNmInterface, "WirelessEnabled", QVariant::fromValue(enabled));
    if (!reply.isValid()) {
        qWarning() << "NetworkService: Failed to set WirelessEnabled:" << reply.error().message();
    }
    // 実際の変更は PropertiesChanged シグナルで反映される
}

void NetworkService::connectSsid(const QString &ssid)
{
    if (!m_available || !d->m_nmIface || !d->m_nmIface->isValid() || ssid.isEmpty()) return;

    // 既知の接続を探す
    QDBusInterface settingsIface(kNmService, "/org/freedesktop/NetworkManager/Settings",
                                  "org.freedesktop.NetworkManager.Settings", d->m_bus);
    if (!settingsIface.isValid()) return;

    QDBusReply<QList<QDBusObjectPath>> connections = settingsIface.call("ListConnections");
    if (!connections.isValid()) return;

    QString connectionPath;
    for (const QDBusObjectPath &path : connections.value()) {
        QDBusInterface connIface(kNmService, path.path(),
                                  "org.freedesktop.NetworkManager.Settings.Connection", d->m_bus);
        if (!connIface.isValid()) continue;

        QDBusReply<QVariantMap> settingsReply = connIface.call("GetSettings");
        if (!settingsReply.isValid()) continue;
        QVariantMap settings = settingsReply.value();
        if (settings.contains("802-11-wireless")) {
            QVariantMap wifiSettings = settings["802-11-wireless"].toMap();
            QByteArray connSsid = wifiSettings.value("ssid").toByteArray();
            if (QString::fromUtf8(connSsid) == ssid) {
                connectionPath = path.path();
                break;
            }
        }
    }

    if (connectionPath.isEmpty()) {
        // 新規接続作成 (簡易版: セキュリティなし/Open のみ)
        // 実際にはパスワード入力ダイアログ等が必要だが、ここでは既知接続のみ対応
        qWarning() << "NetworkService: No known connection for SSID:" << ssid;
        return;
    }

    // デバイスに接続をアクティベート
    QDBusMessage msg = QDBusMessage::createMethodCall(kNmService, kNmPath, kNmInterface, "ActivateConnection");
    msg.setArguments({QVariant::fromValue(QDBusObjectPath(connectionPath)),
                      QVariant::fromValue(QDBusObjectPath(d->m_wifiDevicePath)),
                      QVariant::fromValue(QDBusObjectPath("/"))});
    QDBusReply<QDBusObjectPath> reply = d->m_bus.call(msg);
    if (!reply.isValid()) {
        qWarning() << "NetworkService: Failed to activate connection:" << reply.error().message();
    }
}

void NetworkService::disconnect()
{
    if (!m_available || !d->m_nmIface || !d->m_nmIface->isValid()) return;

    QVariant activeConsVariant = d->m_nmIface->property("ActiveConnections");
    if (!activeConsVariant.isValid() || !activeConsVariant.canConvert<QList<QDBusObjectPath>>()) return;

    auto activeCons = activeConsVariant.value<QList<QDBusObjectPath>>();
    for (const QDBusObjectPath &acPath : activeCons) {
        QDBusInterface acIface(kNmService, acPath.path(), kNmActiveConnectionInterface, d->m_bus);
        if (!acIface.isValid()) continue;

        // Type が 802-11-wireless (2) または vpn 等を確認して切断
        // ここでは単純に最初のアクティブ接続を非アクティブ化
        QDBusReply<void> reply = d->m_nmIface->call("DeactivateConnection", acPath);
        if (!reply.isValid()) {
            qWarning() << "NetworkService: Failed to deactivate connection:" << reply.error().message();
        }
        break;
    }
}

void NetworkService::refresh()
{
    d->refreshWifiList();
    d->refreshActiveConnection();
}

void NetworkService::onNmPropertiesChanged(const QString &interfaceName, const QVariantMap &properties, const QStringList &)
{
    if (interfaceName != kNmInterface) return;

    if (properties.contains("WirelessEnabled")) {
        bool newEnabled = properties["WirelessEnabled"].toBool();
        if (m_wifiEnabled != newEnabled) {
            m_wifiEnabled = newEnabled;
            emit wifiEnabledChanged();
        }
    }
    if (properties.contains("ActiveConnections")) {
        d->refreshActiveConnection();
    }
}

void NetworkService::onDevicePropertiesChanged(const QString &interfaceName, const QVariantMap &properties, const QStringList &)
{
    if (interfaceName != kNmDeviceInterface && interfaceName != kNmDeviceWifiInterface) return;

    if (properties.contains("State")) {
        QString newState = deviceStateToStringStatic(properties["State"].toUInt());
        if (m_state != newState) {
            m_state = newState;
            emit stateChanged();
        }
    }
    if (properties.contains("AccessPoints")) {
        d->refreshWifiList();
    }
}

QVariantMap NetworkService::parseAccessPoint(const QVariantMap &apProps, const QString &activeSsid)
{
    QVariantMap result;

    // SSID (QByteArray -> QString)
    QByteArray ssidBytes = apProps.value("Ssid").toByteArray();
    QString ssid = QString::fromUtf8(ssidBytes);
    if (ssid.isEmpty()) return result;

    result["ssid"] = ssid;
    result["strength"] = apProps.value("Strength", 0).toInt();

    // セキュリティ判定 (Flags: 1=WEP, 2=WPA, 4=WPA2, 8=WPA3 等)
    uint flags = apProps.value("Flags", 0).toUInt();
    uint wpaFlags = apProps.value("WpaFlags", 0).toUInt();
    uint rsnFlags = apProps.value("RsnFlags", 0).toUInt();
    bool secured = (flags != 0) || (wpaFlags != 0) || (rsnFlags != 0);
    result["secured"] = secured;

    result["connected"] = (ssid == activeSsid);
    // "known" は NetworkManager の KnownConnections と照合が必要だが、簡易版では connected と同義とする
    result["known"] = secured; // セキュアなら既知の可能性が高い (簡易判定)

    return result;
}

QString NetworkService::deviceStateToString(uint state)
{
    return deviceStateToStringStatic(state);
}

QString NetworkService::extractSsidFromActiveConnection(const QVariantMap &activeConnectionProps)
{
    // SpecificObject が AccessPoint なら SSID を取得
    if (!activeConnectionProps.contains("SpecificObject")) return QString();

    // ここでは直接取得できないので、呼び出し元で AccessPoint インターフェースを使う
    return QString();
}