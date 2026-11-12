pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import dev.yukirawa.activenotch

// Calendar — 月間カレンダー表示ページ。
//
// CalendarService から取得したデータでグリッドを構築する。
// - 月切替ボタン (◀ ▶) で前月/翌月へ移動
// - 今日はハイライト、祝日は休日色 (アクセント寄り) で表示
// - サービス未配線時は typeof ガードでフォールバック表示
Item {
    id: root
    // PageLoader が anchors.fill でサイズを与える。parent 依存は循環の原因。
    implicitWidth: 604
    implicitHeight: 380

    // ---- 内部状態 -----------------------------------------------------------
    property int currentYear: new Date().getFullYear()
    property int currentMonth: new Date().getMonth() + 1  // 1-12
    property var monthGridData: []  // CalendarService.monthGrid() の戻り値

    // 曜日ラベル (日本語・長形式)
    readonly property var weekdaysLong: (typeof CalendarService !== "undefined" && CalendarService !== null && CalendarService.weekdayLong)
        ? CalendarService.weekdayLong
        : ["日曜日", "月曜日", "火曜日", "水曜日", "木曜日", "金曜日", "土曜日"]

    // 短縮曜日ラベル (ヘッダー用)
    readonly property var weekdaysShort: ["日", "月", "火", "水", "木", "金", "土"]

    // ---- サービス連携: 月グリッド取得 ---------------------------------------
    function refreshGrid() {
        if (typeof CalendarService !== "undefined" && CalendarService !== null && CalendarService.monthGrid) {
            const grid = CalendarService.monthGrid(currentYear, currentMonth)
            if (grid) {
                monthGridData = grid
            }
        } else {
            // フォールバック: ローカル計算でグリッド生成 (祝日なし)
            monthGridData = buildLocalGrid(currentYear, currentMonth)
        }
    }

    // ローカル計算フォールバック (KHolidays 未配線時用)
    function buildLocalGrid(year, month) {
        const firstDay = new Date(year, month - 1, 1)
        const lastDay = new Date(year, month, 0)
        const startWeekday = firstDay.getDay()  // 0=日
        const daysInMonth = lastDay.getDate()
        const today = new Date()
        const isCurrentMonth = (today.getFullYear() === year && today.getMonth() + 1 === month)

        const grid = []
        // 前月の末尾日数埋め
        for (let i = 0; i < startWeekday; ++i) {
            const prevMonth = month === 1 ? 12 : month - 1
            const prevYear = month === 1 ? year - 1 : year
            const prevLastDay = new Date(prevYear, prevMonth, 0).getDate()
            grid.push({
                day: prevLastDay - startWeekday + i + 1,
                inMonth: false,
                isToday: false,
                isHoliday: false,
                holidayName: ""
            })
        }
        // 当月
        for (let d = 1; d <= daysInMonth; ++d) {
            grid.push({
                day: d,
                inMonth: true,
                isToday: isCurrentMonth && d === today.getDate(),
                isHoliday: false,  // 祝日判定はサービス側で行う
                holidayName: ""
            })
        }
        // 翌月の先頭埋め (6行×7列 = 42 セルに満たない場合)
        while (grid.length < 42) {
            grid.push({
                day: grid.length - daysInMonth - startWeekday + 1,
                inMonth: false,
                isToday: false,
                isHoliday: false,
                holidayName: ""
            })
        }
        return grid
    }

    // 初期化
    Component.onCompleted: {
        refreshGrid()
    }

    // 月切替時の再取得
    onCurrentYearChanged: refreshGrid()
    onCurrentMonthChanged: refreshGrid()

    // ---- サービスからの現在月名・年表示用 -----------------------------------
    readonly property string headerYear: (typeof CalendarService !== "undefined" && CalendarService !== null && CalendarService.year !== undefined)
        ? CalendarService.year.toString()
        : currentYear.toString()
    readonly property string headerMonth: (typeof CalendarService !== "undefined" && CalendarService !== null && CalendarService.monthName !== undefined)
        ? CalendarService.monthName
        : Qt.formatDate(new Date(currentYear, currentMonth - 1, 1), "MMMM")

    // ---- レイアウト ---------------------------------------------------------
    Column {
        anchors.fill: parent
        spacing: 12

        // --- ヘッダー: 年月 + ナビボタン --------------------------------------
        Row {
            width: parent.width
            height: 40
            spacing: 8

            // 左: 前月ボタン
            IconButton {
                id: prevBtn
                iconSource: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='20' height='20'><path fill='%23E8F4F2' d='M15.41 7.41L14 6l-6 6 6 6 1.41-1.41L10.83 12z'/></svg>"
                iconSize: 20
                buttonSize: 36
                tooltipText: qsTr("前月")
                onClicked: {
                    if (currentMonth === 1) {
                        currentMonth = 12
                        currentYear--
                    } else {
                        currentMonth--
                    }
                }
            }

            // 中央: 年月表示
            Item {
                // Row (positioner) 内では Layout.fillWidth は無効。
                // 前後ボタン (36×2) + spacing (8×2) を差し引いた幅を明示する。
                width: Math.max(0, parent.width - 88)
                height: parent.height

                Column {
                    anchors.centerIn: parent
                    spacing: 0

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: headerMonth
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPixelSizeTitle
                        font.weight: Font.DemiBold
                        color: Theme.textColor
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: headerYear
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPixelSizeCaption
                        color: Theme.textMuted
                    }
                }
            }

            // 右: 翌月ボタン
            IconButton {
                id: nextBtn
                iconSource: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='20' height='20'><path fill='%23E8F4F2' d='M8.59 16.59L10 18l6-6-6-6-1.41 1.41L13.17 12z'/></svg>"
                iconSize: 20
                buttonSize: 36
                tooltipText: qsTr("翌月")
                onClicked: {
                    if (currentMonth === 12) {
                        currentMonth = 1
                        currentYear++
                    } else {
                        currentMonth++
                    }
                }
            }
        }

        // --- 曜日ヘッダー -----------------------------------------------------
        Row {
            width: parent.width
            height: 28
            spacing: 0

            Repeater {
                model: weekdaysShort
                delegate: Text {
                    width: parent.width / 7
                    height: parent.height
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: modelData
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPixelSizeCaption
                    color: index === 0 || index === 6 ? Theme.accentSoft : Theme.textMuted
                }
            }
        }

        // --- 日付グリッド (6行 × 7列) -----------------------------------------
        Column {
            width: parent.width
            spacing: 4

            Repeater {
                model: 6  // 最大6週間
                delegate: Row {
                    id: weekRow
                    // int モデルの index は行番号 (0-5)。
                    required property int index
                    width: parent.width
                    height: 36
                    spacing: 0

                    Repeater {
                        model: 7
                        delegate: Item {
                            id: dayCellWrap
                            // int モデルの index は列番号 (0-6)。
                            required property int index
                            width: weekRow.width / 7
                            height: weekRow.height

                            DayCell {
                                anchors.fill: parent
                                // DayCell の required property は明示的に満たす。
                                dayData: root.getDayData(weekRow.index, dayCellWrap.index)
                                index: dayCellWrap.index
                                row: weekRow.index
                            }
                        }
                    }
                }
            }
        }
    }

    // グリッドから該当セルのデータを取得
    function getDayData(row, col) {
        const idx = row * 7 + col
        if (idx >= 0 && idx < monthGridData.length) {
            return monthGridData[idx]
        }
        return { day: "", inMonth: false, isToday: false, isHoliday: false, holidayName: "" }
    }
}