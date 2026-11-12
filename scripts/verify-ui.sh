#!/usr/bin/env bash
# ActiveNotch: 自動視覚検証。
#
#   1. ビルド
#   2. ACTIVENOTCH_PRINT_GEOMETRY=1 でバックグラウンド起動
#   3. GEOMETRY / MASK 行を stdout からパース
#   4. spectacle で全画面スクリーンショット
#   5. magick で配置・サイズ・色の差分を検証し PASS/FAIL 表を出力
#
# 成果物は scripts/artifacts/ に保存する。全項目 PASS のときだけ exit 0。
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ARTIFACT_DIR="$ROOT_DIR/scripts/artifacts"
mkdir -p "$ARTIFACT_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
SHOT="$ARTIFACT_DIR/verify-ui-$STAMP.png"
GRAB="$ARTIFACT_DIR/verify-ui-$STAMP-grab.png"
STDOUT_LOG="$ARTIFACT_DIR/verify-ui-$STAMP.stdout.log"
STDERR_LOG="$ARTIFACT_DIR/verify-ui-$STAMP.stderr.log"

APP_PID=""
cleanup() {
    if [[ -n "$APP_PID" ]] && kill -0 "$APP_PID" 2>/dev/null; then
        kill "$APP_PID" 2>/dev/null || true
        wait "$APP_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM

# ---- 0. 事前チェック -----------------------------------------------------
if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
    echo "❌ Wayland セッションではありません (WAYLAND_DISPLAY 未設定)" >&2
    exit 1
fi
for tool in spectacle magick; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "❌ 必要なコマンドがありません: $tool" >&2
        exit 1
    fi
done

# ---- 1. ビルド -----------------------------------------------------------
echo "==> ビルド"
if ! ./scripts/dev.sh; then
    echo "❌ ビルド失敗のため視覚検証を中止します" >&2
    exit 1
fi

# ---- 2. 起動 -------------------------------------------------------------
echo "==> ActiveNotch を起動 (ACTIVENOTCH_PRINT_GEOMETRY=1, ACTIVENOTCH_GRAB)"
QT_FORCE_STDERR_LOGGING=1 ACTIVENOTCH_PRINT_GEOMETRY=1 ACTIVENOTCH_GRAB="$GRAB" \
    ./build/activenotch >"$STDOUT_LOG" 2>"$STDERR_LOG" &
APP_PID=$!

# 描画・configure の完了を待つ。
sleep 2.5

if ! kill -0 "$APP_PID" 2>/dev/null; then
    echo "❌ アプリが起動直後に終了しました。stderr:" >&2
    tail -n 40 "$STDERR_LOG" >&2 || true
    exit 1
fi

# ---- 3. ジオメトリ行のパース --------------------------------------------
# 座標系は C++ 側で論理px に統一済み (マルチモニタ + 混合 DPR 対応)。
GEOMETRY_LINE="$(grep -m1 '^GEOMETRY ' "$STDOUT_LOG" || true)"
SCREEN_LINE="$(grep -m1 '^SCREEN ' "$STDOUT_LOG" || true)"
MASK_LINE="$(grep '^MASK ' "$STDOUT_LOG" | tail -n1 || true)"
GRAB_LINE="$(grep -m1 '^GRAB ' "$STDOUT_LOG" || true)"

field() {
    # $1 = キー, $2 = "KEY x=1 y=2 ..." 形式の行
    awk -v key="$1" '{
        for (i = 1; i <= NF; i++) {
            split($i, kv, "=");
            if (kv[1] == key) { print kv[2]; exit }
        }
    }' <<<"$2"
}

# ---- 4. スクリーンショット ----------------------------------------------
echo "==> スクリーンショットを撮影"
if ! spectacle -b -n -f -o "$SHOT" >/dev/null 2>&1 || [[ ! -s "$SHOT" ]]; then
    echo "❌ spectacle によるスクリーンショット取得に失敗しました" >&2
    exit 1
fi

IMG_W="$(magick identify -format '%w' "$SHOT")"
IMG_H="$(magick identify -format '%h' "$SHOT")"

