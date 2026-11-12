#include "MediaService.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusReply>
#include <QDBusVariant>
#include <QDBusArgument>
#include <QDebug>
#include <QTimer>

namespace {
constexpr char kMprisServicePrefix[] = "org.mpris.MediaPlayer2.";
constexpr char kMprisPlayerInterface[] = "org.mpris.MediaPlayer2.Player";
constexpr char kPropertiesInterface[] = "org.freedesktop.DBus.Properties";
constexpr int kPositionPollIntervalMs = 1000; // Position 取得用ポーリング間隔 (シグナルが来ない場合のフォールバック)

QString playerNameFromService(const QString &service)
{
    if (service.startsWith(kMprisServicePrefix)) {
        return service.mid(strlen(kMprisServicePrefix));
    }
    return service;
}

// MPRIS の Metadata (a{sv}) を QDBusInterface::property() で読むと、
// 動的 metaobject が a{sv} を QDBusRawType<0x617b73767d>* として生成するため
// 失敗する。Properties.Get を直接呼び、'v' を剥がして demarshall する。
QVariantMap readVariantMapProperty(const QDBusConnection &bus, const QString &service,
                                   const QString &path, const QString &iface,
                                   const QString &property)
{
    QDBusMessage msg = QDBusMessage::createMethodCall(
        service, path, QString::fromLatin1(kPropertiesInterface),
        QStringLiteral("Get"));
    msg << iface << property;
    const QDBusMessage reply = bus.call(msg);
    if (reply.type() != QDBusMessage::ReplyMessage || reply.arguments().isEmpty()) {
        return {};
    }

    QVariant value = reply.arguments().at(0);
    if (value.metaType() == QMetaType::fromType<QDBusVariant>()) {
        value = qvariant_cast<QDBusVariant>(value).variant();
    }
    if (value.metaType() == QMetaType::fromType<QDBusArgument>()) {
        return qdbus_cast<QVariantMap>(value);
    }
    return value.toMap();
}

} // namespace

class MediaService::Private
{
public:
    explicit Private(MediaService *q) : q_ptr(q) {}

    MediaService *q_ptr;

    // 現在監視中のプレイヤー
    QString m_currentPlayerService;
    QString m_currentPlayerPath = "/org/mpris/MediaPlayer2";
    // SetPosition の第 1 引数に使う mpris:trackid (Metadata から取得)
    QString m_trackId;
    QDBusInterface *m_playerIface = nullptr;

    // NameOwnerChanged 監視用
    QDBusConnection m_bus = QDBusConnection::sessionBus();

    // Position 取得用タイマー (シグナル駆動が機能しない環境用フォールバック)
    QTimer m_positionTimer;

    void setup()
    {
        // セッションバスの NameOwnerChanged を監視してプレイヤー登場/消失を検出
        m_bus.connect(QString(),
                      "/org/freedesktop/DBus",
                      "org.freedesktop.DBus",
                      "NameOwnerChanged",
                      q_ptr,
                      SLOT(onNameOwnerChanged(QString,QString,QString)));

        // 既存プレイヤーを列挙して最初のアクティブなものを選択
        enumeratePlayers();

        // Position ポーリングタイマー (フォールバック)
        m_positionTimer.setInterval(kPositionPollIntervalMs);
        connect(&m_positionTimer, &QTimer::timeout, q_ptr, [this]() {
            if (!m_currentPlayerService.isEmpty() && m_playerIface && m_playerIface->isValid()) {
                requestPosition();
            }
        });
    }

    void enumeratePlayers()
    {
        QDBusInterface dbusService("org.freedesktop.DBus",
                                   "/org/freedesktop/DBus",
                                   "org.freedesktop.DBus",
                                   m_bus);
        if (!dbusService.isValid()) return;

        QDBusReply<QStringList> names = dbusService.call("ListNames");
        if (!names.isValid()) return;

        for (const QString &name : names.value()) {
            if (name.startsWith(kMprisServicePrefix)) {
                // 所有者がいるか確認
                QDBusReply<QString> owner = dbusService.call("GetNameOwner", name);
                if (owner.isValid() && !owner.value().isEmpty()) {
                    selectPlayer(name);
                    return; // 最初に見つかったプレイヤーを使用
                }
            }
        }

        // プレイヤーが見つからない
        q_ptr->updateAvailable(false);
    }

