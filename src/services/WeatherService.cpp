#include "WeatherService.h"

#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QTimer>
#include <QStandardPaths>
#include <QFile>
#include <QDir>
#include <QDebug>
#include <QDateTime>
#include <algorithm>

namespace {
constexpr char kOpenMeteoUrl[] = "https://api.open-meteo.com/v1/forecast";
constexpr char kIpApiUrl[] = "http://ip-api.com/json/";
constexpr int kCacheDurationMs = 15 * 60 * 1000; // 15分
constexpr int kRequestTimeoutMs = 10000; // 10秒

// WMO Weather Code → 日本語
const QHash<int, QString> kWmoCodeText = {
    {0, "快晴"},
    {1, "晴れ"},
    {2, "曇りがち"},
    {3, "曇り"},
    {45, "霧"},
    {48, "着氷性霧"},
    {51, "弱い霧雨"},
    {53, "霧雨"},
    {55, "強い霧雨"},
    {56, "弱い着氷性霧雨"},
    {57, "強い着氷性霧雨"},
    {61, "弱い雨"},
    {63, "雨"},
    {65, "強い雨"},
    {66, "弱い着氷性雨"},
    {67, "強い着氷性雨"},
    {71, "弱い雪"},
    {73, "雪"},
    {75, "強い雪"},
    {77, "霧氷"},
    {80, "弱いにわか雨"},
    {81, "にわか雨"},
    {82, "強いにわか雨"},
    {85, "弱いにわか雪"},
    {86, "強いにわか雪"},
    {95, "雷雨"},
    {96, "弱い雹を伴う雷雨"},
    {99, "強い雹を伴う雷雨"},
};

} // namespace

class WeatherService::Private
{
public:
    explicit Private(WeatherService *q) : q_ptr(q) {}

    WeatherService *q_ptr;
};

WeatherService::WeatherService(QObject *parent)
    : QObject(parent), m_nam(new QNetworkAccessManager(this)), d(std::make_unique<Private>(this))
{
    // キャッシュ読み込み
    loadCache();

    // 位置情報取得 (自動)
    fetchLocation();

    // 定期更新 (15分)
    m_refreshTimer.setInterval(kCacheDurationMs);
    connect(&m_refreshTimer, &QTimer::timeout, this, [this]() { fetchWeather(); });
    m_refreshTimer.start();

    // 初回取得
    QTimer::singleShot(0, this, [this]() { fetchWeather(); });
}

WeatherService::~WeatherService() = default;

void WeatherService::updateAvailable(bool available)
{
    if (m_available == available) return;
    m_available = available;
    emit availableChanged();
}

void WeatherService::refresh()
{
    fetchLocation();
    fetchWeather();
}

void WeatherService::setLocation(double latitude, double longitude)
{
    if (qFuzzyCompare(m_latitude, latitude) && qFuzzyCompare(m_longitude, longitude)) return;

    m_latitude = latitude;
    m_longitude = longitude;
    m_useAutoLocation = false;

    // 即座に天気取得
    fetchWeather();
}

void WeatherService::fetchLocation()
{
    if (!m_useAutoLocation) return;

    QNetworkRequest request{QUrl(kIpApiUrl)};
    request.setTransferTimeout(kRequestTimeoutMs);

    QNetworkReply *reply = m_nam->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() { onLocationReply(reply); });
}

void WeatherService::fetchWeather()
{
    if (m_useAutoLocation && (m_latitude == 0.0 && m_longitude == 0.0)) {
        // 位置情報がまだ取得できていない
        fetchLocation();
        return;
    }

    // キャッシュが有効ならスキップ
    if (isCacheValid()) {
        qDebug() << "WeatherService: Using cached data";
        return;
    }

    QUrl url(kOpenMeteoUrl);
    QUrlQuery query;
    query.addQueryItem("latitude", QString::number(m_latitude, 'f', 4));
    query.addQueryItem("longitude", QString::number(m_longitude, 'f', 4));
    query.addQueryItem("current_weather", "true");
    query.addQueryItem("daily", "weathercode,temperature_2m_max,temperature_2m_min");
    query.addQueryItem("timezone", "auto");
    query.addQueryItem("forecast_days", "7");
    url.setQuery(query);

    QNetworkRequest request{url};
    request.setTransferTimeout(kRequestTimeoutMs);

    QNetworkReply *reply = m_nam->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() { onWeatherReply(reply); });
}

void WeatherService::onLocationReply(QNetworkReply *reply)
{
    reply->deleteLater();

    if (reply->error() != QNetworkReply::NoError) {
        qWarning() << "WeatherService: Location fetch failed:" << reply->errorString();
        // キャッシュがあればそれを使う
        if (!isCacheValid()) {
            updateAvailable(false);
        }
        return;
    }

    QByteArray data = reply->readAll();
    QJsonDocument doc = QJsonDocument::fromJson(data);
    if (!doc.isObject()) return;

    QJsonObject obj = doc.object();
    if (obj.value("status").toString() != "success") return;

    m_latitude = obj.value("lat").toDouble();
    m_longitude = obj.value("lon").toDouble();
    QString city = obj.value("city").toString();
    QString country = obj.value("country").toString();
    m_locationText = city.isEmpty() ? country : (city + ", " + country);
    emit locationTextChanged();

    qDebug() << "WeatherService: Location detected:" << m_latitude << m_longitude << m_locationText;

    // 位置取得できたら天気取得
    fetchWeather();
}

