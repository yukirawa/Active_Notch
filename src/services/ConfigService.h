#pragma once

#include <QObject>
#include <QColor>
#include <QLocale>

/**
 * ActiveNotch 設定サービス (KConfig ベース)。
 *
 * 設定ファイル: ~/.config/activenotch/activenotchrc
 * スキーマは PLAN.md §11 準拠。
 * すべてのプロパティは Q_PROPERTY + NOTIFY で QML に公開する。
 *
 * 変更時の即時反映:
 *   - ジオメトリ/テーマ/動作: NotchWindow および各サービスへ自動適用
 *   - 言語: QTranslator 再インストール
 *   - インターバル: 各サービスのタイマー更新
 */
class ConfigService : public QObject
{
    Q_OBJECT
    // --- General -----------------------------------------------------------
    Q_PROPERTY(QString language READ language WRITE setLanguage NOTIFY languageChanged)
    Q_PROPERTY(QString anchor READ anchor WRITE setAnchor NOTIFY anchorChanged)              // "top" | "top-left" | "top-right"
    Q_PROPERTY(bool autoHideFullscreen READ autoHideFullscreen WRITE setAutoHideFullscreen NOTIFY autoHideFullscreenChanged)
    // --- Geometry ----------------------------------------------------------
    Q_PROPERTY(int collapsedWidth READ collapsedWidth WRITE setCollapsedWidth NOTIFY collapsedWidthChanged)
    Q_PROPERTY(int collapsedHeight READ collapsedHeight WRITE setCollapsedHeight NOTIFY collapsedHeightChanged)
    Q_PROPERTY(int expandedWidth READ expandedWidth WRITE setExpandedWidth NOTIFY expandedWidthChanged)
    Q_PROPERTY(int expandedHeight READ expandedHeight WRITE setExpandedHeight NOTIFY expandedHeightChanged)
    Q_PROPERTY(int radiusCollapsed READ radiusCollapsed WRITE setRadiusCollapsed NOTIFY radiusCollapsedChanged)
    Q_PROPERTY(int radiusExpanded READ radiusExpanded WRITE setRadiusExpanded NOTIFY radiusExpandedChanged)
    // --- Theme -------------------------------------------------------------
    Q_PROPERTY(QColor accentColor READ accentColor WRITE setAccentColor NOTIFY accentColorChanged)
    Q_PROPERTY(qreal opacity READ opacity WRITE setOpacity NOTIFY opacityChanged)             // 0.0-1.0
    Q_PROPERTY(bool blurEnabled READ blurEnabled WRITE setBlurEnabled NOTIFY blurEnabledChanged)
    // --- Behavior ----------------------------------------------------------
    Q_PROPERTY(bool dnd READ dnd WRITE setDnd NOTIFY dndChanged)
    Q_PROPERTY(QString enabledPages READ enabledPages WRITE setEnabledPages NOTIFY enabledPagesChanged) // カンマ区切り
    Q_PROPERTY(QString weatherLocation READ weatherLocation WRITE setWeatherLocation NOTIFY weatherLocationChanged) // "auto" | "lat,lon"
    Q_PROPERTY(QString weatherUnit READ weatherUnit WRITE setWeatherUnit NOTIFY weatherUnitChanged) // "metric" | "imperial"
    Q_PROPERTY(bool ownDaemon READ ownDaemon WRITE setOwnDaemon NOTIFY ownDaemonChanged) // 通知デーモン自前運用
    Q_PROPERTY(bool doNotDisturb READ doNotDisturb WRITE setDoNotDisturb NOTIFY doNotDisturbChanged)
    Q_PROPERTY(int maxHistory READ maxHistory WRITE setMaxHistory NOTIFY maxHistoryChanged) // 通知履歴最大件数
    // --- Intervals (ms) ----------------------------------------------------
    Q_PROPERTY(int statsInterval READ statsInterval WRITE setStatsInterval NOTIFY statsIntervalChanged)
    Q_PROPERTY(int batteryInterval READ batteryInterval WRITE setBatteryInterval NOTIFY batteryIntervalChanged)
    Q_PROPERTY(int weatherInterval READ weatherInterval WRITE setWeatherInterval NOTIFY weatherIntervalChanged)

public:
    explicit ConfigService(QObject *parent = nullptr);
    ~ConfigService() override;