    void selectPlayer(const QString &serviceName)
    {
        if (m_currentPlayerService == serviceName) return;

        cleanupCurrentPlayer();

        m_currentPlayerService = serviceName;
        m_playerIface = new QDBusInterface(serviceName,
                                           m_currentPlayerPath,
                                           kMprisPlayerInterface,
                                           m_bus,
                                           q_ptr);

        if (!m_playerIface->isValid()) {
            qWarning() << "MediaService: Failed to create player interface for" << serviceName;
            cleanupCurrentPlayer();
            q_ptr->updateAvailable(false);
            return;
        }

        // プロパティ変更シグナルを購読
        m_bus.connect(serviceName,
                      m_currentPlayerPath,
                      kPropertiesInterface,
                      "PropertiesChanged",
                      q_ptr,
                      SLOT(onPropertiesChanged(QString,QVariantMap,QStringList)));

        // 初期プロパティを取得
        fetchInitialProperties();

        q_ptr->m_playerName = playerNameFromService(serviceName);
        emit q_ptr->playerNameChanged();
        q_ptr->updateAvailable(true);

        // Position ポーリング開始
        m_positionTimer.start();
    }

    void cleanupCurrentPlayer()
    {
        if (m_playerIface) {
            m_bus.disconnect(m_currentPlayerService,
                             m_currentPlayerPath,
                             kPropertiesInterface,
                             "PropertiesChanged",
                             q_ptr,
                             SLOT(onPropertiesChanged(QString,QVariantMap,QStringList)));

            m_playerIface->deleteLater();
            m_playerIface = nullptr;
        }
        m_currentPlayerService.clear();
        m_positionTimer.stop();
    }

    void fetchInitialProperties()
    {
        if (!m_playerIface || !m_playerIface->isValid()) return;

        // Metadata (a{sv}) は property() では読めないため Properties.Get を直接使う
        const QVariantMap metadata = readVariantMapProperty(
            m_bus, m_currentPlayerService, m_currentPlayerPath,
            QString::fromLatin1(kMprisPlayerInterface), QStringLiteral("Metadata"));
        if (!metadata.isEmpty()) {
            q_ptr->updateMetadata(metadata);
        }

        // PlaybackStatus
        QVariant statusVariant = m_playerIface->property("PlaybackStatus");
        if (statusVariant.isValid() && statusVariant.canConvert<QString>()) {
            q_ptr->updatePlaybackStatus(statusVariant.toString());
        }

        // Position (マイクロ秒)
        QVariant positionVariant = m_playerIface->property("Position");
        if (positionVariant.isValid() && positionVariant.canConvert<qlonglong>()) {
            q_ptr->updatePosition(positionVariant.toLongLong());
        }

        // CanControl
        QVariant canControlVariant = m_playerIface->property("CanControl");
        if (canControlVariant.isValid() && canControlVariant.canConvert<bool>()) {
            q_ptr->updateCanControl(canControlVariant.toBool());
        }

        // Volume (0.0-1.0)
        // Volume プロパティは Player インターフェースにある (オプション)
    }

    void requestPosition()
    {
        if (!m_playerIface || !m_playerIface->isValid()) return;

        QVariant positionVariant = m_playerIface->property("Position");
        if (positionVariant.isValid() && positionVariant.canConvert<qlonglong>()) {
            q_ptr->updatePosition(positionVariant.toLongLong());
        }
    }

    // プレイヤーメソッド呼び出しヘルパー
    template<typename... Args>
    void callPlayerMethod(const char *method, Args &&... args)
    {
        if (!m_playerIface || !m_playerIface->isValid()) return;
        m_playerIface->call(method, std::forward<Args>(args)...);
    }
};

