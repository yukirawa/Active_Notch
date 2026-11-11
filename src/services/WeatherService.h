#pragma once

#include <QObject>
#include <QString>
#include <QVariant>
#include <QUrl>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QTimer>
#include <QUrlQuery>

/**
 * 天気サービス (Open-Meteo HTTP API)。
 *
 * API: https://api.open-meteo.com (API キー不要)
 * 位置情報: IP → 緯度経度 (ip-api.com 等) または設定で指定
 * キャッシュ: 15 分
 *
 * プロパティ (CONTRACT §3 表):
 *   available, tempC, code, codeText, windKmh, humidity, locationText, daily
 *   daily: QVariantList of {date, tmin, tmax, code}
 * メソッド:
 *   refresh(), setLocation(double lat, double lon)
 *
 * フォールバック: ネットワーク不可 → available=false、キャッシュ表示
 */
class WeatherService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)
    Q_PROPERTY(qreal tempC READ tempC NOTIFY tempCChanged)
    Q_PROPERTY(int code READ code NOTIFY codeChanged)                 // WMO weather code
    Q_PROPERTY(QString codeText READ codeText NOTIFY codeTextChanged) // 日本語天気テキスト
    Q_PROPERTY(qreal windKmh READ windKmh NOTIFY windKmhChanged)
    Q_PROPERTY(int humidity READ humidity NOTIFY humidityChanged)
    Q_PROPERTY(QString locationText READ locationText NOTIFY locationTextChanged)
    Q_PROPERTY(QVariantList daily READ daily NOTIFY dailyChanged)

public:
    explicit WeatherService(QObject *parent = nullptr);
    ~WeatherService() override;

    WeatherService(const WeatherService &) = delete;
    WeatherService &operator=(const WeatherService &) = delete;

    bool available() const { return m_available; }
    qreal tempC() const { return m_tempC; }
    int code() const { return m_code; }
    QString codeText() const { return m_codeText; }
    qreal windKmh() const { return m_windKmh; }
    int humidity() const { return m_humidity; }
    QString locationText() const { return m_locationText; }
    QVariantList daily() const { return m_daily; }

    // 手動更新
    Q_INVOKABLE void refresh();
    // 位置設定 (緯度, 経度)。空なら IP 自動検出
    Q_INVOKABLE void setLocation(double latitude, double longitude);

    // 純粋関数 (単体テスト用)
    // Open-Meteo current_weather レスポンスから現在天気を抽出
    static QVariantMap parseCurrentWeather(const QVariantMap &json);
    // Open-Meteo daily レスポンスから日別予報を抽出
    static QVariantList parseDailyForecast(const QVariantMap &json);
    // WMO コード → 日本語テキスト
    static QString wmoCodeToText(int code);
    // ISO8601 日付文字列 → "M/D" 形式
    static QString formatDate(const QString &isoDate);

signals:
    void availableChanged();
    void tempCChanged();
    void codeChanged();
    void codeTextChanged();
    void windKmhChanged();
    void humidityChanged();
    void locationTextChanged();
    void dailyChanged();

private:
    void updateAvailable(bool available);
    void fetchLocation();
    void fetchWeather();
    void onLocationReply(QNetworkReply *reply);
    void onWeatherReply(QNetworkReply *reply);
    void applyWeatherData(const QVariantMap &current, const QVariantList &daily);
    bool isCacheValid() const;
    void saveCache(const QVariantMap &current, const QVariantList &daily);
    void loadCache();

    bool m_available = false;
    qreal m_tempC = 0.0;
    int m_code = 0;
    QString m_codeText;
    qreal m_windKmh = 0.0;
    int m_humidity = 0;
    QString m_locationText;
    QVariantList m_daily;

    double m_latitude = 0.0;
    double m_longitude = 0.0;
    bool m_useAutoLocation = true;

    QNetworkAccessManager *m_nam = nullptr;
    QTimer m_refreshTimer;

    class Private;
    std::unique_ptr<Private> d;
};