#pragma once

#include <QObject>

/**
 * システム統計サービス。
 *
 * 取得元:
 *   - CPU: /proc/stat 差分計算 (1s 間隔) → cpuPercent
 *   - RAM: /proc/meminfo (MemTotal, MemAvailable) → ramPercent, ramUsedGb, ramTotalGb
 *   - 温度/ファン: hwmon (coretemp, acpi_fan, asus 等) → tempC, fanRpm
 *   - GPU: Intel Arc xe ドライバ sysfs 探索、無ければ intel_gpu_top -J フォールバック → gpuPercent, gpuAvailable
 *
 * 更新: 1s タイマー
 * プロパティ (CONTRACT §3 表):
 *   cpuPercent, ramPercent, ramUsedGb, ramTotalGb, tempC, fanRpm, gpuPercent, gpuAvailable
 */
class StatsService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(qreal cpuPercent READ cpuPercent NOTIFY cpuPercentChanged)
    Q_PROPERTY(qreal ramPercent READ ramPercent NOTIFY ramPercentChanged)
    Q_PROPERTY(qreal ramUsedGb READ ramUsedGb NOTIFY ramUsedGbChanged)
    Q_PROPERTY(qreal ramTotalGb READ ramTotalGb NOTIFY ramTotalGbChanged)
    Q_PROPERTY(qreal tempC READ tempC NOTIFY tempCChanged)
    Q_PROPERTY(int fanRpm READ fanRpm NOTIFY fanRpmChanged)
    Q_PROPERTY(qreal gpuPercent READ gpuPercent NOTIFY gpuPercentChanged)
    Q_PROPERTY(bool gpuAvailable READ gpuAvailable NOTIFY gpuAvailableChanged)

public:
    explicit StatsService(QObject *parent = nullptr);
    ~StatsService() override;

    StatsService(const StatsService &) = delete;
    StatsService &operator=(const StatsService &) = delete;

    qreal cpuPercent() const { return m_cpuPercent; }
    qreal ramPercent() const { return m_ramPercent; }
    qreal ramUsedGb() const { return m_ramUsedGb; }
    qreal ramTotalGb() const { return m_ramTotalGb; }
    qreal tempC() const { return m_tempC; }
    int fanRpm() const { return m_fanRpm; }
    qreal gpuPercent() const { return m_gpuPercent; }
    bool gpuAvailable() const { return m_gpuAvailable; }

    Q_INVOKABLE void refresh(); // 手動更新トリガー

    // 純粋関数 (単体テスト用)
    /**
     * /proc/stat の行 (cpu 行) をパースして user/nice/system/idle/iowait/irq/softirq/steal/guest/guest_nice を抽出。
     * @param line "cpu  123 45 67 890 12 0 3 0 0 0" 形式
     * @return QVector<qulonglong> {user, nice, system, idle, iowait, irq, softirq, steal, guest, guest_nice}
     */
    static QVector<qulonglong> parseCpuStatLine(const QString &line);

    /**
     * 2 回の CPU stat 差分から使用率 (%) を計算。
     * @param prev 前回の値
     * @param curr 今回の値
     * @return 使用率 0.0-100.0
     */
    static qreal calculateCpuPercent(const QVector<qulonglong> &prev, const QVector<qulonglong> &curr);

    /**
     * /proc/meminfo をパースして MemTotal, MemAvailable (kB) を抽出。
     * @return QPair<totalKb, availableKb> 見つからない場合は {0, 0}
     */
    static QPair<qulonglong, qulonglong> parseMemInfo(const QString &content);

    /**
     * 温度 (ミリ度C) を度C (実数) に変換。
     */
    static qreal milliCelsiusToCelsius(int milliCelsius);

    /**
     * hwmon 名前から CPU 温度用かどうかを判定 (coretemp, k10temp 等)。
     */
    static bool isCpuThermalZone(const QString &name);

    // CPU stat インデックス (単体テスト用)
    static constexpr int CpuUser = 0;
    static constexpr int CpuNice = 1;
    static constexpr int CpuSystem = 2;
    static constexpr int CpuIdle = 3;
    static constexpr int CpuIowait = 4;
    static constexpr int CpuIrq = 5;
    static constexpr int CpuSoftirq = 6;
    static constexpr int CpuSteal = 7;
    static constexpr int CpuGuest = 8;
    static constexpr int CpuGuestNice = 9;

signals:
    void cpuPercentChanged();
    void ramPercentChanged();
    void ramUsedGbChanged();
    void ramTotalGbChanged();
    void tempCChanged();
    void fanRpmChanged();
    void gpuPercentChanged();
    void gpuAvailableChanged();

private:
    class Private;
    std::unique_ptr<Private> d;

    // 状態
    qreal m_cpuPercent = 0.0;
    qreal m_ramPercent = 0.0;
    qreal m_ramUsedGb = 0.0;
    qreal m_ramTotalGb = 0.0;
    qreal m_tempC = 0.0;
    int m_fanRpm = 0;
    qreal m_gpuPercent = 0.0;
    bool m_gpuAvailable = false;

    // 前回の CPU stat (差分計算用)
    QVector<qulonglong> m_prevCpuStat;

    void updateCpu();
    void updateMemory();
    void updateThermal();
    void updateGpu();
    void emitAllChanged();
};