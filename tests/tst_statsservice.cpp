#include <QtTest>
#include "services/StatsService.h"

/**
 * StatsService の純粋関数単体テスト。
 *
 * /proc/stat, /proc/meminfo パースと計算を検証。
 * ファイル I/O なしでテスト可能。
 */
class TestStatsService : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void parseCpuStatLineBasic();
    void parseCpuStatLineWithAllFields();
    void parseCpuStatLineExtraSpaces();
    void parseCpuStatLineInvalidPrefix();
    void calculateCpuPercentBasic();
    void calculateCpuPercentZeroDiff();
    void calculateCpuPercentFullLoad();
    void calculateCpuPercentIdle();
    void parseMemInfoBasic();
    void parseMemInfoMissingFields();
    void parseMemInfoEmpty();
    void milliCelsiusToCelsiusBasic();
    void isCpuThermalZoneCoretemp();
    void isCpuThermalZoneK10temp();
    void isCpuThermalZoneFalse();
};

void TestStatsService::parseCpuStatLineBasic()
{
    // 典型的な /proc/stat の cpu 行
    QString line = "cpu  12345 678 9012 345678 123 45 67 89 0 0";
    QVector<qulonglong> result = StatsService::parseCpuStatLine(line);

    QCOMPARE(result.size(), 10);
    QCOMPARE(result[StatsService::CpuUser], qulonglong(12345));
    QCOMPARE(result[StatsService::CpuNice], qulonglong(678));
    QCOMPARE(result[StatsService::CpuSystem], qulonglong(9012));
    QCOMPARE(result[StatsService::CpuIdle], qulonglong(345678));
    QCOMPARE(result[StatsService::CpuIowait], qulonglong(123));
    QCOMPARE(result[StatsService::CpuIrq], qulonglong(45));
    QCOMPARE(result[StatsService::CpuSoftirq], qulonglong(67));
    QCOMPARE(result[StatsService::CpuSteal], qulonglong(89));
    QCOMPARE(result[StatsService::CpuGuest], qulonglong(0));
    QCOMPARE(result[StatsService::CpuGuestNice], qulonglong(0));
}

void TestStatsService::parseCpuStatLineWithAllFields()
{
    // 全フィールドあり
    QString line = "cpu 100 200 300 400 500 600 700 800 900 1000";
    QVector<qulonglong> result = StatsService::parseCpuStatLine(line);

    QCOMPARE(result.size(), 10);
    for (int i = 0; i < 10; ++i) {
        QCOMPARE(result[i], qulonglong((i + 1) * 100));
    }
}

void TestStatsService::parseCpuStatLineExtraSpaces()
{
    // 余分なスペース
    QString line = "cpu    100    200    300    400    50    60    70    80    90    100";
    QVector<qulonglong> result = StatsService::parseCpuStatLine(line);

    QCOMPARE(result.size(), 10);
    QCOMPARE(result[StatsService::CpuUser], qulonglong(100));
    QCOMPARE(result[StatsService::CpuNice], qulonglong(200));
}

void TestStatsService::parseCpuStatLineInvalidPrefix()
{
    // "cpu" で始まらない
    QString line = "ctxt 12345";
    QVector<qulonglong> result = StatsService::parseCpuStatLine(line);

    QVERIFY(result.isEmpty());
}

void TestStatsService::calculateCpuPercentBasic()
{
    // 前回: user=100, nice=0, system=50, idle=800, iowait=50 -> total=1000, idle=850
    // 今回: user=110, nice=0, system=55, idle=780, iowait=55 -> total=1000, idle=835
    // totalDiff = 0, idleDiff = -15 -> 計算不能 (totalDiff=0 なので 0%)
    QVector<qulonglong> prev = {100, 0, 50, 800, 50, 0, 0, 0, 0, 0};
    QVector<qulonglong> curr = {100, 0, 50, 800, 50, 0, 0, 0, 0, 0};

    qreal percent = StatsService::calculateCpuPercent(prev, curr);
    QCOMPARE(percent, 0.0); // 差分なし

    // 時間経過: total 増加
    curr = {110, 0, 55, 780, 55, 0, 0, 0, 0, 0}; // total=1000, idle=835
    // prev total=1000, curr total=1000 -> totalDiff=0 (同じ)
    // 実際には時間が経てば total が増える

    // より現実的な例:
    // 前回: user=1000, nice=0, system=500, idle=8000, iowait=500 -> total=10000, idle=8500
    // 今回: user=1100, nice=0, system=550, idle=7900, iowait=550 -> total=10100, idle=8450
    // totalDiff=100, idleDiff=-50 -> busy=150 -> 150%
    prev = {1000, 0, 500, 8000, 500, 0, 0, 0, 0, 0};
    curr = {1100, 0, 550, 7900, 550, 0, 0, 0, 0, 0};

    percent = StatsService::calculateCpuPercent(prev, curr);
    // busy = (10100-10000) - (8450-8500) = 100 - (-50) = 150
    // percent = 150/100 * 100 = 150% -> clamp to 100%
    QVERIFY(qFuzzyCompare(percent, 100.0));
}

