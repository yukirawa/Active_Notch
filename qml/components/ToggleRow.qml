pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
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

        RowLayout {
            anchors.fill: parent
            spacing: 16

            // アイコン
            // Qt 6 の Image に color (ティント) は無いため、SVG の塗り色を
            // そのまま使い、状態は opacity で表現する。
            Image {
                id: iconImg
                source: root.iconSource
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                Layout.alignment: Qt.AlignVCenter
                fillMode: Image.PreserveAspectFit
                opacity: root.isAvailable ? (root.checked ? 1.0 : 0.85) : 0.5
                Behavior on opacity {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }
            }

            // ラベル + 説明
            Column {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
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
                    color: Theme.textMuted
                }
            }

            // 右側: トグルスイッチ
            ToggleSwitch {
                id: toggleSwitch
                Layout.alignment: Qt.AlignVCenter
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