#include "NotificationService.h"

#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusInterface>
#include <QDBusArgument>
#include <QDateTime>
#include <QDebug>
#include <QCoreApplication>
#include <QTimer>

namespace {

constexpr char kNotificationsService[] = "org.freedesktop.Notifications";
constexpr char kNotificationsPath[] = "/org/freedesktop/Notifications";
constexpr char kNotificationsInterface[] = "org.freedesktop.Notifications";

// Capabilities: body, icon, actions, etc.
const QStringList kCapabilities = {
    "body",
    "icon-static",
    "icon-multi",
    "actions",
    "hints",
    "persistence"
};

} // namespace

// DBus アダプタ: org.freedesktop.Notifications インターフェースを実装
class NotificationService::NotificationAdaptor : public QDBusAbstractAdaptor
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.Notifications")

public:
    explicit NotificationAdaptor(NotificationService *service)
        : QDBusAbstractAdaptor(service), m_service(service) {}

public slots:
    // GetCapabilities: サポート機能のリストを返す
    QStringList GetCapabilities() {
        return kCapabilities;
    }

    // Notify: 新しい通知を送信
    // パラメータ: app_name, replaces_id, app_icon, summary, body, actions, hints, expire_timeout
    // 戻り値: notification ID
    uint Notify(const QString &appName, uint replacesId, const QString &appIcon,
                const QString &summary, const QString &body,
                const QStringList &actions, const QVariantMap &hints, int expireTimeout) {
        Q_UNUSED(appIcon);
        Q_UNUSED(actions);
        Q_UNUSED(expireTimeout);
        return m_service->handleNotify(appName, replacesId, summary, body, hints);
    }

    // CloseNotification: 指定 ID の通知を閉じる
    void CloseNotification(uint id) {
        m_service->handleCloseNotification(id);
    }

    // GetServerInformation: サーバ情報を返す (name, vendor, version, spec_version)
    QStringList GetServerInformation() {
        return {"ActiveNotch", "yukirawa", "0.1.0", "1.2"};
    }

private:
    NotificationService *m_service;
};

NotificationService::NotificationService(QObject *parent)
    : QObject(parent), m_sessionBus(QDBusConnection::sessionBus())
{
    // 設定から maxHistory を読み取る (ConfigService が未初期化の場合はデフォルト 100)
    // 後で ConfigService から更新可能にする

    // セッションバス接続確認
    if (!m_sessionBus.isConnected()) {
        qWarning() << "NotificationService: セッションバスに接続できません";
        emit ownsDaemonChanged();
        return;
    }

    // アダプタ作成
    m_adaptor = new NotificationAdaptor(this);

    // DBus サービス登録を試みる
    tryRegisterDaemon();
}

NotificationService::~NotificationService() = default;

void NotificationService::tryRegisterDaemon()
{
    // 既に他のプロセスが登録しているか確認
    QDBusConnectionInterface *iface = m_sessionBus.interface();
    if (!iface) {
        qWarning() << "NotificationService: DBus インターフェース取得失敗";
        m_ownsDaemon = false;
        emit ownsDaemonChanged();
        return;
    }

    if (iface->isServiceRegistered(kNotificationsService)) {
        qWarning() << "NotificationService: org.freedesktop.Notifications は既に登録されています (ミラーモード)";
        m_ownsDaemon = false;
        emit ownsDaemonChanged();

        // ミラーモード: 標準の通知デーモンから通知を受信するための監視を設定
        // NameOwnerChanged シグナルで所有者変更を検知
        m_sessionBus.connect("org.freedesktop.DBus", "/org/freedesktop/DBus",
                             "org.freedesktop.DBus", "NameOwnerChanged",
                             this, SLOT(onNameOwnerChanged(QString,QString,QString)));
        return;
    }

    // サービス登録を試みる
    QDBusReply<QDBusConnectionInterface::RegisterServiceReply> reply = iface->registerService(kNotificationsService);
    if (!reply.isValid()) {
        qWarning() << "NotificationService: サービス登録失敗:" << reply.error().message();
        m_ownsDaemon = false;
        emit ownsDaemonChanged();
        return;
    }

    // オブジェクト登録
    if (!m_sessionBus.registerObject(kNotificationsPath, this, QDBusConnection::ExportAdaptors)) {
        qWarning() << "NotificationService: オブジェクト登録失敗";
        iface->unregisterService(kNotificationsService);
        m_ownsDaemon = false;
        emit ownsDaemonChanged();
        return;
    }

    qDebug() << "NotificationService: org.freedesktop.Notifications 登録成功";
    m_ownsDaemon = true;
    emit ownsDaemonChanged();
}

