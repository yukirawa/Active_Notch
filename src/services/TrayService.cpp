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
#include <QDir>
#include <QFile>
#include <QUrl>
#include <QtEndian>
#include <QCryptographicHash>
#include <functional>

namespace {

constexpr char kWatcherService[] = "org.kde.StatusNotifierWatcher";
constexpr char kWatcherPath[] = "/StatusNotifierWatcher";
constexpr char kWatcherInterface[] = "org.kde.StatusNotifierWatcher";

constexpr char kItemInterface[] = "org.kde.StatusNotifierItem";
constexpr char kMenuInterface[] = "com.canonical.dbusmenu";

constexpr int kRetryIntervalMs = 5000;
constexpr int kMaxRetries = 3;

// DBusMenu レイアウト項目のキー
constexpr char kMenuItemLabel[] = "label";
constexpr char kMenuItemEnabled[] = "enabled";
constexpr char kMenuItemVisible[] = "visible";
constexpr char kMenuItemType[] = "type";
constexpr char kMenuItemIconName[] = "icon-name";
constexpr char kMenuItemIconData[] = "icon-data";

// Watcher のシグナル値 "サービス名 + オブジェクトパス" を分割する。
// 例: ":1.95/StatusNotifierItem" -> {":1.95", "/StatusNotifierItem"}
bool splitSniId(const QString &id, QString *service, QString *path)
{
    const int slash = id.indexOf(QLatin1Char('/'));
    if (slash <= 0) {
        return false;
    }
    *service = id.left(slash);
    *path = id.mid(slash);
    return true;
}

// org.freedesktop.DBus.Properties.GetAll で a{sv} を一括取得する。
// QDBusInterface::property() は動的 metaobject 経由のため、a(iiay) や o を
// QDBusRawType として生成してしまい読めない。GetAll なら QVariantMap として
// demarshall でき、ネストした複合型も QDBusArgument として取り出せる。
QVariantMap getAllProperties(const QDBusConnection &bus, const QString &service,
                             const QString &path, const QString &iface)
{
    QDBusMessage msg = QDBusMessage::createMethodCall(
        service, path, QStringLiteral("org.freedesktop.DBus.Properties"),
        QStringLiteral("GetAll"));
    msg << iface;
    const QDBusMessage reply = bus.call(msg);
    if (reply.type() != QDBusMessage::ReplyMessage || reply.arguments().isEmpty()) {
        return {};
    }
    QVariant value = reply.arguments().at(0);
    if (value.userType() == qMetaTypeId<QDBusArgument>()) {
        return qdbus_cast<QVariantMap>(value);
    }
    return value.toMap();
}

// QImage をキャッシュディレクトリへ PNG 保存し file:// URL を返す。
// Qt 6.12 では Image.source の data: URL が全滅するため、トレイの
// IconPixmap は一時ファイル経由で渡す (内容ハッシュで重複排除)。
QString savePixmapToCache(const QImage &image)
{
    if (image.isNull()) {
        return QString();
    }
    const QByteArray png = [&image]() {
        QByteArray ba;
        QBuffer buffer(&ba);
        buffer.open(QIODevice::WriteOnly);
        image.save(&buffer, "PNG");
        return ba;
    }();
    if (png.isEmpty()) {
        return QString();
    }

    const QString dirPath = QStandardPaths::writableLocation(QStandardPaths::CacheLocation)
                            + QStringLiteral("/trayicons");
    QDir().mkpath(dirPath);
    const QString hash = QString::fromLatin1(
        QCryptographicHash::hash(png, QCryptographicHash::Sha1).toHex().left(20));
    const QString filePath = dirPath + QLatin1Char('/') + hash + QStringLiteral(".png");
    if (!QFile::exists(filePath)) {
        QFile file(filePath);
        if (!file.open(QIODevice::WriteOnly)) {
            return QString();
        }
        file.write(png);
    }
    return QUrl::fromLocalFile(filePath).toString();
}

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
    // org.kde.StatusNotifierWatcher に UnregisterHost は存在しない。
    // ホスト登録は接続断で watcher 側から自然に消えるため明示解除しない。
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

    // シグナル接続。実シグナルは 1 引数の QString で、
    // 値は "サービス名 + オブジェクトパス" の連結文字列。
    connect(m_watcherIface, SIGNAL(StatusNotifierItemRegistered(QString)),
            this, SLOT(onItemRegistered(QString)));
    connect(m_watcherIface, SIGNAL(StatusNotifierItemUnregistered(QString)),
            this, SLOT(onItemUnregistered(QString)));

    // ホスト登録。正しいメソッド名は RegisterStatusNotifierHost(s)。
    // Plasma の watcher は引数を無視するが、他実装との互換性のため
    // 自ホストのバス名を渡す。
    QDBusReply<void> reply =
        m_watcherIface->call("RegisterStatusNotifierHost", m_bus.baseService());
    if (!reply.isValid()) {
        qWarning() << "TrayService: RegisterStatusNotifierHost failed:" << reply.error().message();
        m_available = false;
        emit availableChanged();
        return;
    }

    qDebug() << "TrayService: Registered as StatusNotifierWatcher host";

