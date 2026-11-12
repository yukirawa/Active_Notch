pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import dev.yukirawa.activenotch

// ComboBox — 設定用ドロップダウン (QtQuick.Controls 2 互換ラッパー)。
//
// Theme トークンでスタイリングし、GlassCard 風の外観にする。
// 選択肢は以下の形式に対応:
//   - string[] : ["item1", "item2"]
//   - object[] : [{ text: "表示名", value: "値" }, ...]
//
// 外部からは currentText (文字列モデル) または currentValue (オブジェクト
// モデル) を Binding で駆動する。選択時は activated(index, value) を発火する。
Item {
    id: root

    // ---- 公開 API -----------------------------------------------------------
    property string currentText: ""
    property var currentValue: ""
    property var model: []          // string[] または {text, value}[] または ListModel
    property int currentIndex: -1
    property string placeholder: ""
    property string displayRole: "text"  // オブジェクト配列時の表示用プロパティ名
    property string valueRole: "value"   // オブジェクト配列時の値用プロパティ名
    signal activated(int index, var value)

    // Item の width / height をそのまま使う (呼び出し側で上書き可能)。
    width: 200
    height: 36

    readonly property real popupWidth: root.width
    readonly property real itemHeight: 36

    // 内部状態
    property bool popupOpen: false
    // 内部同期中フラグ (currentText/currentValue/currentIndex の相互更新用)
    property bool _syncing: false

    // モデルがオブジェクト配列かどうか判定
    readonly property bool isObjectModel: root.model.length > 0
        && typeof root.model[0] === "object" && root.model[0] !== null

    // 表示テキスト取得ヘルパー
    function getDisplayText(item) {
        if (item === undefined || item === null)
            return ""
        return root.isObjectModel ? String(item[root.displayRole] ?? "") : String(item)
    }

    // 値取得ヘルパー
    function getValue(item) {
        if (item === undefined || item === null)
            return ""
        return root.isObjectModel ? item[root.valueRole] : item
    }

    function indexOfValue(v) {
        for (let i = 0; i < root.model.length; ++i) {
            if (root.getValue(root.model[i]) === v)
                return i
        }
        return -1
    }

    function indexOfText(t) {
        for (let i = 0; i < root.model.length; ++i) {
            if (root.getDisplayText(root.model[i]) === t)
                return i
        }
        return -1
    }

    // currentValue / currentText から現在位置を決定する (初期化・外部更新用)。
    function syncFromCurrent() {
        let i = root.indexOfValue(root.currentValue)
        if (i < 0)
            i = root.indexOfText(root.currentText)
        if (i < 0)
            return
        root._syncing = true
        root.currentIndex = i
        root.currentText = root.getDisplayText(root.model[i])
        if (!root.isObjectModel || root.currentValue === "")
            root.currentValue = root.getValue(root.model[i])
        root._syncing = false
    }

    // ---- 背景カード (GlassCard 風) -----------------------------------------
    Rectangle {
        id: bgRect
        anchors.fill: parent
        radius: Theme.cardRadius
        color: Theme.cardBg
        border.width: Theme.borderWidth
        border.color: root.enabled ? Theme.cardBorderGlow : Theme.textMuted
        opacity: root.enabled ? 1 : 0.5
    }

    // アクア縦グラデ
    Rectangle {
        anchors.fill: bgRect
        radius: Theme.cardRadius
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.overlayTop }
            GradientStop { position: 1.0; color: Theme.overlayBottom }
        }
    }

    // 上端スペキュラ
    Rectangle {
        width: parent.width
        height: Math.max(0, Math.min(Theme.specularHeight, parent.height - Theme.cardRadius))
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.specular }
            GradientStop { position: 1.0; color: Theme.specularFade }
        }
    }

    // 発光ボーダー
    Rectangle {
        anchors.fill: bgRect
        radius: Theme.cardRadius
        color: "transparent"
        border.width: Theme.borderWidth
        border.color: Theme.cardBorderGlow
    }

    // ---- 表示テキスト + アイコン -------------------------------------------
    Row {
        id: displayRow
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 40
        spacing: 8

        Text {
            id: displayText
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            text: root.currentText.length > 0 ? root.currentText : root.placeholder
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontPixelSize
            color: root.currentText.length > 0 ? Theme.textColor : Theme.textMuted
            elide: Text.ElideRight
        }
    }

    // ドロップダウンアイコン (SVG 自体がテキスト色で描かれている)
    Image {
        id: dropdownIcon
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 18
        height: 18
        source: "image://svg/<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='18' height='18'><path fill='%23E8F4F2' d='M7 10l5 5 5-5z'/></svg>"
        rotation: root.popupOpen ? 180 : 0
        Behavior on rotation {
            SpringAnimation { mass: 0.3; spring: 3.0; damping: 0.8 }
        }
    }

    // ---- タッチ領域 ---------------------------------------------------------
    MouseArea {
        id: clickArea
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        onClicked: root.popupOpen = !root.popupOpen
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    // ---- ポップアップメニュー -----------------------------------------------
    Menu {
        id: popupMenu
        width: root.popupWidth
        x: 0
        y: root.height + 4

        background: Rectangle {
            radius: Theme.cardRadius
            color: Theme.panelBg
            border.width: Theme.borderWidth
            border.color: Theme.borderGlow
        }

        delegate: MenuItem {
            id: menuItem
            required property int index
            required property var modelData

            width: popupMenu.width
            height: root.itemHeight
            padding: 0

            contentItem: Text {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: root.getDisplayText(menuItem.modelData)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPixelSize
                color: Theme.textColor
                elide: Text.ElideRight
            }

            highlighted: menuItem.index === root.currentIndex

            onTriggered: {
                root._syncing = true
                root.currentIndex = menuItem.index
                root.currentText = root.getDisplayText(menuItem.modelData)
                root.currentValue = root.getValue(menuItem.modelData)
                root._syncing = false
                root.activated(menuItem.index, root.currentValue)
                popupMenu.close()
            }

            background: Rectangle {
                color: menuItem.highlighted ? Theme.accentSoft : "transparent"
                opacity: menuItem.highlighted ? 0.2 : 0
                Behavior on opacity { NumberAnimation { duration: 100 } }
            }
        }

        model: root.model

        onAboutToHide: root.popupOpen = false
    }

    // ポップアップ開閉制御
    onPopupOpenChanged: {
        if (root.popupOpen) {
            popupMenu.popup()
        } else {
            popupMenu.close()
        }
    }

    // ---- 外部プロパティ変更時の同期 -----------------------------------------
    onCurrentValueChanged: {
        if (root._syncing)
            return
        const i = root.indexOfValue(root.currentValue)
        if (i < 0)
            return
        root._syncing = true
        root.currentIndex = i
        root.currentText = root.getDisplayText(root.model[i])
        root._syncing = false
    }

    onCurrentIndexChanged: {
        if (root._syncing)
            return
        if (root.currentIndex < 0 || root.currentIndex >= root.model.length)
            return
        const item = root.model[root.currentIndex]
        root._syncing = true
        root.currentText = root.getDisplayText(item)
        root.currentValue = root.getValue(item)
        root._syncing = false
    }

    onCurrentTextChanged: {
        if (root._syncing || root.isObjectModel)
            return
        const i = root.indexOfText(root.currentText)
        if (i < 0)
            return
        root._syncing = true
        root.currentIndex = i
        root.currentValue = root.getValue(root.model[i])
        root._syncing = false
    }

    Component.onCompleted: {
        if (root.currentIndex < 0)
            root.syncFromCurrent()
    }
}
