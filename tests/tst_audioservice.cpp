#include <QtTest>
#include "services/AudioService.h"

/**
 * AudioService::parseWpctlOutput() の単体テスト。
 *
 * wpctl get-volume の出力パースを検証。
 */
class TestAudioService : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void parseNormalVolume();
    void parseMutedVolume();
    void parseZeroVolume();
    void parseFullVolume();
    void parseInvalidOutput();
    void parseExtraWhitespace();
};

void TestAudioService::parseNormalVolume()
{
    // "Volume: 0.65"
    auto result = AudioService::parseWpctlOutput("Volume: 0.65");
    QVERIFY(qFuzzyCompare(result.first, 0.65));
    QCOMPARE(result.second, false);
}

void TestAudioService::parseMutedVolume()
{
    // "Volume: 0.65 [MUTED]"
    auto result = AudioService::parseWpctlOutput("Volume: 0.65 [MUTED]");
    QVERIFY(qFuzzyCompare(result.first, 0.65));
    QCOMPARE(result.second, true);
}

void TestAudioService::parseZeroVolume()
{
    // "Volume: 0.00"
    auto result = AudioService::parseWpctlOutput("Volume: 0.00");
    QVERIFY(qFuzzyCompare(result.first, 0.0));
    QCOMPARE(result.second, false);
}

void TestAudioService::parseFullVolume()
{
    // "Volume: 1.00"
    auto result = AudioService::parseWpctlOutput("Volume: 1.00");
    QVERIFY(qFuzzyCompare(result.first, 1.0));
    QCOMPARE(result.second, false);
}

void TestAudioService::parseInvalidOutput()
{
    // 不正な出力
    auto result = AudioService::parseWpctlOutput("Error: no default sink");
    QVERIFY(qFuzzyCompare(result.first, 0.0));
    QCOMPARE(result.second, false);
}

void TestAudioService::parseExtraWhitespace()
{
    // 余分な空白
    auto result = AudioService::parseWpctlOutput("  Volume: 0.50  \n");
    QVERIFY(qFuzzyCompare(result.first, 0.5));
    QCOMPARE(result.second, false);
}

QTEST_MAIN(TestAudioService)
#include "tst_audioservice.moc"