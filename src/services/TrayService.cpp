#include "TrayService.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDBusMessage>
#include <QDBusArgument>
#include <QDBusObjectPath>
#include <QDebug>
#include <QTimer>
#include <QImage>
#include <QBuffer>
#include <QPixmap>
#include <QStandardPaths>
#include <QByteArray>

namespace {

constexpr char kWatcherService[] = "org.kde.StatusNotifierWatcher";
constexpr char kWatcherPath[] = "/StatusNotifierWatcher";
constexpr char kWatcherInterface[] = "org.kde.StatusNotifierWatcher";

constexpr char kItemInterface[] = "org.kde.StatusNotifierItem";
constexpr char kMenuInterface[] = "com.canonical.dbusmenu";

constexpr int kRetryIntervalMs = 5000;
constexpr int kMaxRetries = 3;

// DBusMenu レイアウト項目のキー
constexpr char kMenuItemId[] = "id";
constexpr char kMenuItemLabel[] = "label";
constexpr char kMenuItemEnabled[] = "enabled";
constexpr char kMenuItemVisible[] = "visible";
constexpr char kMenuItemType[] = "type";
constexpr char kMenuItemChildren[] = "children-display";
constexpr char kMenuItemIconName[] = "icon-name";
constexpr char kMenuItemIconData[] = "icon-data";

} // namespace

TrayService::TrayService(QObject *parent)
    : QObject(parent), m_bus(QDBusConnection::sessionBus())
{
    // セッションバス接続確認
    if (!m_bus.isConnected()) {
        qWarning() << "TrayService: Session bus not connected";
        m_available = false;
        emit availableChanged();
        return;
    }

    // リトライタイマー
    m_retryTimer.setSingleShot(true);
    connect(&m_retryTimer, &QTimer::timeout, this, &TrayService::registerWatcher);

    // Watcher 登録
    registerWatcher();
}

TrayService::~TrayService()
{
    // 登録解除
    if (m_watcherIface && m_watcherIface->isValid()) {
        m_watcherIface->call("UnregisterHost", "ActiveNotch");
    }
    // メニューインターフェース削除
    for (auto &item : m_itemMap) {
        delete item.menuIface;
    }
    delete m_watcherIface;
}

void TrayService::registerWatcher()
{
    if (m_watcherIface) {
        delete m_watcherIface;
        m_watcherIface = nullptr;
    }

    m_watcherIface = new QDBusInterface(kWatcherService, kWatcherPath, kWatcherInterface, m_bus, this);

    if (!m_watcherIface->isValid()) {
        qWarning() << "TrayService: StatusNotifierWatcher not available:" << m_watcherIface->lastError().message();

        m_retryCount++;
        if (m_retryCount < kMaxRetries) {
            qDebug() << "TrayService: Retrying in" << kRetryIntervalMs << "ms (attempt" << m_retryCount + 1 << ")";
            m_retryTimer.start(kRetryIntervalMs);
        } else {
            qWarning() << "TrayService: Max retries reached, disabling tray service";
            m_available = false;
            emit availableChanged();
        }
        return;
    }

    // シグナル接続
    connect(m_watcherIface, SIGNAL(StatusNotifierItemRegistered(QString,QDBusObjectPath)),
            this, SLOT(onItemRegistered(QString,QDBusObjectPath)));
    connect(m_watcherIface, SIGNAL(StatusNotifierItemUnregistered(QString,QDBusObjectPath)),
            this, SLOT(onItemUnregistered(QString,QDBusObjectPath)));

    // ホスト登録
    QDBusReply<void> reply = m_watcherIface->call("RegisterHost", "ActiveNotch");
    if (!reply.isValid()) {
        qWarning() << "TrayService: RegisterHost failed:" << reply.error().message();
        m_available = false;
        emit availableChanged();
        return;
    }

    qDebug() << "TrayService: Registered as StatusNotifierWatcher host";

    // 既存アイテム取得
    QDBusReply<QList<QDBusObjectPath>> itemsReply = m_watcherIface->call("RegisteredStatusNotifierItems");
    if (itemsReply.isValid()) {
        for (const QDBusObjectPath &path : itemsReply.value()) {
            onItemRegistered(kWatcherService, path);
        }
    }

    m_retryCount = 0;
    m_available = true;
    emit availableChanged();
}

