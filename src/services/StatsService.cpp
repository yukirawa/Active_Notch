#include "StatsService.h"

#include <QFile>
#include <QDir>
#include <QTimer>
#include <QProcess>
#include <QRegularExpression>
#include <QDebug>
#include <QtMath>

namespace {
constexpr int kUpdateIntervalMs = 1000;
constexpr char kProcStatPath[] = "/proc/stat";
constexpr char kProcMemInfoPath[] = "/proc/meminfo";
constexpr char kHwmonBasePath[] = "/sys/class/hwmon";
constexpr char kIntelGpuTopCmd[] = "intel_gpu_top";
constexpr char kXeGpuBasePath[] = "/sys/class/drm";

// CPU stat のインデックス
enum CpuStatIndex {
    CPU_USER = 0,
    CPU_NICE = 1,
    CPU_SYSTEM = 2,
    CPU_IDLE = 3,
    CPU_IOWAIT = 4,
    CPU_IRQ = 5,
    CPU_SOFTIRQ = 6,
    CPU_STEAL = 7,
    CPU_GUEST = 8,
    CPU_GUEST_NICE = 9
};

QString readFile(const QString &path)
{
    QFile f(path);
    if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return QString::fromUtf8(f.readAll()).trimmed();
    }
    return QString();
}

bool readFirstLine(const QString &path, QString &line)
{
    QFile f(path);
    if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        line = QString::fromUtf8(f.readLine()).trimmed();
        return true;
    }
    return false;
}

} // namespace

class StatsService::Private
{
public:
    explicit Private(StatsService *q) : q_ptr(q) {}

    StatsService *q_ptr;
    QTimer updateTimer;

    void setup()
    {
        updateTimer.setInterval(kUpdateIntervalMs);
        connect(&updateTimer, &QTimer::timeout, q_ptr, [this]() { q_ptr->refresh(); });
        updateTimer.start();

        // 初回即時実行
        QTimer::singleShot(0, q_ptr, [this]() { q_ptr->refresh(); });
    }

    // GPU: xe ドライバの sysfs を探索
    bool findXeGpuEnginePath(QString &enginePath)
    {
        QDir drmDir(kXeGpuBasePath);
        if (!drmDir.exists()) return false;

        // card* ディレクトリを探索
        auto cards = drmDir.entryList(QStringList() << "card*", QDir::Dirs | QDir::NoDotAndDotDot);
        for (const QString &card : cards) {
            QString cardPath = drmDir.filePath(card);
            QDir cardDir(cardPath);

            // device/engine/render 等を探す
            // Intel xe の場合: /sys/class/drm/card0/device/engine/rcs0/busy 等
            QString engineDir = cardPath + "/device/engine";
            QDir eDir(engineDir);
            if (!eDir.exists()) continue;

            auto engines = eDir.entryList(QStringList() << "*", QDir::Dirs | QDir::NoDotAndDotDot);
            for (const QString &eng : engines) {
                // render/compute/video エンジンを優先
                if (eng.contains("rcs") || eng.contains("ccs") || eng.contains("vcs") || eng.contains("vecs")) {
                    QString busyFile = eDir.filePath(eng) + "/busy";
                    if (QFile::exists(busyFile)) {
                        enginePath = busyFile;
                        return true;
                    }
                }
            }

            // 見つからない場合は最初のエンジンを使う
            if (!engines.isEmpty()) {
                QString busyFile = eDir.filePath(engines.first()) + "/busy";
                if (QFile::exists(busyFile)) {
                    enginePath = busyFile;
                    return true;
                }
            }
        }
        return false;
    }

    // intel_gpu_top -J で JSON 出力を取得してパース
    bool queryIntelGpuTop(qreal &gpuPercent)
    {
        QProcess proc;
        proc.start(kIntelGpuTopCmd, QStringList() << "-J" << "-o" << "-");
        if (!proc.waitForFinished(2000)) return false;

        QString output = QString::fromUtf8(proc.readAllStandardOutput()).trimmed();
        if (output.isEmpty()) return false;

        // JSON パース: {"engines": {"Render/3D/0": {"busy": 45.2, ...}, ...}}
        // 簡易パース: "busy": 数値 を探す
        static const QRegularExpression re(R"("busy"\s*:\s*([0-9.]+))");
        auto match = re.match(output);
        if (match.hasMatch()) {
            bool ok = false;
            qreal busy = match.captured(1).toDouble(&ok);
            if (ok) {
                gpuPercent = qBound<qreal>(0.0, busy, 100.0);
                return true;
            }
        }
        return false;
    }

