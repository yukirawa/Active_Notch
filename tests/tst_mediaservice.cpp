#include <QtTest>
#include "services/MediaService.h"

/**
 * MediaService の純粋関数単体テスト。
 *
 * MPRIS Metadata パースと Position 変換を検証。
 * UI や DBus なしでテスト可能。
 */
class TestMediaService : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void parseMetadataFull();
    void parseMetadataMinimal();
    void parseMetadataEmpty();
    void parseMetadataArtistList();
    void positionUsToMsBasic();
    void positionUsToMsZero();
    void positionUsToMsNegative();
    void positionUsToMsLarge();
};

void TestMediaService::parseMetadataFull()
{
    // 完全な MPRIS Metadata
    QVariantMap metadata;
    metadata["xesam:title"] = "Test Song";
    metadata["xesam:artist"] = QVariantList{"Artist One", "Artist Two"};
    metadata["xesam:album"] = "Test Album";
    metadata["mpris:artUrl"] = QUrl("file:///path/to/cover.jpg");
    metadata["mpris:length"] = QVariant::fromValue(qlonglong(3 * 60 * 1000000 + 30 * 1000000)); // 3:30 in microseconds

    QVariantMap result = MediaService::parseMetadata(metadata);

    QCOMPARE(result["title"].toString(), QString("Test Song"));
    QCOMPARE(result["artist"].toString(), QString("Artist One")); // 最初のアーティスト
    QCOMPARE(result["album"].toString(), QString("Test Album"));
    QCOMPARE(result["artUrl"].toUrl(), QUrl("file:///path/to/cover.jpg"));
    QCOMPARE(result["lengthMs"].toLongLong(), qint64(210000)); // 3:30 = 210秒 = 210000ms
}

void TestMediaService::parseMetadataMinimal()
{
    // title のみ
    QVariantMap metadata;
    metadata["xesam:title"] = "Minimal Track";

    QVariantMap result = MediaService::parseMetadata(metadata);

    QCOMPARE(result["title"].toString(), QString("Minimal Track"));
    QVERIFY(result["artist"].toString().isEmpty());
    QVERIFY(result["album"].toString().isEmpty());
    QVERIFY(!result["artUrl"].toUrl().isValid());
    QCOMPARE(result["lengthMs"].toLongLong(), qint64(0));
}

void TestMediaService::parseMetadataEmpty()
{
    // 空の Metadata
    QVariantMap metadata;

    QVariantMap result = MediaService::parseMetadata(metadata);

    QVERIFY(result["title"].toString().isEmpty());
    QVERIFY(result["artist"].toString().isEmpty());
    QVERIFY(result["album"].toString().isEmpty());
    QVERIFY(!result["artUrl"].toUrl().isValid());
    QCOMPARE(result["lengthMs"].toLongLong(), qint64(0));
}

void TestMediaService::parseMetadataArtistList()
{
    // アーティストが複数
    QVariantMap metadata;
    metadata["xesam:title"] = "Collab Track";
    metadata["xesam:artist"] = QVariantList{"Main Artist", "Featured Artist", "Remixer"};

    QVariantMap result = MediaService::parseMetadata(metadata);

    QCOMPARE(result["artist"].toString(), QString("Main Artist")); // 最初のみ
}

void TestMediaService::positionUsToMsBasic()
{
    // 1秒 = 1,000,000 us -> 1000 ms
    QCOMPARE(MediaService::positionUsToMs(1000000), qint64(1000));

    // 1分30秒 = 90,000,000 us -> 90000 ms
    QCOMPARE(MediaService::positionUsToMs(90000000), qint64(90000));

    // 1時間 = 3,600,000,000 us -> 3600000 ms
    QCOMPARE(MediaService::positionUsToMs(3600000000LL), qint64(3600000));
}

void TestMediaService::positionUsToMsZero()
{
    QCOMPARE(MediaService::positionUsToMs(0), qint64(0));
}

void TestMediaService::positionUsToMsNegative()
{
    // 負の値は 0 にクランプ
    QCOMPARE(MediaService::positionUsToMs(-1), qint64(0));
    QCOMPARE(MediaService::positionUsToMs(-1000000), qint64(0));
}

void TestMediaService::positionUsToMsLarge()
{
    // 大きな値 (overflow しない範囲)
    qint64 largeUs = 9223372036854775807LL / 1000; // LLONG_MAX/1000 程度
    qint64 expectedMs = largeUs / 1000;
    QCOMPARE(MediaService::positionUsToMs(largeUs), expectedMs);
}

QTEST_MAIN(TestMediaService)
#include "tst_mediaservice.moc"