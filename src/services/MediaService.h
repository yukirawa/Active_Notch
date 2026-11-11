#pragma once

#include <QObject>
#include <QString>
#include <QUrl>

/**
 * メディアサービス (MPRIS over QtDBus)。
 *
 * 対象: org.mpris.MediaPlayer2.* 全プレイヤー
 * - NameOwnerChanged でプレイヤー登場/消失を検出
 * - アクティブなプレイヤーのプロパティ (Metadata, PlaybackStatus, Position) を購読
 * - シグナル駆動で更新 (ポーリング不要)
 * - プレイヤー無し時は available=false で graceful 退化
 *
 * プロパティ (CONTRACT §3 表):
 *   available, title, artist, album, artUrl, playing, positionMs, lengthMs, canControl, playerName
 * メソッド:
 *   playPause(), next(), previous(), seekMs(ms), setVolumePct(v)
 */
class MediaService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)
    Q_PROPERTY(QString title READ title NOTIFY titleChanged)
    Q_PROPERTY(QString artist READ artist NOTIFY artistChanged)
    Q_PROPERTY(QString album READ album NOTIFY albumChanged)
    Q_PROPERTY(QUrl artUrl READ artUrl NOTIFY artUrlChanged)
    Q_PROPERTY(bool playing READ playing NOTIFY playingChanged)
    Q_PROPERTY(qint64 positionMs READ positionMs NOTIFY positionMsChanged)
    Q_PROPERTY(qint64 lengthMs READ lengthMs NOTIFY lengthChanged)
    Q_PROPERTY(bool canControl READ canControl NOTIFY canControlChanged)
    Q_PROPERTY(QString playerName READ playerName NOTIFY playerNameChanged)

public:
    explicit MediaService(QObject *parent = nullptr);
    ~MediaService() override;

    MediaService(const MediaService &) = delete;
    MediaService &operator=(const MediaService &) = delete;

    bool available() const { return m_available; }
    QString title() const { return m_title; }
    QString artist() const { return m_artist; }
    QString album() const { return m_album; }
    QUrl artUrl() const { return m_artUrl; }
    bool playing() const { return m_playing; }
    qint64 positionMs() const { return m_positionMs; }
    qint64 lengthMs() const { return m_lengthMs; }
    bool canControl() const { return m_canControl; }
    QString playerName() const { return m_playerName; }

    // 再生制御
    Q_INVOKABLE void playPause();
    Q_INVOKABLE void next();
    Q_INVOKABLE void previous();
    Q_INVOKABLE void seekMs(qint64 ms);
    Q_INVOKABLE void setVolumePct(int v); // 0-100

    // MPRIS Metadata パース用純粋関数 (単体テスト用)
    // D-Bus VariantMap から title, artist, album, artUrl, lengthUs を抽出
    static QVariantMap parseMetadata(const QVariantMap &metadata);

    // Position (us) を ms に変換 (単体テスト用)
    static qint64 positionUsToMs(qint64 positionUs);

signals:
    void availableChanged();
    void titleChanged();
    void artistChanged();
    void albumChanged();
    void artUrlChanged();
    void playingChanged();
    void positionMsChanged();
    void lengthChanged();
    void canControlChanged();
    void playerNameChanged();

private:
    // D-Bus 関連の実装詳細
    class Private;
    std::unique_ptr<Private> d;

    // 内部状態
    bool m_available = false;
    QString m_title;
    QString m_artist;
    QString m_album;
    QUrl m_artUrl;
    bool m_playing = false;
    qint64 m_positionMs = 0;
    qint64 m_lengthMs = 0;
    bool m_canControl = false;
    QString m_playerName;

    void updateAvailable(bool available);
    void updateMetadata(const QVariantMap &metadata);
    void updatePlaybackStatus(const QString &status);
    void updatePosition(qint64 positionUs);
    void updateCanControl(bool canControl);
    void clearPlayerState();

public slots:
    void onNameOwnerChanged(const QString &name, const QString &oldOwner, const QString &newOwner);
    void onPropertiesChanged(const QString &interfaceName, const QVariantMap &changedProperties, const QStringList &invalidatedProperties);
};