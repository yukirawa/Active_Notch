#include <QtTest>
#include "services/NetworkService.h"

/**
 * NetworkService の純粋関数単体テスト。
 *
 * NM アクセスポイントパース、デバイスステート変換を検証。
 * UI や DBus なしでテスト可能。
 */
class TestNetworkService : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void parseAccessPointBasic();
    void parseAccessPointSecured();
    void parseAccessPointConnected();
    void parseAccessPointEmptySsid();
    void deviceStateToStringKnown();
    void deviceStateToStringUnknown();
    void extractSsidFromActiveConnection();
};

void TestNetworkService::parseAccessPointBasic()
{
    // 基本的なアクセスポイント (オープン、非接続)
    QVariantMap apProps;
    apProps["Ssid"] = QByteArray("TestWiFi");
    apProps["Strength"] = 75;
    apProps["Flags"] = 0;
    apProps["WpaFlags"] = 0;
    apProps["RsnFlags"] = 0;

    QVariantMap result = NetworkService::parseAccessPoint(apProps, "OtherSSID");

    QCOMPARE(result["ssid"].toString(), QString("TestWiFi"));
    QCOMPARE(result["strength"].toInt(), 75);
    QCOMPARE(result["secured"].toBool(), false);
    QCOMPARE(result["connected"].toBool(), false);
    QCOMPARE(result["known"].toBool(), false);
}

void TestNetworkService::parseAccessPointSecured()
{
    // WPA2 セキュアド AP
    QVariantMap apProps;
    apProps["Ssid"] = QByteArray("SecureWiFi");
    apProps["Strength"] = 90;
    apProps["Flags"] = 0;
    apProps["WpaFlags"] = 0;
    apProps["RsnFlags"] = 4; // WPA2

    QVariantMap result = NetworkService::parseAccessPoint(apProps, "OtherSSID");

    QCOMPARE(result["ssid"].toString(), QString("SecureWiFi"));
    QCOMPARE(result["strength"].toInt(), 90);
    QCOMPARE(result["secured"].toBool(), true);
    QCOMPARE(result["known"].toBool(), true); // セキュアなら既知扱い (簡易判定)
}

void TestNetworkService::parseAccessPointConnected()
{
    // 現在接続中の AP
    QVariantMap apProps;
    apProps["Ssid"] = QByteArray("MyWiFi");
    apProps["Strength"] = 85;
    apProps["Flags"] = 0;
    apProps["WpaFlags"] = 2;
    apProps["RsnFlags"] = 4;

    QVariantMap result = NetworkService::parseAccessPoint(apProps, "MyWiFi");

    QCOMPARE(result["ssid"].toString(), QString("MyWiFi"));
    QCOMPARE(result["connected"].toBool(), true);
}

void TestNetworkService::parseAccessPointEmptySsid()
{
    // SSID 空 (hidden network 等) -> 空のマップが返る
    QVariantMap apProps;
    apProps["Ssid"] = QByteArray();
    apProps["Strength"] = 50;

    QVariantMap result = NetworkService::parseAccessPoint(apProps, "");

    QVERIFY(result.isEmpty());
}

void TestNetworkService::deviceStateToStringKnown()
{
    // NM Device.State の既知値
    QCOMPARE(NetworkService::deviceStateToString(100u), QString("connected"));
    QCOMPARE(NetworkService::deviceStateToString(30u), QString("disconnected"));
    QCOMPARE(NetworkService::deviceStateToString(20u), QString("unavailable"));
    QCOMPARE(NetworkService::deviceStateToString(120u), QString("failed"));
    QCOMPARE(NetworkService::deviceStateToString(50u), QString("config"));
    QCOMPARE(NetworkService::deviceStateToString(70u), QString("ip-config"));
}

void TestNetworkService::deviceStateToStringUnknown()
{
    // 未知のステート値
    QCOMPARE(NetworkService::deviceStateToString(999u), QString("unknown"));
}

void TestNetworkService::extractSsidFromActiveConnection()
{
    // 実装がスタブなので空文字列が返ることを確認
    QVariantMap props;
    QString result = NetworkService::extractSsidFromActiveConnection(props);
    QVERIFY(result.isEmpty());
}

QTEST_MAIN(TestNetworkService)
#include "tst_networkservice.moc"