void TrayService::onItemRegistered(const QString &service, const QDBusObjectPath &objectPath)
{
    QString itemId = generateId(service, objectPath.path());
    qDebug() << "TrayService: Item registered:" << itemId;

    if (m_itemMap.contains(itemId)) {
        return; // 既に処理済み
    }

    TrayItem item;
    item.id = itemId;
    item.service = service;
    item.objectPath = objectPath.path();

    m_itemMap[itemId] = std::move(item);
    fetchItemProperties(service, objectPath.path());
}

void TrayService::onItemUnregistered(const QString &service, const QDBusObjectPath &objectPath)
{
    QString itemId = generateId(service, objectPath.path());
    qDebug() << "TrayService: Item unregistered:" << itemId;
    cleanupItem(itemId);
}

void TrayService::fetchItemProperties(const QString &service, const QString &objectPath)
{
    QString itemId = generateId(service, objectPath);
    TrayItem *item = findItem(itemId);
    if (!item) return;

    QDBusInterface itemIface(service, objectPath, kItemInterface, m_bus, this);
    if (!itemIface.isValid()) {
        qWarning() << "TrayService: Invalid item interface for" << itemId;
        cleanupItem(itemId);
        return;
    }

    // プロパティ取得
    item->title = itemIface.property("Title").toString();
    item->status = itemIface.property("Status").toString(); // "Passive", "Active", "NeedsAttention"
    item->iconName = itemIface.property("IconName").toString();
    item->iconPixmap = itemIface.property("IconPixmap");
    QString menuPath = itemIface.property("Menu").toString();

    // アイコンソース生成
    item->iconSource = iconToSource(item->iconPixmap);
    if (item->iconSource.isEmpty() && !item->iconName.isEmpty()) {
        item->iconSource = "image://theme/" + item->iconName;
    }

    // DBusMenu 取得
    if (!menuPath.isEmpty() && menuPath != "/") {
        item->menuObjectPath = menuPath;
        fetchMenu(service, objectPath, menuPath);
    }

    updateItemsProperty();
}

void TrayService::fetchMenu(const QString &service, const QString &objectPath, const QString &menuPath)
{
    Q_UNUSED(objectPath);
    QString itemId = generateId(service, objectPath);
    TrayItem *item = findItem(itemId);
    if (!item) return;

    // 既存インターフェース削除
    if (item->menuIface) {
        delete item->menuIface;
        item->menuIface = nullptr;
    }

    item->menuIface = new QDBusInterface(service, menuPath, kMenuInterface, m_bus, this);
    if (!item->menuIface->isValid()) {
        qWarning() << "TrayService: Invalid DBusMenu interface for" << itemId << ":" << item->menuIface->lastError().message();
        delete item->menuIface;
        item->menuIface = nullptr;
        return;
    }

    // シグナル接続
    connect(item->menuIface, SIGNAL(LayoutUpdated()),
            this, SLOT(onMenuLayoutUpdated()));
    connect(item->menuIface, SIGNAL(PropertiesUpdated(QDBusArgument)),
            this, SLOT(onMenuPropertiesUpdated()));

    // レイアウト取得 (GetLayout: 0 = depth, -1 = all)
    QDBusReply<QDBusArgument> reply = item->menuIface->call("GetLayout", 0, -1, QStringList());
    if (reply.isValid()) {
        QDBusArgument arg = reply.value();
        item->menuModel = buildMenuModel(arg);
        qDebug() << "TrayService: Menu loaded for" << itemId << "with" << item->menuModel.size() << "root items";
    } else {
        qWarning() << "TrayService: GetLayout failed for" << itemId << ":" << reply.error().message();
    }
}

