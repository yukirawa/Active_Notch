#include "ConfigService.h"

#include <KConfig>
#include <KConfigGroup>
#include <QColor>
#include <QDebug>
#include <QRegularExpression>
#include <QStandardPaths>

namespace {

// キー名定数
constexpr char kGroupGeneral[] = "General";
constexpr char kGroupGeometry[] = "Geometry";
constexpr char kGroupTheme[] = "Theme";
constexpr char kGroupBehavior[] = "Behavior";
constexpr char kGroupIntervals[] = "Intervals";
constexpr char kGroupMeta[] = "Meta";

// デフォルト値 (PLAN §11 準拠)
constexpr char kDefLanguage[] = "ja";
constexpr char kDefAnchor[] = "top";
constexpr bool kDefAutoHideFullscreen = true;
constexpr int kDefCollapsedWidth = 220;
constexpr int kDefCollapsedHeight = 30;
constexpr int kDefExpandedWidth = 660;
constexpr int kDefExpandedHeight = 440;
constexpr int kDefRadiusCollapsed = 16;
constexpr int kDefRadiusExpanded = 28;
constexpr char kDefAccentColor[] = "#7FB8B0";
constexpr qreal kDefOpacity = 0.72;
constexpr bool kDefBlurEnabled = true;
constexpr bool kDefDnd = false;
constexpr char kDefEnabledPages[] = "media,stats,battery,sound,calendar,notifications,network,weather,quick,clipboard,launcher,tray";
constexpr char kDefWeatherLocation[] = "auto";
constexpr char kDefWeatherUnit[] = "metric";
constexpr bool kDefOwnDaemon = true;
constexpr bool kDefDoNotDisturb = false;
constexpr int kDefMaxHistory = 100;
constexpr int kDefStatsInterval = 1000;
constexpr int kDefBatteryInterval = 30000;
constexpr int kDefWeatherInterval = 900000;

// 検証用の制限値
constexpr int kMinCollapsedWidth = 100;
constexpr int kMaxCollapsedWidth = 800;
constexpr int kMinCollapsedHeight = 20;
constexpr int kMaxCollapsedHeight = 100;
constexpr int kMinExpandedWidth = 300;
constexpr int kMaxExpandedWidth = 1200;
constexpr int kMinExpandedHeight = 200;
constexpr int kMaxExpandedHeight = 800;
constexpr int kMinRadius = 0;
constexpr int kMaxRadius = 100;
constexpr qreal kMinOpacity = 0.1;
constexpr qreal kMaxOpacity = 1.0;
constexpr int kMinInterval = 100;       // 100ms minimum
constexpr int kMaxInterval = 3600000;   // 1 hour maximum

} // namespace

class ConfigService::Private
{
public:
    explicit Private(ConfigService *q) : q_ptr(q) {}

    KConfig config{QStandardPaths::writableLocation(QStandardPaths::ConfigLocation) + "/activenotch/activenotchrc",
                   KConfig::SimpleConfig};

    ConfigService *q_ptr;

    // キャッシュ
    QString m_language = kDefLanguage;
    QString m_anchor = kDefAnchor;
    bool m_autoHideFullscreen = kDefAutoHideFullscreen;
    int m_collapsedWidth = kDefCollapsedWidth;
    int m_collapsedHeight = kDefCollapsedHeight;
    int m_expandedWidth = kDefExpandedWidth;
    int m_expandedHeight = kDefExpandedHeight;
    int m_radiusCollapsed = kDefRadiusCollapsed;
    int m_radiusExpanded = kDefRadiusExpanded;
    QColor m_accentColor = QColor(kDefAccentColor);
    qreal m_opacity = kDefOpacity;
    bool m_blurEnabled = kDefBlurEnabled;
    bool m_dnd = kDefDnd;
    QString m_enabledPages = kDefEnabledPages;
    QString m_weatherLocation = kDefWeatherLocation;
    QString m_weatherUnit = kDefWeatherUnit;
    bool m_ownDaemon = kDefOwnDaemon;
    bool m_doNotDisturb = kDefDoNotDisturb;
    int m_maxHistory = kDefMaxHistory;
    int m_statsInterval = kDefStatsInterval;
    int m_batteryInterval = kDefBatteryInterval;
    int m_weatherInterval = kDefWeatherInterval;
    int m_schemaVersion = ConfigService::CurrentSchemaVersion;

