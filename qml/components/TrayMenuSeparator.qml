pragma ComponentBehavior: Bound
import QtQuick
import dev.yukirawa.activenotch

// TrayMenuSeparator — トレイメニューのセパレータ
Item {
    id: root
    width: parent ? parent.width : 268
    height: 12

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, parent.width - 16)
        height: 1
        color: Theme.borderGlow
        opacity: 0.5
    }
}