    // 既存アイテム取得。RegisteredStatusNotifierItems は読み取り専用
    // プロパティ (as)。メソッド呼び出しではなく property() で読む。
    const QVariant registered = m_watcherIface->property("RegisteredStatusNotifierItems");
    for (const QString &id : registered.toStringList()) {
        onItemRegistered(id);
    }

    m_retryCount = 0;
    m_available = true;
    emit availableChanged();
}

void TrayService::onItemRegistered(const QString &serviceAndPath)
{
    QString service, path;
    if (!splitSniId(serviceAndPath, &service, &path)) {
        qWarning() << "TrayService: Invalid SNI id:" << serviceAndPath;
        return;
    }

    QString itemId = generateId(service, path);
    qDebug() << "TrayService: Item registered:" << itemId;

    if (m_itemMap.contains(itemId)) {
        return; // 既に処理済み
    }

    TrayItem item;
    item.id = itemId;
    item.service = service;
    item.objectPath = path;

    m_itemMap[itemId] = std::move(item);
    fetchItemProperties(service, path);
}

void TrayService::onItemUnregistered(const QString &serviceAndPath)
{
    QString service, path;
    if (!splitSniId(serviceAndPath, &service, &path)) {
        return;
    }
    QString itemId = generateId(service, path);
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

    // GetAll で a{sv} を一括取得する。property() は Menu (o) や
    // IconPixmap (a(iiay)) を QDBusRawType として生成して読めない。
    const QVariantMap props = getAllProperties(m_bus, service, objectPath,
                                               QString::fromLatin1(kItemInterface));
    item->title = props.value(QStringLiteral("Title")).toString();
    item->status = props.value(QStringLiteral("Status")).toString(); // "Passive", "Active", "NeedsAttention"
    item->iconName = props.value(QStringLiteral("IconName")).toString();
    item->iconPixmap = props.value(QStringLiteral("IconPixmap"));

    // Menu は D-Bus の 'o' (QDBusObjectPath)。toString() では空になる。
    const QVariant menuVar = props.value(QStringLiteral("Menu"));
    const QString menuPath = (menuVar.userType() == qMetaTypeId<QDBusObjectPath>())
        ? qvariant_cast<QDBusObjectPath>(menuVar).path()
        : menuVar.toString();

    // GetAll が失敗した場合のフォールバック (単純型のみ)
    if (props.isEmpty()) {
        item->title = itemIface.property("Title").toString();
        item->status = itemIface.property("Status").toString();
        item->iconName = itemIface.property("IconName").toString();
    }

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

    // シグナル接続。実シグネチャ:
    //   LayoutUpdated(u revision, i parentId)
    //   ItemsPropertiesUpdated(a(ia{sv}) updatedProps, a(ias) removedProps)
    // スロット側は引数を使わない (sender() でアイテムを特定)。
    connect(item->menuIface, SIGNAL(LayoutUpdated(uint,int)),
            this, SLOT(onMenuLayoutUpdated()));
    // a(ia{sv}) は QDBusInterface の動的 metaobject では型解決できず
    // SIGNAL(...) マクロが一致しない。署名文字列を明示する overload を使う。
    m_bus.connect(service, menuPath, QString::fromLatin1(kMenuInterface),
                  QStringLiteral("ItemsPropertiesUpdated"),
                  QStringLiteral("a(ia{sv})a(ias)"),
                  this, SLOT(onMenuPropertiesUpdated()));

    // レイアウト取得。GetLayout は out が 2 個 (u revision, (ia{sv}av) layout)
    // のため QDBusReply<T> では受け取れない。QDBusMessage で直接呼ぶ。
    refreshMenu(*item);
    qDebug() << "TrayService: Menu loaded for" << itemId
             << "with" << item->menuModel.size() << "root items";
}

void TrayService::onMenuLayoutUpdated()
{
    QDBusInterface *senderIface = qobject_cast<QDBusInterface*>(sender());
    if (!senderIface) return;

    // どのアイテムか特定
    for (auto &item : m_itemMap) {
        if (item.menuIface == senderIface) {
            refreshMenu(item);
            emit menuReady(item.id);
            break;
        }
    }
}

void TrayService::onMenuPropertiesUpdated()
{
    // QDBusConnection::connect の署名文字列 overload では sender() から
    // どのアイテムかを特定できない。アイテム数は少ないので全メニューを
    // 再取得する (プロパティ更新は頻度が低い)。
    for (auto &item : m_itemMap) {
        if (item.menuIface && !item.menuObjectPath.isEmpty()) {
            refreshMenu(item);
            emit menuReady(item.id);
        }
    }
}