void TrayService::onMenuLayoutUpdated()
{
    QDBusInterface *senderIface = qobject_cast<QDBusInterface*>(sender());
    if (!senderIface) return;

    // どのアイテムか特定
    for (auto &item : m_itemMap) {
        if (item.menuIface == senderIface) {
            QDBusReply<QDBusArgument> reply = senderIface->call("GetLayout", 0, -1, QStringList());
            if (reply.isValid()) {
                item.menuModel = buildMenuModel(reply.value());
                emit menuReady(item.id);
            }
            break;
        }
    }
}

void TrayService::onMenuPropertiesUpdated()
{
    // プロパティ更新時も再取得 (簡易実装)
    onMenuLayoutUpdated();
}

void TrayService::cleanupItem(const QString &id)
{
    auto it = m_itemMap.find(id);
    if (it == m_itemMap.end()) return;

    if (it->menuIface) {
        delete it->menuIface;
        it->menuIface = nullptr;
    }
    m_itemMap.erase(it);
    updateItemsProperty();
}

void TrayService::updateItemsProperty()
{
    m_items.clear();
    for (const auto &item : m_itemMap) {
        QVariantMap map;
        map["id"] = item.id;
        map["title"] = item.title.isEmpty() ? item.id : item.title;
        map["iconSource"] = item.iconSource;
        map["status"] = item.status.isEmpty() ? "Passive" : item.status;
        m_items.append(map);
    }
    emit itemsChanged();
}

QString TrayService::generateId(const QString &service, const QString &objectPath) const
{
    // サービス名 + オブジェクトパスから一意ID生成
    QString sanitized = service + objectPath;
    sanitized.replace('/', '_').replace('.', '_').replace(':', '_');
    return sanitized;
}

TrayService::TrayItem* TrayService::findItem(const QString &id)
{
    auto it = m_itemMap.find(id);
    if (it != m_itemMap.end()) {
        return &it.value();
    }
    return nullptr;
}

const TrayService::TrayItem* TrayService::findItem(const QString &id) const
{
    auto it = m_itemMap.constFind(id);
    if (it != m_itemMap.constEnd()) {
        return &it.value();
    }
    return nullptr;
}

void TrayService::activate(const QString &id)
{
    TrayItem *item = findItem(id);
    if (!item) return;

    QDBusInterface itemIface(item->service, item->objectPath, kItemInterface, m_bus, this);
    if (itemIface.isValid()) {
        // Activate(x, y, timestamp) - パラメータは省略可能
        itemIface.call("Activate", 0, 0, 0);
    }
}

void TrayService::openMenu(const QString &id)
{
    TrayItem *item = findItem(id);
    if (!item) return;

    // メニューがまだ読み込まれていない場合、読み込みをトリガー
    if (item->menuModel.isEmpty() && !item->menuObjectPath.isEmpty()) {
        fetchMenu(item->service, item->objectPath, item->menuObjectPath);
    }

    // menuReady シグナルを出して QML 側で menuModel(id) を呼ばせる
    emit menuReady(id);
}

QVariantList TrayService::menuModel(const QString &id) const
{
    const TrayItem *item = findItem(id);
    if (!item) return QVariantList();
    return item->menuModel;
}

