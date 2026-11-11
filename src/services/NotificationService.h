#pragma once

#include <QObject>
#include <QString>
#include <QVariant>
#include <QDBusConnection>
#include <QDBusAbstractAdaptor>

/**
 * 通知サービス (自前 org.freedesktop.Notifications サーバ実装)。
 *
 * freedesktop.org Notification Specification 準拠:
 * - GetCapabilities
 * - Notify
 * - CloseNotification
 * - GetServerInformation
 *
 * プロパティ (CONTRACT §3 表):
 *   ownsDaemon (bool)  - DBus サービス登録に成功したか
 *   dnd (bool)         - Do Not Disturb モード
 *   history (QVariantList) - 通知履歴 {id, app, summary, body, ts, urgent}
 *
 * メソッド:
 *   close(uint id)     - 指定 ID の通知を閉じる
 *   clearAll()         - 全履歴をクリア
 *   setDnd(bool)       - DND 切替
 *   test()             - テスト通知送信
 *
 * 実装詳細:
 * - セッションバスで org.freedesktop.Notifications を登録
 * - 登録失敗時 ownsDaemon=false でミラーモード (標準通知デーモンの通知を受信して履歴に反映)
 * - 履歴はメモリ管理 (上限 Config.maxHistory)
 * - DND 時は履歴のみ記録・表示抑制
 * - シグナル: notificationAdded(id), notificationRemoved(id), dndChanged
 */
class NotificationService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool ownsDaemon READ ownsDaemon NOTIFY ownsDaemonChanged)
    Q_PROPERTY(bool dnd READ dnd WRITE setDnd NOTIFY dndChanged)
    Q_PROPERTY(QVariantList history READ history NOTIFY historyChanged)

public:
    explicit NotificationService(QObject *parent = nullptr);
    ~NotificationService() override;

    NotificationService(const NotificationService &) = delete;
    NotificationService &operator=(const NotificationService &) = delete;

    bool ownsDaemon() const { return m_ownsDaemon; }
    bool dnd() const { return m_dnd; }
    QVariantList history() const { return m_history; }

    // 通知を閉じる (DBus CloseNotification 相当)
    Q_INVOKABLE void close(uint id);
    // 全履歴をクリア
    Q_INVOKABLE void clearAll();
    // DND 切替
    Q_INVOKABLE void setDnd(bool enabled);
    // テスト通知送信
    Q_INVOKABLE void test();

    // 純粋関数 (単体テスト用)
    // 通知データから履歴エントリを生成
    static QVariantMap createHistoryEntry(uint id, const QString &appName, const QString &summary,
                                           const QString &body, const QVariantMap &hints, bool urgent);
    // hints から urgency を抽出 (0=low, 1=normal, 2=critical)
    static int extractUrgency(const QVariantMap &hints);
    // hints からカテゴリを抽出
    static QString extractCategory(const QVariantMap &hints);
    // タイムスタンプ文字列生成 (ISO 8601)
    static QString timestampToString(qint64 msSinceEpoch);

signals:
    void ownsDaemonChanged();
    void dndChanged();
    void historyChanged();
    void notificationAdded(uint id);
    void notificationRemoved(uint id);

public slots:
    void onNameOwnerChanged(const QString &name, const QString &oldOwner, const QString &newOwner);

private:
    void tryRegisterDaemon();
    uint handleNotify(const QString &appName, uint replacesId, const QString &summary,
                      const QString &body, const QVariantMap &hints);
    void handleCloseNotification(uint id);
    void addToHistory(const QVariantMap &entry);
    void removeFromHistory(uint id);
    void enforceMaxHistory();
    void emitAllChanged();

    bool m_ownsDaemon = false;
    bool m_dnd = false;
    QVariantList m_history;
    int m_maxHistory = 100;
    uint m_nextId = 1;

    // DBus アダプタ (内部クラス)
    class NotificationAdaptor;
    NotificationAdaptor *m_adaptor = nullptr;
    QDBusConnection m_sessionBus;
};