void WeatherService::onWeatherReply(QNetworkReply *reply)
{
    reply->deleteLater();

    if (reply->error() != QNetworkReply::NoError) {
        qWarning() << "WeatherService: Weather fetch failed:" << reply->errorString();
        if (!isCacheValid()) {
            updateAvailable(false);
        }
        return;
    }

    QByteArray data = reply->readAll();
    QJsonDocument doc = QJsonDocument::fromJson(data);
    if (!doc.isObject()) return;

    QJsonObject obj = doc.object();

    // current_weather パース
    QVariantMap current = parseCurrentWeather(obj.value("current_weather").toObject().toVariantMap());

    // daily パース
    QVariantList daily = parseDailyForecast(obj.value("daily").toObject().toVariantMap());

    applyWeatherData(current, daily);
    saveCache(current, daily);
    updateAvailable(true);
}

void WeatherService::applyWeatherData(const QVariantMap &current, const QVariantList &daily)
{
    bool changed = false;

    qreal newTemp = current.value("temperature", 0.0).toDouble();
    if (!qFuzzyCompare(m_tempC, newTemp)) { m_tempC = newTemp; emit tempCChanged(); changed = true; }

    int newCode = current.value("weathercode", 0).toInt();
    if (m_code != newCode) { m_code = newCode; emit codeChanged(); changed = true; }

    QString newCodeText = wmoCodeToText(newCode);
    if (m_codeText != newCodeText) { m_codeText = newCodeText; emit codeTextChanged(); changed = true; }

    qreal newWind = current.value("windspeed", 0.0).toDouble() * 3.6; // m/s -> km/h
    if (!qFuzzyCompare(m_windKmh, newWind)) { m_windKmh = newWind; emit windKmhChanged(); changed = true; }

    // Open-Meteo current_weather には湿度がないため daily から推定または別 API が必要
    // ここではデフォルト値
    int newHumidity = 0;
    if (!daily.isEmpty()) {
        // 簡易的に最初の日のデータから推定不可なので 0 のまま
    }
    if (m_humidity != newHumidity) { m_humidity = newHumidity; emit humidityChanged(); changed = true; }

    if (m_daily != daily) { m_daily = daily; emit dailyChanged(); changed = true; }

    if (changed) {
        qDebug() << "WeatherService: Weather updated:" << m_tempC << "°C" << m_codeText;
    }
}

bool WeatherService::isCacheValid() const
{
    QString cachePath = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/weather_cache.json";
    QFileInfo info(cachePath);
    if (!info.exists()) return false;

    qint64 age = QDateTime::currentMSecsSinceEpoch() - info.lastModified().toMSecsSinceEpoch();
    return age < kCacheDurationMs;
}

void WeatherService::saveCache(const QVariantMap &current, const QVariantList &daily)
{
    QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    QDir().mkpath(cacheDir);
    QString cachePath = cacheDir + "/weather_cache.json";

    QJsonObject obj;
    obj["timestamp"] = QDateTime::currentMSecsSinceEpoch();
    obj["latitude"] = m_latitude;
    obj["longitude"] = m_longitude;
    obj["locationText"] = m_locationText;
    obj["current"] = QJsonValue::fromVariant(current);
    obj["daily"] = QJsonValue::fromVariant(daily);

    QFile file(cachePath);
    if (file.open(QIODevice::WriteOnly)) {
        file.write(QJsonDocument(obj).toJson());
    }
}

void WeatherService::loadCache()
{
    QString cachePath = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/weather_cache.json";
    QFile file(cachePath);
    if (!file.open(QIODevice::ReadOnly)) return;

    QByteArray data = file.readAll();
    QJsonDocument doc = QJsonDocument::fromJson(data);
    if (!doc.isObject()) return;

    QJsonObject obj = doc.object();
    qint64 timestamp = obj.value("timestamp").toVariant().toLongLong();
    qint64 age = QDateTime::currentMSecsSinceEpoch() - timestamp;
    if (age >= kCacheDurationMs) return; // 期限切れ

    m_latitude = obj.value("latitude").toDouble();
    m_longitude = obj.value("longitude").toDouble();
    m_locationText = obj.value("locationText").toString();
    emit locationTextChanged();

    QVariantMap current = obj.value("current").toObject().toVariantMap();
    QVariantList daily = obj.value("daily").toArray().toVariantList();

    applyWeatherData(current, daily);
    updateAvailable(true);

    qDebug() << "WeatherService: Loaded cached weather";
}

QVariantMap WeatherService::parseCurrentWeather(const QVariantMap &json)
{
    QVariantMap result;
    result["temperature"] = json.value("temperature", 0.0);
    result["weathercode"] = json.value("weathercode", 0);
    result["windspeed"] = json.value("windspeed", 0.0); // m/s
    result["winddirection"] = json.value("winddirection", 0);
    result["time"] = json.value("time", "");
    return result;
}

QVariantList WeatherService::parseDailyForecast(const QVariantMap &json)
{
    QVariantList result;

    QVariantList dates = json.value("time").toList();
    QVariantList codes = json.value("weathercode").toList();
    QVariantList tmax = json.value("temperature_2m_max").toList();
    QVariantList tmin = json.value("temperature_2m_min").toList();

    int count = std::min({dates.size(), codes.size(), tmax.size(), tmin.size()});
    for (int i = 0; i < count; ++i) {
        QVariantMap day;
        day["date"] = formatDate(dates[i].toString());
        day["code"] = codes[i].toInt();
        day["tmax"] = qRound(tmax[i].toDouble());
        day["tmin"] = qRound(tmin[i].toDouble());
        result.append(day);
    }

    return result;
}

QString WeatherService::wmoCodeToText(int code)
{
    return kWmoCodeText.value(code, "不明");
}

QString WeatherService::formatDate(const QString &isoDate)
{
    // "2024-01-15" -> "1/15"
    QDate date = QDate::fromString(isoDate, "yyyy-MM-dd");
    if (!date.isValid()) return isoDate;
    return QString("%1/%2").arg(date.month()).arg(date.day());
}