    // 汎用セッタ
    template <typename T>
    bool setIfChanged(T &field, const T &value, const char *signal)
    {
        if (field == value) return false;
        field = value;
        QMetaObject::invokeMethod(q_ptr, signal, Qt::DirectConnection);
        QMetaObject::invokeMethod(q_ptr, "configChanged", Qt::DirectConnection);
        return true;
    }

    void loadAll()
    {
        KConfigGroup g = config.group(kGroupMeta);
        m_schemaVersion = g.readEntry("SchemaVersion", 0);

        g = config.group(kGroupGeneral);
        m_language = clampLanguage(g.readEntry("Language", kDefLanguage));
        m_anchor = clampAnchor(g.readEntry("Anchor", kDefAnchor));
        m_autoHideFullscreen = g.readEntry("AutoHideFullscreen", kDefAutoHideFullscreen);

        g = config.group(kGroupGeometry);
        m_collapsedWidth = clampGeometry(g.readEntry("CollapsedWidth", kDefCollapsedWidth), kMinCollapsedWidth, kMaxCollapsedWidth, kDefCollapsedWidth);
        m_collapsedHeight = clampGeometry(g.readEntry("CollapsedHeight", kDefCollapsedHeight), kMinCollapsedHeight, kMaxCollapsedHeight, kDefCollapsedHeight);
        m_expandedWidth = clampGeometry(g.readEntry("ExpandedWidth", kDefExpandedWidth), kMinExpandedWidth, kMaxExpandedWidth, kDefExpandedWidth);
        m_expandedHeight = clampGeometry(g.readEntry("ExpandedHeight", kDefExpandedHeight), kMinExpandedHeight, kMaxExpandedHeight, kDefExpandedHeight);
        m_radiusCollapsed = clampGeometry(g.readEntry("CornerRadiusCollapsed", kDefRadiusCollapsed), kMinRadius, kMaxRadius, kDefRadiusCollapsed);
        m_radiusExpanded = clampGeometry(g.readEntry("CornerRadiusExpanded", kDefRadiusExpanded), kMinRadius, kMaxRadius, kDefRadiusExpanded);

        g = config.group(kGroupTheme);
        m_accentColor = QColor(g.readEntry("AccentColor", kDefAccentColor));
        if (!m_accentColor.isValid()) m_accentColor = QColor(kDefAccentColor);
        m_opacity = clampOpacity(g.readEntry("Opacity", kDefOpacity));
        m_blurEnabled = g.readEntry("BlurEnabled", kDefBlurEnabled);

        g = config.group(kGroupBehavior);
        m_dnd = g.readEntry("Dnd", kDefDnd);
        m_enabledPages = g.readEntry("EnabledPages", kDefEnabledPages);
        m_weatherLocation = g.readEntry("WeatherLocation", kDefWeatherLocation);
        m_weatherUnit = clampWeatherUnit(g.readEntry("WeatherUnit", kDefWeatherUnit));
        m_ownDaemon = g.readEntry("OwnDaemon", kDefOwnDaemon);
        m_doNotDisturb = g.readEntry("DoNotDisturb", kDefDoNotDisturb);
        m_maxHistory = clampGeometry(g.readEntry("MaxHistory", kDefMaxHistory), 10, 1000, kDefMaxHistory);

        g = config.group(kGroupIntervals);
        m_statsInterval = clampInterval(g.readEntry("StatsInterval", kDefStatsInterval), kMinInterval, kDefStatsInterval);
        m_batteryInterval = clampInterval(g.readEntry("BatteryInterval", kDefBatteryInterval), kMinInterval, kDefBatteryInterval);
        m_weatherInterval = clampInterval(g.readEntry("WeatherInterval", kDefWeatherInterval), kMinInterval, kDefWeatherInterval);

        // マイグレーション (将来用)
        if (m_schemaVersion < ConfigService::CurrentSchemaVersion) {
            migrate(m_schemaVersion);
            m_schemaVersion = ConfigService::CurrentSchemaVersion;
        }
    }