FAIL_COUNT=0
print_result() {
    # $1=項目 $2=PASS/FAIL $3=詳細
    printf '%-44s %-6s %s\n' "$1" "$2" "$3"
    if [[ "$2" == "FAIL" ]]; then
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

echo
echo "===== verify-ui 結果 (画面 ${IMG_W}x${IMG_H}) ====="
printf '%-44s %-6s %s\n' "検証項目" "結果" "詳細"
printf '%-44s %-6s %s\n' "--------------------------------------------" "------" "----"

# GEOMETRY / MASK が取れているか
if [[ -z "$GEOMETRY_LINE" || -z "$MASK_LINE" ]]; then
    print_result "GEOMETRY/MASK 行の出力" "FAIL" \
        "stdout に出力がありません (ACTIVENOTCH_PRINT_GEOMETRY を確認)"
    echo
    echo "--- stdout (tail) ---"
    tail -n 20 "$STDOUT_LOG" || true
    echo "--- stderr (tail) ---"
    tail -n 20 "$STDERR_LOG" || true
    echo
    echo "成果物: $ARTIFACT_DIR"
    exit 1
fi

print_result "GEOMETRY/MASK 行の出力" "PASS" "x/y/w/h/scale を取得"

GX="$(field x "$GEOMETRY_LINE")"
GY="$(field y "$GEOMETRY_LINE")"
GW="$(field w "$GEOMETRY_LINE")"
GH="$(field h "$GEOMETRY_LINE")"
GSCALE="$(field scale "$GEOMETRY_LINE")"
GSCREEN="$(field screen "$GEOMETRY_LINE")"

MX="$(field x "$MASK_LINE")"
MY="$(field y "$MASK_LINE")"
MW="$(field w "$MASK_LINE")"
MH="$(field h "$MASK_LINE")"

# SCREEN: アプリが配置されている出力の論理ジオメトリ (マルチモニタ対応)
SX="$(field x "$SCREEN_LINE")"
SY="$(field y "$SCREEN_LINE")"
SW="$(field w "$SCREEN_LINE")"
SH="$(field h "$SCREEN_LINE")"
SDPR="$(field dpr "$SCREEN_LINE")"
SNAME="$(field name "$SCREEN_LINE")"

printf '  GEOMETRY: x=%s y=%s w=%s h=%s scale=%s screen=%s\n' \
    "$GX" "$GY" "$GW" "$GH" "$GSCALE" "$GSCREEN"
printf '  SCREEN  : x=%s y=%s w=%s h=%s dpr=%s name=%s\n' \
    "$SX" "$SY" "$SW" "$SH" "$SDPR" "$SNAME"
printf '  MASK    : x=%s y=%s w=%s h=%s (論理px)\n\n' "$MX" "$MY" "$MW" "$MH"

# MASK 中心 (論理) と、その出力 (SCREEN) の中心 (論理)
MASK_CX="$(awk -v x="$MX" -v w="$MW" 'BEGIN { print x + w/2 }')"
MASK_CY="$(awk -v y="$MY" -v h="$MH" 'BEGIN { print y + h/2 }')"
SCREEN_CX="$(awk -v x="$SX" -v w="$SW" 'BEGIN { print x + w/2 }')"
CENTER_DIFF="$(awk -v a="$MASK_CX" -v b="$SCREEN_CX" 'BEGIN { printf "%d", a - b }')"
CENTER_ABS="${CENTER_DIFF#-}"

# ---- (a) 配置先の出力の水平中央 ------------------------------------------
# デスクトップ全体の中央ではなく「アプリが載っている出力 (SCREEN)」の
# 中央と比較する。これがマルチモニタで正しい判定になる。
if (( CENTER_ABS <= 2 )); then
    print_result "(a) MASK 中心が配置先出力の中央 (±2px)" "PASS" \
        "mask_cx=${MASK_CX} screen_cx=${SCREEN_CX} (${SNAME}) 差=${CENTER_DIFF}px"
else
    print_result "(a) MASK 中心が配置先出力の中央 (±2px)" "FAIL" \
        "mask_cx=${MASK_CX} screen_cx=${SCREEN_CX} (${SNAME}) 差=${CENTER_DIFF}px"
fi

# ---- (b) MASK サイズ (論理px) --------------------------------------------
# collapsed ピルは論理 220x30。C++ の出力も論理px なので DPR 倍しない。
EXPECTED_MW=220
EXPECTED_MH=30
MW_DIFF=$((MW - EXPECTED_MW))
MH_DIFF=$((MH - EXPECTED_MH))
MW_DIFF_ABS=${MW_DIFF#-}
MH_DIFF_ABS=${MH_DIFF#-}
if (( MW_DIFF_ABS <= 2 && MH_DIFF_ABS <= 2 )); then
    print_result "(b) MASK がピル相当サイズ" "PASS" \
        "${MW}x${MH}px (期待 ${EXPECTED_MW}x${EXPECTED_MH} 論理px)"
else
    print_result "(b) MASK がピル相当サイズ" "FAIL" \
        "${MW}x${MH}px (期待 ${EXPECTED_MW}x${EXPECTED_MH} 論理px, 許容 ±2px)"
fi

# ---- (c) 自ウィンドウ grab で「描画」と「外側透過」を検証 -----------------
# 壁紙がアニメーションするため、スクリーンショットの色差分は不安定。
# ACTIVENOTCH_GRAB でアプリ自身のウィンドウ (alpha 付き) を取り出し、
# ピル中心が不透明・ピル外が完全透過であることを直接確認する。
GRAB_W="$(field w "$GRAB_LINE")"
GRAB_H="$(field h "$GRAB_LINE")"
GRAB_SCALE="$(awk -v g="$GRAB_W" -v w="$GW" 'BEGIN {
    if (w > 0) printf "%.4f", g / w; else print "1"
}')"

# ウィンドウの配置原点 (論理px)。layer-shell の AnchorTop + 中央寄せ。
WIN_X="$(awk -v sx="$SX" -v sw="$SW" -v gw="$GW" 'BEGIN { printf "%d", sx + (sw - gw) / 2 }')"
WIN_Y="$SY"

grab_x() { awk -v v="$1" -v s="$GRAB_SCALE" 'BEGIN { printf "%d", v*s + 0.5 }'; }

# ピル中心 (ウィンドウローカル → grab 座標)
PILL_LX=$((MX - WIN_X + MW / 2))
PILL_LY=$((MY - WIN_Y + MH / 2))
PILL_GX="$(grab_x "$PILL_LX")"
PILL_GY="$(grab_x "$PILL_LY")"
# ピル外の参照点 (ウィンドウ左下寄り。collapsed では必ず透明)
OUT_GX="$(grab_x 60)"
OUT_GY="$(grab_x $((GH - 60)))"

grab_alpha() {
    magick "$GRAB" -crop "1x1+$1+$2" +repage -format '%[fx:round(255*a)]' info:
}

if [[ -z "$GRAB_LINE" || ! -s "$GRAB" ]]; then
    print_result "(c) ノッチが描画され外側が透過" "FAIL" \
        "自ウィンドウ grab が取得できませんでした (GRAB 行なし)"
else
    PILL_ALPHA="$(grab_alpha "$PILL_GX" "$PILL_GY")"
    OUT_ALPHA="$(grab_alpha "$OUT_GX" "$OUT_GY")"
    if (( PILL_ALPHA >= 100 && OUT_ALPHA == 0 )); then
        print_result "(c) ノッチが描画され外側が透過" "PASS" \
            "pill_alpha=${PILL_ALPHA} outside_alpha=${OUT_ALPHA} (grab ${GRAB_W}x${GRAB_H})"
    else
        print_result "(c) ノッチが描画され外側が透過" "FAIL" \
            "pill_alpha=${PILL_ALPHA} (>=100) outside_alpha=${OUT_ALPHA} (==0)"
    fi
fi

# ---- (d) 入力マスクはピル領域のみ ----------------------------------------
# setMask() により MASK 外はクリック透過になる。マスクがウィンドウ全体へ
# 広がっていないことを幾何的に確認する (外側クリック透過の担保)。
if (( MW * 2 <= GW && MH * 4 <= GH )); then
    print_result "(d) 入力マスクはピル領域のみ (外側クリック透過)" "PASS" \
        "mask=${MW}x${MH} window=${GW}x${GH}"
else
    print_result "(d) 入力マスクはピル領域のみ (外側クリック透過)" "FAIL" \
        "mask=${MW}x${MH} window=${GW}x${GH} (マスクが大きすぎる)"
fi

# ---- (e) MASK が配置先出力の内側に収まる --------------------------------
if (( MX >= SX && MY >= SY && MX + MW <= SX + SW && MY + MH <= SY + SH )); then
    print_result "(e) MASK が配置先出力内に収まる" "PASS" \
        "mask=(${MX},${MY})..($((MX + MW)),$((MY + MH))) screen=(${SX},${SY})..($((SX + SW)),$((SY + SH)))"
else
    print_result "(e) MASK が配置先出力内に収まる" "FAIL" \
        "mask=(${MX},${MY})..($((MX + MW)),$((MY + MH))) screen=(${SX},${SY})..($((SX + SW)),$((SY + SH)))"
fi

echo
echo "成果物:"
echo "  スクリーンショット: $SHOT"
echo "  stdout: $STDOUT_LOG"
echo "  stderr: $STDERR_LOG"

if (( FAIL_COUNT > 0 )); then
    echo
    echo "❌ ${FAIL_COUNT} 件の検証に失敗しました。ヒント:"
    echo "  - マウスが画面上部中央にあるとホバー展開し、形状が変わって FAIL する場合があります。"
    echo "    マウスを画面中央へ移動して再実行してください。"
    echo "  - QML 側 (qml/) が未実装・読み込みエラーの可能性があります (ui-designer 担当)。"
    echo "  - (a)(b) が FAIL: マルチモニタ座標 / 入力領域マスクの座標系を確認してください。"
    echo "  - (c) が FAIL: ノッチが描画されていない (QML ロード失敗 / 透明) 可能性があります。"
    echo "  - (d)(e) が FAIL: setMask() の形状がピルより大きい / 出力外へはみ出しています。"
    exit 1
fi

echo "✅ すべての視覚検証に PASS しました"
exit 0
