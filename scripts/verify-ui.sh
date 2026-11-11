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
echo "==> ActiveNotch を起動 (ACTIVENOTCH_PRINT_GEOMETRY=1)"
QT_FORCE_STDERR_LOGGING=1 ACTIVENOTCH_PRINT_GEOMETRY=1 ./build/activenotch >"$STDOUT_LOG" 2>"$STDERR_LOG" &
APP_PID=$!

# 描画・configure の完了を待つ。
sleep 2.5

if ! kill -0 "$APP_PID" 2>/dev/null; then
    echo "❌ アプリが起動直後に終了しました。stderr:" >&2
    tail -n 40 "$STDERR_LOG" >&2 || true
    exit 1
fi

# ---- 3. ジオメトリ行のパース --------------------------------------------
GEOMETRY_LINE="$(grep -m1 '^GEOMETRY ' "$STDOUT_LOG" || true)"
MASK_LINE="$(grep '^MASK ' "$STDOUT_LOG" | tail -n1 || true)"

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

pixel_rgb() {
    # $1=file $2=x $3=y → "r,g,b"
    magick "$1" -crop "1x1+$2+$3" +repage -depth 8 \
        -format '%[fx:round(255*r)],%[fx:round(255*g)],%[fx:round(255*b)]' info:
}
rgb_sum_diff() {
    # $1,$2 = "r,g,b"
    local -a a b
    IFS=',' read -r -a a <<<"$1"
    IFS=',' read -r -a b <<<"$2"
    echo $(( (${a[0]} > ${b[0]} ? ${a[0]} - ${b[0]} : ${b[0]} - ${a[0]})
            + (${a[1]} > ${b[1]} ? ${a[1]} - ${b[1]} : ${b[1]} - ${a[1]})
            + (${a[2]} > ${b[2]} ? ${a[2]} - ${b[2]} : ${b[2]} - ${a[2]}) ))
}
clamp() {
    local v="$1" max="$2"
    if (( v < 0 )); then echo 0; elif (( v >= max )); then echo $((max - 1)); else echo "$v"; fi
}

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

printf '  GEOMETRY: x=%s y=%s w=%s h=%s scale=%s screen=%s\n' \
    "$GX" "$GY" "$GW" "$GH" "$GSCALE" "$GSCREEN"
printf '  MASK    : x=%s y=%s w=%s h=%s\n\n' "$MX" "$MY" "$MW" "$MH"

# ---- (a) 水平中央 --------------------------------------------------------
CENTER_X=$((MX + MW / 2))
CENTER_DIFF=$((CENTER_X - IMG_W / 2))
CENTER_ABS=${CENTER_DIFF#-}
if (( CENTER_ABS <= 2 )); then
    print_result "(a) MASK 中心が画面中央 (±2px)" "PASS" \
        "cx=${CENTER_X} W/2=$((IMG_W / 2)) 差=${CENTER_DIFF}px"
else
    print_result "(a) MASK 中心が画面中央 (±2px)" "FAIL" \
        "cx=${CENTER_X} W/2=$((IMG_W / 2)) 差=${CENTER_DIFF}px"
fi

# ---- (b) MASK サイズ (物理 px, scale 追従) ------------------------------
# collapsed ピルは論理 220x30。物理サイズは DPR 倍になる。
# 実機 eDP-1 (scale 1.2) なら 264x36、DP-2 (scale 1.0) なら 220x30。
EXPECTED_MW="$(awk -v s="$GSCALE" 'BEGIN { printf "%d", 220 * s + 0.5 }')"
EXPECTED_MH="$(awk -v s="$GSCALE" 'BEGIN { printf "%d", 30 * s + 0.5 }')"
MW_DIFF=$((MW - EXPECTED_MW))
MH_DIFF=$((MH - EXPECTED_MH))
MW_DIFF_ABS=${MW_DIFF#-}
MH_DIFF_ABS=${MH_DIFF#-}
if (( MW_DIFF_ABS <= 2 && MH_DIFF_ABS <= 2 )); then
    print_result "(b) MASK がピル相当サイズ" "PASS" \
        "${MW}x${MH}px (期待 ${EXPECTED_MW}x${EXPECTED_MH} = 220x30 x scale ${GSCALE})"
else
    print_result "(b) MASK がピル相当サイズ" "FAIL" \
        "${MW}x${MH}px (期待 ${EXPECTED_MW}x${EXPECTED_MH} = 220x30 x scale ${GSCALE}, 許容 ±2px)"
fi

# ---- 色検証用座標 --------------------------------------------------------
CENTER_PX="$(clamp "$CENTER_X" "$IMG_W")"
CENTER_PY="$(clamp $((MY + MH / 2)) "$IMG_H")"
OUTSIDE_PX="$(clamp "$CENTER_X" "$IMG_W")"
OUTSIDE_PY="$(clamp $((MY + MH + 10)) "$IMG_H")"
BELOW_REF_PY="$(clamp $((MY + MH + 60)) "$IMG_H")"
SIDE_REF_PX="$(clamp 60 "$IMG_W")"

PILL_RGB="$(pixel_rgb "$SHOT" "$CENTER_PX" "$CENTER_PY")"
DESKTOP_BELOW_RGB="$(pixel_rgb "$SHOT" "$CENTER_PX" "$BELOW_REF_PY")"
OUTSIDE_RGB="$(pixel_rgb "$SHOT" "$OUTSIDE_PX" "$OUTSIDE_PY")"
SIDE_REF_RGB="$(pixel_rgb "$SHOT" "$SIDE_REF_PX" "$OUTSIDE_PY")"

# ---- (c) ピル内がデスクトップと異なる ------------------------------------
PILL_DIFF="$(rgb_sum_diff "$PILL_RGB" "$DESKTOP_BELOW_RGB")"
if (( PILL_DIFF > 20 )); then
    print_result "(c) ピル中心がデスクトップと異なる色" "PASS" \
        "pill=${PILL_RGB} desktop=${DESKTOP_BELOW_RGB} 差=${PILL_DIFF}"
else
    print_result "(c) ピル中心がデスクトップと異なる色" "FAIL" \
        "pill=${PILL_RGB} desktop=${DESKTOP_BELOW_RGB} 差=${PILL_DIFF} (<=20)"
fi

# ---- (d) ピル外はデスクトップと同色 --------------------------------------
OUTSIDE_DIFF="$(rgb_sum_diff "$OUTSIDE_RGB" "$SIDE_REF_RGB")"
if (( OUTSIDE_DIFF < 30 )); then
    print_result "(d) MASK 外数px 下はデスクトップと同色" "PASS" \
        "outside=${OUTSIDE_RGB} ref=${SIDE_REF_RGB} 差=${OUTSIDE_DIFF}"
else
    print_result "(d) MASK 外数px 下はデスクトップと同色" "FAIL" \
        "outside=${OUTSIDE_RGB} ref=${SIDE_REF_RGB} 差=${OUTSIDE_DIFF} (>=30)"
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
    echo "  - (a)(b) が FAIL: DPR (scale 1.2) と入力領域マスクの座標系を確認してください。"
    echo "  - (c) が FAIL: ノッチが描画されていない (QML ロード失敗 / 透明) 可能性があります。"
    echo "  - (d) が FAIL: ドロップシャドウ等がピル外へ漏れている可能性があります。"
    exit 1
fi

echo "✅ すべての視覚検証に PASS しました"
exit 0
