#pragma once

#include <QObject>
#include <QString>
#include <QVariant>
#include <QFileSystemWatcher>
#include <QTimer>

/**
 * アプリランチャーサービス (KF6Service + XDG)。
 *
 * 依存: KF6::Service (KService, KDesktopFile), KF6::Package (オプション)
 * - .desktop ファイル走査: XDG_DATA_DIRS + ~/.local/share/applications
 * - アプリ検索: あいまいマッチ (名前/コメント/実行コマンド)
 * - 簡易計算パーサ: 四則演算・括弧・関数なし・eval 禁止
 *
 * プロパティ (CONTRACT §3 表):
 *   available (bool)      - KService 利用可能か
 *   lastQuery (string)    - 直前の検索クエリ
 *
 * メソッド:
 *   search(query) -> QVariantList of {name, icon, comment, desktopFile, score, type("app"|"calc")}
 *   launch(desktopFile) -> 起動 (KRun または QProcess::startDetached)
 *
 * インデックス: 起動時 + QFileSystemWatcher でディレクトリ監視し差分更新
 * フォールバック: KService 無し → available=false
 */
class LauncherService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)
    Q_PROPERTY(QString lastQuery READ lastQuery NOTIFY lastQueryChanged)

public:
    explicit LauncherService(QObject *parent = nullptr);
    ~LauncherService() override;

    LauncherService(const LauncherService &) = delete;
    LauncherService &operator=(const LauncherService &) = delete;

    bool available() const { return m_available; }
    QString lastQuery() const { return m_lastQuery; }

    // 検索: アプリ + 計算結果を混在して返す (スコア順)
    Q_INVOKABLE QVariantList search(const QString &query);
    // 起動: .desktop ファイルパスを指定
    Q_INVOKABLE bool launch(const QString &desktopFile);

    // 純粋関数 (単体テスト用)
    // .desktop ファイルからエントリ情報を抽出
    static QVariantMap parseDesktopFile(const QString &path);
    // あいまいスコア計算 (0.0-1.0, 高いほど一致)
    static qreal fuzzyScore(const QString &query, const QString &target);
    // 簡易計算パーサ: 四則演算・括弧のみ (eval 不使用)
    // 返り値: QPair<成功か, 結果文字列>
    static QPair<bool, QString> evaluateExpression(const QString &expr);
    // 式が計算式らしいか判定 (数字/演算子/括弧/スペースのみ)
    static bool isCalculationExpression(const QString &query);

signals:
    void availableChanged();
    void lastQueryChanged();

private:
    void scanApplications();
    void onDirectoryChanged(const QString &path);
    void buildIndex();
    void addDesktopEntriesFromDir(const QString &dir, QVector<QVariantMap> &entries);
    void scheduleRebuild();

    bool m_available = false;
    QString m_lastQuery;
    QVector<QVariantMap> m_appIndex; // キャッシュ: {name, icon, comment, desktopFile, exec, genericName}
    QFileSystemWatcher m_watcher;
    QTimer m_rebuildTimer;
    QStringList m_watchDirs;
    bool m_indexBuilt = false;

    class Private;
    std::unique_ptr<Private> d;
};