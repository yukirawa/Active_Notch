#include <QtTest>
#include <QTemporaryDir>
#include <QStandardPaths>
#include <QSignalSpy>
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
    void testValidationClamping();
    void testSchemaVersion();
    void testLanguageSwitching();
    void testStaticClampFunctions();

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
    QCOMPARE(languageCount, 1);

    // anchor: まず有効な異なる値をセット
    service.setAnchor("top-left");
    QCOMPARE(anchorCount, 1);
    // 無効な値 "bottom" は "top" にクランプされるが、現在 "top-left" なので変更あり → シグナル発火
    service.setAnchor("bottom");
    QCOMPARE(anchorCount, 2);
    QCOMPARE(service.anchor(), QString("top")); // クランプ結果確認

    service.setOpacity(0.8);
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

void TestConfigService::testValidationClamping()
{
    ConfigService service;
    service.resetToDefaults();

    // 負の値・範囲外の値がクランプされることを確認
    service.setCollapsedWidth(-50);
    QCOMPARE(service.collapsedWidth(), 220); // デフォルトにフォールバック

    service.setCollapsedWidth(9999);
    QCOMPARE(service.collapsedWidth(), 220); // デフォルトにフォールバック

    service.setCollapsedWidth(300); // 正常範囲内
    QCOMPARE(service.collapsedWidth(), 300);

    service.setCollapsedHeight(-10);
    QCOMPARE(service.collapsedHeight(), 30);

    service.setExpandedWidth(50); // 最小値未満
    QCOMPARE(service.expandedWidth(), 660);

    service.setExpandedWidth(2000); // 最大値超過
    QCOMPARE(service.expandedWidth(), 660);

    service.setExpandedHeight(100); // 最小値未満
    QCOMPARE(service.expandedHeight(), 440);

    service.setRadiusCollapsed(-5);
    QCOMPARE(service.radiusCollapsed(), 16);

    service.setRadiusCollapsed(200);
    QCOMPARE(service.radiusCollapsed(), 16);

    service.setRadiusExpanded(-5);
    QCOMPARE(service.radiusExpanded(), 28);

    // Opacity: 0.0-1.0 の範囲外
    service.setOpacity(-0.5);
    QCOMPARE(service.opacity(), 0.72);

    service.setOpacity(1.5);
    QCOMPARE(service.opacity(), 0.72);

    service.setOpacity(0.5); // 正常
    QVERIFY(qFuzzyCompare(service.opacity(), 0.5));

    // Anchor: 無効な値
    service.setAnchor("bottom");
    QCOMPARE(service.anchor(), QString("top"));

    service.setAnchor("top-left");
    QCOMPARE(service.anchor(), QString("top-left"));

    service.setAnchor("top-right");
    QCOMPARE(service.anchor(), QString("top-right"));

    // Language: 無効な形式
    service.setLanguage("");
    QCOMPARE(service.language(), QString("ja"));

    service.setLanguage("invalid");
    QCOMPARE(service.language(), QString("ja"));

    service.setLanguage("en");
    QCOMPARE(service.language(), QString("en"));

    service.setLanguage("ja_JP");
    QCOMPARE(service.language(), QString("ja_JP"));

    // Weather unit: 無効な値
    service.setWeatherUnit("kelvin");
    QCOMPARE(service.weatherUnit(), QString("metric"));

    service.setWeatherUnit("imperial");
    QCOMPARE(service.weatherUnit(), QString("imperial"));

    // MaxHistory: 範囲外
    service.setMaxHistory(5);
    QCOMPARE(service.maxHistory(), 100);

    service.setMaxHistory(2000);
    QCOMPARE(service.maxHistory(), 100);

    service.setMaxHistory(200);
    QCOMPARE(service.maxHistory(), 200);

    // Intervals: 範囲外
    service.setStatsInterval(50); // 最小 100ms
    QCOMPARE(service.statsInterval(), 1000);

    service.setStatsInterval(5000000); // 最大 1時間
    QCOMPARE(service.statsInterval(), 1000);

    service.setStatsInterval(2000);
    QCOMPARE(service.statsInterval(), 2000);

    service.setBatteryInterval(50);
    QCOMPARE(service.batteryInterval(), 30000);

    service.setWeatherInterval(50);
    QCOMPARE(service.weatherInterval(), 900000);
}

