#pragma once

#include <QObject>

/**
 * 画面輝度サービス (sysfs 読み + logind 書き)。
 *
 * 読み: /sys/class/backlight/intel_backlight/{max_brightness,brightness}
 * 書き: logind org.freedesktop.login1 Session.SetBrightness (PolicyKit 不要)
 * フォールバック: sysfs 直接書き込み (video グループ要)
 *
 * 利用不可時は available=false で graceful 退化。
 */
class BrightnessService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)
    Q_PROPERTY(qreal brightness READ brightness NOTIFY brightnessChanged) // 0.0-1.0

public:
    explicit BrightnessService(QObject *parent = nullptr);
    ~BrightnessService() override;

    BrightnessService(const BrightnessService &) = delete;
    BrightnessService &operator=(const BrightnessService &) = delete;

    bool available() const { return m_available; }
    qreal brightness() const { return m_brightness; }

    // 0.0-1.0 で指定
    Q_INVOKABLE void setBrightness(qreal v);

    /**
     * sysfs の max_brightness / brightness ファイルから輝度比率を計算する純粋関数 (単体テスト用)。
     * @param maxPath max_brightness ファイルパス
     * @param curPath brightness ファイルパス
     * @return 0.0-1.0 (ファイル不在・不正値・max=0 のとき 0.0)
     */
    static qreal parseBrightness(const QString &maxPath, const QString &curPath);

signals:
    void availableChanged();
    void brightnessChanged();

private:
    void poll();
    bool writeViaLogind(int value);
    bool writeViaSysfs(int value);
    void emitAllChanged();

    bool m_available = false;
    qreal m_brightness = 0.0;
    int m_maxBrightness = 0;
    QString m_brightnessPath;
    QString m_maxBrightnessPath;

    class Private;
    std::unique_ptr<Private> d;
};