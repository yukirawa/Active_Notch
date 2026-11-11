#pragma once

#include <QObject>
#include <QString>

/**
 * バッテリーサービス (UPower DBus + sysfs フォールバック)。
 *
 * UPower: org.freedesktop.UPower / org.freedesktop.UPower.Device
 * sysfs: /sys/class/power_supply/{BAT0,AC0}
 *
 * 利用不可時は available=false で全プロパティ 0/空文字で graceful 退化。
 */
class BatteryService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)
    Q_PROPERTY(int percent READ percent NOTIFY percentChanged)                // 0-100
    Q_PROPERTY(bool charging READ charging NOTIFY chargingChanged)
    Q_PROPERTY(bool plugged READ plugged NOTIFY pluggedChanged)
    Q_PROPERTY(qreal powerW READ powerW NOTIFY powerWChanged)                // 消費電力 (W)
    Q_PROPERTY(QString timeRemainingText READ timeRemainingText NOTIFY timeRemainingTextChanged) // "1h 23m" 等

public:
    explicit BatteryService(QObject *parent = nullptr);
    ~BatteryService() override;

    BatteryService(const BatteryService &) = delete;
    BatteryService &operator=(const BatteryService &) = delete;

    bool available() const { return m_available; }
    int percent() const { return m_percent; }
    bool charging() const { return m_charging; }
    bool plugged() const { return m_plugged; }
    qreal powerW() const { return m_powerW; }
    QString timeRemainingText() const { return m_timeRemainingText; }

    Q_INVOKABLE void refresh(); // 手動更新トリガー

    /**
     * 残り時間文字列を生成する純粋関数 (単体テスト用)。
     * @param seconds 残り秒数 (充電中なら TimeToFull, 放電中なら TimeToEmpty)
     * @param charging true=充電中 / false=放電中
     * @return 日本語フォーマット文字列 ("3h 15m", "充電中: 2h 15m", "まもなく空", "不明", "計算中..." 等)
     */
    static QString formatTimeRemaining(qint64 seconds, bool charging);

public slots:
    void onUPowerPropertiesChanged(const QString &interfaceName, const QVariantMap &properties, const QStringList &invalidatedProperties);

signals:
    void availableChanged();
    void percentChanged();
    void chargingChanged();
    void pluggedChanged();
    void powerWChanged();
    void timeRemainingTextChanged();

private:
    void updateFromUPower();
    void updateFromSysfs();
    void emitAllChanged();
    static QString formatDuration(qint64 seconds);

    bool m_available = false;
    int m_percent = 0;
    bool m_charging = false;
    bool m_plugged = false;
    qreal m_powerW = 0.0;
    QString m_timeRemainingText;

    // DBus 関連 (実装は .cpp で前方宣言)
    class Private;
    std::unique_ptr<Private> d;
};