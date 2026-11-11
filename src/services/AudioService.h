#pragma once

#include <QObject>
#include <QString>

/**
 * 音量サービス (PipeWire wpctl)。
 *
 * wpctl get-volume @DEFAULT_AUDIO_SINK@ を非同期実行してパース。
 * 利用不可時は available=false で graceful 退化。
 */
class AudioService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)
    Q_PROPERTY(qreal volume READ volume NOTIFY volumeChanged)           // 0.0-1.0
    Q_PROPERTY(bool muted READ muted NOTIFY mutedChanged)
    Q_PROPERTY(QString sinkName READ sinkName NOTIFY sinkNameChanged)

public:
    explicit AudioService(QObject *parent = nullptr);
    ~AudioService() override;

    AudioService(const AudioService &) = delete;
    AudioService &operator=(const AudioService &) = delete;

    bool available() const { return m_available; }
    qreal volume() const { return m_volume; }
    bool muted() const { return m_muted; }
    QString sinkName() const { return m_sinkName; }

    // 0.0-1.0 で指定
    Q_INVOKABLE void setVolume(qreal v);
    Q_INVOKABLE void toggleMute();
    // 相対変更: d > 0 なら増, d < 0 なら減 (例: 0.05 = 5%)
    Q_INVOKABLE void step(qreal d);
    // UI 表示中のみポーリングを有効化 (notchState 連動用)
    Q_INVOKABLE void setPollingEnabled(bool enabled);

    /**
     * wpctl get-volume の出力をパースする純粋関数 (単体テスト用)。
     * @return QPair<volume(0.0-1.0), muted>
     */
    static QPair<qreal, bool> parseWpctlOutput(const QString &output);

signals:
    void availableChanged();
    void volumeChanged();
    void mutedChanged();
    void sinkNameChanged();

private:
    void poll();
    void parseOutput(const QString &out);

    bool m_available = false;
    qreal m_volume = 0.0;
    bool m_muted = false;
    QString m_sinkName;
    bool m_pollingEnabled = false;

    class Private;
    std::unique_ptr<Private> d;
};