void TestStatsService::calculateCpuPercentZeroDiff()
{
    QVector<qulonglong> prev = {100, 0, 50, 800, 50, 0, 0, 0, 0, 0};
    QVector<qulonglong> curr = {100, 0, 50, 800, 50, 0, 0, 0, 0, 0};

    qreal percent = StatsService::calculateCpuPercent(prev, curr);
    QCOMPARE(percent, 0.0);
}

void TestStatsService::calculateCpuPercentFullLoad()
{
    // アイドル時間が増えない (100% 負荷)
    QVector<qulonglong> prev = {1000, 0, 500, 8000, 500, 0, 0, 0, 0, 0};
    QVector<qulonglong> curr = {2000, 0, 1000, 8000, 500, 0, 0, 0, 0, 0};

    // prev total=10000, idle=8500
    // curr total=11500, idle=8500
    // totalDiff=1500, idleDiff=0 -> busy=1500 -> 100%
    qreal percent = StatsService::calculateCpuPercent(prev, curr);
    QVERIFY(qFuzzyCompare(percent, 100.0));
}

void TestStatsService::calculateCpuPercentIdle()
{
    // アイドル時間だけ増える (0% 負荷)
    QVector<qulonglong> prev = {1000, 0, 500, 8000, 500, 0, 0, 0, 0, 0};
    QVector<qulonglong> curr = {1000, 0, 500, 9000, 1500, 0, 0, 0, 0, 0};

    // prev total=10000, idle=8500
    // curr total=11500, idle=10500
    // totalDiff=1500, idleDiff=2000 -> busy=-500 -> 0% (clamp)
    qreal percent = StatsService::calculateCpuPercent(prev, curr);
    QVERIFY(qFuzzyCompare(percent, 0.0));
}

void TestStatsService::parseMemInfoBasic()
{
    QString content = "MemTotal:       16384000 kB\n"
                      "MemFree:         5120000 kB\n"
                      "MemAvailable:   10240000 kB\n"
                      "Buffers:          512000 kB\n"
                      "Cached:          4096000 kB\n";

    auto result = StatsService::parseMemInfo(content);
    QCOMPARE(result.first, qulonglong(16384000));  // MemTotal
    QCOMPARE(result.second, qulonglong(10240000)); // MemAvailable
}

void TestStatsService::parseMemInfoMissingFields()
{
    // MemAvailable がない場合 (古いカーネル)
    QString content = "MemTotal:       8192000 kB\n"
                      "MemFree:         2048000 kB\n"
                      "Buffers:          256000 kB\n"
                      "Cached:          2048000 kB\n";

    auto result = StatsService::parseMemInfo(content);
    QCOMPARE(result.first, qulonglong(8192000));
    QCOMPARE(result.second, qulonglong(0)); // MemAvailable なし -> 0
}

void TestStatsService::parseMemInfoEmpty()
{
    QString content = "";
    auto result = StatsService::parseMemInfo(content);
    QCOMPARE(result.first, qulonglong(0));
    QCOMPARE(result.second, qulonglong(0));
}

void TestStatsService::milliCelsiusToCelsiusBasic()
{
    QCOMPARE(StatsService::milliCelsiusToCelsius(0), 0.0);
    QCOMPARE(StatsService::milliCelsiusToCelsius(1000), 1.0);
    QCOMPARE(StatsService::milliCelsiusToCelsius(45000), 45.0);
    QCOMPARE(StatsService::milliCelsiusToCelsius(123456), 123.456);
    QCOMPARE(StatsService::milliCelsiusToCelsius(-5000), -5.0);
}

void TestStatsService::isCpuThermalZoneCoretemp()
{
    QVERIFY(StatsService::isCpuThermalZone("coretemp"));
    QVERIFY(StatsService::isCpuThermalZone("CORETEMP"));
    QVERIFY(StatsService::isCpuThermalZone("CoreTemp"));
}

void TestStatsService::isCpuThermalZoneK10temp()
{
    QVERIFY(StatsService::isCpuThermalZone("k10temp"));
    QVERIFY(StatsService::isCpuThermalZone("K10TEMP"));
}

void TestStatsService::isCpuThermalZoneFalse()
{
    QVERIFY(!StatsService::isCpuThermalZone("acpitz"));
    QVERIFY(!StatsService::isCpuThermalZone("nvme"));
    QVERIFY(!StatsService::isCpuThermalZone("iwlwifi"));
    QVERIFY(!StatsService::isCpuThermalZone("asus"));
    QVERIFY(!StatsService::isCpuThermalZone(""));
}

QTEST_MAIN(TestStatsService)
#include "tst_statsservice.moc"