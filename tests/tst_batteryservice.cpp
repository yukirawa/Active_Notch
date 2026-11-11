#include <QtTest>
#include "services/BatteryService.h"

/**
 * BatteryService::formatTimeRemaining() の単体テスト。
 *
 * 純粋関数として分離されているため、UI や DBus なしでテスト可能。
 */
class TestBatteryService : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void formatTimeRemainingChargingHours();
    void formatTimeRemainingChargingMinutes();
    void formatTimeRemainingDischargingHours();
    void formatTimeRemainingDischargingMinutes();
    void formatTimeRemainingDischargingSoon();
    void formatTimeRemainingUnknown();
    void formatTimeRemainingZero();
    void formatTimeRemainingNegative();
};

void TestBatteryService::formatTimeRemainingChargingHours()
{
    // 充電中: 2時間15分
    QString result = BatteryService::formatTimeRemaining(2 * 3600 + 15 * 60, true);
    QCOMPARE(result, QString("充電中: 2h 15m"));
}

void TestBatteryService::formatTimeRemainingChargingMinutes()
{
    // 充電中: 45分
    QString result = BatteryService::formatTimeRemaining(45 * 60, true);
    QCOMPARE(result, QString("充電中: 45m"));
}

void TestBatteryService::formatTimeRemainingDischargingHours()
{
    // 放電中: 3時間30分
    QString result = BatteryService::formatTimeRemaining(3 * 3600 + 30 * 60, false);
    QCOMPARE(result, QString("3h 30m"));
}

void TestBatteryService::formatTimeRemainingDischargingMinutes()
{
    // 放電中: 20分
    QString result = BatteryService::formatTimeRemaining(20 * 60, false);
    QCOMPARE(result, QString("20m"));
}

void TestBatteryService::formatTimeRemainingDischargingSoon()
{
    // 放電中: 1分未満 (seconds=30 → minutes=0)
    QString result = BatteryService::formatTimeRemaining(30, false);
    QCOMPARE(result, QString("まもなく空"));
}

void TestBatteryService::formatTimeRemainingUnknown()
{
    // 充電中で秒数不明
    QString result = BatteryService::formatTimeRemaining(0, true);
    QCOMPARE(result, QString("計算中..."));
}

void TestBatteryService::formatTimeRemainingZero()
{
    // 放電中で秒数0
    QString result = BatteryService::formatTimeRemaining(0, false);
    QCOMPARE(result, QString("不明"));
}

void TestBatteryService::formatTimeRemainingNegative()
{
    // 負の値は不明扱い
    QString result = BatteryService::formatTimeRemaining(-100, false);
    QCOMPARE(result, QString("不明"));
}

QTEST_MAIN(TestBatteryService)
#include "tst_batteryservice.moc"