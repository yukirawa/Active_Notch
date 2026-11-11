#include "CalendarService.h"

#include <KHolidays/HolidayRegion>
#include <QLocale>
#include <QDate>
#include <QDebug>

CalendarService::CalendarService(QObject *parent)
    : QObject(parent)
{
    // 日本語ロケール固定
    m_locale = QLocale(QLocale::Japanese, QLocale::Japan);
    m_holidayRegion = new KHolidays::HolidayRegion(QStringLiteral("jp"));

    // 今日に初期化
    const QDate today = QDate::currentDate();
    m_year = today.year();
    m_month = today.month();
    updateTodayInfo();
}

CalendarService::~CalendarService()
{
    delete m_holidayRegion;
}

QVariantList CalendarService::monthGrid(int year, int month)
{
    QVariantList result;
    if (year < 1900 || year > 2100 || month < 1 || month > 12) {
        return result;
    }

    m_year = year;
    m_month = month;
    updateTodayInfo();

    const QDate firstDay(year, month, 1);
    const int daysInMonth = firstDay.daysInMonth();
    const int firstWeekday = firstDay.dayOfWeek(); // 1=Mon .. 7=Sun (Qt)
    // QML GridView は通常日曜始まり (0=Sun)。調整:
    // firstWeekday: Mon=1->1, Tue=2->2, ..., Sat=6->6, Sun=7->0
    const int startOffset = (firstWeekday == 7) ? 0 : firstWeekday;

    const QDate today = QDate::currentDate();

    // 前月の末尾を埋める
    QDate prevMonthLast = firstDay.addDays(-1);
    for (int i = startOffset - 1; i >= 0; --i) {
        const QDate d = prevMonthLast.addDays(-i);
        QVariantMap cell;
        cell["day"] = d.day();
        cell["inMonth"] = false;
        cell["isToday"] = (d == today);
        cell["isHoliday"] = false;
        cell["holidayName"] = QString();
        result.append(cell);
    }

    // 今月の日付
    for (int day = 1; day <= daysInMonth; ++day) {
        const QDate d(year, month, day);
        QVariantMap cell;
        cell["day"] = day;
        cell["inMonth"] = true;
        cell["isToday"] = (d == today);
        // KHolidays で祝日判定
        const KHolidays::Holiday::List holidays = m_holidayRegion ? m_holidayRegion->rawHolidays(d, d) : KHolidays::Holiday::List();
        cell["isHoliday"] = !holidays.isEmpty();
        cell["holidayName"] = holidays.isEmpty() ? QString() : holidays.first().name();
        result.append(cell);
    }

    // 翌月の先頭を埋めて 6 週 (42 セル) に揃える (UI 簡易化)
    while (result.size() < 42) {
        const int nextDay = result.size() - startOffset - daysInMonth + 1;
        const QDate d = firstDay.addMonths(1).addDays(nextDay - 1);
        QVariantMap cell;
        cell["day"] = d.day();
        cell["inMonth"] = false;
        cell["isToday"] = (d == today);
        cell["isHoliday"] = false;
        cell["holidayName"] = QString();
        result.append(cell);
    }

    return result;
}

void CalendarService::resetToToday()
{
    const QDate today = QDate::currentDate();
    if (m_year != today.year() || m_month != today.month()) {
        m_year = today.year();
        m_month = today.month();
        updateTodayInfo();
        emit dateChanged();
    }
}

void CalendarService::updateTodayInfo()
{
    const QDate firstDay(m_year, m_month, 1);
    m_monthName = m_locale.toString(firstDay, QLocale::LongFormat); // "2026年11月"
    // "2026年11月12日 (木)" 形式
    const QDate today = QDate::currentDate();
    m_todayText = m_locale.toString(today, QLocale::LongFormat)
                    + QStringLiteral(" (") + m_locale.dayName(today.dayOfWeek(), QLocale::ShortFormat) + QStringLiteral(")");
    m_weekdayLong = m_locale.dayName(today.dayOfWeek(), QLocale::LongFormat);
}

QPair<bool, QString> CalendarService::isHoliday(const QDate &date)
{
    if (!date.isValid()) return {false, QString()};

    if (!m_holidayRegion) return {false, QString()};

    const KHolidays::Holiday::List holidays = m_holidayRegion->rawHolidays(date, date);
    if (holidays.isEmpty()) return {false, QString()};
    return {true, holidays.first().name()};
}