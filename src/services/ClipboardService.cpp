#include "ClipboardService.h"

#include <QStandardPaths>
#include <QProcess>
#include <QDateTime>
#include <QDebug>
#include <QTimer>
#include <QRegularExpression>

namespace {

constexpr int kDefaultMaxHistory = 100;
constexpr int kMaxClipboardTextLength = 10000;

} // namespace

ClipboardService::ClipboardService(QObject *parent)
    : QObject(parent)
{
    checkAvailability();
    if (m_available) {
        startWatchProcess();
    }
}

ClipboardService::~ClipboardService()
{
    if (m_watchProcess) {
        m_watchProcess->terminate();
        m_watchProcess->waitForFinished(1000);
        delete m_watchProcess;
    }
}

void ClipboardService::checkAvailability()
{
    m_wlPastePath = QStandardPaths::findExecutable("wl-paste");
    m_wlCopyPath = QStandardPaths::findExecutable("wl-copy");

    m_available = !m_wlPastePath.isEmpty() && !m_wlCopyPath.isEmpty();

    if (!m_available) {
        qWarning() << "ClipboardService: wl-clipboard が見つかりません (wl-paste:" << m_wlPastePath
                   << ", wl-copy:" << m_wlCopyPath << ")";
    } else {
        qDebug() << "ClipboardService: wl-clipboard 利用可能 (wl-paste:" << m_wlPastePath
                 << ", wl-copy:" << m_wlCopyPath << ")";
    }
    emit availableChanged();
}

void ClipboardService::startWatchProcess()
{
    if (!m_available) return;

    m_watchProcess = new QProcess(this);
    m_watchProcess->setProgram(m_wlPastePath);
    m_watchProcess->setArguments({"--watch"});
    m_watchProcess->setProcessChannelMode(QProcess::MergedChannels);

    connect(m_watchProcess, &QProcess::readyReadStandardOutput, this, &ClipboardService::onWatchOutput);
    connect(m_watchProcess, QOverload<QProcess::ProcessError>::of(&QProcess::errorOccurred),
            this, &ClipboardService::onWatchError);
    connect(m_watchProcess, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &ClipboardService::onWatchFinished);

    m_watchProcess->start();
    if (!m_watchProcess->waitForStarted(2000)) {
        qWarning() << "ClipboardService: wl-paste --watch 起動失敗:" << m_watchProcess->errorString();
        m_available = false;
        emit availableChanged();
        return;
    }

    qDebug() << "ClipboardService: wl-paste --watch 開始";
}

void ClipboardService::onWatchOutput()
{
    if (!m_watchProcess) return;

    // wl-paste --watch は新しいクリップボード内容が来るたびにその内容を stdout に出力する
    // 出力は NUL 文字区切り、または改行区切りの場合がある
    // ここでは改行区切りとして読み、空行で区切る方式を採用

    QByteArray data = m_watchProcess->readAllStandardOutput();
    m_watchBuffer += QString::fromUtf8(data);

    // wl-paste --watch の出力仕様:
    // - テキストがコピーされるたびに、その内容が出力され、その後に改行が入る
    // - 画像等のバイナリデータの場合は "(binary)" 等が出力される
    // - 複数行テキストの場合、そのまま複数行で出力される
    //
    // 戦略: 最後の改行で区切り、直前の内容を1つのクリップボードエントリとして扱う
    // ただし、単純に改行で split すると複数行テキストが分割されてしまう
    // wl-paste --watch は各クリップボード変更ごとに出力し、区切りとして空行を入れることはない
    // 実際の挙動: 各コピー操作で内容が丸ごと出力される (改行を含む)
    // -> 単純化のため、出力が来るたびに1エントリとして追加する

    QString text = QString::fromUtf8(data).trimmed();
    if (!text.isEmpty() && text != "(binary)") {
        addToHistory(text);
    }
}

void ClipboardService::onWatchError(QProcess::ProcessError error)
{
    qWarning() << "ClipboardService: wl-paste --watch エラー:" << error << m_watchProcess->errorString();

    // プロセスが死んだ場合は再起動を試みる
    if (error == QProcess::Crashed || error == QProcess::Timedout) {
        QTimer::singleShot(5000, this, &ClipboardService::startWatchProcess);
    }
}

