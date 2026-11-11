#include <QtTest>
#include "services/WeatherService.h"

/**
 * WeatherService の純粋関数単体テスト。
 *
 * Open-Meteo JSON パース、WMO コード変換、日付フォーマットを検証。
 * UI や HTTP なしでテスト可能。
 */
class TestWeatherService : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void parseCurrentWeatherFull();
    void parseCurrentWeatherMinimal();
    void parseDailyForecastFull();
    void parseDailyForecastPartial();
    void wmoCodeToTextKnown();
    void wmoCodeToTextUnknown();
    void formatDateValid();
    void formatDateInvalid();
};

void TestWeatherService::parseCurrentWeatherFull()
{
    // 完全な current_weather レスポンス
    QVariantMap json;
    json["temperature"] = 22.5;
    json["weathercode"] = 1; // 晴れ
    json["windspeed"] = 5.0; // m/s
    json["winddirection"] = 180;
    json["time"] = "2024-01-15T14:00";

    QVariantMap result = WeatherService::parseCurrentWeather(json);

    QCOMPARE(result["temperature"].toDouble(), 22.5);
    QCOMPARE(result["weathercode"].toInt(), 1);
    QCOMPARE(result["windspeed"].toDouble(), 5.0);
    QCOMPARE(result["winddirection"].toInt(), 180);
    QCOMPARE(result["time"].toString(), QString("2024-01-15T14:00"));
}

void TestWeatherService::parseCurrentWeatherMinimal()
{
    // 最小限のレスポンス (デフォルト値で埋められる)
    QVariantMap json;

    QVariantMap result = WeatherService::parseCurrentWeather(json);

    QCOMPARE(result["temperature"].toDouble(), 0.0);
    QCOMPARE(result["weathercode"].toInt(), 0);
    QCOMPARE(result["windspeed"].toDouble(), 0.0);
    QCOMPARE(result["winddirection"].toInt(), 0);
    QVERIFY(result["time"].toString().isEmpty());
}

void TestWeatherService::parseDailyForecastFull()
{
    // 完全な daily レスポンス (3日分)
    QVariantMap json;
    json["time"] = QVariantList{"2024-01-15", "2024-01-16", "2024-01-17"};
    json["weathercode"] = QVariantList{0, 1, 3};
    json["temperature_2m_max"] = QVariantList{25.0, 23.0, 20.0};
    json["temperature_2m_min"] = QVariantList{15.0, 14.0, 12.0};

    QVariantList result = WeatherService::parseDailyForecast(json);

    QCOMPARE(result.size(), 3);

    // Day 1
    QVariantMap day1 = result[0].toMap();
    QCOMPARE(day1["date"].toString(), QString("1/15"));
    QCOMPARE(day1["code"].toInt(), 0);
    QCOMPARE(day1["tmax"].toInt(), 25);
    QCOMPARE(day1["tmin"].toInt(), 15);

    // Day 2
    QVariantMap day2 = result[1].toMap();
    QCOMPARE(day2["date"].toString(), QString("1/16"));
    QCOMPARE(day2["code"].toInt(), 1);
    QCOMPARE(day2["tmax"].toInt(), 23);
    QCOMPARE(day2["tmin"].toInt(), 14);

    // Day 3
    QVariantMap day3 = result[2].toMap();
    QCOMPARE(day3["date"].toString(), QString("1/17"));
    QCOMPARE(day3["code"].toInt(), 3);
    QCOMPARE(day3["tmax"].toInt(), 20);
    QCOMPARE(day3["tmin"].toInt(), 12);
}

void TestWeatherService::parseDailyForecastPartial()
{
    // 配列長が異なる場合 (最小長に合わせる)
    QVariantMap json;
    json["time"] = QVariantList{"2024-01-15", "2024-01-16", "2024-01-17"};
    json["weathercode"] = QVariantList{0, 1}; // 2要素のみ
    json["temperature_2m_max"] = QVariantList{25.0};
    json["temperature_2m_min"] = QVariantList{15.0, 14.0, 12.0};

    QVariantList result = WeatherService::parseDailyForecast(json);

    // 最小長 = 1 (weathercode が 2 だが max が 1) -> 実際は min(3,2,1,3) = 1
    QCOMPARE(result.size(), 1);
    QCOMPARE(result[0].toMap()["date"].toString(), QString("1/15"));
}

void TestWeatherService::wmoCodeToTextKnown()
{
    // 既知の WMO コード
    QCOMPARE(WeatherService::wmoCodeToText(0), QString("快晴"));
    QCOMPARE(WeatherService::wmoCodeToText(1), QString("晴れ"));
    QCOMPARE(WeatherService::wmoCodeToText(3), QString("曇り"));
    QCOMPARE(WeatherService::wmoCodeToText(61), QString("弱い雨"));
    QCOMPARE(WeatherService::wmoCodeToText(95), QString("雷雨"));
    QCOMPARE(WeatherService::wmoCodeToText(99), QString("強い雹を伴う雷雨"));
}

void TestWeatherService::wmoCodeToTextUnknown()
{
    // 未知のコード
    QCOMPARE(WeatherService::wmoCodeToText(999), QString("不明"));
    QCOMPARE(WeatherService::wmoCodeToText(-1), QString("不明"));
}

void TestWeatherService::formatDateValid()
{
    // 有効な ISO8601 日付
    QCOMPARE(WeatherService::formatDate("2024-01-15"), QString("1/15"));
    QCOMPARE(WeatherService::formatDate("2024-12-01"), QString("12/1"));
    QCOMPARE(WeatherService::formatDate("2025-06-30"), QString("6/30"));
}

void TestWeatherService::formatDateInvalid()
{
    // 無効な日付 -> 元の文字列を返す
    QCOMPARE(WeatherService::formatDate("invalid"), QString("invalid"));
    QCOMPARE(WeatherService::formatDate(""), QString(""));
    QCOMPARE(WeatherService::formatDate("2024/01/15"), QString("2024/01/15"));
}

QTEST_MAIN(TestWeatherService)
#include "tst_weatherservice.moc"