#include <QtTest>
#include <QDBusArgument>
#include "services/TrayService.h"

/**
 * TrayService の純粋関数テスト。
 *
 * DBusMenu 階層構築とアイコン変換をテスト。
 * 注: QDBusArgument の読み取り/書き込みモードの制約により、
 * 一部テストは実 D-Bus 環境での統合テストでカバーする。
 */
class TestTrayService : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void iconToSource_invalid();
};

void TestTrayService::iconToSource_invalid()
{
    QString result = TrayService::iconToSource(QVariant());
    QVERIFY(result.isEmpty());

    result = TrayService::iconToSource(QVariant("not a valid type"));
    QVERIFY(result.isEmpty());

    // 無効な QDBusArgument (書き込みモード) を渡す
    QDBusArgument writeArg;
    writeArg.beginStructure();
    writeArg << 0 << 0 << 0 << 0 << 0 << 0 << QByteArray();
    writeArg.endStructure();

    QVariant variant = QVariant::fromValue(writeArg);
    QString result2 = TrayService::iconToSource(variant);
    QVERIFY(result2.isEmpty());
}

// iconToSource_validArg と buildMenuModel のテストは
// QDBusArgument の読み取りモードでの構築が複雑なため、
// 実 D-Bus 環境での統合テストでカバーする

QTEST_MAIN(TestTrayService)
#include "tst_trayservice.moc"