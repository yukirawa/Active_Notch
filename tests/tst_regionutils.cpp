#include <QtTest>

#include "RegionUtils.h"

/**
 * RegionUtils::roundedRectRegion() の性質検証 (Phase 1)。
 *
 * 角丸の「見た目」は厳密な円弧ではないため、以下の不変条件を検証する:
 *  - boundingRect が指定矩形と一致する
 *  - 中央部は領域内
 *  - 四隅の角 (半径分の外側) は領域外
 *  - radius=0 は素の矩形に一致する
 *  - radius は幅・高さの半分にクランプされる
 *  - 同じ入力で常に同じ領域 (決定的)
 */
class TestRegionUtils : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void boundingRectMatches();
    void centerInside();
    void cornersOutside();
    void radiusZeroIsPlainRect();
    void radiusClampedToHalfHeight();
    void emptyForNonPositiveSize();
    void topEdgeCenterInside();
    void deterministicForSameInput();
};

void TestRegionUtils::boundingRectMatches()
{
    const QRect expected(10, 20, 200, 120);
    const QRegion region = RegionUtils::roundedRectRegion(10, 20, 200, 120, 16);
    QCOMPARE(region.boundingRect(), expected);
}

void TestRegionUtils::centerInside()
{
    const QRegion region = RegionUtils::roundedRectRegion(10, 20, 200, 120, 16);
    // 中心。
    QVERIFY(region.contains(QPoint(10 + 100, 20 + 60)));
    // 上辺中央・下辺中央 (丸みの外側ではあるが中央列は含まれる)。
    QVERIFY(region.contains(QPoint(10 + 100, 20)));
    QVERIFY(region.contains(QPoint(10 + 100, 20 + 119)));
}

void TestRegionUtils::cornersOutside()
{
    const QRegion region = RegionUtils::roundedRectRegion(10, 20, 200, 120, 16);
    // 四隅の角 (半径分だけ内側に入り込む位置の角ピクセル) は領域外。
    QVERIFY(!region.contains(QPoint(10, 20)));
    QVERIFY(!region.contains(QPoint(10 + 199, 20)));
    QVERIFY(!region.contains(QPoint(10, 20 + 119)));
    QVERIFY(!region.contains(QPoint(10 + 199, 20 + 119)));
}

void TestRegionUtils::radiusZeroIsPlainRect()
{
    const QRegion region = RegionUtils::roundedRectRegion(0, 0, 50, 50, 0);
    QCOMPARE(region, QRegion(QRect(0, 0, 50, 50)));
}

void TestRegionUtils::radiusClampedToHalfHeight()
{
    // radius=100 は高さ 50 の半分 (25) にクランプされ、矩形は崩れない。
    const QRegion region = RegionUtils::roundedRectRegion(0, 0, 100, 50, 100);
    QCOMPARE(region.boundingRect(), QRect(0, 0, 100, 50));
    QVERIFY(!region.contains(QPoint(0, 0)));
    QVERIFY(region.contains(QPoint(50, 25)));
}

void TestRegionUtils::emptyForNonPositiveSize()
{
    QVERIFY(RegionUtils::roundedRectRegion(0, 0, 0, 10, 5).isEmpty());
    QVERIFY(RegionUtils::roundedRectRegion(0, 0, 10, 0, 5).isEmpty());
    QVERIFY(RegionUtils::roundedRectRegion(0, 0, 10, -1, 5).isEmpty());
}

void TestRegionUtils::topEdgeCenterInside()
{
    // 実機の collapsed ピル (220x30, radius16) で上辺中央が含まれること。
    const QRegion region = RegionUtils::roundedRectRegion(220, 0, 220, 30, 16);
    QVERIFY(region.contains(QPoint(330, 0)));
    QVERIFY(region.contains(QPoint(330, 29)));
    QCOMPARE(region.boundingRect(), QRect(220, 0, 220, 30));
}

void TestRegionUtils::deterministicForSameInput()
{
    QCOMPARE(RegionUtils::roundedRectRegion(3, 4, 100, 40, 10),
             RegionUtils::roundedRectRegion(3, 4, 100, 40, 10));
}

QTEST_MAIN(TestRegionUtils)

#include "tst_regionutils.moc"