    void saveAll()
    {
        KConfigGroup g = config.group(kGroupMeta);
        g.writeEntry("SchemaVersion", ConfigService::CurrentSchemaVersion);

        g = config.group(kGroupGeneral);
        g.writeEntry("Language", m_language);
        g.writeEntry("Anchor", m_anchor);
        g.writeEntry("AutoHideFullscreen", m_autoHideFullscreen);

        g = config.group(kGroupGeometry);
        g.writeEntry("CollapsedWidth", m_collapsedWidth);
        g.writeEntry("CollapsedHeight", m_collapsedHeight);
        g.writeEntry("ExpandedWidth", m_expandedWidth);
        g.writeEntry("ExpandedHeight", m_expandedHeight);
        g.writeEntry("CornerRadiusCollapsed", m_radiusCollapsed);
        g.writeEntry("CornerRadiusExpanded", m_radiusExpanded);

        g = config.group(kGroupTheme);
        g.writeEntry("AccentColor", m_accentColor.name(QColor::HexArgb));
        g.writeEntry("Opacity", m_opacity);
        g.writeEntry("BlurEnabled", m_blurEnabled);

        g = config.group(kGroupBehavior);
        g.writeEntry("Dnd", m_dnd);
        g.writeEntry("EnabledPages", m_enabledPages);
        g.writeEntry("WeatherLocation", m_weatherLocation);
        g.writeEntry("WeatherUnit", m_weatherUnit);
        g.writeEntry("OwnDaemon", m_ownDaemon);
        g.writeEntry("DoNotDisturb", m_doNotDisturb);
        g.writeEntry("MaxHistory", m_maxHistory);

        g = config.group(kGroupIntervals);
        g.writeEntry("StatsInterval", m_statsInterval);
        g.writeEntry("BatteryInterval", m_batteryInterval);
        g.writeEntry("WeatherInterval", m_weatherInterval);

        config.sync();
    }

    void migrate(int fromVersion)
    {
        Q_UNUSED(fromVersion);
        // 将来のスキーママイグレーションロジックをここに追加
        // 例: fromVersion == 1 -> v2 への変換
        qDebug() << "ConfigService: Migrating schema from version" << fromVersion << "to" << ConfigService::CurrentSchemaVersion;
    }

    void resetToDefaults()
    {
        m_language = kDefLanguage;
        m_anchor = kDefAnchor;
        m_autoHideFullscreen = kDefAutoHideFullscreen;
        m_collapsedWidth = kDefCollapsedWidth;
        m_collapsedHeight = kDefCollapsedHeight;
        m_expandedWidth = kDefExpandedWidth;
        m_expandedHeight = kDefExpandedHeight;
        m_radiusCollapsed = kDefRadiusCollapsed;
        m_radiusExpanded = kDefRadiusExpanded;
        m_accentColor = QColor(kDefAccentColor);
        m_opacity = kDefOpacity;
        m_blurEnabled = kDefBlurEnabled;
        m_dnd = kDefDnd;
        m_enabledPages = kDefEnabledPages;
        m_weatherLocation = kDefWeatherLocation;
        m_weatherUnit = kDefWeatherUnit;
        m_ownDaemon = kDefOwnDaemon;
        m_doNotDisturb = kDefDoNotDisturb;
        m_maxHistory = kDefMaxHistory;
        m_statsInterval = kDefStatsInterval;
        m_batteryInterval = kDefBatteryInterval;
        m_weatherInterval = kDefWeatherInterval;
        m_schemaVersion = ConfigService::CurrentSchemaVersion;
    }

    // 検証・クランプ用静的関数 (テスト可能)
    static int clampGeometry(int value, int min, int max, int defaultValue)
    {
        if (value < min || value > max) {
            qWarning() << "ConfigService: Geometry value" << value << "out of range [" << min << "," << max << "], using default" << defaultValue;
            return defaultValue;
        }
        return value;
    }

    static qreal clampOpacity(qreal value)
    {
        if (value < kMinOpacity || value > kMaxOpacity || qIsNaN(value)) {
            qWarning() << "ConfigService: Opacity value" << value << "out of range [" << kMinOpacity << "," << kMaxOpacity << "], using default" << kDefOpacity;
            return kDefOpacity;
        }
        return value;
    }

    static QString clampAnchor(const QString &value)
    {
        static const QStringList validAnchors = {"top", "top-left", "top-right"};
        if (!validAnchors.contains(value)) {
            qWarning() << "ConfigService: Invalid anchor" << value << ", using default" << kDefAnchor;
            return kDefAnchor;
        }
        return value;
    }

