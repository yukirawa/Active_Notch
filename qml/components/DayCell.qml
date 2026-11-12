pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import dev.yukirawa.activenotch

// DayCell — カレンダーの 1 日分セル (Calendar ページで使用)。
Item {
    id: root

    // ---- 公開プロパティ ------------------------------------------------------
    required property var dayData
    required property int index
    required property int row

    // ツールチップ表示用 (祝日名はホバー時のみ)
    property bool hovered: false

    // クリック可能領域
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: root.hovered = true
        onExited: root.hovered = false
        onClicked: {
            // 将来: 日付クリックで詳細表示など
        }
    }

    // 背景: 今日のハイライト (円形)
    Rectangle {
        id: todayBg
        width: Math.min(parent.width, parent.height) * 0.7
        height: todayBg.width
        anchors.centerIn: parent
        radius: todayBg.width / 2
        color: Theme.accent
        opacity: root.dayData.isToday && root.dayData.inMonth ? 0.25 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
    }

    // 祝日マーカー (小さなドット)
    Rectangle {
        id: holidayDot
        width: 5
        height: 5
        radius: 2.5
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        anchors.horizontalCenter: parent.horizontalCenter
        color: Theme.accent
        opacity: root.dayData.isHoliday && root.dayData.inMonth ? 1 : 0
        visible: opacity > 0
    }

    // 日付数字
    Text {
        anchors.centerIn: parent
        text: root.dayData.day
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontPixelSize
        font.weight: root.dayData.isToday ? Font.DemiBold : Font.Normal
        color: root.dayData.inMonth
            ? (root.dayData.isHoliday ? Theme.accent : (root.index === 0 || root.index === 6 ? Theme.accentSoft : Theme.textColor))
            : Theme.textMuted
        opacity: root.dayData.day ? 1 : 0
    }

    // ツールチップ (祝日名表示)
    ToolTip {
        text: root.dayData.holidayName || ""
        visible: root.hovered && root.dayData.isHoliday
            && (root.dayData.holidayName || "").length > 0
        delay: 300
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontPixelSizeCaption
    }
}