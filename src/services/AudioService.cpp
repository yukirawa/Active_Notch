#include "AudioService.h"

#include <QProcess>
#include <QTimer>
#include <QRegularExpression>
#include <QDebug>

namespace {
constexpr int kPollIntervalMs = 300;
constexpr char kWpctlGetVolume[] = "wpctl";
constexpr char kWpctlArgs[] = "get-volume @DEFAULT_AUDIO_SINK@";

QString runWpctlGetVolumeSync()
{
    QProcess proc;
    proc.start(kWpctlGetVolume, QStringList() << "get-volume" << "@DEFAULT_AUDIO_SINK@");
    if (!proc.waitForFinished(1000)) return QString();
    return QString::fromUtf8(proc.readAllStandardOutput()).trimmed();
}

} // namespace

class AudioService::Private
{
public:
    explicit Private(AudioService *q) : q_ptr(q) {}

    AudioService *q_ptr;
    QTimer pollTimer;

    void setup()
    {
        pollTimer.setInterval(kPollIntervalMs);
        connect(&pollTimer, &QTimer::timeout, q_ptr, [this]() { q_ptr->poll(); });
    }

    void pollIfEnabled()
    {
        if (m_pollingEnabled) {
            QString out = runWpctlGetVolumeSync();
            if (!out.isEmpty()) q_ptr->parseOutput(out);
        }
    }

    bool m_pollingEnabled = false;
};

AudioService::AudioService(QObject *parent)
    : QObject(parent), d(std::make_unique<Private>(this))
{
    d->setup();

    // 初回同期取得
    QString out = runWpctlGetVolumeSync();
    if (!out.isEmpty()) parseOutput(out);

    // ポーリングは setPollingEnabled(true) で開始
}

AudioService::~AudioService() = default;

void AudioService::setPollingEnabled(bool enabled)
{
    if (d->m_pollingEnabled == enabled) return;
    d->m_pollingEnabled = enabled;
    if (enabled) {
        d->pollTimer.start();
        poll(); // 即時 1 回
    } else {
        d->pollTimer.stop();
    }
}

void AudioService::poll()
{
    QProcess *proc = new QProcess(this);
    connect(proc, &QProcess::finished, this, [this, proc](int exitCode, QProcess::ExitStatus) {
        if (exitCode == 0) {
            QString out = QString::fromUtf8(proc->readAllStandardOutput()).trimmed();
            if (!out.isEmpty()) parseOutput(out);
        } else {
            if (m_available) {
                m_available = false;
                emit availableChanged();
                emit volumeChanged();
                emit mutedChanged();
            }
        }
        proc->deleteLater();
    });
    proc->start(kWpctlGetVolume, QStringList() << "get-volume" << "@DEFAULT_AUDIO_SINK@");
    if (!proc->waitForStarted(500)) {
        proc->deleteLater();
        if (m_available) {
            m_available = false;
            emit availableChanged();
        }
    }
}

void AudioService::parseOutput(const QString &out)
{
    // "Volume: 0.65" または "Volume: 0.65 [MUTED]"
    static const QRegularExpression re(R"(Volume:\s*([0-9.]+)(?:\s*\[MUTED\])?)");
    auto match = re.match(out);
    if (!match.hasMatch()) return;

    bool wasAvailable = m_available;
    m_available = true;
    m_volume = qBound<qreal>(0.0, match.captured(1).toDouble(), 1.0);
    m_muted = out.contains("[MUTED]", Qt::CaseInsensitive);

    if (!wasAvailable) {
        emit availableChanged();
    }
    emit volumeChanged();
    emit mutedChanged();
}

void AudioService::setVolume(qreal v)
{
    v = qBound<qreal>(0.0, v, 1.0);
    int pct = qRound(v * 100);
    QProcess::execute(kWpctlGetVolume, QStringList() << "set-volume" << "@DEFAULT_AUDIO_SINK@" << QString("%1%").arg(pct));
    m_volume = v;
    emit volumeChanged();
}

void AudioService::toggleMute()
{
    QProcess::execute(kWpctlGetVolume, QStringList() << "set-mute" << "@DEFAULT_AUDIO_SINK@" << "toggle");
    // 次回ポーリングで反映されるのを待つ (即時反映したいなら poll() 呼び出し)
    poll();
}

void AudioService::step(qreal d)
{
    setVolume(m_volume + d);
}

QPair<qreal, bool> AudioService::parseWpctlOutput(const QString &output)
{
    static const QRegularExpression re(R"(Volume:\s*([0-9.]+)(?:\s*\[MUTED\])?)");
    auto match = re.match(output);
    if (!match.hasMatch()) {
        return {0.0, false};
    }
    qreal vol = qBound<qreal>(0.0, match.captured(1).toDouble(), 1.0);
    bool muted = output.contains("[MUTED]", Qt::CaseInsensitive);
    return {vol, muted};
}