#pragma once

#include <QRegion>

/**
 * ActiveNotch の形状関連ユーティリティ。
 *
 * すべて副作用のない純関数として実装し、tests/ から単体テストできるようにする
 * (CONTRACT §0「パース系ロジックは static 純関数に分離」の形状版)。
 */
namespace RegionUtils {

/**
 * 角丸矩形を QRegion で近似する。
 *
 * QRegion は円弧を持てないため、本体矩形と四隅の「階段状 (1 論理px 刻みの
 * 水平ストリップ) の矩形和集合」で角丸を表現する。厳密な円弧ではないが
 * 決定的 (同じ入力なら常に同じ領域) で、テスト可能である。
 *
 * @param x      左上 X (論理px)
 * @param y      左上 Y (論理px)
 * @param w      幅 (論理px)
 * @param h      高さ (論理px)
 * @param radius 角丸半径 (論理px)。w/2 と h/2 を超える場合は自動でクランプする。
 * @return       角丸矩形を表す QRegion。w <= 0 または h <= 0 のときは空。
 *
 * 備考: QRegion はデバイスピクセルでは整数座標のため、境界は QRectF::toRect()
 * 相当の丸め (四捨五入) で整数化する。boundingRect() はその整数矩形に一致する。
 */
QRegion roundedRectRegion(qreal x, qreal y, qreal w, qreal h, qreal radius);

} // namespace RegionUtils
