#include <QtTest>
#include "services/BluetoothService.h"

/**
 * BluetoothService の純粋関数単体テスト。
 *
 * BluezQt Device パースを検証。
 * UI や DBus なしでテスト可能。
 */
class TestBluetoothService : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void parseDeviceBasic();
    void parseDeviceWithAlias();
    void parseDeviceConnected();
    void parseDeviceWithBattery();
    void parseDeviceEmptyName();
    void parseDeviceMinimal();
};

void TestBluetoothService::parseDeviceBasic()
{
    // 基本的なデバイス
    QVariantMap deviceProps;
    deviceProps["Name"] = "WH-1000XM4";
    deviceProps["Address"] = "00:11:22:33:44:55";
    deviceProps["Connected"] = false;
    deviceProps["Paired"] = true;

    QVariantMap result = BluetoothService::parseDevice(deviceProps);

    QCOMPARE(result["name"].toString(), QString("WH-1000XM4"));
    QCOMPARE(result["address"].toString(), QString("00:11:22:33:44:55"));
    QCOMPARE(result["connected"].toBool(), false);
    QCOMPARE(result["paired"].toBool(), true);
    QCOMPARE(result["battery"].toInt(), -1); // 不明
}

void TestBluetoothService::parseDeviceWithAlias()
{
    // Name が空で Alias がある場合
    QVariantMap deviceProps;
    deviceProps["Name"] = "";
    deviceProps["Alias"] = "My Mouse";
    deviceProps["Address"] = "AA:BB:CC:DD:EE:FF";
    deviceProps["Connected"] = true;
    deviceProps["Paired"] = true;

    QVariantMap result = BluetoothService::parseDevice(deviceProps);

    QCOMPARE(result["name"].toString(), QString("My Mouse"));
    QCOMPARE(result["connected"].toBool(), true);
}

void TestBluetoothService::parseDeviceConnected()
{
    // 接続中デバイス
    QVariantMap deviceProps;
    deviceProps["Name"] = "Keyboard";
    deviceProps["Address"] = "11:22:33:44:55:66";
    deviceProps["Connected"] = true;
    deviceProps["Paired"] = true;

    QVariantMap result = BluetoothService::parseDevice(deviceProps);

    QCOMPARE(result["connected"].toBool(), true);
}

void TestBluetoothService::parseDeviceWithBattery()
{
    // バッテリー情報あり (BlueZ 5.60+)
    QVariantMap deviceProps;
    deviceProps["Name"] = "Gamepad";
    deviceProps["Address"] = "22:33:44:55:66:77";
    deviceProps["Connected"] = true;
    deviceProps["Paired"] = true;
    deviceProps["BatteryPercentage"] = 75;

    QVariantMap result = BluetoothService::parseDevice(deviceProps);

    QCOMPARE(result["battery"].toInt(), 75);
}

void TestBluetoothService::parseDeviceEmptyName()
{
    // Name も Alias も空 -> 空のマップが返る
    QVariantMap deviceProps;
    deviceProps["Name"] = "";
    deviceProps["Alias"] = "";
    deviceProps["Address"] = "33:44:55:66:77:88";

    QVariantMap result = BluetoothService::parseDevice(deviceProps);

    QVERIFY(result.isEmpty());
}

void TestBluetoothService::parseDeviceMinimal()
{
    // 最小限のプロパティ
    QVariantMap deviceProps;
    deviceProps["Name"] = "Minimal Device";
    deviceProps["Address"] = "44:55:66:77:88:99";

    QVariantMap result = BluetoothService::parseDevice(deviceProps);

    QCOMPARE(result["name"].toString(), QString("Minimal Device"));
    QCOMPARE(result["address"].toString(), QString("44:55:66:77:88:99"));
    QCOMPARE(result["connected"].toBool(), false);
    QCOMPARE(result["paired"].toBool(), false);
    QCOMPARE(result["battery"].toInt(), -1);
}

QTEST_MAIN(TestBluetoothService)
#include "tst_bluetoothservice.moc"