    static QString clampLanguage(const QString &value)
    {
        // 言語コード: "ja", "en", "ja_JP", "en_US" など
        if (value.isEmpty()) {
            qWarning() << "ConfigService: Empty language, using default" << kDefLanguage;
            return kDefLanguage;
        }
        // 基本的な形式チェック (2-5文字のアルファベット/アンダースコア)
        static const QRegularExpression langRe("^[a-z]{2}(_[A-Z]{2})?$");
        if (!langRe.match(value).hasMatch()) {
            qWarning() << "ConfigService: Invalid language code" << value << ", using default" << kDefLanguage;
            return kDefLanguage;
        }
        return value;
    }

    static QString clampWeatherUnit(const QString &value)
    {
        if (value != "metric" && value != "imperial") {
            qWarning() << "ConfigService: Invalid weather unit" << value << ", using default" << kDefWeatherUnit;
            return kDefWeatherUnit;
        }
        return value;
    }

    static int clampInterval(int value, int min, int defaultValue)
    {
        if (value < min || value > kMaxInterval) {
            qWarning() << "ConfigService: Interval value" << value << "out of range [" << min << "," << kMaxInterval << "], using default" << defaultValue;
            return defaultValue;
        }
        return value;
    }
};

ConfigService::ConfigService(QObject *parent)
    : QObject(parent), d(std::make_unique<Private>(this))
{
    d->loadAll();
}

void ConfigService::setLanguage(const QString &v)
{
    const QString clamped = Private::clampLanguage(v);
    if (d->setIfChanged(d->m_language, clamped, "languageChanged")) {}
}

void ConfigService::setAnchor(const QString &v)
{
    const QString clamped = Private::clampAnchor(v);
    if (d->setIfChanged(d->m_anchor, clamped, "anchorChanged")) {}
}

void ConfigService::setAutoHideFullscreen(bool v)
{
    if (d->setIfChanged(d->m_autoHideFullscreen, v, "autoHideFullscreenChanged")) {}
}

void ConfigService::setCollapsedWidth(int v)
{
    const int clamped = Private::clampGeometry(v, kMinCollapsedWidth, kMaxCollapsedWidth, kDefCollapsedWidth);
    if (d->setIfChanged(d->m_collapsedWidth, clamped, "collapsedWidthChanged")) {}
}

void ConfigService::setCollapsedHeight(int v)
{
    const int clamped = Private::clampGeometry(v, kMinCollapsedHeight, kMaxCollapsedHeight, kDefCollapsedHeight);
    if (d->setIfChanged(d->m_collapsedHeight, clamped, "collapsedHeightChanged")) {}
}

void ConfigService::setExpandedWidth(int v)
{
    const int clamped = Private::clampGeometry(v, kMinExpandedWidth, kMaxExpandedWidth, kDefExpandedWidth);
    if (d->setIfChanged(d->m_expandedWidth, clamped, "expandedWidthChanged")) {}
}

void ConfigService::setExpandedHeight(int v)
{
    const int clamped = Private::clampGeometry(v, kMinExpandedHeight, kMaxExpandedHeight, kDefExpandedHeight);
    if (d->setIfChanged(d->m_expandedHeight, clamped, "expandedHeightChanged")) {}
}

void ConfigService::setRadiusCollapsed(int v)
{
    const int clamped = Private::clampGeometry(v, kMinRadius, kMaxRadius, kDefRadiusCollapsed);
    if (d->setIfChanged(d->m_radiusCollapsed, clamped, "radiusCollapsedChanged")) {}
}

void ConfigService::setRadiusExpanded(int v)
{
    const int clamped = Private::clampGeometry(v, kMinRadius, kMaxRadius, kDefRadiusExpanded);
    if (d->setIfChanged(d->m_radiusExpanded, clamped, "radiusExpandedChanged")) {}
}

void ConfigService::setAccentColor(const QColor &v)
{
    if (d->setIfChanged(d->m_accentColor, v.isValid() ? v : QColor(kDefAccentColor), "accentColorChanged")) {}
}

void ConfigService::setOpacity(qreal v)
{
    const qreal clamped = Private::clampOpacity(v);
    if (d->setIfChanged(d->m_opacity, clamped, "opacityChanged")) {}
}

void ConfigService::setBlurEnabled(bool v)
{
    if (d->setIfChanged(d->m_blurEnabled, v, "blurEnabledChanged")) {}
}

void ConfigService::setDnd(bool v)
{
    if (d->setIfChanged(d->m_dnd, v, "dndChanged")) {}
}

void ConfigService::setEnabledPages(const QString &v)
{
    if (d->setIfChanged(d->m_enabledPages, v, "enabledPagesChanged")) {}
}

