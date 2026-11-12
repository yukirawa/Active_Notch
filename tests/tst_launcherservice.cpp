#include <QtTest>
#include "services/LauncherService.h"

/**
 * LauncherService の純粋関数テスト。
 *
 * - .desktop パース
 * - あいまいスコア
 * - 計算パーサ
 * - 計算式判定
 */
class TestLauncherService : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void parseDesktopFile_basic();
    void parseDesktopFile_hidden();
    void parseDesktopFile_noDisplay();
    void parseDesktopFile_notApplication();
    void fuzzyScore_exactMatch();
    void fuzzyScore_prefixMatch();
    void fuzzyScore_wordBoundaryMatch();
    void fuzzyScore_substringMatch();
    void fuzzyScore_fuzzyMatch();
    void fuzzyScore_noMatch();
    void evaluateExpression_simple();
    void evaluateExpression_precedence();
    void evaluateExpression_parentheses();
    void evaluateExpression_negativeNumbers();
    void evaluateExpression_decimals();
    void evaluateExpression_divisionByZero();
    void evaluateExpression_invalidChars();
    void evaluateExpression_unmatchedParen();
    void isCalculationExpression_positive();
    void isCalculationExpression_negative();
};

void TestLauncherService::parseDesktopFile_basic()
{
    // 一時的な .desktop ファイルを作成
    QTemporaryFile tempFile;
    tempFile.setAutoRemove(true);
    QVERIFY(tempFile.open());
    tempFile.write("[Desktop Entry]\n"
                   "Type=Application\n"
                   "Name=Test App\n"
                   "GenericName=Test\n"
                   "Comment=A test application\n"
                   "Icon=test-icon\n"
                   "Exec=test-app %F\n"
                   "Terminal=false\n");
    tempFile.flush();

    QVariantMap entry = LauncherService::parseDesktopFile(tempFile.fileName());

    QVERIFY(!entry.isEmpty());
    QCOMPARE(entry["name"].toString(), QString("Test App"));
    QCOMPARE(entry["genericName"].toString(), QString("Test"));
    QCOMPARE(entry["comment"].toString(), QString("A test application"));
    QCOMPARE(entry["icon"].toString(), QString("test-icon"));
    QCOMPARE(entry["exec"].toString(), QString("test-app %F"));
    QCOMPARE(entry["terminal"].toBool(), false);
    QCOMPARE(entry["desktopFile"].toString(), tempFile.fileName());
}

void TestLauncherService::parseDesktopFile_hidden()
{
    QTemporaryFile tempFile;
    tempFile.setAutoRemove(true);
    QVERIFY(tempFile.open());
    tempFile.write("[Desktop Entry]\n"
                   "Type=Application\n"
                   "Name=Hidden App\n"
                   "Hidden=true\n");
    tempFile.flush();

    QVariantMap entry = LauncherService::parseDesktopFile(tempFile.fileName());
    QVERIFY(entry.isEmpty());
}

void TestLauncherService::parseDesktopFile_noDisplay()
{
    QTemporaryFile tempFile;
    tempFile.setAutoRemove(true);
    QVERIFY(tempFile.open());
    tempFile.write("[Desktop Entry]\n"
                   "Type=Application\n"
                   "Name=NoDisplay App\n"
                   "NoDisplay=true\n");
    tempFile.flush();

    QVariantMap entry = LauncherService::parseDesktopFile(tempFile.fileName());
    QVERIFY(entry.isEmpty());
}

void TestLauncherService::parseDesktopFile_notApplication()
{
    QTemporaryFile tempFile;
    tempFile.setAutoRemove(true);
    QVERIFY(tempFile.open());
    tempFile.write("[Desktop Entry]\n"
                   "Type=Link\n"
                   "Name=Not An App\n"
                   "URL=https://example.com\n");
    tempFile.flush();

    QVariantMap entry = LauncherService::parseDesktopFile(tempFile.fileName());
    QVERIFY(entry.isEmpty());
}

void TestLauncherService::fuzzyScore_exactMatch()
{
    qreal score = LauncherService::fuzzyScore("firefox", "firefox");
    QCOMPARE(score, 1.0);
}

void TestLauncherService::fuzzyScore_prefixMatch()
{
    qreal score = LauncherService::fuzzyScore("fire", "firefox");
    QVERIFY(score >= 0.85 && score <= 0.95); // 前方一致
}

void TestLauncherService::fuzzyScore_wordBoundaryMatch()
{
    qreal score = LauncherService::fuzzyScore("fox", "firefox");
    QVERIFY(score < 0.8); // 単語境界ではない
    // 部分一致として 0.6 程度
}

void TestLauncherService::fuzzyScore_substringMatch()
{
    qreal score = LauncherService::fuzzyScore("ire", "firefox");
    QVERIFY(score >= 0.5 && score <= 0.7);
}

void TestLauncherService::fuzzyScore_fuzzyMatch()
{
    qreal score = LauncherService::fuzzyScore("frfx", "firefox");
    QVERIFY(score > 0.0 && score < 0.5); // あいまい一致
}

void TestLauncherService::fuzzyScore_noMatch()
{
    qreal score = LauncherService::fuzzyScore("xyz", "firefox");
    QCOMPARE(score, 0.0);
}