void TestConfigService::testSchemaVersion()
{
    ConfigService service;
    service.resetToDefaults();

    // スキーマバージョンが正しく設定されることを確認
    QCOMPARE(service.schemaVersion(), ConfigService::CurrentSchemaVersion);

    // 保存・読み込みでバージョンが保持されることを確認
    service.save();

    ConfigService service2;
    service2.load();
    QCOMPARE(service2.schemaVersion(), ConfigService::CurrentSchemaVersion);
}

void TestConfigService::testLanguageSwitching()
{
    ConfigService service;
    service.resetToDefaults();

    // 言語変更シグナルが発火することを確認
    QSignalSpy spy(&service, &ConfigService::languageChanged);

    service.setLanguage("en");
    QCOMPARE(spy.count(), 1);
    QCOMPARE(service.language(), QString("en"));

    // 同じ値をセットしてもシグナルは発火しない
    service.setLanguage("en");
    QCOMPARE(spy.count(), 1);

    service.setLanguage("ja");
    QCOMPARE(spy.count(), 2);
    QCOMPARE(service.language(), QString("ja"));

    // configChanged シグナルも発火することを確認
    QSignalSpy configSpy(&service, &ConfigService::configChanged);
    service.setLanguage("en_US");
    QCOMPARE(configSpy.count(), 1);
}

void TestConfigService::testStaticClampFunctions()
{
    // 静的検証関数の直接テスト (純粋関数)

    // clampGeometry
    QCOMPARE(ConfigService::clampGeometry(100, 10, 200, 50), 100);
    QCOMPARE(ConfigService::clampGeometry(5, 10, 200, 50), 50);   // 最小値未満 → デフォルト
    QCOMPARE(ConfigService::clampGeometry(300, 10, 200, 50), 50);  // 最大値超過 → デフォルト

    // clampOpacity
    QVERIFY(qFuzzyCompare(ConfigService::clampOpacity(0.5), 0.5));
    QVERIFY(qFuzzyCompare(ConfigService::clampOpacity(-0.1), 0.72)); // デフォルト
    QVERIFY(qFuzzyCompare(ConfigService::clampOpacity(1.5), 0.72));  // デフォルト
    QVERIFY(qFuzzyCompare(ConfigService::clampOpacity(qQNaN()), 0.72)); // NaN → デフォルト

    // clampAnchor
    QCOMPARE(ConfigService::clampAnchor("top"), QString("top"));
    QCOMPARE(ConfigService::clampAnchor("top-left"), QString("top-left"));
    QCOMPARE(ConfigService::clampAnchor("top-right"), QString("top-right"));
    QCOMPARE(ConfigService::clampAnchor("bottom"), QString("top"));   // 無効 → デフォルト
    QCOMPARE(ConfigService::clampAnchor("center"), QString("top"));   // 無効 → デフォルト

    // clampLanguage
    QCOMPARE(ConfigService::clampLanguage("ja"), QString("ja"));
    QCOMPARE(ConfigService::clampLanguage("en"), QString("en"));
    QCOMPARE(ConfigService::clampLanguage("ja_JP"), QString("ja_JP"));
    QCOMPARE(ConfigService::clampLanguage("en_US"), QString("en_US"));
    QCOMPARE(ConfigService::clampLanguage(""), QString("ja"));         // 空 → デフォルト
    QCOMPARE(ConfigService::clampLanguage("invalid"), QString("ja"));  // 無効形式 → デフォルト
    QCOMPARE(ConfigService::clampLanguage("japanese"), QString("ja")); // 形式不正 → デフォルト

    // clampWeatherUnit
    QCOMPARE(ConfigService::clampWeatherUnit("metric"), QString("metric"));
    QCOMPARE(ConfigService::clampWeatherUnit("imperial"), QString("imperial"));
    QCOMPARE(ConfigService::clampWeatherUnit("kelvin"), QString("metric")); // 無効 → デフォルト
    QCOMPARE(ConfigService::clampWeatherUnit(""), QString("metric"));       // 空 → デフォルト

    // clampInterval
    QCOMPARE(ConfigService::clampInterval(1000, 100, 1000), 1000);
    QCOMPARE(ConfigService::clampInterval(50, 100, 1000), 1000);       // 最小値未満 → デフォルト
    QCOMPARE(ConfigService::clampInterval(5000000, 100, 1000), 1000);  // 最大値超過 → デフォルト
}

QTEST_MAIN(TestConfigService)
#include "tst_configservice.moc"