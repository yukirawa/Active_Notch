#!/usr/bin/env bash
# ActiveNotch: configure + build。
# 警告は表示のみ (ビルド成功なら exit 0)、コンパイルエラーは exit 非ゼロ。
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

BUILD_DIR="${BUILD_DIR:-build}"
LOG_FILE="$(mktemp "${TMPDIR:-/tmp}/activenotch-build-XXXXXX.log")"
cleanup() {
    rm -f "$LOG_FILE"
}
trap cleanup EXIT INT TERM

echo "==> CMake configure (${BUILD_DIR})"
if ! cmake -B "$BUILD_DIR" -G Ninja -DCMAKE_BUILD_TYPE=Release 2>&1 | tee "$LOG_FILE"; then
    echo "❌ CMake configure に失敗しました" >&2
    exit 1
fi

echo "==> ビルド"
if ! cmake --build "$BUILD_DIR" 2>&1 | tee -a "$LOG_FILE"; then
    echo "❌ ビルドに失敗しました (上のエラーを確認してください)" >&2
    exit 1
fi

WARN_COUNT="$(grep -c -E 'warning:' "$LOG_FILE" || true)"
if [[ "${WARN_COUNT}" -gt 0 ]]; then
    echo "⚠ 警告 ${WARN_COUNT} 件 (表示のみ。ビルド自体は成功しています)"
    grep -E 'warning:' "$LOG_FILE" | sed 's/^/    /'
else
    echo "✅ ビルド成功 (警告 0 件)"
fi