MediaService::MediaService(QObject *parent)
    : QObject(parent), d(std::make_unique<Private>(this))
{
    d->setup();
}

MediaService::~MediaService() = default;

void MediaService::playPause()
{
    d->callPlayerMethod("PlayPause");
}

void MediaService::next()
{
    d->callPlayerMethod("Next");
}

void MediaService::previous()
{
    d->callPlayerMethod("Previous");
}

void MediaService::seekMs(qint64 ms)
{
    if (!d->m_playerIface || !d->m_playerIface->isValid()) return;
    // SetPosition(o trackId, x positionUs)。trackId は Metadata の
    // mpris:trackid であり、プレイヤーのオブジェクトパスではない。
    const QString trackId = d->m_trackId.isEmpty()
        ? QStringLiteral("/org/mpris/MediaPlayer2/TrackList/NoTrack")
        : d->m_trackId;
    qint64 us = ms * 1000;
    d->m_playerIface->call("SetPosition", QDBusObjectPath(trackId), us);
}

void MediaService::setVolumePct(int v)
{
    if (!d->m_playerIface || !d->m_playerIface->isValid()) return;
    v = qBound(0, v, 100);
    double volume = v / 100.0;
    d->m_playerIface->call("SetVolume", volume);
}

void MediaService::updateAvailable(bool available)
{
    if (m_available == available) return;
    m_available = available;
    if (!available) {
        clearPlayerState();
    }
    emit availableChanged();
}

void MediaService::updateMetadata(const QVariantMap &metadata)
{
    // SetPosition 用に mpris:trackid を保持する (o = QDBusObjectPath)
    const QVariant trackVar = metadata.value(QStringLiteral("mpris:trackid"));
    if (trackVar.userType() == qMetaTypeId<QDBusObjectPath>()) {
        d->m_trackId = qvariant_cast<QDBusObjectPath>(trackVar).path();
    } else {
        d->m_trackId = trackVar.toString();
    }

    auto parsed = parseMetadata(metadata);

    QString newTitle = parsed.value("title").toString();
    QString newArtist = parsed.value("artist").toString();
    QString newAlbum = parsed.value("album").toString();
    QUrl newArtUrl = parsed.value("artUrl").toUrl();
    qint64 newLengthMs = parsed.value("lengthMs").toLongLong();

    bool changed = false;
    if (m_title != newTitle) { m_title = newTitle; emit titleChanged(); changed = true; }
    if (m_artist != newArtist) { m_artist = newArtist; emit artistChanged(); changed = true; }
    if (m_album != newAlbum) { m_album = newAlbum; emit albumChanged(); changed = true; }
    if (m_artUrl != newArtUrl) { m_artUrl = newArtUrl; emit artUrlChanged(); changed = true; }
    if (m_lengthMs != newLengthMs) { m_lengthMs = newLengthMs; emit lengthChanged(); changed = true; }
    if (changed) {
        // lengthMsChanged シグナル名が lengthChanged になっているので注意
    }
}

void MediaService::updatePlaybackStatus(const QString &status)
{
    bool newPlaying = (status == "Playing");
    if (m_playing != newPlaying) {
        m_playing = newPlaying;
        emit playingChanged();
    }
}

void MediaService::updatePosition(qint64 positionUs)
{
    qint64 newPositionMs = positionUsToMs(positionUs);
    if (m_positionMs != newPositionMs) {
        m_positionMs = newPositionMs;
        emit positionMsChanged();
    }
}

void MediaService::updateCanControl(bool canControl)
{
    if (m_canControl != canControl) {
        m_canControl = canControl;
        emit canControlChanged();
    }
}

