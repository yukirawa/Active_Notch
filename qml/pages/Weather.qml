pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import dev.yukirawa.activenotch

// Weather — 天気情報ページ (Phase 4)。
//
// WeatherService から現在の天気・5日間予報を取得し表示する。
// - 現在の天気: 気温/天気コード→絵文字/アイコン/風速/湿度/場所名
// - 日別予報: 5日間 (日付/最低/最高/天気コード)
// - 更新ボタン (refresh)、位置設定 (将来)
// - available=false 時「天気データ取得不可」表示
Item {
    id: root
    width: parent ? parent.width : 604
    height: parent ? parent.height : 380

    // =========================================================================
    // WeatherService プロパティ (typeof ガード付き)
    // =========================================================================
    readonly property bool available: (typeof WeatherService !== "undefined" && WeatherService !== null && WeatherService.available !== undefined)
        ? WeatherService.available
        : false
    readonly property real tempC: (typeof WeatherService !== "undefined" && WeatherService !== null && WeatherService.tempC !== undefined)
        ? WeatherService.tempC
        : 0
    readonly property int code: (typeof WeatherService !== "undefined" && WeatherService !== null && WeatherService.code !== undefined)
        ? WeatherService.code
        : 0
    readonly property string codeText: (typeof WeatherService !== "undefined" && WeatherService !== null && WeatherService.codeText !== undefined)
        ? WeatherService.codeText
        : qsTr("不明")
    readonly property real windKmh: (typeof WeatherService !== "undefined" && WeatherService !== null && WeatherService.windKmh !== undefined)
        ? WeatherService.windKmh
        : 0
    readonly property int humidity: (typeof WeatherService !== "undefined" && WeatherService !== null && WeatherService.humidity !== undefined)
        ? WeatherService.humidity
        : 0
    readonly property string locationText: (typeof WeatherService !== "undefined" && WeatherService !== null && WeatherService.locationText !== undefined)
        ? WeatherService.locationText
        : qsTr("位置不明")
    readonly property var daily: (typeof WeatherService !== "undefined" && WeatherService !== null && WeatherService.daily !== undefined)
        ? WeatherService.daily
        : []

    // =========================================================================
    // 内部状態
    // =========================================================================
    property bool refreshing: false

    // =========================================================================
    // ヘルパー関数: WMO 天気コード → 絵文字 / アイコン / 日本語説明
    // =========================================================================
    // WMO weather codes: https://www.nodc.noaa.gov/archive/arc0021/0002199/1.1/data/0-data/HTML/WMO-CODE/WMO4677.HTM
    // Open-Meteo 使用コード参照
    function weatherInfo(code) {
        // { emoji, iconSvg, description }
        switch (code) {
            case 0:  return { emoji: "☀️",  desc: qsTr("快晴"),       icon: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%23FFB300' d='M12 2.25c-5.385 0-9.75 4.365-9.75 9.75s4.365 9.75 9.75 9.75 9.75-4.365 9.75-9.75S17.385 2.25 12 2.25zm0 18c-4.553 0-8.25-3.697-8.25-8.25S7.447 5.75 12 5.75s8.25 3.697 8.25 8.25-3.697 8.25-8.25 8.25zM12 8.25a3.75 3.75 0 110 7.5 3.75 3.75 0 010-7.5z'/></svg>" }
            case 1:  return { emoji: "🌤️",  desc: qsTr("晴れ"),        icon: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%23FFB300' d='M12 2.25c-5.385 0-9.75 4.365-9.75 9.75s4.365 9.75 9.75 9.75 9.75-4.365 9.75-9.75S17.385 2.25 12 2.25zm0 18c-4.553 0-8.25-3.697-8.25-8.25S7.447 5.75 12 5.75s8.25 3.697 8.25 8.25-3.697 8.25-8.25 8.25zM12 8.25a3.75 3.75 0 110 7.5 3.75 3.75 0 010-7.5z'/><path fill='%23E8F4F2' d='M18.89 8.15a5.25 5.25 0 00-7.78 0H5.25a.75.75 0 000 1.5h5.86a5.25 5.25 0 007.78 0h5.86a.75.75 0 000-1.5h-5.86z'/></svg>" }
            case 2:  return { emoji: "⛅",   desc: qsTr("一部曇り"),    icon: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%23FFB300' d='M12 2.25c-5.385 0-9.75 4.365-9.75 9.75s4.365 9.75 9.75 9.75 9.75-4.365 9.75-9.75S17.385 2.25 12 2.25zm0 18c-4.553 0-8.25-3.697-8.25-8.25S7.447 5.75 12 5.75s8.25 3.697 8.25 8.25-3.697 8.25-8.25 8.25zM12 8.25a3.75 3.75 0 110 7.5 3.75 3.75 0 010-7.5z'/><path fill='%239FB8B4' d='M19.5 12.75a5.25 5.25 0 01-10.5 0H5.25a.75.75 0 000 1.5h5.86a5.25 5.25 0 017.78 3.67.75.75 0 001.5 0A6.75 6.75 0 0019.5 12.75z'/></svg>" }
            case 3:  return { emoji: "☁️",   desc: qsTr("曇り"),        icon: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%239FB8B4' d='M19.5 12.75a5.25 5.25 0 01-10.5 0H5.25a.75.75 0 000 1.5h5.86a5.25 5.25 0 017.78 3.67.75.75 0 001.5 0A6.75 6.75 0 0019.5 12.75z'/></svg>" }
            case 45: return { emoji: "🌫️",  desc: qsTr("霧"),          icon: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%239FB8B4' d='M3 7h18M3 12h18M3 17h18'/></svg>" }
            case 48: return { emoji: "🌫️",  desc: qsTr("着氷性霧"),     icon: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%239FB8B4' d='M3 7h18M3 12h18M3 17h18'/><path fill='%23E8F4F2' d='M8 5l2 4-2 4M14 5l2 4-2 4M20 5l2 4-2 4'/></svg>" }
            case 51: return { emoji: "🌦️",  desc: qsTr("弱い霧雨"),      icon: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%23FFB300' d='M12 2.25c-5.385 0-9.75 4.365-9.75 9.75s4.365 9.75 9.75 9.75 9.75-4.365 9.75-9.75S17.385 2.25 12 2.25zm0 18c-4.553 0-8.25-3.697-8.25-8.25S7.447 5.75 12 5.75s8.25 3.697 8.25 8.25-3.697 8.25-8.25 8.25zM12 8.25a3.75 3.75 0 110 7.5 3.75 3.75 0 010-7.5z'/><path fill='%237FB8B0' d='M8 16l2 4-2 4M14 16l2 4-2 4M20 16l2 4-2 4'/></svg>" }
            case 53: return { emoji: "🌧️",  desc: qsTr("霧雨"),          icon: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%237FB8B0' d='M8 16l2 4-2 4M14 16l2 4-2 4M20 16l2 4-2 4'/></svg>" }
            case 55: return { emoji: "🌧️",  desc: qsTr("強い霧雨"),      icon: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%237FB8B0' d='M8 16l2 4-2 4M14 16l2 4-2 4M20 16l2 4-2 4'/></svg>" }
            case 56: return { emoji: "🌧️",  desc: qsTr("弱い着氷性霧雨"), icon: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%237FB8B0' d='M8 16l2 4-2 4M14 16l2 4-2 4M20 16l2 4-2 4'/><path fill='%23E8F4F2' d='M8 5l2 4-2 4M14 5l2 4-2 4M20 5l2 4-2 4'/></svg>" }
            case 57: return { emoji: "🌧️",  desc: qsTr("強い着氷性霧雨"), icon: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%237FB8B0' d='M8 16l2 4-2 4M14 16l2 4-2 4M20 16l2 4-2 4'/><path fill='%23E8F4F2' d='M8 5l2 4-2 4M14 5l2 4-2 4M20 5l2 4-2 4'/></svg>" }
            case 61: return { emoji: "🌦️",  desc: qsTr("弱い雨"),        icon: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%23FFB300' d='M12 2.25c-5.385 0-9.75 4.365-9.75 9.75s4.365 9.75 9.75 9.75 9.75-4.365 9.75-9.75S17.385 2.25 12 2.25zm0 18c-4.553 0-8.25-3.697-8.25-8.25S7.447 5.75 12 5.75s8.25 3.697 8.25 8.25-3.697 8.25-8.25 8.25zM12 8.25a3.75 3.75 0 110 7.5 3.75 3.75 0 010-7.5z'/><path fill='%237FB8B0' d='M8 16l2 4-2 4M14 16l2 4-2 4M20 16l2 4-2 4'/></svg>" }
            case 63: return { emoji: "🌧️",  desc: qsTr("雨"),            icon: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%237FB8B0' d='M8 16l2 4-2 4M14 16l2 4-2 4M20 16l2 4-2 4'/></svg>" }
            case 65: return { emoji: "🌧️",  desc: qsTr("強い雨"),        icon: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%237FB8B0' d='M8 16l2 4-2 4M14 16l2 4-2 4M20 16l2 4-2 4'/></svg>" }
            case 66: return { emoji: "🌧️",  desc: qsTr("弱い着氷性雨"),  icon: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%237FB8B0' d='M8 16l2 4-2 4M14 16l2 4-2 4M20 16l2 4-2 4'/><path fill='%23E8F4F2' d='M8 5l2 4-2 4M14 5l2 4-2 4M20 5l2 4-2 4'/></svg>" }
            case 67: return { emoji: "🌧️",  desc: qsTr("強い着氷性雨"),  icon: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%237FB8B0' d='M8 16l2 4-2 4M14 16l2 4-2 4M20 16l2 4-2 4'/><path fill='%23E8F4F2' d='M8 5l2 4-2 4M14 5l2 4-2 4M20 5l2 4-2 4'/></svg>" }
            case 71: return { emoji: "🌨️",  desc: qsTr("弱い雪"),        icon: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%23E8F4F2' d='M12 8l-3 5 1.5 1.5L12 11l3 5L13.5 18H10.5L12 15.5 8.5 18H7.5L9 13 6 8l3-5z'/></svg>" }
            case 73: return { emoji: "🌨️",  desc: qsTr("雪"),            icon: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%23E8F4F2' d='M12 8l-3 5 1.5 1.5L12 11l3 5L13.5 18H10.5L12 15.5 8.5 18H7.5L9 13 6 8l3-5z'/></svg>" }
            case 75: return { emoji: "🌨️",  desc: qsTr("強い雪"),        icon: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%23E8F4F2' d='M12 8l-3 5 1.5 1.5L12 11l3 5L13.5 18H10.5L12 15.5 8.5 18H7.5L9 13 6 8l3-5z'/></svg>" }
            case 77: return { emoji: "🌨️",  desc: qsTr("雪粒"),          icon: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%23E8F4F2' d='M12 8l-3 5 1.5 1.5L12 11l3 5L13.5 18H10.5L12 15.5 8.5 18H7.5L9 13 6 8l3-5z'/></svg>" }
            case 80: return { emoji: "🌦️",  desc: qsTr("弱い雨天気雨"),   icon: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%23FFB300' d='M12 2.25c-5.385 0-9.75 4.365-9.75 9.75s4.365 9.75 9.75 9.75 9.75-4.365 9.75-9.75S17.385 2.25 12 2.25zm0 18c-4.553 0-8.25-3.697-8.25-8.25S7.447 5.75 12 5.75s8.25 3.697 8.25 8.25-3.697 8.25-8.25 8.25zM12 8.25a3.75 3.75 0 110 7.5 3.75 3.75 0 010-7.5z'/><path fill='%237FB8B0' d='M8 16l2 4-2 4M14 16l2 4-2 4M20 16l2 4-2 4'/></svg>" }
            case 81: return { emoji: "🌧️",  desc: qsTr("雨天気雨"),      icon: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%237FB8B0' d='M8 16l2 4-2 4M14 16l2 4-2 4M20 16l2 4-2 4'/></svg>" }
            case 82: return { emoji: "🌧️",  desc: qsTr("激しい雨天気雨"), icon: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%237FB8B0' d='M8 16l2 4-2 4M14 16l2 4-2 4M20 16l2 4-2 4'/></svg>" }
            case 85: return { emoji: "🌨️",  desc: qsTr("弱い雪天気雨"),   icon: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%23E8F4F2' d='M12 8l-3 5 1.5 1.5L12 11l3 5L13.5 18H10.5L12 15.5 8.5 18H7.5L9 13 6 8l3-5z'/></svg>" }
            case 86: return { emoji: "🌨️",  desc: qsTr("強い雪天気雨"),   icon: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%23E8F4F2' d='M12 8l-3 5 1.5 1.5L12 11l3 5L13.5 18H10.5L12 15.5 8.5 18H7.5L9 13 6 8l3-5z'/></svg>" }
            case 95: return { emoji: "⛈️",  desc: qsTr("雷雨"),          icon: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%23FFB300' d='M13 2L3 14h9l-1 8 10-12h-9l1-8z'/><path fill='%237FB8B0' d='M8 16l2 4-2 4M14 16l2 4-2 4M20 16l2 4-2 4'/></svg>" }
            case 96: return { emoji: "⛈️",  desc: qsTr("弱い雹を伴う雷雨"),icon: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%23FFB300' d='M13 2L3 14h9l-1 8 10-12h-9l1-8z'/><path fill='%237FB8B0' d='M8 16l2 4-2 4M14 16l2 4-2 4M20 16l2 4-2 4'/></svg>" }
            case 99: return { emoji: "⛈️",  desc: qsTr("強い雹を伴う雷雨"),icon: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><path fill='%23FFB300' d='M13 2L3 14h9l-1 8 10-12h-9l1-8z'/><path fill='%237FB8B0' d='M8 16l2 4-2 4M14 16l2 4-2 4M20 16l2 4-2 4'/></svg>" }
            default: return { emoji: "❓",   desc: qsTr("不明"),        icon: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64'><text x='50%' y='55%' font-size='32' text-anchor='middle' fill='%237FB8B0'>?</text></svg>" }
        }
    }

    // 風速 km/h → m/s 表示用
    function formatWind(kmh) {
        const ms = kmh / 3.6
        return qsTr("%1 m/s").arg(ms.toFixed(1))
    }

    // 日付文字列 (YYYY-MM-DD) → "M/d (曜日)"
    function formatDate(dateStr) {
        if (!dateStr) return ""
        const parts = dateStr.split("-")
        if (parts.length !== 3) return dateStr
        const date = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]))
        const wd = [qsTr("日"), qsTr("月"), qsTr("火"), qsTr("水"), qsTr("木"), qsTr("金"), qsTr("土")]
        return qsTr("%1/%2 (%3)").arg(date.getMonth() + 1).arg(date.getDate()).arg(wd[date.getDay()])
    }

    // =========================================================================
    // アクション
    // =========================================================================
    function onRefresh() {
        if (typeof WeatherService !== "undefined" && WeatherService !== null && WeatherService.refresh) {
            WeatherService.refresh()
        }
    }

    // =========================================================================
    // レイアウト
    // =========================================================================
    Column {
        anchors.fill: parent
        anchors.margins: Theme.panelPadding
        spacing: 16

        // --- ヘッダー ---------------------------------------------------------
        Row {
            width: parent.width
            height: 36
            spacing: 12

            Image {
                source: root.available
                    ? root.weatherInfo(root.code).icon
                    : "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24'><path fill='%237FB8B0' d='M12 2.25c-5.385 0-9.75 4.365-9.75 9.75s4.365 9.75 9.75 9.75 9.75-4.365 9.75-9.75S17.385 2.25 12 2.25zm0 18c-4.553 0-8.25-3.697-8.25-8.25S7.447 5.75 12 5.75s8.25 3.697 8.25 8.25-3.697 8.25-8.25 8.25zM12 8.25a3.75 3.75 0 110 7.5 3.75 3.75 0 010-7.5z'/></svg>"
                width: 24
                height: 24
                anchors.verticalCenter: parent.verticalCenter
                fillMode: Image.PreserveAspectFit
                color: root.available ? Theme.accentSoft : Theme.textMuted
                opacity: root.available ? 1 : 0.5
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    text: root.available ? qsTr("天気") : qsTr("天気データ取得不可")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPixelSizeTitle
                    font.weight: Font.DemiBold
                    color: root.available ? Theme.textColor : Theme.textMuted
                }

                Text {
                    visible: root.available
                    text: qsTr("現在の天気と 5 日間予報")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPixelSizeCaption
                    color: Theme.textMuted
                }
            }

            // 更新ボタン
            Item {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                IconButton {
                    iconSource: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='20' height='20'><path fill='%23E8F4F2' d='M17.65 6.35A7.958 7.958 0 0012 4C7.42 4 3.73 7.02 2.47 10.93l2.14 2.14A5.942 5.942 0 0112 6c2.48 0 4.56 1.48 5.51 3.49l1.64-1.64zm-11.3 11.3A7.958 7.958 0 0012 20c4.58 0 8.27-3.02 9.53-6.93l-2.14-2.14A5.942 5.942 0 0112 18c-2.48 0-4.56-1.48-5.51-3.49L2.35 17.65zM12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8z'/></svg>"
                    iconSize: 20
                    buttonSize: 36
                    tooltipText: qsTr("天気データを更新")
                    enabled: root.available
                    onClicked: root.onRefresh()
                }
            }
        }

        // --- 現在の天気カード -------------------------------------------------
        Item {
            id: currentWeatherCard
            width: parent.width
            visible: root.available

            GlassCard {
                anchors.fill: parent
                padding: 20
                radius: Theme.cardRadius

                Row {
                    width: parent.width
                    spacing: 24

                    // 左: 天気アイコン + 気温
                    Column {
                        width: 140
                        spacing: 8
                        anchors.verticalCenter: parent.verticalCenter

                        // 天気アイコン (大きめ)
                        Image {
                            id: currentWeatherIcon
                            source: root.weatherInfo(root.code).icon
                            width: 96
                            height: 96
                            anchors.horizontalCenter: parent.horizontalCenter
                            fillMode: Image.PreserveAspectFit
                        }

                        // 天気説明
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.weatherInfo(root.code).desc
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontPixelSize
                            color: Theme.textColor
                        }
                    }

                    // 右: 詳細情報
                    Column {
                        width: parent.width - 164
                        spacing: 10
                        anchors.verticalCenter: parent.verticalCenter

                        // 気温 (大きく)
                        Text {
                            text: "%1°C".arg(root.tempC.toFixed(1))
                            font.family: Theme.fontFamily
                            font.pixelSize: 48
                            font.weight: Font.DemiBold
                            color: Theme.textColor
                        }

                        // 場所
                        Text {
                            text: root.locationText
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontPixelSizeCaption
                            color: Theme.textMuted
                        }

                        // 詳細グリッド (風速 / 湿度)
                        GridLayout {
                            width: parent.width
                            columns: 2
                            rowSpacing: 8
                            columnSpacing: 16

                            // 風速
                            DetailItem {
                                Layout.fillWidth: true
                                iconSource: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='20' height='20'><path fill='%237FB8B0' d='M9.59 4.59A2 2 0 1111 8H2m10.59 11.41A2 2 0 1013 18H2m15.73-7.73A2 2 0 1113.41 8H2m-1.42 8.42A2 2 0 1010.59 18H2'/></svg>"
                                label: qsTr("風速")
                                value: root.formatWind(root.windKmh)
                                valueColor: Theme.textColor
                            }

                            // 湿度
                            DetailItem {
                                Layout.fillWidth: true
                                iconSource: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='20' height='20'><path fill='%237FB8B0' d='M12 2.69l5.66 5.66a8 8 0 11-11.31 0z'/></svg>"
                                label: qsTr("湿度")
                                value: "%1%".arg(root.humidity)
                                valueColor: Theme.textColor
                            }
                        }
                    }
                }
            }
        }

        // --- 5日間予報 ---------------------------------------------------------
        Item {
            id: forecastSection
            width: parent.width
            Layout.fillHeight: true
            visible: root.available && root.daily.length > 0

            Column {
                width: parent.width
                spacing: 8

                // セクションヘッダー
                Text {
                    text: qsTr("5日間予報")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPixelSize
                    font.weight: Font.Medium
                    color: Theme.textColor
                }

                // 予報リスト (横スクロール)
                Flickable {
                    width: parent.width
                    height: 120
                    clip: true
                    flickableDirection: Flickable.HorizontalFlick
                    boundsBehavior: Flickable.DragOverBounds
                    contentWidth: forecastRow.implicitWidth + 16
                    contentHeight: 120

                    Row {
                        id: forecastRow
                        spacing: 12
                        height: 120

                        Repeater {
                            model: root.daily
                            delegate: ForecastDayCard {
                                required property var modelData
                                dayData: modelData
                            }
                        }
                    }
                }
            }
        }

        // --- 利用不可時のフォールバックカード ---------------------------------
        Item {
            id: unavailableCard
            width: parent.width
            Layout.fillHeight: true
            visible: !root.available

            GlassCard {
                anchors.fill: parent
                padding: 24
                radius: Theme.cardRadius

                Column {
                    anchors.centerIn: parent
                    spacing: 12

                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        source: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='48' height='48'><path fill='%237FB8B0' d='M12 2.25c-5.385 0-9.75 4.365-9.75 9.75s4.365 9.75 9.75 9.75 9.75-4.365 9.75-9.75S17.385 2.25 12 2.25zm0 18c-4.553 0-8.25-3.697-8.25-8.25S7.447 5.75 12 5.75s8.25 3.697 8.25 8.25-3.697 8.25-8.25 8.25zM12 8.25a3.75 3.75 0 110 7.5 3.75 3.75 0 010-7.5z'/></svg>"
                        color: Theme.accentSoft
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("天気データを取得できません")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPixelSize
                        font.weight: Font.DemiBold
                        color: Theme.textColor
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("WeatherService (Open-Meteo API) が実装されていないか、\nネットワーク接続に問題があります。")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPixelSizeCaption
                        color: Theme.textMuted
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }
}