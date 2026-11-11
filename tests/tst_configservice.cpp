#include <QtTest>
#include <QTemporaryDir>
#include <QStandardPaths>
#include "services/ConfigService.h"

/**
 * ConfigService の単体テスト。
 *
 * KConfig の読み書きを一時ディレクトリでテストする。
 * 注意: KConfig は XDG_CONFIG_DIRS を見るため、テスト用に環境変数を設定する。
 */
class TestConfigService : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void initTestCase();
    void cleanupTestCase();
    void testDefaults();
    void testSaveAndLoad();
    void testSetterSignals();
    void testResetToDefaults();

private:
    QTemporaryDir m_tempDir;
    QString m_originalConfigDir;
};

void TestConfigService::initTestCase()
{
    QVERIFY(m_tempDir.isValid());

    // XDG_CONFIG_HOME を一時ディレクトリに向ける
    m_originalConfigDir = qEnvironmentVariable("XDG_CONFIG_HOME");
    qputenv("XDG_CONFIG_HOME", m_tempDir.path().toUtf8());

    // KConfig のキャッシュをクリアするため、KSharedConfig::openConfig() の前に
    // 環境変数を設定しておく必要がある
}

void TestConfigService::cleanupTestCase()
{
    if (!m_originalConfigDir.isEmpty()) {
        qputenv("XDG_CONFIG_HOME", m_originalConfigDir.toUtf8());
    } else {
        qunsetenv("XDG_CONFIG_HOME");
    }
}

void TestConfigService::testDefaults()
{
    ConfigService service;
    service.resetToDefaults(); // 確実にデフォルト値にする

    QCOMPARE(service.language(), QString("ja"));
    QCOMPARE(service.anchor(), QString("top"));
    QCOMPARE(service.autoHideFullscreen(), true);
    QCOMPARE(service.collapsedWidth(), 220);
    QCOMPARE(service.collapsedHeight(), 30);
    QCOMPARE(service.expandedWidth(), 660);
    QCOMPARE(service.expandedHeight(), 440);
    QCOMPARE(service.radiusCollapsed(), 16);
    QCOMPARE(service.radiusExpanded(), 28);
    QCOMPARE(service.accentColor(), QColor("#7FB8B0"));
    QCOMPARE(service.opacity(), 0.72);
    QCOMPARE(service.blurEnabled(), true);
    QCOMPARE(service.dnd(), false);
    QCOMPARE(service.enabledPages(), QString("media,stats,battery,sound,calendar,notifications,network,weather,quick,clipboard,launcher,tray"));
    QCOMPARE(service.weatherLocation(), QString("auto"));
    QCOMPARE(service.weatherUnit(), QString("metric"));
    QCOMPARE(service.ownDaemon(), true);
    QCOMPARE(service.doNotDisturb(), false);
    QCOMPARE(service.maxHistory(), 100);
    QCOMPARE(service.statsInterval(), 1000);
    QCOMPARE(service.batteryInterval(), 30000);
    QCOMPARE(service.weatherInterval(), 900000);
}

void TestConfigService::testSaveAndLoad()
{
    // 1. サービスを作成し、値を変更して保存
    {
        ConfigService service;
        service.setLanguage("en");
        service.setAnchor("top-right");
        service.setAutoHideFullscreen(false);
        service.setCollapsedWidth(200);
        service.setAccentColor(QColor("#FF0000"));
        service.setOpacity(0.5);
        service.setBlurEnabled(false);
        service.setDnd(true);
        service.setEnabledPages("media,stats");
        service.setWeatherLocation("35.68,139.76");
        service.setWeatherUnit("imperial");
        service.setOwnDaemon(false);
        service.setDoNotDisturb(true);
        service.setMaxHistory(50);
        service.setStatsInterval(2000);
        service.setBatteryInterval(60000);
        service.setWeatherInterval(1800000);
        service.save();
    }

    // 2. 新しいサービスインスタンスで読み込み、値が復元されることを確認
    {
        ConfigService service;
        service.load();

        QCOMPARE(service.language(), QString("en"));
        QCOMPARE(service.anchor(), QString("top-right"));
        QCOMPARE(service.autoHideFullscreen(), false);
        QCOMPARE(service.collapsedWidth(), 200);
        QCOMPARE(service.accentColor(), QColor("#FF0000"));
        QVERIFY(qFuzzyCompare(service.opacity(), 0.5));
        QCOMPARE(service.blurEnabled(), false);
        QCOMPARE(service.dnd(), true);
        QCOMPARE(service.enabledPages(), QString("media,stats"));
        QCOMPARE(service.weatherLocation(), QString("35.68,139.76"));
        QCOMPARE(service.weatherUnit(), QString("imperial"));
        QCOMPARE(service.ownDaemon(), false);
        QCOMPARE(service.doNotDisturb(), true);
        QCOMPARE(service.maxHistory(), 50);
        QCOMPARE(service.statsInterval(), 2000);
        QCOMPARE(service.batteryInterval(), 60000);
        QCOMPARE(service.weatherInterval(), 1800000);
    }
}

void TestConfigService::testSetterSignals()
{
    ConfigService service;
    service.resetToDefaults();

    // シグナル発火回数をカウント
    int languageCount = 0;
    int anchorCount = 0;
    int opacityCount = 0;

    connect(&service, &ConfigService::languageChanged, [&languageCount]() { languageCount++; });
    connect(&service, &ConfigService::anchorChanged, [&anchorCount]() { anchorCount++; });
    connect(&service, &ConfigService::opacityChanged, [&opacityCount]() { opacityCount++; });

    // 同じ値をセット → シグナル発火しない
    service.setLanguage("ja");
    service.setAnchor("top");
    service.setOpacity(0.72);
    QCOMPARE(languageCount, 0);
    QCOMPARE(anchorCount, 0);
    QCOMPARE(opacityCount, 0);

    // 異なる値をセット → シグナル発火する
    service.setLanguage("en");
    service.setAnchor("bottom");
    service.setOpacity(0.8);
    QCOMPARE(languageCount, 1);
    QCOMPARE(anchorCount, 1);
    QCOMPARE(opacityCount, 1);

    // 再度同じ値 → 発火しない
    service.setLanguage("en");
    service.setOpacity(0.8);
    QCOMPARE(languageCount, 1);
    QCOMPARE(opacityCount, 1);
}

void TestConfigService::testResetToDefaults()
{
    ConfigService service;
    service.setLanguage("en");
    service.setCollapsedWidth(100);
    service.setOpacity(0.1);

    service.resetToDefaults();

    QCOMPARE(service.language(), QString("ja"));
    QCOMPARE(service.collapsedWidth(), 220);
    QCOMPARE(service.opacity(), 0.72);
}

QTEST_MAIN(TestConfigService)
#include "tst_configservice.moc"