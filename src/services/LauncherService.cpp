#include "LauncherService.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>
#include <QProcess>
#include <QDebug>
#include <QRegularExpression>
#include <QCoreApplication>
#include <algorithm>

namespace {

// XDG データディレクトリ取得 (XDG_DATA_DIRS + ~/.local/share)
QStringList getXdgDataDirs()
{
    QStringList dirs;

    // XDG_DATA_DIRS 環境変数
    const QString xdgDataDirs = qEnvironmentVariable("XDG_DATA_DIRS");
    if (!xdgDataDirs.isEmpty()) {
        dirs += xdgDataDirs.split(':', Qt::SkipEmptyParts);
    } else {
        // デフォルト (freedesktop.org 仕様)
        dirs << "/usr/local/share" << "/usr/share";
    }

    // ユーザー固有: ~/.local/share
    const QString home = QDir::homePath();
    dirs.prepend(home + "/.local/share");

    // 重複除去 & 存在チェック
    QStringList result;
    for (const QString &d : dirs) {
        QFileInfo fi(d);
        if (fi.exists() && fi.isDir() && !result.contains(d)) {
            result << d;
        }
    }
    return result;
}

// applications/ サブディレクトリを取得
QStringList getApplicationDirs()
{
    QStringList result;
    for (const QString &base : getXdgDataDirs()) {
        QString appsDir = base + "/applications";
        QFileInfo fi(appsDir);
        if (fi.exists() && fi.isDir()) {
            result << appsDir;
        }
    }
    return result;
}

// .desktop ファイルのパース (KDesktopFile または手動)
QVariantMap parseDesktopFileManual(const QString &path)
{
    QVariantMap entry;
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return entry;
    }

    QString currentGroup;
    QString name, genericName, comment, icon, exec, terminal, type, noDisplay, hidden, onlyShowIn, notShowIn, tryExec;

    while (!file.atEnd()) {
        QString line = QString::fromUtf8(file.readLine()).trimmed();

        if (line.isEmpty() || line.startsWith('#')) continue;

        if (line.startsWith('[') && line.endsWith(']')) {
            currentGroup = line.mid(1, line.length() - 2);
            continue;
        }

        if (currentGroup != "Desktop Entry") continue;

        int eqPos = line.indexOf('=');
        if (eqPos <= 0) continue;

        QString key = line.left(eqPos).trimmed();
        QString value = line.mid(eqPos + 1).trimmed();

        // ロケール固有キーの処理 (簡易: ja 優先)
        if (key.endsWith("[ja]")) {
            key = key.left(key.length() - 4);
            // 既に値がある場合は上書きしない (ja 以外が先に来た場合を想定)
            // ここでは単純に上書きする
        }

        if (key == "Name") name = value;
        else if (key == "GenericName") genericName = value;
        else if (key == "Comment") comment = value;
        else if (key == "Icon") icon = value;
        else if (key == "Exec") exec = value;
        else if (key == "Terminal") terminal = value.toLower();
        else if (key == "Type") type = value.toLower();
        else if (key == "NoDisplay") noDisplay = value.toLower();
        else if (key == "Hidden") hidden = value.toLower();
        else if (key == "OnlyShowIn") onlyShowIn = value;
        else if (key == "NotShowIn") notShowIn = value;
        else if (key == "TryExec") tryExec = value;
    }

    // 有効な Application タイプのみ
    if (type != "application") return QVariantMap();
    if (hidden == "true") return QVariantMap();
    if (noDisplay == "true") return QVariantMap();

    // OnlyShowIn / NotShowIn チェック (簡易: 現在のデスクトップを "KDE" と仮定)
    QString currentDesktop = qEnvironmentVariable("XDG_CURRENT_DESKTOP").toLower();
    if (!onlyShowIn.isEmpty()) {
        bool match = false;
        for (const QString &desk : onlyShowIn.split(';', Qt::SkipEmptyParts)) {
            if (desk.toLower() == currentDesktop || desk.toLower() == "kde") {
                match = true; break;
            }
        }
        if (!match) return QVariantMap();
    }
    if (!notShowIn.isEmpty()) {
        for (const QString &desk : notShowIn.split(';', Qt::SkipEmptyParts)) {
            if (desk.toLower() == currentDesktop || desk.toLower() == "kde") {
                return QVariantMap();
            }
        }
    }

    // TryExec チェック (実行可能ファイルが存在するか)
    if (!tryExec.isEmpty()) {
        if (!QStandardPaths::findExecutable(tryExec).isEmpty()) {
            // OK
        } else if (!QFileInfo(tryExec).isExecutable()) {
            return QVariantMap();
        }
    }

