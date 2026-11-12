#pragma once

#include <QObject>
#include <QString>
#include <QVariant>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusAbstractInterface>
#include <QDBusArgument>
#include <QTimer>

/**
 * システムトレイサービス (SNI Watcher + DBusMenu)。
 *
 * 依存: QtDBus (KF6 追加依存なしで自前実装)
 * 仕様: StatusNotifierItem (SNI) Watcher (`org.kde.StatusNotifierWatcher`), DBusMenu (`com.canonical.dbusmenu`)
 *
 * プロパティ (CONTRACT §3 表):
 *   items (QVariantList) - {id, title, iconSource, status}
 *
 * メソッド:
 *   activate(id)     - 左クリック: Activate
 *   openMenu(id)     - 右クリック: ContextMenu
 *
 * シグナル:
 *   menuReady(id)    - menuModel(id) がメニュー構造 (QVariantList 階層) を返す
 *
 * 実装:
 *   Watcher 登録 -> Host にアイテム登録 -> 各アイテムの DBusMenu 取得 -> メニュー階層構築
 * 複雑度高 -> エラー時 available=false で機能 OFF (PLAN 代替案通り)
 * フォールバック: SNI/DBusMenu 失敗 → available=false
 */
class TrayService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)
    Q_PROPERTY(QVariantList items READ items NOTIFY itemsChanged)

public:
    explicit TrayService(QObject *parent = nullptr);
    ~TrayService() override;

    TrayService(const TrayService &) = delete;
    TrayService &operator=(const TrayService &) = delete;

    bool available() const { return m_available; }
    QVariantList items() const { return m_items; }

    // 左クリック: Activate
    Q_INVOKABLE void activate(const QString &id);
    // 右クリック: ContextMenu 表示要求 -> menuReady(id) が出る
    Q_INVOKABLE void openMenu(const QString &id);
    // メニュー構造取得 (QML から呼ぶ)
    Q_INVOKABLE QVariantList menuModel(const QString &id) const;

    // 純粋関数 (単体テスト用)
    // DBusMenu レイアウトから階層メニュー構築
    static QVariantList buildMenuModel(const QDBusArgument &layoutData);
    // アイコンデータから QUrl/画像ソース生成
    static QString iconToSource(const QVariant &iconData);

signals:
    void availableChanged();
    void itemsChanged();
    // メニュー準備完了 (QML 側で menuModel(id) を呼ぶ)
    void menuReady(const QString &id);

private:
    struct TrayItem {
        QString id;              // 一意識別子 (service + objectPath)
        QString service;         // D-Bus サービス名
        QString objectPath;      // オブジェクトパス
        QString title;           // タイトル
        QString status;          // Passive, Active, NeedsAttention
        QString iconName;        // アイコン名
        QVariant iconPixmap;     // アイコンピクセルデータ
        QString iconSource;      // QML 用画像ソース
        QString menuObjectPath;  // DBusMenu オブジェクトパス
        QVariantList menuModel;  // キャッシュされたメニュー構造
        QDBusInterface *menuIface = nullptr;
    };

    void registerWatcher();
    void fetchItemProperties(const QString &service, const QString &objectPath);
    void fetchMenu(const QString &service, const QString &objectPath, const QString &menuPath);
    void refreshMenu(TrayItem &item);
    void cleanupItem(const QString &id);
    void updateItemsProperty();
    QString generateId(const QString &service, const QString &objectPath) const;
    TrayItem* findItem(const QString &id);
    const TrayItem* findItem(const QString &id) const;

private slots:
    // Watcher のシグナル引数は 1 個の QString で、
    // "サービス名 + オブジェクトパス" (例: ":1.95/StatusNotifierItem")。
    void onItemRegistered(const QString &serviceAndPath);
    void onItemUnregistered(const QString &serviceAndPath);
    // DBusMenu のシグナル。引数は使わない (sender() でアイテムを特定)。
    void onMenuLayoutUpdated();
    void onMenuPropertiesUpdated();

private:
    bool m_available = false;
    QVariantList m_items;
    QHash<QString, TrayItem> m_itemMap;

    QDBusInterface *m_watcherIface = nullptr;
    QDBusConnection m_bus;

    // 失敗時のリトライ
    QTimer m_retryTimer;
    int m_retryCount = 0;
};