void TestLauncherService::evaluateExpression_simple()
{
    auto result = LauncherService::evaluateExpression("2+3");
    QVERIFY(result.first);
    QCOMPARE(result.second, QString("5"));

    result = LauncherService::evaluateExpression("10-4");
    QVERIFY(result.first);
    QCOMPARE(result.second, QString("6"));

    result = LauncherService::evaluateExpression("6*7");
    QVERIFY(result.first);
    QCOMPARE(result.second, QString("42"));

    result = LauncherService::evaluateExpression("20/4");
    QVERIFY(result.first);
    QCOMPARE(result.second, QString("5"));
}

void TestLauncherService::evaluateExpression_precedence()
{
    auto result = LauncherService::evaluateExpression("2+3*4");
    QVERIFY(result.first);
    QCOMPARE(result.second, QString("14")); // 2 + (3*4) = 14

    result = LauncherService::evaluateExpression("10/2+3");
    QVERIFY(result.first);
    QCOMPARE(result.second, QString("8")); // (10/2) + 3 = 8
}

void TestLauncherService::evaluateExpression_parentheses()
{
    auto result = LauncherService::evaluateExpression("(2+3)*4");
    QVERIFY(result.first);
    QCOMPARE(result.second, QString("20"));

    result = LauncherService::evaluateExpression("2*(3+4)");
    QVERIFY(result.first);
    QCOMPARE(result.second, QString("14"));

    result = LauncherService::evaluateExpression("((2+3)*4)");
    QVERIFY(result.first);
    QCOMPARE(result.second, QString("20"));
}

void TestLauncherService::evaluateExpression_negativeNumbers()
{
    auto result = LauncherService::evaluateExpression("-5+3");
    QVERIFY(result.first);
    QCOMPARE(result.second, QString("-2"));

    result = LauncherService::evaluateExpression("10+-5");
    QVERIFY(result.first);
    QCOMPARE(result.second, QString("5"));

    result = LauncherService::evaluateExpression("(-5)*(-3)");
    QVERIFY(result.first);
    QCOMPARE(result.second, QString("15"));
}

void TestLauncherService::evaluateExpression_decimals()
{
    auto result = LauncherService::evaluateExpression("1.5+2.5");
    QVERIFY(result.first);
    QCOMPARE(result.second, QString("4"));

    result = LauncherService::evaluateExpression("10/4");
    QVERIFY(result.first);
    QCOMPARE(result.second, QString("2.5"));

    result = LauncherService::evaluateExpression("0.1+0.2");
    QVERIFY(result.first);
    // 浮動小数点誤差許容
    QVERIFY(result.second == "0.3" || result.second == "0.30000000000000004");
}

void TestLauncherService::evaluateExpression_divisionByZero()
{
    auto result = LauncherService::evaluateExpression("5/0");
    QVERIFY(!result.first);

    result = LauncherService::evaluateExpression("1/(2-2)");
    QVERIFY(!result.first);
}

void TestLauncherService::evaluateExpression_invalidChars()
{
    auto result = LauncherService::evaluateExpression("2++3");
    QVERIFY(!result.first); // 連続演算子

    result = LauncherService::evaluateExpression("2^3");
    QVERIFY(!result.first); // 無効文字

    result = LauncherService::evaluateExpression("2 a 3");
    QVERIFY(!result.first); // 文字
}

void TestLauncherService::evaluateExpression_unmatchedParen()
{
    auto result = LauncherService::evaluateExpression("(2+3");
    QVERIFY(!result.first);

    result = LauncherService::evaluateExpression("2+3)");
    QVERIFY(!result.first);

    result = LauncherService::evaluateExpression("((2+3)");
    QVERIFY(!result.first);
}

void TestLauncherService::isCalculationExpression_positive()
{
    QVERIFY(LauncherService::isCalculationExpression("2+3"));
    QVERIFY(LauncherService::isCalculationExpression("10-4"));
    QVERIFY(LauncherService::isCalculationExpression("6*7"));
    QVERIFY(LauncherService::isCalculationExpression("20/4"));
    QVERIFY(LauncherService::isCalculationExpression("(2+3)*4"));
    QVERIFY(LauncherService::isCalculationExpression("1.5+2.5"));
    QVERIFY(LauncherService::isCalculationExpression("-5+3"));
    QVERIFY(LauncherService::isCalculationExpression("  2  +  3  ")); // スペース込み
}

void TestLauncherService::isCalculationExpression_negative()
{
    QVERIFY(!LauncherService::isCalculationExpression("")); // 空
    QVERIFY(!LauncherService::isCalculationExpression("firefox")); // 文字のみ
    QVERIFY(!LauncherService::isCalculationExpression("123")); // 数字のみ (演算子なし)
    QVERIFY(!LauncherService::isCalculationExpression("2^3")); // 無効文字
    QVERIFY(!LauncherService::isCalculationExpression("(2+3")); // 括弧不一致
    QVERIFY(!LauncherService::isCalculationExpression("2+3)")); // 括弧不一致
    QVERIFY(!LauncherService::isCalculationExpression("2++3")); // 連続演算子
}

QTEST_MAIN(TestLauncherService)
#include "tst_launcherservice.moc"