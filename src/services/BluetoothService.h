#pragma once

#include <QObject>
#include <QString>
#include <QVariant>

/**
 * Bluetooth サービス (KF6 BluezQt)。
 *
 * 依存: KF6BluezQt (find_package)
 * - Manager/Device でアダプタ監視
 * - デバイス一覧取得
 * - 接続 / 切断 / ペアリング
 *
 * プロパティ (CONTRACT §3 表):
 *   available, powered, devices
 *   devices: QVariantList of {name, address, connected, paired, battery}
 * メソッド:
 *   setPowered(bool), connectDevice(QString address), disconnectDevice(QString address)
 *
 * フォールバック: BluezQt 無し/アダプタ無し → available=false
 */
class BluetoothService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)
    Q_PROPERTY(bool powered READ powered NOTIFY poweredChanged)
    Q_PROPERTY(QVariantList devices READ devices NOTIFY devicesChanged)

public:
    explicit BluetoothService(QObject *parent = nullptr);
    ~BluetoothService() override;

    BluetoothService(const BluetoothService &) = delete;
    BluetoothService &operator=(const BluetoothService &) = delete;

    bool available() const { return m_available; }
    bool powered() const { return m_powered; }
    QVariantList devices() const { return m_devices; }

    // アダプタ電源 ON/OFF
    Q_INVOKABLE void setPowered(bool powered);
    // デバイス接続
    Q_INVOKABLE void connectDevice(const QString &address);
    // デバイス切断
    Q_INVOKABLE void disconnectDevice(const QString &address);
    // 手動更新トリガー
    Q_INVOKABLE void refresh();

    // 純粋関数 (単体テスト用)
    // BluezQt Device から表示用 Map を生成
    static QVariantMap parseDevice(const QVariantMap &deviceProps);

signals:
    void availableChanged();
    void poweredChanged();
    void devicesChanged();

private:
    void updateAvailable(bool available);
    void updatePowered(bool powered);
    void updateDevices();
    void onAdapterPropertiesChanged(const QString &interfaceName, const QVariantMap &properties);
    // DBus ObjectManager signals have different signatures
    void onInterfacesAdded(const QString &objectPath, const QVariantMap &interfaces);
    void onInterfacesRemoved(const QString &objectPath, const QStringList &interfaces);

    bool m_available = false;
    bool m_powered = false;
    QVariantList m_devices;

    class Private;
    std::unique_ptr<Private> d;
};