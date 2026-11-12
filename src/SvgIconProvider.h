#pragma once

#include <QQuickImageProvider>

/**
 * SvgIconProvider — QML の Image からインライン SVG を描画するプロバイダ。
 *
 * 背景 (Qt 6.12 実機で確認した問題):
 *   `Image { source: "data:image/svg+xml;utf8,<svg ...>" }` は
 *   QQuickPixmapReader が data: URL をネットワーク扱いし、
 *   QNetworkAccessManager が同期的に完了するため finished シグナルを
 *   取りこぼす。結果として全アイコンが "Error decoding" になる。
 *
 * そこで QML 側は `image://svg/<percent-encoded-svg>` を使い、
 * このプロバイダがパーセントデコード → QSvgRenderer でラスタライズする。
 * 外部ファイルを増やさず、既存のインライン SVG をそのまま活かせる。
 */
class SvgIconProvider : public QQuickImageProvider
{
public:
    SvgIconProvider();

    /**
     * @param id            `image://svg/` より後ろ (パーセントエンコード済み SVG)
     * @param size          返す画像の実サイズを書き込む
     * @param requestedSize QML 側の sourceSize / width / height
     */
    QImage requestImage(const QString &id, QSize *size,
                        const QSize &requestedSize) override;
};