void TrayService::refreshMenu(TrayItem &item)
{
    QDBusMessage msg = QDBusMessage::createMethodCall(
        item.service, item.menuObjectPath, QString::fromLatin1(kMenuInterface),
        QStringLiteral("GetLayout"));
    msg << 0 << -1 << QStringList();
    const QDBusMessage reply = m_bus.call(msg);
    if (reply.type() == QDBusMessage::ReplyMessage && reply.arguments().size() >= 2) {
        const QVariant layoutVar = reply.arguments().at(1);
        if (layoutVar.userType() == qMetaTypeId<QDBusArgument>()) {
            item.menuModel = buildMenuModel(qvariant_cast<QDBusArgument>(layoutVar));
        }
    }
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
    // DBusMenu GetLayout の第 2 戻り値は (ia{sv}av) の再帰構造。
    //   ノード = (id: i, properties: a{sv}, children: av)
    // 以前の実装は (i, i, a{ia{sv}}) を前提にしており実データと一致しなかった。
    std::function<QVariantMap(const QDBusArgument &)> parseNode =
        [&](const QDBusArgument &nodeArg) -> QVariantMap {
            // 重要: 読み取りモードを使うには const でなければならない。
            // 非 const だと書き込み用 beginStructure() が選ばれ、
            // read-only の QDBusArgument へ書き込もうとして abort する。
            const QDBusArgument arg = nodeArg;
            arg.beginStructure();
            int id = 0;
            QVariantMap props;
            QVariantList children;
            arg >> id >> props >> children;
            arg.endStructure();

            QVariantMap node;
            node["id"] = QString::number(id);
            QString label = props.value(QLatin1String(kMenuItemLabel)).toString();
            label.remove(QLatin1Char('&')); // ニーモニック (&) を除去
            node["label"] = label;
            node["enabled"] = props.value(QLatin1String(kMenuItemEnabled), true).toBool();
            node["visible"] = props.value(QLatin1String(kMenuItemVisible), true).toBool();
            node["type"] = props.value(QLatin1String(kMenuItemType),
                                       QStringLiteral("standard")).toString();

            QString iconSource = iconToSource(props.value(QLatin1String(kMenuItemIconData)));
            if (iconSource.isEmpty()) {
                const QString iconName = props.value(QLatin1String(kMenuItemIconName)).toString();
                if (!iconName.isEmpty()) {
                    iconSource = "image://theme/" + iconName;
                }
            }
            node["iconSource"] = iconSource;

            QVariantList childNodes;
            for (const QVariant &child : children) {
                if (child.userType() == qMetaTypeId<QDBusArgument>()) {
                    childNodes.append(parseNode(qvariant_cast<QDBusArgument>(child)));
                } else if (child.canConvert<QVariantMap>()) {
                    childNodes.append(child.toMap());
                }
            }
            if (!childNodes.isEmpty()) {
                node["children"] = childNodes;
            }
            return node;
        };

    const QVariantMap root = parseNode(layoutData);
    // ルート自身 (id=0) は表示せず、子だけをトップレベルとして返す。
    QVariantList result = root.value(QStringLiteral("children")).toList();
    if (result.isEmpty() && !root.isEmpty()) {
        result.append(root);
    }
    return result;
}

QString TrayService::iconToSource(const QVariant &iconData)
{
    // SNI の IconPixmap は a(iiay) 形式: [(width, height, data), ...]
    // data は ARGB32 のネットワークバイトオーダー。
    // 以前の実装は (iiibiiay) を想定しており実データと一致しなかった。
    if (!iconData.isValid()) {
        return QString();
    }

    // 複数アイコンの配列 (QVariantList) は先頭の有効なものを使う。
    if (iconData.typeId() == QMetaType::QVariantList) {
        const QVariantList list = iconData.toList();
        for (const QVariant &entry : list) {
            const QString source = iconToSource(entry);
            if (!source.isEmpty()) {
                return source;
            }
        }
        return QString();
    }

    if (iconData.userType() != qMetaTypeId<QDBusArgument>()) {
        return QString();
    }

    // 読み取りモードを使うため const。非 const だと書き込み用 overload になる。
    const QDBusArgument arg = qvariant_cast<QDBusArgument>(iconData);
    // 書き込みモードの構造体など、配列でないものは無効として扱う。
    if (arg.currentType() != QDBusArgument::ArrayType) {
        return QString();
    }

    arg.beginArray();
    while (!arg.atEnd()) {
        if (arg.currentType() != QDBusArgument::StructureType) {
            // ay (DBusMenu icon-data) などは未対応。icon-name へフォールバック。
            break;
        }
        arg.beginStructure();
        int width = 0;
        int height = 0;
        QByteArray data;
        arg >> width >> height >> data;
        arg.endStructure();

        if (width <= 0 || height <= 0 || data.size() < width * height * 4) {
            continue;
        }

        // ネットワークバイトオーダー (ARGB) → ホストの ARGB32 へ変換。
        QImage image(width, height, QImage::Format_ARGB32);
        const uchar *src = reinterpret_cast<const uchar *>(data.constData());
        for (int y = 0; y < height; ++y) {
            QRgb *dst = reinterpret_cast<QRgb *>(image.scanLine(y));
            const uchar *row = src + y * width * 4;
            for (int x = 0; x < width; ++x) {
                dst[x] = qFromBigEndian<quint32>(row + x * 4);
            }
        }
        arg.endArray();
        // Qt 6.12 では data: URL が使えないためキャッシュファイル経由で返す。
        return savePixmapToCache(image);
    }
    arg.endArray();

    return QString();
}