// DBus NameOwnerChanged シグナルハンドラ (スロットとして宣言)
void NotificationService::onNameOwnerChanged(const QString &name, const QString &oldOwner, const QString &newOwner)
{
    if (name == kNotificationsService) {
        if (oldOwner.isEmpty() && !newOwner.isEmpty()) {
            // 新しいデーモンが起動した
            qDebug() << "NotificationService: 新しい通知デーモン検出:" << newOwner;
        } else if (!oldOwner.isEmpty() && newOwner.isEmpty()) {
            // デーモンが終了した -> 再登録を試みる
            qDebug() << "NotificationService: 通知デーモン終了、再登録を試行";
            QTimer::singleShot(1000, this, &NotificationService::tryRegisterDaemon);
        }
    }
}

uint NotificationService::handleNotify(const QString &appName, uint replacesId,
                                        const QString &summary, const QString &body,
                                        const QVariantMap &hints)
{
    uint id;
    if (replacesId != 0) {
        // 既存通知の置き換え
        id = replacesId;
        // 履歴から古いエントリを削除
        removeFromHistory(id);
    } else {
        // 新規通知
        id = m_nextId++;
    }

    bool urgent = extractUrgency(hints) == 2; // critical = urgent

    // DND モードでも履歴には記録するが、表示は抑制
    // (UI 側で dnd プロパティを見て表示制御する)

    QVariantMap entry = createHistoryEntry(id, appName, summary, body, hints, urgent);
    addToHistory(entry);

    emit notificationAdded(id);
    return id;
}

void NotificationService::handleCloseNotification(uint id)
{
    removeFromHistory(id);
    emit notificationRemoved(id);
}

QVariantMap NotificationService::createHistoryEntry(uint id, const QString &appName,
                                                     const QString &summary, const QString &body,
                                                     const QVariantMap &hints, bool urgent)
{
    QVariantMap entry;
    entry["id"] = static_cast<int>(id);
    entry["app"] = appName;
    entry["summary"] = summary;
    entry["body"] = body;
    entry["ts"] = timestampToString(QDateTime::currentMSecsSinceEpoch());
    entry["urgent"] = urgent;
    entry["category"] = extractCategory(hints);
    // hints も保存 (アイコン等)
    if (!hints.isEmpty()) {
        entry["hints"] = hints;
    }
    return entry;
}

int NotificationService::extractUrgency(const QVariantMap &hints)
{
    if (hints.contains("urgency")) {
        bool ok = false;
        int v = hints["urgency"].toInt(&ok);
        if (ok) return qBound(0, v, 2);
    }
    return 1; // normal
}

QString NotificationService::extractCategory(const QVariantMap &hints)
{
    if (hints.contains("category")) {
        return hints["category"].toString();
    }
    return QString();
}

QString NotificationService::timestampToString(qint64 msSinceEpoch)
{
    QDateTime dt = QDateTime::fromMSecsSinceEpoch(msSinceEpoch);
    return dt.toString(Qt::ISODateWithMs); // ISO 8601 with milliseconds
}

void NotificationService::addToHistory(const QVariantMap &entry)
{
    // 最新を先頭に追加
    m_history.prepend(entry);
    enforceMaxHistory();
    emit historyChanged();
}

void NotificationService::removeFromHistory(uint id)
{
    for (int i = 0; i < m_history.size(); ++i) {
        QVariantMap entry = m_history[i].toMap();
        if (entry.value("id").toUInt() == id) {
            m_history.removeAt(i);
            emit historyChanged();
            break;
        }
    }
}

void NotificationService::enforceMaxHistory()
{
    while (m_history.size() > m_maxHistory) {
        m_history.removeLast();
    }
}

void NotificationService::close(uint id)
{
    // DBus CloseNotification と同じ処理
    handleCloseNotification(id);
}

void NotificationService::clearAll()
{
    m_history.clear();
    emit historyChanged();
}

void NotificationService::setDnd(bool enabled)
{
    if (m_dnd == enabled) return;
    m_dnd = enabled;
    emit dndChanged();
}

void NotificationService::test()
{
    // テスト通知を送信 (自分自身の Notify を呼ぶ)
    QVariantMap hints;
    hints["urgency"] = 1; // normal
    hints["category"] = "test";
    handleNotify("ActiveNotch", 0, "テスト通知", "これはテスト通知です。", hints);
}

void NotificationService::emitAllChanged()
{
    emit ownsDaemonChanged();
    emit dndChanged();
    emit historyChanged();
}

#include "NotificationService.moc"