    entry["name"] = name;
    entry["genericName"] = genericName;
    entry["comment"] = comment;
    entry["icon"] = icon;
    entry["exec"] = exec;
    entry["terminal"] = (terminal == "true");
    entry["desktopFile"] = path;

    return entry;
}

} // namespace

class LauncherService::Private
{
public:
    explicit Private(LauncherService *q) : q_ptr(q) {}

    LauncherService *q_ptr;
};

LauncherService::LauncherService(QObject *parent)
    : QObject(parent), d(std::make_unique<Private>(this))
{
    // KF6::Service 利用可能かチェック
#if defined(HAVE_KF6_SERVICE)
    m_available = true;
#else
    m_available = false;
    qWarning() << "LauncherService: KF6::Service not available, falling back to manual .desktop parsing";
#endif

    // 監視ディレクトリ設定
    m_watchDirs = getApplicationDirs();
    for (const QString &dir : m_watchDirs) {
        m_watcher.addPath(dir);
    }
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, &LauncherService::onDirectoryChanged);

    // 再構築タイマー (デバウンス)
    m_rebuildTimer.setSingleShot(true);
    m_rebuildTimer.setInterval(500);
    connect(&m_rebuildTimer, &QTimer::timeout, this, &LauncherService::buildIndex);

    // 初期インデックス構築 (非同期)
    QTimer::singleShot(0, this, &LauncherService::buildIndex);

    emit availableChanged();
}

LauncherService::~LauncherService() = default;

void LauncherService::buildIndex()
{
    QVector<QVariantMap> newIndex;

    for (const QString &dir : m_watchDirs) {
        addDesktopEntriesFromDir(dir, newIndex);
    }

    // 名前でソート (安定性のため)
    std::sort(newIndex.begin(), newIndex.end(),
              [](const QVariantMap &a, const QVariantMap &b) {
                  return a["name"].toString().toLower() < b["name"].toString().toLower();
              });

    m_appIndex = std::move(newIndex);
    m_indexBuilt = true;
    qDebug() << "LauncherService: Index built with" << m_appIndex.size() << "applications";
}

void LauncherService::addDesktopEntriesFromDir(const QString &dir, QVector<QVariantMap> &entries)
{
    QDir d(dir);
    if (!d.exists()) return;

    // 再帰的に .desktop ファイルを探す (サブディレクトリも含む)
    QStringList filters = {"*.desktop"};
    QStringList files = d.entryList(filters, QDir::Files | QDir::NoDotAndDotDot);

    for (const QString &file : files) {
        QString path = dir + "/" + file;
        QVariantMap entry = parseDesktopFileManual(path);

        if (!entry.isEmpty()) {
            entries.append(entry);
        }
    }

    // サブディレクトリも再帰
    QStringList subdirs = d.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString &subdir : subdirs) {
        addDesktopEntriesFromDir(dir + "/" + subdir, entries);
    }
}

void LauncherService::onDirectoryChanged(const QString &path)
{
    Q_UNUSED(path);
    // デバウンスして再構築
    m_rebuildTimer.start();
}

void LauncherService::scheduleRebuild()
{
    m_rebuildTimer.start();
}

