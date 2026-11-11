pragma ComponentBehavior: Bound
import QtQuick
import dev.yukirawa.activenotch

// ToggleRow — トグル付き設定行 (Quick ページ等で使用)。
Item {
    id: root

    // ---- 公開 API -----------------------------------------------------------
    property string iconSource: ""
    property string labelText: ""
    property string descriptionText: ""
    property bool isAvailable: true
    property bool checked: false
    signal toggled(bool newState)

    readonly property real rowHeight: 56
    height: rowHeight

    // 背景カード
    GlassCard {
        id: card
        anchors.fill: parent
        padding: 0
        radius: Theme.cardRadius
        opacity: root.isAvailable ? 1 : 0.5
        Behavior on opacity {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        Row {
            anchors.fill: parent
            spacing: 16

            // アイコン
            Image {
                id: iconImg
                source: root.iconSource
                width: 24
                height: 24
                anchors.verticalCenter: parent.verticalCenter
                fillMode: Image.PreserveAspectFit
                color: root.isAvailable
                    ? (root.checked ? Theme.accent : Theme.textColor)
                    : Theme.textMuted
                opacity: root.isAvailable ? 1 : 0.5
                Behavior on color {
                    ColorAnimation { duration: 150; easing.type: Easing.OutCubic }
                }
            }

            // ラベル + 説明
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: root.labelText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPixelSize
                    font.weight: Font.Medium
                    color: root.isAvailable ? Theme.textColor : Theme.textMuted
                }

                Text {
                    visible: root.descriptionText.length > 0
                    text: root.descriptionText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPixelSizeCaption
                    color: root.isAvailable ? Theme.textMuted : Theme.textMuted
                }
            }

            // 右側: トグルスイッチ
            ToggleSwitch {
                id: toggleSwitch
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: root.checked
                enabled: root.isAvailable
                onToggled: root.toggled(checked)
            }
        }
    }

    // クリックでトグル (カード全体をタッチターゲットに)
    MouseArea {
        anchors.fill: card
        hoverEnabled: true
        onClicked: {
            if (root.isAvailable) {
                toggleSwitch.checked = !toggleSwitch.checked
            }
        }
        cursorShape: root.isAvailable ? Qt.PointingHandCursor : Qt.ArrowCursor
    }
}