    // hwmon から CPU 温度とファン回転数を取得
    void updateThermalSensors(qreal &tempC, int &fanRpm)
    {
        QDir hwmonDir(kHwmonBasePath);
        if (!hwmonDir.exists()) return;

        auto hwmons = hwmonDir.entryList(QStringList() << "hwmon*", QDir::Dirs | QDir::NoDotAndDotDot);
        qreal maxTemp = 0.0;
        int maxFan = 0;

        for (const QString &hwmon : hwmons) {
            QString hwmonPath = hwmonDir.filePath(hwmon);

            // name ファイルでデバイス種別を判定
            QString name = readFile(hwmonPath + "/name").toLower();

            // CPU 温度: coretemp, k10temp, zenpower 等
            if (name.contains("coretemp") || name.contains("k10temp") || name.contains("zenpower")) {
                // temp*_input ファイルを探す
                auto tempFiles = QDir(hwmonPath).entryList(QStringList() << "temp*_input", QDir::Files);
                for (const QString &tf : tempFiles) {
                    QString labelName = tf;
                    labelName.replace("_input", "_label");
                    QString labelFile = hwmonPath + "/" + labelName;
                    QString label = readFile(labelFile).toLower();

                    // Package id 0 または CPU core 温度を優先
                    bool isPackage = label.contains("package") && label.contains("id 0");
                    bool isCore = label.contains("core");

                    if (isPackage || isCore) {
                        bool ok = false;
                        int milliC = readFile(hwmonPath + "/" + tf).toInt(&ok);
                        if (ok && milliC > 0) {
                            qreal c = milliC / 1000.0;
                            if (c > maxTemp) maxTemp = c;
                        }
                    }
                }
            }

            // ファン: acpi_fan, asus, thinkpad 等
            if (name.contains("fan") || name.contains("acpi") || name.contains("asus") || name.contains("thinkpad")) {
                auto fanFiles = QDir(hwmonPath).entryList(QStringList() << "fan*_input", QDir::Files);
                for (const QString &ff : fanFiles) {
                    bool ok = false;
                    int rpm = readFile(hwmonPath + "/" + ff).toInt(&ok);
                    if (ok && rpm > maxFan) maxFan = rpm;
                }
            }
        }

        if (maxTemp > 0) tempC = maxTemp;
        if (maxFan > 0) fanRpm = maxFan;
    }
};

StatsService::StatsService(QObject *parent)
    : QObject(parent), d(std::make_unique<Private>(this))
{
    d->setup();
}

StatsService::~StatsService() = default;

void StatsService::refresh()
{
    updateCpu();
    updateMemory();
    updateThermal();
    updateGpu();
    emitAllChanged();
}

void StatsService::updateCpu()
{
    QString line;
    if (!readFirstLine(kProcStatPath, line)) return;

    QVector<qulonglong> curr = parseCpuStatLine(line);
    if (curr.size() < 4) return; // 最低限 user, nice, system, idle が必要

    if (!m_prevCpuStat.isEmpty()) {
        qreal percent = calculateCpuPercent(m_prevCpuStat, curr);
        if (qFuzzyCompare(m_cpuPercent, percent) == false) {
            m_cpuPercent = percent;
        }
    }
    m_prevCpuStat = curr;
}

void StatsService::updateMemory()
{
    QString content = readFile(kProcMemInfoPath);
    if (content.isEmpty()) return;

    auto [totalKb, availableKb] = parseMemInfo(content);
    if (totalKb == 0) return;

    qulonglong usedKb = totalKb - availableKb;
    qreal totalGb = totalKb / 1024.0 / 1024.0;
    qreal usedGb = usedKb / 1024.0 / 1024.0;
    qreal percent = (totalKb > 0) ? (qreal(usedKb) / totalKb * 100.0) : 0.0;

    if (!qFuzzyCompare(m_ramTotalGb, totalGb)) { m_ramTotalGb = totalGb; }
    if (!qFuzzyCompare(m_ramUsedGb, usedGb)) { m_ramUsedGb = usedGb; }
    if (!qFuzzyCompare(m_ramPercent, percent)) { m_ramPercent = percent; }
}

void StatsService::updateThermal()
{
    qreal newTemp = 0.0;
    int newFan = 0;
    d->updateThermalSensors(newTemp, newFan);

    if (!qFuzzyCompare(m_tempC, newTemp)) { m_tempC = newTemp; }
    if (m_fanRpm != newFan) { m_fanRpm = newFan; }
}