QVariantList LauncherService::search(const QString &query)
{
    m_lastQuery = query;
    emit lastQueryChanged();

    QVariantList results;

    if (!m_indexBuilt) {
        // インデックス未完成なら即時構築を試みる
        buildIndex();
    }

    QString trimmedQuery = query.trimmed();

    // 空クエリなら最近使った順などで返す (ここではアルファベット順で上位20件)
    if (trimmedQuery.isEmpty()) {
        int limit = qMin(20, m_appIndex.size());
        for (int i = 0; i < limit; ++i) {
            QVariantMap entry = m_appIndex[i];
            entry["score"] = 1.0 - (i * 0.01);
            entry["type"] = "app";
            results.append(entry);
        }
        return results;
    }

    // 計算式判定
    if (isCalculationExpression(trimmedQuery)) {
        auto calcResult = evaluateExpression(trimmedQuery);
        if (calcResult.first) {
            QVariantMap calcEntry;
            calcEntry["name"] = QString("%1 = %2").arg(trimmedQuery, calcResult.second);
            calcEntry["icon"] = "accessories-calculator";
            calcEntry["comment"] = QStringLiteral("計算結果: %1").arg(calcResult.second);
            calcEntry["desktopFile"] = "";
            calcEntry["score"] = 1.0;
            calcEntry["type"] = "calc";
            results.append(calcEntry);
        }
    }

    // アプリ検索 (あいまいマッチ)
    struct ScoredEntry {
        QVariantMap entry;
        qreal score;
    };
    QVector<ScoredEntry> scored;

    for (const QVariantMap &app : m_appIndex) {
        QString name = app["name"].toString();
        QString genericName = app["genericName"].toString();
        QString comment = app["comment"].toString();
        QString exec = app["exec"].toString();

        // 最大スコアを採用
        qreal bestScore = 0.0;
        bestScore = qMax(bestScore, fuzzyScore(trimmedQuery, name));
        bestScore = qMax(bestScore, fuzzyScore(trimmedQuery, genericName));
        bestScore = qMax(bestScore, fuzzyScore(trimmedQuery, comment));
        bestScore = qMax(bestScore, fuzzyScore(trimmedQuery, exec));

        // 閾値以上のみ
        if (bestScore > 0.15) {
            scored.append({app, bestScore});
        }
    }

    // スコア降順ソート
    std::sort(scored.begin(), scored.end(),
              [](const ScoredEntry &a, const ScoredEntry &b) {
                  return a.score > b.score;
              });

    // 上位 20 件を結果に追加
    int limit = qMin(20, scored.size());
    for (int i = 0; i < limit; ++i) {
        QVariantMap entry = scored[i].entry;
        entry["score"] = scored[i].score;
        entry["type"] = "app";
        results.append(entry);
    }

    return results;
}

bool LauncherService::launch(const QString &desktopFile)
{
    if (desktopFile.isEmpty()) {
        return false;
    }

    // .desktop ファイルから Exec 行を読み取り
    QVariantMap entry = parseDesktopFile(desktopFile);
    QString exec = entry["exec"].toString();
    if (exec.isEmpty()) {
        qWarning() << "LauncherService: Exec line not found in" << desktopFile;
        return false;
    }

    // Exec 行のプレースホルダ除去 (%f, %u, %F, %U, %i, %c, %k など)
    exec = exec.replace(QRegularExpression("%[fFuUiIcCkK]"), "");

    // コマンド分割 (簡易: シェル風に分割)
    QStringList args = exec.split(' ', Qt::SkipEmptyParts);
    if (args.isEmpty()) return false;

    QString program = args.takeFirst();
    bool success = QProcess::startDetached(program, args);
    if (!success) {
        qWarning() << "LauncherService: Failed to launch" << program << args;
    }
    return success;
}

QVariantMap LauncherService::parseDesktopFile(const QString &path)
{
    return parseDesktopFileManual(path);
}

qreal LauncherService::fuzzyScore(const QString &query, const QString &target)
{
    if (query.isEmpty() || target.isEmpty()) return 0.0;

    QString q = query.toLower();
    QString t = target.toLower();

    // 完全一致
    if (q == t) return 1.0;

    // 前方一致
    if (t.startsWith(q)) return 0.9;

    // 単語境界での前方一致
    QStringList words = t.split(QRegularExpression("[\\s_-]+"), Qt::SkipEmptyParts);
    for (const QString &word : words) {
        if (word.startsWith(q)) return 0.8;
    }

    // 部分文字列一致
    if (t.contains(q)) return 0.6;

    // あいまい一致 (文字順序保持)
    int ti = 0;
    for (int qi = 0; qi < q.length(); ++qi) {
        ti = t.indexOf(q[qi], ti);
        if (ti == -1) return 0.0;
        ++ti;
    }

    // 一致文字数 / ターゲット長 でスコア化
    return 0.4 * (q.length() / static_cast<qreal>(t.length()));
}

