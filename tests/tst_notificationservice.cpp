#include <QtTest>
#include "services/NotificationService.h"

/**
 * NotificationService の純粋関数テスト。
 *
 * DBus や UI なしでテスト可能な静的メソッドを検証。
 */
class TestNotificationService : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void createHistoryEntry_basic();
    void createHistoryEntry_withHints();
    void extractUrgency_normal();
    void extractUrgency_low();
    void extractUrgency_critical();
    void extractUrgency_invalid();
    void extractUrgency_missing();
    void extractCategory_present();
    void extractCategory_missing();
    void timestampToString_format();
};

void TestNotificationService::createHistoryEntry_basic()
{
    QVariantMap hints;
    QVariantMap entry = NotificationService::createHistoryEntry(42, "TestApp", "Summary", "Body", hints, false);

    QCOMPARE(entry["id"].toInt(), 42);
    QCOMPARE(entry["app"].toString(), QString("TestApp"));
    QCOMPARE(entry["summary"].toString(), QString("Summary"));
    QCOMPARE(entry["body"].toString(), QString("Body"));
    QCOMPARE(entry["urgent"].toBool(), false);
    QVERIFY(!entry["ts"].toString().isEmpty());
    QVERIFY(entry["ts"].toString().contains('T')); // ISO 8601
    QVERIFY(entry["category"].toString().isEmpty());
    QVERIFY(!entry.contains("hints"));
}

void TestNotificationService::createHistoryEntry_withHints()
{
    QVariantMap hints;
    hints["urgency"] = 2;
    hints["category"] = "im.received";
    hints["custom-key"] = "custom-value";

    QVariantMap entry = NotificationService::createHistoryEntry(1, "App", "Sum", "Body", hints, true);

    QCOMPARE(entry["urgent"].toBool(), true);
    QCOMPARE(entry["category"].toString(), QString("im.received"));
    QVERIFY(entry.contains("hints"));
    QVariantMap storedHints = entry["hints"].toMap();
    QCOMPARE(storedHints["custom-key"].toString(), QString("custom-value"));
}

void TestNotificationService::extractUrgency_normal()
{
    QVariantMap hints;
    hints["urgency"] = 1;
    QCOMPARE(NotificationService::extractUrgency(hints), 1);
}

void TestNotificationService::extractUrgency_low()
{
    QVariantMap hints;
    hints["urgency"] = 0;
    QCOMPARE(NotificationService::extractUrgency(hints), 0);
}

void TestNotificationService::extractUrgency_critical()
{
    QVariantMap hints;
    hints["urgency"] = 2;
    QCOMPARE(NotificationService::extractUrgency(hints), 2);
}

void TestNotificationService::extractUrgency_invalid()
{
    QVariantMap hints;
    hints["urgency"] = 5; // 範囲外 -> clamp される
    QCOMPARE(NotificationService::extractUrgency(hints), 2);

    hints["urgency"] = -1;
    QCOMPARE(NotificationService::extractUrgency(hints), 0);
}

void TestNotificationService::extractUrgency_missing()
{
    QVariantMap hints;
    QCOMPARE(NotificationService::extractUrgency(hints), 1); // デフォルト normal
}

void TestNotificationService::extractCategory_present()
{
    QVariantMap hints;
    hints["category"] = "email.arrived";
    QCOMPARE(NotificationService::extractCategory(hints), QString("email.arrived"));
}

void TestNotificationService::extractCategory_missing()
{
    QVariantMap hints;
    QCOMPARE(NotificationService::extractCategory(hints), QString());
}

void TestNotificationService::timestampToString_format()
{
    // 固定タイムスタンプでテスト: 2024-01-15T10:30:45.123Z (UTC)
    // Qt::ISODateWithMs はローカルタイムゾーンで出力するため、ISO 8601 形式であることのみ確認
    qint64 ms = 1705314645123;
    QString result = NotificationService::timestampToString(ms);
    // ISO 8601 形式の基本チェック: YYYY-MM-DDTHH:MM:SS.zzz
    QVERIFY(result.contains(QRegularExpression("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}\\.\\d{3}")));
    QVERIFY(result.contains(".123"));
}

QTEST_MAIN(TestNotificationService)
#include "tst_notificationservice.moc"