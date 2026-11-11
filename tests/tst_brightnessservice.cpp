#include <QtTest>
#include <QTemporaryFile>
#include <QTextStream>
#include "services/BrightnessService.h"

/**
 * BrightnessService::parseBrightness() の単体テスト。
 *
 * sysfs の max_brightness / brightness ファイルを模擬してパースを検証。
 */
class TestBrightnessService : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void parseNormalBrightness();
    void parseZeroBrightness();
    void parseFullBrightness();
    void parseMaxBrightnessZero();
    void parseMissingFiles();
    void parseInvalidContent();

private:
    QString createTempFile(const QString &content);
};

QString TestBrightnessService::createTempFile(const QString &content)
{
    QTemporaryFile file;
    file.setAutoRemove(false);
    if (!file.open()) {
        return QString();
    }
    QTextStream out(&file);
    out << content;
    file.close();
    return file.fileName();
}

void TestBrightnessService::parseNormalBrightness()
{
    // max=1000, current=500 → 0.5
    QString maxPath = createTempFile("1000\n");
    QString curPath = createTempFile("500\n");

    qreal result = BrightnessService::parseBrightness(maxPath, curPath);
    QVERIFY(qFuzzyCompare(result, 0.5));

    QFile::remove(maxPath);
    QFile::remove(curPath);
}

void TestBrightnessService::parseZeroBrightness()
{
    // max=1000, current=0 → 0.0
    QString maxPath = createTempFile("1000\n");
    QString curPath = createTempFile("0\n");

    qreal result = BrightnessService::parseBrightness(maxPath, curPath);
    QVERIFY(qFuzzyCompare(result, 0.0));

    QFile::remove(maxPath);
    QFile::remove(curPath);
}

void TestBrightnessService::parseFullBrightness()
{
    // max=1000, current=1000 → 1.0
    QString maxPath = createTempFile("1000\n");
    QString curPath = createTempFile("1000\n");

    qreal result = BrightnessService::parseBrightness(maxPath, curPath);
    QVERIFY(qFuzzyCompare(result, 1.0));

    QFile::remove(maxPath);
    QFile::remove(curPath);
}

void TestBrightnessService::parseMaxBrightnessZero()
{
    // max=0 (異常値) → 0.0
    QString maxPath = createTempFile("0\n");
    QString curPath = createTempFile("500\n");

    qreal result = BrightnessService::parseBrightness(maxPath, curPath);
    QVERIFY(qFuzzyCompare(result, 0.0));

    QFile::remove(maxPath);
    QFile::remove(curPath);
}

void TestBrightnessService::parseMissingFiles()
{
    // 存在しないファイル → 0.0
    qreal result = BrightnessService::parseBrightness("/nonexistent/max_brightness", "/nonexistent/brightness");
    QVERIFY(qFuzzyCompare(result, 0.0));
}

void TestBrightnessService::parseInvalidContent()
{
    // 数値でない内容
    QString maxPath = createTempFile("abc\n");
    QString curPath = createTempFile("xyz\n");

    qreal result = BrightnessService::parseBrightness(maxPath, curPath);
    QVERIFY(qFuzzyCompare(result, 0.0));

    QFile::remove(maxPath);
    QFile::remove(curPath);
}

QTEST_MAIN(TestBrightnessService)
#include "tst_brightnessservice.moc"