QPair<bool, QString> LauncherService::evaluateExpression(const QString &expr)
{
    // シェルアルゴリズム (Shunting-yard) で中置記法を後置記法 (RPN) に変換し評価
    // 四則演算 + 括弧のみ対応

    QString s = expr;
    s.remove(' ');

    if (s.isEmpty()) return {false, ""};

    // トークン化
    struct Token {
        enum Type { Number, Operator, LeftParen, RightParen } type;
        QString value;
    };

    QVector<Token> tokens;
    for (int i = 0; i < s.length(); ) {
        QChar c = s[i];
        if (c.isDigit() || c == '.') {
            QString num;
            while (i < s.length() && (s[i].isDigit() || s[i] == '.')) {
                num += s[i++];
            }
            tokens.append({Token::Number, num});
        } else if (c == '+' || c == '-' || c == '*' || c == '/') {
            // 負数の判定: 先頭、または ( の直後、または演算子の直後
            if (c == '-' && (tokens.isEmpty() ||
                tokens.last().type == Token::Operator ||
                tokens.last().type == Token::LeftParen)) {
                // 負数として数値に含める
                QString num = "-";
                ++i;
                while (i < s.length() && (s[i].isDigit() || s[i] == '.')) {
                    num += s[i++];
                }
                if (num == "-") return {false, ""}; // 単独の - はエラー
                tokens.append({Token::Number, num});
            } else {
                tokens.append({Token::Operator, QString(c)});
                ++i;
            }
        } else if (c == '(') {
            tokens.append({Token::LeftParen, "("});
            ++i;
        } else if (c == ')') {
            tokens.append({Token::RightParen, ")"});
            ++i;
        } else {
            // 無効文字
            return {false, ""};
        }
    }

    // Shunting-yard algorithm
    QVector<Token> output;
    QVector<Token> opStack;

    auto precedence = [](const QString &op) -> int {
        if (op == "+" || op == "-") return 1;
        if (op == "*" || op == "/") return 2;
        return 0;
    };

    for (const Token &tok : tokens) {
        switch (tok.type) {
        case Token::Number:
            output.append(tok);
            break;
        case Token::Operator:
            while (!opStack.isEmpty() && opStack.last().type == Token::Operator &&
                   precedence(opStack.last().value) >= precedence(tok.value)) {
                output.append(opStack.takeLast());
            }
            opStack.append(tok);
            break;
        case Token::LeftParen:
            opStack.append(tok);
            break;
        case Token::RightParen:
            while (!opStack.isEmpty() && opStack.last().type != Token::LeftParen) {
                output.append(opStack.takeLast());
            }
            if (opStack.isEmpty()) return {false, ""}; // 括弧不一致
            opStack.takeLast(); // LeftParen を捨てる
            break;
        }
    }

    while (!opStack.isEmpty()) {
        if (opStack.last().type == Token::LeftParen || opStack.last().type == Token::RightParen) {
            return {false, ""}; // 括弧不一致
        }
        output.append(opStack.takeLast());
    }

    // RPN 評価
    QVector<double> stack;
    for (const Token &tok : output) {
        if (tok.type == Token::Number) {
            bool ok = false;
            double val = tok.value.toDouble(&ok);
            if (!ok) return {false, ""};
            stack.append(val);
        } else if (tok.type == Token::Operator) {
            if (stack.size() < 2) return {false, ""};
            double b = stack.takeLast();
            double a = stack.takeLast();
            double result = 0;
            if (tok.value == "+") result = a + b;
            else if (tok.value == "-") result = a - b;
            else if (tok.value == "*") result = a * b;
            else if (tok.value == "/") {
                if (qFuzzyIsNull(b)) return {false, ""};
                result = a / b;
            } else return {false, ""};
            stack.append(result);
        }
    }

    if (stack.size() != 1) return {false, ""};

    double result = stack[0];
    // 整数なら小数点なしで、そうでなければ適度な精度で
    QString resultStr;
    if (qFuzzyCompare(result, qRound(result))) {
        resultStr = QString::number(qRound(result));
    } else {
        resultStr = QString::number(result, 'g', 10);
    }

    return {true, resultStr};
}

bool LauncherService::isCalculationExpression(const QString &query)
{
    QString s = query.trimmed();
    if (s.isEmpty()) return false;

    // 許可文字: 数字、演算子、括弧、スペース、小数点
    // ただし、単なる数字だけの場合は計算式とみなさない (検索として扱う)
    QRegularExpression calcRegex(R"(^[\d\s\+\-\*\/\(\)\.]+$)");
    if (!calcRegex.match(s).hasMatch()) return false;

    // 演算子が含まれているか
    if (!s.contains(QRegularExpression("[\\+\\-\\*\\/]"))) return false;

    // 連続する演算子チェック (++, --, +-, -+, */, /* など)
    // スペースを除去してからチェック
    QString noSpace = s;
    noSpace.remove(' ');
    if (noSpace.contains(QRegularExpression("[\\+\\-\\*\\/]{2,}"))) return false;

    // 括弧のバランスチェック
    int parenCount = 0;
    for (QChar c : s) {
        if (c == '(') ++parenCount;
        else if (c == ')') --parenCount;
        if (parenCount < 0) return false;
    }
    if (parenCount != 0) return false;

    return true;
}