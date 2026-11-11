#include "ConfigService.h"

#include <KConfig>
#include <KConfigGroup>
#include <QColor>
#include <QDebug>
#include <QStandardPaths>

namespace {

// キー名定数
constexpr char kGroupGeneral[] = "General";
constexpr char kGroupGeometry[] = "Geometry";
constexpr char kGroupTheme[] = "Theme";
constexpr char kGroupBehavior[] = "Behavior";
constexpr char kGroupIntervals[] = "Intervals";

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

    // 汎用セッタ
    template <typename T>
    bool setIfChanged(T &field, const T &value, const char *signal)
    {
        if (field == value) return false;
        field = value;
        QMetaObject::invokeMethod(q_ptr, signal, Qt::DirectConnection);
        return true;
    }

    void loadAll()
    {
        KConfigGroup g = config.group(kGroupGeneral);
        m_language = g.readEntry("Language", kDefLanguage);
        m_anchor = g.readEntry("Anchor", kDefAnchor);
        m_autoHideFullscreen = g.readEntry("AutoHideFullscreen", kDefAutoHideFullscreen);

        g = config.group(kGroupGeometry);
        m_collapsedWidth = g.readEntry("CollapsedWidth", kDefCollapsedWidth);
        m_collapsedHeight = g.readEntry("CollapsedHeight", kDefCollapsedHeight);
        m_expandedWidth = g.readEntry("ExpandedWidth", kDefExpandedWidth);
        m_expandedHeight = g.readEntry("ExpandedHeight", kDefExpandedHeight);
        m_radiusCollapsed = g.readEntry("CornerRadiusCollapsed", kDefRadiusCollapsed);
        m_radiusExpanded = g.readEntry("CornerRadiusExpanded", kDefRadiusExpanded);

        g = config.group(kGroupTheme);
        m_accentColor = g.readEntry("AccentColor", kDefAccentColor);
        m_opacity = g.readEntry("Opacity", kDefOpacity);
        m_blurEnabled = g.readEntry("BlurEnabled", kDefBlurEnabled);

        g = config.group(kGroupBehavior);
        m_dnd = g.readEntry("Dnd", kDefDnd);
        m_enabledPages = g.readEntry("EnabledPages", kDefEnabledPages);
        m_weatherLocation = g.readEntry("WeatherLocation", kDefWeatherLocation);
        m_weatherUnit = g.readEntry("WeatherUnit", kDefWeatherUnit);
        m_ownDaemon = g.readEntry("OwnDaemon", kDefOwnDaemon);
        m_doNotDisturb = g.readEntry("DoNotDisturb", kDefDoNotDisturb);
        m_maxHistory = g.readEntry("MaxHistory", kDefMaxHistory);

        g = config.group(kGroupIntervals);
        m_statsInterval = g.readEntry("StatsInterval", kDefStatsInterval);
        m_batteryInterval = g.readEntry("BatteryInterval", kDefBatteryInterval);
        m_weatherInterval = g.readEntry("WeatherInterval", kDefWeatherInterval);
    }

    void saveAll()
    {
        KConfigGroup g = config.group(kGroupGeneral);
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
    }
};

ConfigService::ConfigService(QObject *parent)
    : QObject(parent), d(std::make_unique<Private>(this))
{
    d->loadAll();
}

void ConfigService::setLanguage(const QString &v) { if (d->setIfChanged(d->m_language, v, "languageChanged")) {} }
void ConfigService::setAnchor(const QString &v) { if (d->setIfChanged(d->m_anchor, v, "anchorChanged")) {} }
void ConfigService::setAutoHideFullscreen(bool v) { if (d->setIfChanged(d->m_autoHideFullscreen, v, "autoHideFullscreenChanged")) {} }
void ConfigService::setCollapsedWidth(int v) { if (d->setIfChanged(d->m_collapsedWidth, v, "collapsedWidthChanged")) {} }
void ConfigService::setCollapsedHeight(int v) { if (d->setIfChanged(d->m_collapsedHeight, v, "collapsedHeightChanged")) {} }
void ConfigService::setExpandedWidth(int v) { if (d->setIfChanged(d->m_expandedWidth, v, "expandedWidthChanged")) {} }
void ConfigService::setExpandedHeight(int v) { if (d->setIfChanged(d->m_expandedHeight, v, "expandedHeightChanged")) {} }
void ConfigService::setRadiusCollapsed(int v) { if (d->setIfChanged(d->m_radiusCollapsed, v, "radiusCollapsedChanged")) {} }
void ConfigService::setRadiusExpanded(int v) { if (d->setIfChanged(d->m_radiusExpanded, v, "radiusExpandedChanged")) {} }
void ConfigService::setAccentColor(const QColor &v) { if (d->setIfChanged(d->m_accentColor, v, "accentColorChanged")) {} }
void ConfigService::setOpacity(qreal v) { if (d->setIfChanged(d->m_opacity, v, "opacityChanged")) {} }
void ConfigService::setBlurEnabled(bool v) { if (d->setIfChanged(d->m_blurEnabled, v, "blurEnabledChanged")) {} }
void ConfigService::setDnd(bool v) { if (d->setIfChanged(d->m_dnd, v, "dndChanged")) {} }
void ConfigService::setEnabledPages(const QString &v) { if (d->setIfChanged(d->m_enabledPages, v, "enabledPagesChanged")) {} }
void ConfigService::setWeatherLocation(const QString &v) { if (d->setIfChanged(d->m_weatherLocation, v, "weatherLocationChanged")) {} }
void ConfigService::setWeatherUnit(const QString &v) { if (d->setIfChanged(d->m_weatherUnit, v, "weatherUnitChanged")) {} }
void ConfigService::setOwnDaemon(bool v) { if (d->setIfChanged(d->m_ownDaemon, v, "ownDaemonChanged")) {} }
void ConfigService::setDoNotDisturb(bool v) { if (d->setIfChanged(d->m_doNotDisturb, v, "doNotDisturbChanged")) {} }
void ConfigService::setMaxHistory(int v) { if (d->setIfChanged(d->m_maxHistory, v, "maxHistoryChanged")) {} }
void ConfigService::setStatsInterval(int v) { if (d->setIfChanged(d->m_statsInterval, v, "statsIntervalChanged")) {} }
void ConfigService::setBatteryInterval(int v) { if (d->setIfChanged(d->m_batteryInterval, v, "batteryIntervalChanged")) {} }
void ConfigService::setWeatherInterval(int v) { if (d->setIfChanged(d->m_weatherInterval, v, "weatherIntervalChanged")) {} }

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

ConfigService::~ConfigService() = default;