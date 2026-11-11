#include "RegionUtils.h"

#include <QRectF>

#include <algorithm>
#include <cmath>

namespace RegionUtils {

QRegion roundedRectRegion(qreal x, qreal y, qreal w, qreal h, qreal radius)
{
    // 幅・高さが正でなければ空領域。
    if (w <= 0.0 || h <= 0.0) {
        return QRegion();
    }

    // 論理座標を整数ピクセルへ丸める。boundingRect() がこの矩形に一致する。
    const QRect box = QRectF(x, y, w, h).toRect();
    if (box.isEmpty()) {
        return QRegion();
    }

    // radius は幅・高さの半分までにクランプする (それ以上は単なる矩形)。
    const int maxRadius = std::min(box.width(), box.height()) / 2;
    const int r = std::clamp<int>(qRound(radius), 0, maxRadius);

    // 角丸なし = 素の矩形。
    if (r <= 0) {
        return QRegion(box);
    }

    // 水平 1px ストリップの和集合で角丸を近似する。
    // 各行 Y について、四隅の円の方程式から左右の内側オフセットを求め、
    // 中央の直線部分を 1 本の矩形として加える。
    //
    //   円中心 (左上): (box.x + r, box.y + r), 半径 r
    //   行 y (box.y .. box.y + r) における垂直距離 vy = (box.y + r) - y
    //   左端 = 円中心X - sqrt(r^2 - vy^2)  →  box.x からの内側オフセット
    //
    // 下側も同様に box.y + box.height - r を中心とする円で計算する。
    QRegion region;
    for (int row = 0; row < box.height(); ++row) {
        const int y = box.y() + row;

        int leftInset = 0;
        int rightInset = 0;

        // 上側の角丸 (上半分の r 行)
        if (row < r) {
            const int vy = r - row; // 1 .. r
            const qreal dx = std::sqrt(std::max(0, r * r - vy * vy));
            leftInset = static_cast<int>(std::lround(r - dx));
        }
        // 下側の角丸 (下半分の r 行)
        else if (row >= box.height() - r) {
            const int vy = row - (box.height() - r - 1); // 1 .. r
            const qreal dx = std::sqrt(std::max(0, r * r - vy * vy));
            leftInset = static_cast<int>(std::lround(r - dx));
        }

        // 左右は対称。
        rightInset = leftInset;

        const int stripWidth = box.width() - leftInset - rightInset;
        if (stripWidth > 0) {
            region += QRect(box.x() + leftInset, y, stripWidth, 1);
        }
    }

    return region;
}

} // namespace RegionUtils