void MediaService::clearPlayerState()
{
    if (!m_title.isEmpty()) { m_title.clear(); emit titleChanged(); }
    if (!m_artist.isEmpty()) { m_artist.clear(); emit artistChanged(); }
    if (!m_album.isEmpty()) { m_album.clear(); emit albumChanged(); }
    if (m_artUrl.isValid()) { m_artUrl = QUrl(); emit artUrlChanged(); }
    if (m_playing) { m_playing = false; emit playingChanged(); }
    if (m_positionMs != 0) { m_positionMs = 0; emit positionMsChanged(); }
    if (m_lengthMs != 0) { m_lengthMs = 0; emit lengthChanged(); }
    if (m_canControl) { m_canControl = false; emit canControlChanged(); }
    if (!m_playerName.isEmpty()) { m_playerName.clear(); emit playerNameChanged(); }
}

QVariantMap MediaService::parseMetadata(const QVariantMap &metadata)
{
    QVariantMap result;

    // xesam:title
    if (metadata.contains("xesam:title")) {
        result["title"] = metadata["xesam:title"].toString();
    }

    // xesam:artist (stringlist)
    if (metadata.contains("xesam:artist")) {
        QVariantList artists = metadata["xesam:artist"].toList();
        if (!artists.isEmpty()) {
            result["artist"] = artists.first().toString();
        }
    }

    // xesam:album
    if (metadata.contains("xesam:album")) {
        result["album"] = metadata["xesam:album"].toString();
    }

    // mpris:artUrl
    if (metadata.contains("mpris:artUrl")) {
        result["artUrl"] = metadata["mpris:artUrl"].toUrl();
    }

    // mpris:length (マイクロ秒) -> ミリ秒
    if (metadata.contains("mpris:length")) {
        qint64 lengthUs = metadata["mpris:length"].toLongLong();
        result["lengthMs"] = positionUsToMs(lengthUs);
    }

    return result;
}

qint64 MediaService::positionUsToMs(qint64 positionUs)
{
    if (positionUs < 0) return 0;
    return positionUs / 1000;
}

// --- DBus スロット ---

void MediaService::onNameOwnerChanged(const QString &name, const QString &oldOwner, const QString &newOwner)
{
    if (!name.startsWith(kMprisServicePrefix)) return;

    if (newOwner.isEmpty()) {
        // プレイヤーが消えた
        if (name == d->m_currentPlayerService) {
            qDebug() << "MediaService: Player disappeared:" << name;
            d->cleanupCurrentPlayer();
            // 次のプレイヤーを探す
            d->enumeratePlayers();
        }
    } else if (oldOwner.isEmpty()) {
        // 新しいプレイヤーが現れた
        if (d->m_currentPlayerService.isEmpty()) {
            qDebug() << "MediaService: New player appeared:" << name;
            d->selectPlayer(name);
        }
    }
}

void MediaService::onPropertiesChanged(const QString &interfaceName,
                                       const QVariantMap &changedProperties,
                                       const QStringList &invalidatedProperties)
{
    Q_UNUSED(invalidatedProperties);

    if (interfaceName != kMprisPlayerInterface) return;

    if (changedProperties.contains("Metadata")) {
        // PropertiesChanged の a{sv} 内の Metadata は QVariant<QDBusArgument> で届く
        const QVariant metadataValue = changedProperties.value(QStringLiteral("Metadata"));
        if (metadataValue.metaType() == QMetaType::fromType<QDBusArgument>()) {
            updateMetadata(qdbus_cast<QVariantMap>(metadataValue));
        } else {
            updateMetadata(metadataValue.toMap());
        }
    }
    if (changedProperties.contains("PlaybackStatus")) {
        updatePlaybackStatus(changedProperties["PlaybackStatus"].toString());
    }
    if (changedProperties.contains("Position")) {
        updatePosition(changedProperties["Position"].toLongLong());
    }
    if (changedProperties.contains("CanControl")) {
        updateCanControl(changedProperties["CanControl"].toBool());
    }
    if (changedProperties.contains("Volume")) {
        // Volume 変更は現状プロパティとして公開していないが、必要なら追加可能
    }
}