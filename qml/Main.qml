import QtQuick

// ActiveNotch ルート。
//
// - C++ (NotchWindow) は QQuickView::SizeRootObjectToView +
//   resize(220, 30) でこの型 "Main" をロードするため、root のサイズは
//   ウィンドウ (= Phase 0 ではピルそのもの) に追従する。よってここでは
//   サイズを指定しない。
// - Phase 1 でウィンドウが最大サイズ固定 (660x440 程度) になっても
//   root はウィンドウに追従するため、下記の anchors による「上部中央」
//   配置はそのまま機能する。
Item {
    id: root

    // 折りたたみピル: 画面上部中央に密着
    // (Phase 1 の状態機械 Collapsed/Expanded/Pinned は Notch 内で管理)
    Notch {
        id: notch
        anchors.top: root.top
        anchors.horizontalCenter: root.horizontalCenter
    }
}
