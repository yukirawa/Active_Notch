import QtQuick

// ActiveNotch ルート。
//
// - C++ (NotchWindow) は QQuickView::SizeRootObjectToView でこの型 "Main" を
//   ロードするため、root のサイズはウィンドウ (Phase 1 から 660x448 論理px 固定)
//   に追従する。ここではサイズを指定しない。
// - Notch は Notch.qml 側で anchors.fill: parent を宣言しており、全ウィンドウを
//   覆う。これにより:
//     * 展開 shape は QML 内部のジオメトリでモーフする (ウィンドウはリサイズしない)
//     * pinned 時は pinCatcher が全ウィンドウ領域のクリック (ノッチ外) を受ける
// - C++ は findChild<QQuickItem*>("notch") + shapeSettled シグナルで
//   入力領域マスクを更新する (docs/CONTRACT.md §2)。
Item {
    id: root

    // 状態機械 (Collapsed/Expanded/Pinned) と開閉アニメは Notch 内で管理
    Notch {
        id: notch
    }
}