QVariantList TrayService::buildMenuModel(const QDBusArgument &layoutData)
{
    QVariantList result;

    // DBusMenu レイアウト構造:
    // (revision: int, rootId: int, layouts: a{ia{sv}})
    // layouts: map<itemId, map<property, value>>
    // プロパティ: id, label, enabled, visible, type, children-display, icon-name, icon-data

    layoutData.beginStructure();
    int revision = 0;
    int rootId = 0;
    QVariantMap layouts;

    layoutData >> revision >> rootId >> layouts;
    layoutData.endStructure();

    if (layouts.isEmpty()) return result;

    // 全アイテムを収集
    QMap<QString, QVariantMap> allItems;
    for (auto it = layouts.constBegin(); it != layouts.constEnd(); ++it) {
        QString key = it.key();
        QVariantMap props = it.value().toMap();
        props["id"] = key;
        allItems[key] = props;
    }

    if (allItems.isEmpty()) return result;

    // 子IDを収集
    QSet<QString> childIds;
    for (auto it = allItems.constBegin(); it != allItems.constEnd(); ++it) {
        if (it.value().contains(kMenuItemChildren)) {
            QString childrenStr = it.value()[kMenuItemChildren].toString();
            QStringList childIdStrs = childrenStr.split(' ', Qt::SkipEmptyParts);
            for (const QString &cidStr : childIdStrs) {
                childIds.insert(cidStr);
            }
        }
    }

    // ルートアイテムを見つける (rootId または親を持たないもの)
    QStringList rootIds;
    QString rootIdStr = QString::number(rootId);
    if (rootId > 0 && allItems.contains(rootIdStr)) {
        rootIds.append(rootIdStr);
    } else {
        for (auto it = allItems.constBegin(); it != allItems.constEnd(); ++it) {
            if (!childIds.contains(it.key())) {
                rootIds.append(it.key());
            }
        }
    }

    // 再帰構築
    std::function<QVariantMap(const QString&)> buildNode = [&](const QString &id) -> QVariantMap {
        QVariantMap node;
        auto it = allItems.find(id);
        if (it == allItems.end()) return node;

        QVariantMap props = *it;
        node["id"] = props.value(kMenuItemId, id).toString();
        node["label"] = props.value(kMenuItemLabel, "").toString();
        node["enabled"] = props.value(kMenuItemEnabled, true).toBool();
        node["visible"] = props.value(kMenuItemVisible, true).toBool();
        node["type"] = props.value(kMenuItemType, "standard").toString(); // standard, separator, etc.
        node["iconSource"] = iconToSource(props.value(kMenuItemIconData));
        if (node["iconSource"].toString().isEmpty()) {
            QString iconName = props.value(kMenuItemIconName, "").toString();
            if (!iconName.isEmpty()) {
                node["iconSource"] = "image://theme/" + iconName;
            }
        }

        // 子アイテム
        if (props.contains(kMenuItemChildren)) {
            QString childrenStr = props[kMenuItemChildren].toString();
            QStringList childIdStrs = childrenStr.split(' ', Qt::SkipEmptyParts);
            QVariantList childNodes;
            for (const QString &cidStr : childIdStrs) {
                childNodes.append(buildNode(cidStr));
            }
            node["children"] = childNodes;
        }

        return node;
    };

    for (const QString &rid : rootIds) {
        result.append(buildNode(rid));
    }

    return result;
}

QString TrayService::iconToSource(const QVariant &iconData)
{
    // iconData は a(iiibiiay) 形式: [(width, height, depth, hasAlpha, rowstride, nChannels, data)]
    // または単一の構造体

    if (!iconData.isValid()) return QString();

    // QDBusArgument として来る場合
    if (iconData.userType() == qMetaTypeId<QDBusArgument>()) {
        QDBusArgument arg = qvariant_cast<QDBusArgument>(iconData);
        arg.beginStructure();
        int width, height, depth, hasAlpha, rowstride, nChannels;
        QByteArray data;
        arg >> width >> height >> depth >> hasAlpha >> rowstride >> nChannels >> data;
        arg.endStructure();

        if (width <= 0 || height <= 0 || data.isEmpty()) return QString();

        QImage::Format fmt = hasAlpha ? QImage::Format_ARGB32 : QImage::Format_RGB32;
        QImage img(reinterpret_cast<const uchar*>(data.constData()), width, height, rowstride, fmt);
        if (img.isNull()) return QString();

        // データコピー (元データが解放される可能性があるため)
        img = img.copy();

        // data URI に変換
        QByteArray ba;
        QBuffer buffer(&ba);
        buffer.open(QIODevice::WriteOnly);
        img.save(&buffer, "PNG");
        return "data:image/png;base64," + ba.toBase64();
    }

    // QVariantList として来る場合 (複数アイコン)
    if (iconData.typeId() == QMetaType::QVariantList) {
        QVariantList list = iconData.toList();
        if (!list.isEmpty()) {
            return iconToSource(list.first());
        }
    }

    return QString();
}