#pragma once

#include <QObject>

/**
 * クイック設定サービス (KWin Night Light DBus)。
 *
 * 対象: org.kde.KWin /org/kde/KWin/NightLight
 * プロパティ: enabled (bool)
 * メソッド: SetEnabled(bool)
 */
class QuickSettingsService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool nightLightAvailable READ nightLightAvailable NOTIFY nightLightAvailableChanged)
    Q_PROPERTY(bool nightLightOn READ nightLightOn NOTIFY nightLightOnChanged)

public:
    explicit QuickSettingsService(QObject *parent = nullptr);
    ~QuickSettingsService() override;

    QuickSettingsService(const QuickSettingsService &) = delete;
    QuickSettingsService &operator=(const QuickSettingsService &) = delete;

    bool nightLightAvailable() const { return m_available; }
    bool nightLightOn() const { return m_nightLightOn; }

    Q_INVOKABLE void toggleNightLight();
    Q_INVOKABLE void refresh();

signals:
    void nightLightAvailableChanged();
    void nightLightOnChanged();

private:
    void updateFromDBus();

    bool m_available = false;
    bool m_nightLightOn = false;

    class Private;
    std::unique_ptr<Private> d;
};