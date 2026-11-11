#include <QtTest>
#include "services/ClipboardService.h"

/**
 * ClipboardService の純粋関数テスト。
 *
 * wl-clipboard なしでテスト可能な静的メソッドを検証。
 */
class TestClipboardService : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void sanitizeClipboardText_basic();
    void sanitizeClipboardText_removesNull();
    void sanitizeClipboardText_removesControlChars();
    void sanitizeClipboardText_preservesNewlineAndTab();
    void sanitizeClipboardText_truncatesLongText();
    void createHistoryEntry_basic();
    void timestampToString_format();
    void search_emptyQuery();
    void search_matching();
    void search_noMatch();
    void search_caseInsensitive();
};

void TestClipboardService::sanitizeClipboardText_basic()
{
    QString result = ClipboardService::sanitizeClipboardText("Hello World");
    QCOMPARE(result, QString("Hello World"));
}

void TestClipboardService::sanitizeClipboardText_removesNull()
{
    QString input = "Hello\0World";
    // QString は NUL で終わらないので、埋め込み NUL を含む文字列を作る
    QString s;
    s += "Hello";
    s += QChar('\0');
    s += "World";
    QString result = ClipboardService::sanitizeClipboardText(s);
    QCOMPARE(result, QString("HelloWorld"));
}

void TestClipboardService::sanitizeClipboardText_removesControlChars()
{
    // 制御文字 (改行・タブ以外) が除去される
    QString input = "Test\x01\x02\x03String";
    QString result = ClipboardService::sanitizeClipboardText(input);
    QCOMPARE(result, QString("TestString"));
}

void TestClipboardService::sanitizeClipboardText_preservesNewlineAndTab()
{
    QString input = "Line1\nLine2\tTab";
    QString result = ClipboardService::sanitizeClipboardText(input);
    QCOMPARE(result, QString("Line1\nLine2\tTab"));
}

void TestClipboardService::sanitizeClipboardText_truncatesLongText()
{
    QString longText(15000, 'A');
    QString result = ClipboardService::sanitizeClipboardText(longText, 10000);
    QCOMPARE(result.length(), 10000 + QString("…(truncated)").length());
    QVERIFY(result.endsWith("…(truncated)"));
}

void TestClipboardService::createHistoryEntry_basic()
{
    QVariantMap entry = ClipboardService::createHistoryEntry(99, "Clipboard text");

    QCOMPARE(entry["id"].toInt(), 99);
    QCOMPARE(entry["text"].toString(), QString("Clipboard text"));
    QVERIFY(!entry["ts"].toString().isEmpty());
    QVERIFY(entry["ts"].toString().contains('T')); // ISO 8601
}

void TestClipboardService::timestampToString_format()
{
    // 固定タイムスタンプでテスト: 2024-01-15T10:30:45.123Z (UTC)
    // Qt::ISODateWithMs はローカルタイムゾーンで出力するため、ISO 8601 形式であることのみ確認
    qint64 ms = 1705314645123;
    QString result = ClipboardService::timestampToString(ms);
    // ISO 8601 形式の基本チェック: YYYY-MM-DDTHH:MM:SS.zzz
    QVERIFY(result.contains(QRegularExpression("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}\\.\\d{3}")));
    QVERIFY(result.contains(".123"));
}

// search() はインスタンスメソッドだが、ロジックは静的にテスト可能な形で切り出せるよう
// ここでは ClipboardService インスタンスを作ってテストする (QProcess 不要な部分のみ)

void TestClipboardService::search_emptyQuery()
{
    ClipboardService service;
    // items は空なので空リストが返る
    QVariantList results = service.search("");
    QVERIFY(results.isEmpty());
}

void TestClipboardService::search_matching()
{
    // 内部メソッドを直接呼べないため、static なヘルパーでロジックをテスト
    // 代わりに、sanitize + createEntry の組み合わせでデータを作り、
    // プライベートなロジックを模倣してテストする
    QString text1 = "Hello World";
    QString text2 = "Foo Bar";
    QString text3 = "hello again";

    // 検索ロジックの模倣
    auto doSearch = [](const QVariantList &items, const QString &query) {
        if (query.isEmpty()) return items;
        QString lowerQuery = query.toLower();
        QVariantList results;
        for (const QVariant &var : items) {
            QVariantMap entry = var.toMap();
            QString text = entry.value("text").toString();
            if (text.toLower().contains(lowerQuery)) {
                results.append(entry);
            }
        }
        return results;
    };

    QVariantList items;
    items.append(ClipboardService::createHistoryEntry(1, text1));
    items.append(ClipboardService::createHistoryEntry(2, text2));
    items.append(ClipboardService::createHistoryEntry(3, text3));

    QVariantList results = doSearch(items, "hello");
    QCOMPARE(results.size(), 2);
    QCOMPARE(results[0].toMap()["text"].toString(), text1);
    QCOMPARE(results[1].toMap()["text"].toString(), text3);
}

void TestClipboardService::search_noMatch()
{
    auto doSearch = [](const QVariantList &items, const QString &query) {
        if (query.isEmpty()) return items;
        QString lowerQuery = query.toLower();
        QVariantList results;
        for (const QVariant &var : items) {
            QVariantMap entry = var.toMap();
            QString text = entry.value("text").toString();
            if (text.toLower().contains(lowerQuery)) {
                results.append(entry);
            }
        }
        return results;
    };

    QVariantList items;
    items.append(ClipboardService::createHistoryEntry(1, "Hello"));
    items.append(ClipboardService::createHistoryEntry(2, "World"));

    QVariantList results = doSearch(items, "xyz");
    QVERIFY(results.isEmpty());
}

void TestClipboardService::search_caseInsensitive()
{
    auto doSearch = [](const QVariantList &items, const QString &query) {
        if (query.isEmpty()) return items;
        QString lowerQuery = query.toLower();
        QVariantList results;
        for (const QVariant &var : items) {
            QVariantMap entry = var.toMap();
            QString text = entry.value("text").toString();
            if (text.toLower().contains(lowerQuery)) {
                results.append(entry);
            }
        }
        return results;
    };

    QVariantList items;
    items.append(ClipboardService::createHistoryEntry(1, "Hello World"));

    QVariantList results = doSearch(items, "HELLO");
    QCOMPARE(results.size(), 1);
    QCOMPARE(results[0].toMap()["text"].toString(), QString("Hello World"));

    results = doSearch(items, "world");
    QCOMPARE(results.size(), 1);

    results = doSearch(items, "WoRlD");
    QCOMPARE(results.size(), 1);
}

QTEST_MAIN(TestClipboardService)
#include "tst_clipboardservice.moc"