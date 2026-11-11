#pragma once

#include <QObject>
#include <QVariant>
#include <QLocale>
#include <KHolidays/HolidayRegion>

/**
 * カレンダーサービス (KHolidays + QLocale)。
 *
 * 日本語ロケールで月名・曜日・祝日名を提供する。
 * monthGrid() は QML の GridView/Repeater でそのまま使える QVariantList を返す。
 */
class CalendarService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int year READ year NOTIFY dateChanged)
    Q_PROPERTY(QString monthName READ monthName NOTIFY dateChanged)
    Q_PROPERTY(QString todayText READ todayText NOTIFY dateChanged)
    Q_PROPERTY(QString weekdayLong READ weekdayLong NOTIFY dateChanged)

public:
    explicit CalendarService(QObject *parent = nullptr);
    ~CalendarService() override;

    CalendarService(const CalendarService &) = delete;
    CalendarService &operator=(const CalendarService &) = delete;

    int year() const { return m_year; }
    QString monthName() const { return m_monthName; }
    QString todayText() const { return m_todayText; }
    QString weekdayLong() const { return m_weekdayLong; }

    /**
     * 指定年月のカレンダーグリッドを返す。
     * @return QVariantList of QVariantMap {day, inMonth, isToday, isHoliday, holidayName}
     *   - day: 1-31 (その月の日付). inMonth=false のときは前月/翌月の日付
     *   - inMonth: 表示対象月内なら true
     *   - isToday: システム日付と一致なら true
     *   - isHoliday: 日本の祝日なら true (KHolidays)
     *   - holidayName: 祝日名 (祝日でないとき空文字)
     */
    Q_INVOKABLE QVariantList monthGrid(int year, int month);

    /**
     * 指定日付が祝日か判定する (単体テスト用)。
     * @return pair<isHoliday, holidayName>
     */
    QPair<bool, QString> isHoliday(const QDate &date);

    /** 今月へリセット (year/month を現在に戻す) */
    Q_INVOKABLE void resetToToday();

signals:
    void dateChanged();

private:
    void updateTodayInfo();

    QLocale m_locale;
    KHolidays::HolidayRegion *m_holidayRegion = nullptr;

    int m_year = 0;
    int m_month = 0;
    QString m_monthName;
    QString m_todayText;
    QString m_weekdayLong;
};