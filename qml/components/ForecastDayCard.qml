pragma ComponentBehavior: Bound
import QtQuick
import dev.yukirawa.activenotch

// ForecastDayCard — 1 日分の予報カード (Phase 4: Weather ページ用)。
Item {
    id: cardRoot
    property var dayData: {}
    readonly property real cardWidth: 96
    width: cardWidth
    height: 120

    // ---- ヘルパー関数 (Weather.qml から移植) --------------------------------
    function weatherInfo(code) {
        switch (code) {
            case 0:  return { desc: qsTr("快晴"), icon: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%23FFB300' d='M12 2.25c-5.385 0-9.75 4.365-9.75 9.75s4.365 9.75 9.75 9.75 9.75-4.365 9.75-9.75S17.385 2.25 12 2.25zm0 18c-4.553 0-8.25-3.697-8.25-8.25S7.447 5.75 12 5.75s8.25 3.697 8.25 8.25-3.697 8.25-8.25 8.25zM12 8.25a3.75 3.75 0 110 7.5 3.75 3.75 0 010-7.5z'/></svg>" }
            case 1:  return { desc: qsTr("晴れ"), icon: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%23FFB300' d='M12 2.25c-5.385 0-9.75 4.365-9.75 9.75s4.365 9.75 9.75 9.75 9.75-4.365 9.75-9.75S17.385 2.25 12 2.25zm0 18c-4.553 0-8.25-3.697-8.25-8.25S7.447 5.75 12 5.75s8.25 3.697 8.25 8.25-3.697 8.25-8.25 8.25zM12 8.25a3.75 3.75 0 110 7.5 3.75 3.75 0 010-7.5z'/><path fill='%23E8F4F2' d='M18.89 8.15a5.25 5.25 0 00-7.78 0H5.25a.75.75 0 000 1.5h5.86a5.25 5.25 0 007.78 0h5.86a.75.75 0 000-1.5h-5.86z'/></svg>" }
            case 2:  return { desc: qsTr("一部曇り"), icon: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%23FFB300' d='M12 2.25c-5.385 0-9.75 4.365-9.75 9.75s4.365 9.75 9.75 9.75 9.75-4.365 9.75-9.75S17.385 2.25 12 2.25zm0 18c-4.553 0-8.25-3.697-8.25-8.25S7.447 5.75 12 5.75s8.25 3.697 8.25 8.25-3.697 8.25-8.25 8.25zM12 8.25a3.75 3.75 0 110 7.5 3.75 3.75 0 010-7.5z'/><path fill='%239FB8B4' d='M19.5 12.75a5.25 5.25 0 01-10.5 0H5.25a.75.75 0 000 1.5h5.86a5.25 5.25 0 017.78 3.67.75.75 0 001.5 0A6.75 6.75 0 0019.5 12.75z'/></svg>" }
            case 3:  return { desc: qsTr("曇り"), icon: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%239FB8B4' d='M19.5 12.75a5.25 5.25 0 01-10.5 0H5.25a.75.75 0 000 1.5h5.86a5.25 5.25 0 017.78 3.67.75.75 0 001.5 0A6.75 6.75 0 0019.5 12.75z'/></svg>" }
            case 45: return { desc: qsTr("霧"), icon: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%239FB8B4' d='M3 7h18M3 12h18M3 17h18'/></svg>" }
            case 48: return { desc: qsTr("着氷性霧"), icon: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%239FB8B4' d='M3 7h18M3 12h18M3 17h18'/><path fill='%23E8F4F2' d='M8 5l2 4-2 4M14 5l2 4-2 4M20 5l2 4-2 4'/></svg>" }
            case 51: return { desc: qsTr("弱い霧雨"), icon: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%23FFB300' d='M12 2.25c-5.385 0-9.75 4.365-9.75 9.75s4.365 9.75 9.75 9.75 9.75-4.365 9.75-9.75S17.385 2.25 12 2.25zm0 18c-4.553 0-8.25-3.697-8.25-8.25S7.447 5.75 12 5.75s8.25 3.697 8.25 8.25-3.697 8.25-8.25 8.25zM12 8.25a3.75 3.75 0 110 7.5 3.75 3.75 0 010-7.5z'/><path fill='%237FB8B0' d='M8 16l2 4-2 4M14 16l2 4-2 4M20 16l2 4-2 4'/></svg>" }
            case 53: return { desc: qsTr("霧雨"), icon: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%237FB8B0' d='M8 16l2 4-2 4M14 16l2 4-2 4M20 16l2 4-2 4'/></svg>" }
            case 55: return { desc: qsTr("強い霧雨"), icon: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%237FB8B0' d='M8 16l2 4-2 4M14 16l2 4-2 4M20 16l2 4-2 4'/></svg>" }
            case 56: return { desc: qsTr("弱い着氷性霧雨"), icon: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%237FB8B0' d='M8 16l2 4-2 4M14 16l2 4-2 4M20 16l2 4-2 4'/><path fill='%23E8F4F2' d='M8 5l2 4-2 4M14 5l2 4-2 4M20 5l2 4-2 4'/></svg>" }
            case 57: return { desc: qsTr("強い着氷性霧雨"), icon: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%237FB8B0' d='M8 16l2 4-2 4M14 16l2 4-2 4M20 16l2 4-2 4'/><path fill='%23E8F4F2' d='M8 5l2 4-2 4M14 5l2 4-2 4M20 5l2 4-2 4'/></svg>" }
            case 61: return { desc: qsTr("弱い雨"), icon: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%23FFB300' d='M12 2.25c-5.385 0-9.75 4.365-9.75 9.75s4.365 9.75 9.75 9.75 9.75-4.365 9.75-9.75S17.385 2.25 12 2.25zm0 18c-4.553 0-8.25-3.697-8.25-8.25S7.447 5.75 12 5.75s8.25 3.697 8.25 8.25-3.697 8.25-8.25 8.25zM12 8.25a3.75 3.75 0 110 7.5 3.75 3.75 0 010-7.5z'/><path fill='%237FB8B0' d='M8 16l2 4-2 4M14 16l2 4-2 4M20 16l2 4-2 4'/></svg>" }
            case 63: return { desc: qsTr("雨"), icon: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%237FB8B0' d='M8 16l2 4-2 4M14 16l2 4-2 4M20 16l2 4-2 4'/></svg>" }
            case 65: return { desc: qsTr("強い雨"), icon: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%237FB8B0' d='M8 16l2 4-2 4M14 16l2 4-2 4M20 16l2 4-2 4'/></svg>" }
            case 66: return { desc: qsTr("弱い着氷性雨"), icon: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%237FB8B0' d='M8 16l2 4-2 4M14 16l2 4-2 4M20 16l2 4-2 4'/><path fill='%23E8F4F2' d='M8 5l2 4-2 4M14 5l2 4-2 4M20 5l2 4-2 4'/></svg>" }
            case 67: return { desc: qsTr("強い着氷性雨"), icon: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%237FB8B0' d='M8 16l2 4-2 4M14 16l2 4-2 4M20 16l2 4-2 4'/><path fill='%23E8F4F2' d='M8 5l2 4-2 4M14 5l2 4-2 4M20 5l2 4-2 4'/></svg>" }
            case 71: return { desc: qsTr("弱い雪"), icon: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%23E8F4F2' d='M12 8l-3 5 1.5 1.5L12 11l3 5L13.5 18H10.5L12 15.5 8.5 18H7.5L9 13 6 8l3-5z'/></svg>" }
            case 73: return { desc: qsTr("雪"), icon: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%23E8F4F2' d='M12 8l-3 5 1.5 1.5L12 11l3 5L13.5 18H10.5L12 15.5 8.5 18H7.5L9 13 6 8l3-5z'/></svg>" }
            case 75: return { desc: qsTr("強い雪"), icon: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%23E8F4F2' d='M12 8l-3 5 1.5 1.5L12 11l3 5L13.5 18H10.5L12 15.5 8.5 18H7.5L9 13 6 8l3-5z'/></svg>" }
            case 77: return { desc: qsTr("雪粒"), icon: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%23E8F4F2' d='M12 8l-3 5 1.5 1.5L12 11l3 5L13.5 18H10.5L12 15.5 8.5 18H7.5L9 13 6 8l3-5z'/></svg>" }
            case 80: return { desc: qsTr("弱い雨天気雨"), icon: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%23FFB300' d='M12 2.25c-5.385 0-9.75 4.365-9.75 9.75s4.365 9.75 9.75 9.75 9.75-4.365 9.75-9.75S17.385 2.25 12 2.25zm0 18c-4.553 0-8.25-3.697-8.25-8.25S7.447 5.75 12 5.75s8.25 3.697 8.25 8.25-3.697 8.25-8.25 8.25zM12 8.25a3.75 3.75 0 110 7.5 3.75 3.75 0 010-7.5z'/><path fill='%237FB8B0' d='M8 16l2 4-2 4M14 16l2 4-2 4M20 16l2 4-2 4'/></svg>" }
            case 81: return { desc: qsTr("雨天気雨"), icon: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%237FB8B0' d='M8 16l2 4-2 4M14 16l2 4-2 4M20 16l2 4-2 4'/></svg>" }
            case 82: return { desc: qsTr("激しい雨天気雨"), icon: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%237FB8B0' d='M8 16l2 4-2 4M14 16l2 4-2 4M20 16l2 4-2 4'/></svg>" }
            case 85: return { desc: qsTr("弱い雪天気雨"), icon: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%23E8F4F2' d='M12 8l-3 5 1.5 1.5L12 11l3 5L13.5 18H10.5L12 15.5 8.5 18H7.5L9 13 6 8l3-5z'/></svg>" }
            case 86: return { desc: qsTr("強い雪天気雨"), icon: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%23E8F4F2' d='M12 8l-3 5 1.5 1.5L12 11l3 5L13.5 18H10.5L12 15.5 8.5 18H7.5L9 13 6 8l3-5z'/></svg>" }
            case 95: return { desc: qsTr("雷雨"), icon: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%23FFB300' d='M13 2L3 14h9l-1 8 10-12h-9l1-8z'/><path fill='%237FB8B0' d='M8 16l2 4-2 4M14 16l2 4-2 4M20 16l2 4-2 4'/></svg>" }
            case 96: return { desc: qsTr("弱い雹を伴う雷雨"), icon: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%23FFB300' d='M13 2L3 14h9l-1 8 10-12h-9l1-8z'/><path fill='%237FB8B0' d='M8 16l2 4-2 4M14 16l2 4-2 4M20 16l2 4-2 4'/></svg>" }
            case 99: return { desc: qsTr("強い雹を伴う雷雨"), icon: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%23FFB300' d='M13 2L3 14h9l-1 8 10-12h-9l1-8z'/><path fill='%237FB8B0' d='M8 16l2 4-2 4M14 16l2 4-2 4M20 16l2 4-2 4'/></svg>" }
            default: return { desc: qsTr("不明"), icon: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><text x='50%' y='55%' font-size='32' text-anchor='middle' fill='%237FB8B0'>?</text></svg>" }
        }
    }

    function formatDate(dateStr) {
        if (!dateStr) return ""
        const parts = dateStr.split("-")
        if (parts.length !== 3) return dateStr
        const date = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]))
        const wd = [qsTr("日"), qsTr("月"), qsTr("火"), qsTr("水"), qsTr("木"), qsTr("金"), qsTr("土")]
        return qsTr("%1/%2 (%3)").arg(date.getMonth() + 1).arg(date.getDate()).arg(wd[date.getDay()])
    }

    GlassCard {
        anchors.fill: parent
        padding: 12
        radius: Theme.cardRadius

        Column {
            width: parent.width
            spacing: 6
            anchors.centerIn: parent

            // 日付
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: cardRoot.formatDate(cardRoot.dayData.date)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPixelSizeCaption
                color: Theme.textMuted
            }

            // 天気アイコン
            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                source: cardRoot.weatherInfo(cardRoot.dayData.code).icon
                width: 40
                height: 40
                fillMode: Image.PreserveAspectFit
            }

            // 天気説明 (短縮)
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: cardRoot.weatherInfo(cardRoot.dayData.code).desc
                font.family: Theme.fontFamily
                font.pixelSize: 10
                color: Theme.textColor
                elide: Text.ElideRight
            }

            // 最高/最低気温
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                Text {
                    text: "%1°".arg(Math.round(cardRoot.dayData.tmax))
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPixelSize
                    font.weight: Font.DemiBold
                    color: Theme.textColor
                }

                Text {
                    text: "%1°".arg(Math.round(cardRoot.dayData.tmin))
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPixelSize
                    color: Theme.textMuted
                }
            }
        }
    }
}