    ConfigService(const ConfigService &) = delete;
    ConfigService &operator=(const ConfigService &) = delete;

    // --- General -----------------------------------------------------------
    QString language() const;
    void setLanguage(const QString &v);
    QString anchor() const;
    void setAnchor(const QString &v);
    bool autoHideFullscreen() const;
    void setAutoHideFullscreen(bool v);
    // --- Geometry ----------------------------------------------------------
    int collapsedWidth() const;
    void setCollapsedWidth(int v);
    int collapsedHeight() const;
    void setCollapsedHeight(int v);
    int expandedWidth() const;
    void setExpandedWidth(int v);
    int expandedHeight() const;
    void setExpandedHeight(int v);
    int radiusCollapsed() const;
    void setRadiusCollapsed(int v);
    int radiusExpanded() const;
    void setRadiusExpanded(int v);
    // --- Theme -------------------------------------------------------------
    QColor accentColor() const;
    void setAccentColor(const QColor &v);
    qreal opacity() const;
    void setOpacity(qreal v);
    bool blurEnabled() const;
    void setBlurEnabled(bool v);
    // --- Behavior ----------------------------------------------------------
    bool dnd() const;
    void setDnd(bool v);
    QString enabledPages() const;
    void setEnabledPages(const QString &v);
    QString weatherLocation() const;
    void setWeatherLocation(const QString &v);
    QString weatherUnit() const;
    void setWeatherUnit(const QString &v);
    bool ownDaemon() const;
    void setOwnDaemon(bool v);
    bool doNotDisturb() const;
    void setDoNotDisturb(bool v);
    int maxHistory() const;
    void setMaxHistory(int v);
    // --- Intervals ---------------------------------------------------------
    int statsInterval() const;
    void setStatsInterval(int v);
    int batteryInterval() const;
    void setBatteryInterval(int v);
    int weatherInterval() const;
    void setWeatherInterval(int v);

    // 永続化
    Q_INVOKABLE void save();
    Q_INVOKABLE void load();
    Q_INVOKABLE void resetToDefaults();

    // スキーマバージョン (将来のマイグレーション用)
    static constexpr int CurrentSchemaVersion = 1;
    int schemaVersion() const;

    // 値の検証・クランプ (静的純関数: 単体テスト可能)
    static int clampGeometry(int value, int min, int max, int defaultValue);
    static qreal clampOpacity(qreal value);
    static QString clampAnchor(const QString &value);
    static QString clampLanguage(const QString &value);
    static QString clampWeatherUnit(const QString &value);
    static int clampInterval(int value, int min, int defaultValue);

signals:
    void languageChanged();
    void anchorChanged();
    void autoHideFullscreenChanged();
    void collapsedWidthChanged();
    void collapsedHeightChanged();
    void expandedWidthChanged();
    void expandedHeightChanged();
    void radiusCollapsedChanged();
    void radiusExpandedChanged();
    void accentColorChanged();
    void opacityChanged();
    void blurEnabledChanged();
    void dndChanged();
    void enabledPagesChanged();
    void weatherLocationChanged();
    void weatherUnitChanged();
    void ownDaemonChanged();
    void doNotDisturbChanged();
    void maxHistoryChanged();
    void statsIntervalChanged();
    void batteryIntervalChanged();
    void weatherIntervalChanged();

    // 設定変更の一括通知 (QML 側で全プロパティ再読み込みしたい場合など)
    void configChanged();

private:
    class Private;
    std::unique_ptr<Private> d;
};