#pragma once

#include <QObject>
#include <QString>
#include <QVariant>

/**
 * ネットワークサービス (NetworkManager DBus)。
 *
 * DBus: org.freedesktop.NetworkManager
 * - デバイス監視 (Wi-Fi / 有線)
 * - アクティブ接続の SSID / 強度 / 状態取得
 * - Wi-Fi アクセスポイントスキャン (一覧取得)
 * - 接続 / 切断操作
 *
 * プロパティ (CONTRACT §3 表):
 *   available, wifiEnabled, state, activeSsid, signalStrength, list
 *   list: QVariantList of {ssid, strength, secured, connected, known}
 * メソッド:
 *   setWifiEnabled(bool), connectSsid(QString), disconnect()
 *
 * フォールバック: NM 無し → available=false
 */
class NetworkService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)
    Q_PROPERTY(bool wifiEnabled READ wifiEnabled NOTIFY wifiEnabledChanged)
    Q_PROPERTY(QString state READ state NOTIFY stateChanged)              // "connected", "connecting", "disconnected", "unavailable"
    Q_PROPERTY(QString activeSsid READ activeSsid NOTIFY activeSsidChanged)
    Q_PROPERTY(int signalStrength READ signalStrength NOTIFY signalStrengthChanged) // 0-100
    Q_PROPERTY(QVariantList list READ list NOTIFY listChanged)            // Wi-Fi AP 一覧

public:
    explicit NetworkService(QObject *parent = nullptr);
    ~NetworkService() override;

    NetworkService(const NetworkService &) = delete;
    NetworkService &operator=(const NetworkService &) = delete;

    bool available() const { return m_available; }
    bool wifiEnabled() const { return m_wifiEnabled; }
    QString state() const { return m_state; }
    QString activeSsid() const { return m_activeSsid; }
    int signalStrength() const { return m_signalStrength; }
    QVariantList list() const { return m_list; }

    // Wi-Fi 有効/無効
    Q_INVOKABLE void setWifiEnabled(bool enabled);
    // SSID に接続 (既知の接続プロファイルがある前提、なければ NM が新規作成を試みる)
    Q_INVOKABLE void connectSsid(const QString &ssid);
    // 現在のアクティブ接続を切断
    Q_INVOKABLE void disconnect();
    // 手動スキャン/更新トリガー
    Q_INVOKABLE void refresh();

    // 純粋関数 (単体テスト用)
    // NM のアクセスポイントプロパティから list 要素を生成
    static QVariantMap parseAccessPoint(const QVariantMap &apProps, const QString &activeSsid);
    // NM のデバイスステート値 (uint) を文字列に変換
    static QString deviceStateToString(uint state);
    // NM のアクティブ接続から SSID を抽出
    static QString extractSsidFromActiveConnection(const QVariantMap &activeConnectionProps);

signals:
    void availableChanged();
    void wifiEnabledChanged();
    void stateChanged();
    void activeSsidChanged();
    void signalStrengthChanged();
    void listChanged();

private slots:
    // QDBusConnection::connect は string-based のため、受信メソッドは
    // slot として metaobject に登録されている必要がある。
    void onNmPropertiesChanged(const QString &interfaceName, const QVariantMap &properties, const QStringList &invalidatedProperties);
    void onDevicePropertiesChanged(const QString &interfaceName, const QVariantMap &properties, const QStringList &invalidatedProperties);

private:
    void updateAvailable(bool available);
    void refreshWifiList();
    void refreshActiveConnection();

    bool m_available = false;
    bool m_wifiEnabled = false;
    QString m_state = "unavailable";
    QString m_activeSsid;
    int m_signalStrength = 0;
    QVariantList m_list;

    class Private;
    std::unique_ptr<Private> d;
};