void ConfigService::setWeatherLocation(const QString &v)
{
    if (d->setIfChanged(d->m_weatherLocation, v, "weatherLocationChanged")) {}
}

void ConfigService::setWeatherUnit(const QString &v)
{
    const QString clamped = Private::clampWeatherUnit(v);
    if (d->setIfChanged(d->m_weatherUnit, clamped, "weatherUnitChanged")) {}
}

void ConfigService::setOwnDaemon(bool v)
{
    if (d->setIfChanged(d->m_ownDaemon, v, "ownDaemonChanged")) {}
}

void ConfigService::setDoNotDisturb(bool v)
{
    if (d->setIfChanged(d->m_doNotDisturb, v, "doNotDisturbChanged")) {}
}

void ConfigService::setMaxHistory(int v)
{
    const int clamped = Private::clampGeometry(v, 10, 1000, kDefMaxHistory);
    if (d->setIfChanged(d->m_maxHistory, clamped, "maxHistoryChanged")) {}
}

void ConfigService::setStatsInterval(int v)
{
    const int clamped = Private::clampInterval(v, kMinInterval, kDefStatsInterval);
    if (d->setIfChanged(d->m_statsInterval, clamped, "statsIntervalChanged")) {}
}

void ConfigService::setBatteryInterval(int v)
{
    const int clamped = Private::clampInterval(v, kMinInterval, kDefBatteryInterval);
    if (d->setIfChanged(d->m_batteryInterval, clamped, "batteryIntervalChanged")) {}
}

void ConfigService::setWeatherInterval(int v)
{
    const int clamped = Private::clampInterval(v, kMinInterval, kDefWeatherInterval);
    if (d->setIfChanged(d->m_weatherInterval, clamped, "weatherIntervalChanged")) {}
}

QString ConfigService::language() const { return d->m_language; }
QString ConfigService::anchor() const { return d->m_anchor; }
bool ConfigService::autoHideFullscreen() const { return d->m_autoHideFullscreen; }
int ConfigService::collapsedWidth() const { return d->m_collapsedWidth; }
int ConfigService::collapsedHeight() const { return d->m_collapsedHeight; }
int ConfigService::expandedWidth() const { return d->m_expandedWidth; }
int ConfigService::expandedHeight() const { return d->m_expandedHeight; }
int ConfigService::radiusCollapsed() const { return d->m_radiusCollapsed; }
int ConfigService::radiusExpanded() const { return d->m_radiusExpanded; }
QColor ConfigService::accentColor() const { return d->m_accentColor; }
qreal ConfigService::opacity() const { return d->m_opacity; }
bool ConfigService::blurEnabled() const { return d->m_blurEnabled; }
bool ConfigService::dnd() const { return d->m_dnd; }
QString ConfigService::enabledPages() const { return d->m_enabledPages; }
QString ConfigService::weatherLocation() const { return d->m_weatherLocation; }
QString ConfigService::weatherUnit() const { return d->m_weatherUnit; }
bool ConfigService::ownDaemon() const { return d->m_ownDaemon; }
bool ConfigService::doNotDisturb() const { return d->m_doNotDisturb; }
int ConfigService::maxHistory() const { return d->m_maxHistory; }
int ConfigService::statsInterval() const { return d->m_statsInterval; }
int ConfigService::batteryInterval() const { return d->m_batteryInterval; }
int ConfigService::weatherInterval() const { return d->m_weatherInterval; }

void ConfigService::save() { d->saveAll(); }
void ConfigService::load() { d->loadAll(); }
void ConfigService::resetToDefaults() { d->resetToDefaults(); }

int ConfigService::schemaVersion() const { return d->m_schemaVersion; }

// 静的検証関数 (単体テスト用)
int ConfigService::clampGeometry(int value, int min, int max, int defaultValue)
{
    return Private::clampGeometry(value, min, max, defaultValue);
}

qreal ConfigService::clampOpacity(qreal value)
{
    return Private::clampOpacity(value);
}

QString ConfigService::clampAnchor(const QString &value)
{
    return Private::clampAnchor(value);
}

QString ConfigService::clampLanguage(const QString &value)
{
    return Private::clampLanguage(value);
}

QString ConfigService::clampWeatherUnit(const QString &value)
{
    return Private::clampWeatherUnit(value);
}

int ConfigService::clampInterval(int value, int min, int defaultValue)
{
    return Private::clampInterval(value, min, defaultValue);
}

ConfigService::~ConfigService() = default;