void StatsService::updateGpu()
{
    qreal gpuPercent = 0.0;
    bool available = false;

    // 1. xe ドライバ sysfs を試す
    QString enginePath;
    if (d->findXeGpuEnginePath(enginePath)) {
        // busy ファイルから使用率を計算 (簡易: 過去の値との差分が必要だが、ここでは intel_gpu_top にフォールバック)
        // sysfs からの正確な取得は複雑なため、intel_gpu_top を優先
    }

    // 2. intel_gpu_top -J を試す
    if (d->queryIntelGpuTop(gpuPercent)) {
        available = true;
    }

    if (m_gpuAvailable != available) { m_gpuAvailable = available; emit gpuAvailableChanged(); }
    if (available && !qFuzzyCompare(m_gpuPercent, gpuPercent)) { m_gpuPercent = gpuPercent; }
    if (!available && m_gpuPercent != 0.0) { m_gpuPercent = 0.0; }
}

void StatsService::emitAllChanged()
{
    emit cpuPercentChanged();
    emit ramPercentChanged();
    emit ramUsedGbChanged();
    emit ramTotalGbChanged();
    emit tempCChanged();
    emit fanRpmChanged();
    emit gpuPercentChanged();
    // gpuAvailableChanged は updateGpu 内で個別に emit
}

// --- 純粋関数 (単体テスト用) ---

QVector<qulonglong> StatsService::parseCpuStatLine(const QString &line)
{
    QVector<qulonglong> result;
    // "cpu  user nice system idle iowait irq softirq steal guest guest_nice"
    QStringList parts = line.split(' ', Qt::SkipEmptyParts);
    if (parts.isEmpty() || parts.first() != "cpu") return result;

    for (int i = 1; i < parts.size() && i <= 10; ++i) {
        bool ok = false;
        qulonglong v = parts[i].toULongLong(&ok);
        result.append(ok ? v : 0);
    }
    // 不足分を 0 で埋める
    while (result.size() < 10) result.append(0);
    return result;
}

qreal StatsService::calculateCpuPercent(const QVector<qulonglong> &prev, const QVector<qulonglong> &curr)
{
    if (prev.size() < 4 || curr.size() < 4) return 0.0;

    // 総時間 = user + nice + system + idle + iowait + irq + softirq + steal
    // (guest, guest_nice は nice/user に含まれるため除外)
    auto totalTime = [](const QVector<qulonglong> &v) -> qulonglong {
        qulonglong sum = 0;
        for (int i = CPU_USER; i <= CPU_STEAL && i < v.size(); ++i) {
            sum += v[i];
        }
        return sum;
    };

    auto idleTime = [](const QVector<qulonglong> &v) -> qulonglong {
        qulonglong sum = 0;
        if (CPU_IDLE < v.size()) sum += v[CPU_IDLE];
        if (CPU_IOWAIT < v.size()) sum += v[CPU_IOWAIT];
        return sum;
    };

    qulonglong prevTotal = totalTime(prev);
    qulonglong currTotal = totalTime(curr);
    qulonglong prevIdle = idleTime(prev);
    qulonglong currIdle = idleTime(curr);

    qulonglong totalDiff = currTotal - prevTotal;
    qulonglong idleDiff = currIdle - prevIdle;

    if (totalDiff == 0) return 0.0;

    qreal percent = 100.0 * (totalDiff - idleDiff) / totalDiff;
    return qBound<qreal>(0.0, percent, 100.0);
}

QPair<qulonglong, qulonglong> StatsService::parseMemInfo(const QString &content)
{
    qulonglong totalKb = 0;
    qulonglong availableKb = 0;

    QStringList lines = content.split('\n');
    for (const QString &line : lines) {
        if (line.startsWith("MemTotal:")) {
            QStringList parts = line.split(' ', Qt::SkipEmptyParts);
            if (parts.size() >= 2) {
                bool ok = false;
                totalKb = parts[1].toULongLong(&ok);
            }
        } else if (line.startsWith("MemAvailable:")) {
            QStringList parts = line.split(' ', Qt::SkipEmptyParts);
            if (parts.size() >= 2) {
                bool ok = false;
                availableKb = parts[1].toULongLong(&ok);
            }
        }
    }

    return {totalKb, availableKb};
}

qreal StatsService::milliCelsiusToCelsius(int milliCelsius)
{
    return milliCelsius / 1000.0;
}

bool StatsService::isCpuThermalZone(const QString &name)
{
    QString lower = name.toLower();
    return lower.contains("coretemp") || lower.contains("k10temp") || lower.contains("zenpower");
}