void ClipboardService::onWatchFinished(int exitCode, QProcess::ExitStatus exitStatus)
{
    qWarning() << "ClipboardService: wl-paste --watch 終了 (code:" << exitCode << ", status:" << exitStatus << ")";

    // 残りバッファがあれば処理
    if (!m_watchBuffer.trimmed().isEmpty()) {
        addToHistory(m_watchBuffer.trimmed());
        m_watchBuffer.clear();
    }

    // 再起動を試みる
    QTimer::singleShot(5000, this, &ClipboardService::startWatchProcess);
}

QString ClipboardService::sanitizeClipboardText(const QString &raw, int maxLength)
{
    QString text = raw;
    // NUL 文字除去
    text.remove(QChar('\0'));
    // 制御文字除去 (改行・タブは許可)
    text = text.replace(QRegularExpression("[\\x00-\\x08\\x0B\\x0C\\x0E-\\x1F\\x7F]"), "");
    // 長さ制限
    if (text.length() > maxLength) {
        text.truncate(maxLength);
        text += "…(truncated)";
    }
    return text;
}

QVariantMap ClipboardService::createHistoryEntry(uint id, const QString &text)
{
    QVariantMap entry;
    entry["id"] = static_cast<int>(id);
    entry["text"] = text;
    entry["ts"] = timestampToString(QDateTime::currentMSecsSinceEpoch());
    return entry;
}

QString ClipboardService::timestampToString(qint64 msSinceEpoch)
{
    QDateTime dt = QDateTime::fromMSecsSinceEpoch(msSinceEpoch);
    return dt.toString(Qt::ISODateWithMs);
}

void ClipboardService::addToHistory(const QString &rawText)
{
    QString text = sanitizeClipboardText(rawText);
    if (text.isEmpty()) return;

    // 重複チェック (直前と同じなら無視)
    if (!m_items.isEmpty()) {
        QVariantMap last = m_items.first().toMap();
        if (last.value("text").toString() == text) {
            return;
        }
    }

    QVariantMap entry = createHistoryEntry(m_nextId++, text);
    m_items.prepend(entry);
    enforceMaxHistory();
    emit itemsChanged();
}

void ClipboardService::enforceMaxHistory()
{
    while (m_items.size() > m_maxHistory) {
        m_items.removeLast();
    }
}

void ClipboardService::paste(uint id)
{
    if (!m_available || m_wlCopyPath.isEmpty()) return;

    for (const QVariant &var : m_items) {
        QVariantMap entry = var.toMap();
        if (entry.value("id").toUInt() == id) {
            QString text = entry.value("text").toString();
            QProcess::execute(m_wlCopyPath, {text});
            qDebug() << "ClipboardService: pasted id" << id;
            return;
        }
    }
    qWarning() << "ClipboardService: paste 失敗 - ID が見つかりません:" << id;
}

void ClipboardService::remove(uint id)
{
    for (int i = 0; i < m_items.size(); ++i) {
        QVariantMap entry = m_items[i].toMap();
        if (entry.value("id").toUInt() == id) {
            m_items.removeAt(i);
            emit itemsChanged();
            return;
        }
    }
}

void ClipboardService::clearAll()
{
    m_items.clear();
    emit itemsChanged();
}

QVariantList ClipboardService::search(const QString &query) const
{
    if (query.isEmpty()) {
        return m_items;
    }

    QString lowerQuery = query.toLower();
    QVariantList results;
    for (const QVariant &var : m_items) {
        QVariantMap entry = var.toMap();
        QString text = entry.value("text").toString();
        if (text.toLower().contains(lowerQuery)) {
            results.append(entry);
        }
    }
    return results;
}

void ClipboardService::refresh()
{
    if (!m_available) {
        checkAvailability();
        if (m_available) {
            startWatchProcess();
        }
        return;
    }

    // 現在のクリップボード内容を一度取得して履歴に追加
    QProcess pasteProc;
    pasteProc.setProgram(m_wlPastePath);
    pasteProc.setArguments({});
    pasteProc.start();
    if (pasteProc.waitForStarted(1000) && pasteProc.waitForFinished(2000)) {
        QString text = QString::fromUtf8(pasteProc.readAllStandardOutput()).trimmed();
        if (!text.isEmpty() && text != "(binary)") {
            addToHistory(text);
        }
    }
}

void ClipboardService::emitAllChanged()
{
    emit availableChanged();
    emit itemsChanged();
}