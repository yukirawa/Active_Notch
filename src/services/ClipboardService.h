#pragma once

#include <QObject>
#include <QString>
#include <QVariant>
#include <QProcess>

/**
 * クリップボード履歴サービス (wl-paste --watch + wl-copy)。
 *
 * 依存: wl-clipboard (wl-paste, wl-copy) — 未導入時は available=false で graceful 退化。
 *
 * プロパティ (CONTRACT §3 表):
 *   available (bool)   - wl-paste / wl-copy が利用可能か
 *   items (QVariantList) - 履歴アイテム {id, text, ts}
 *
 * メソッド:
 *   paste(uint id)     - 指定 ID のテキストをクリップボードに書き込み (wl-copy)
 *   remove(uint id)    - 指定 ID を履歴から削除
 *   clearAll()         - 全履歴をクリア
 *   search(QString)    - クエリでフィルタした履歴を返す
 *
 * 実装詳細:
 * - wl-paste --watch を QProcess で起動、標準出力から新規クリップボード内容を検出
 * - 履歴管理 (上限 Config.maxHistory)
 * - 書き込み: wl-copy で指定テキストをクリップボードに書き込み
 * - フォールバック: wl-clipboard 無し → available=false、UI 側で「wl-clipboard 未導入」表示
 */
class ClipboardService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)
    Q_PROPERTY(QVariantList items READ items NOTIFY itemsChanged)

public:
    explicit ClipboardService(QObject *parent = nullptr);
    ~ClipboardService() override;

    ClipboardService(const ClipboardService &) = delete;
    ClipboardService &operator=(const ClipboardService &) = delete;

    bool available() const { return m_available; }
    QVariantList items() const { return m_items; }

    // 指定 ID のテキストをクリップボードに書き込み (wl-copy)
    Q_INVOKABLE void paste(uint id);
    // 指定 ID を履歴から削除
    Q_INVOKABLE void remove(uint id);
    // 全履歴をクリア
    Q_INVOKABLE void clearAll();
    // クエリでフィルタした履歴を返す (部分一致、大文字小文字無視)
    Q_INVOKABLE QVariantList search(const QString &query) const;
    // 手動リフレッシュ (wl-paste --watch が動いていない場合のフォールバック)
    Q_INVOKABLE void refresh();

    // 純粋関数 (単体テスト用)
    // wl-paste 出力からテキストを抽出 (先頭 N 文字に制限)
    static QString sanitizeClipboardText(const QString &raw, int maxLength = 10000);
    // 履歴エントリ生成
    static QVariantMap createHistoryEntry(uint id, const QString &text);
    // タイムスタンプ文字列生成 (ISO 8601)
    static QString timestampToString(qint64 msSinceEpoch);

signals:
    void availableChanged();
    void itemsChanged();

private:
    void checkAvailability();
    void startWatchProcess();
    void onWatchOutput();
    void onWatchError(QProcess::ProcessError error);
    void onWatchFinished(int exitCode, QProcess::ExitStatus exitStatus);
    void addToHistory(const QString &text);
    void enforceMaxHistory();
    void emitAllChanged();

    bool m_available = false;
    QVariantList m_items;
    int m_maxHistory = 100;
    uint m_nextId = 1;
    QString m_wlPastePath;
    QString m_wlCopyPath;
    QProcess *m_watchProcess = nullptr;
    QString m_watchBuffer; // wl-paste --watch の出力バッファ (複数行対応)
};