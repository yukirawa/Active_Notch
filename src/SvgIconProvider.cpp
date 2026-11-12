#include "SvgIconProvider.h"

#include <QImage>
#include <QPainter>
#include <QSvgRenderer>
#include <QUrl>

SvgIconProvider::SvgIconProvider()
    : QQuickImageProvider(QQuickImageProvider::Image)
{
}

QImage SvgIconProvider::requestImage(const QString &id, QSize *size,
                                     const QSize &requestedSize)
{
    // QML の Image.source は URL パスをパーセントエンコードして渡してくる。
    // 例: %3Csvg ... fill='%23E8F4F2' ...%3E → <svg ... fill='#E8F4F2' ...>
    const QString svg = QUrl::fromPercentEncoding(id.toUtf8());

    QSvgRenderer renderer(svg.toUtf8());
    if (!renderer.isValid()) {
        if (size)
            *size = QSize();
        return QImage();
    }

    // 要求サイズが無い場合は SVG 自身の defaultSize を使う。
    // (fillMode: PreserveAspectFit と組み合わせて QML 側で拡縮される)
    QSize target = requestedSize;
    if (!target.isValid() || target.isEmpty())
        target = renderer.defaultSize();
    if (!target.isValid() || target.isEmpty())
        target = QSize(24, 24);

    // 高 DPI でもぼやけないよう、要求サイズをそのままピクセル数として描く。
    QImage image(target, QImage::Format_ARGB32_Premultiplied);
    image.fill(Qt::transparent);

    QPainter painter(&image);
    painter.setRenderHint(QPainter::Antialiasing, true);
    painter.setRenderHint(QPainter::SmoothPixmapTransform, true);
    renderer.render(&painter, QRectF(QPointF(0, 0), QSizeF(target)));
    painter.end();

    if (size)
        *size = target;
    return image;
}
