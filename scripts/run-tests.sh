#!/usr/bin/env bash
# ActiveNotch: QtTest 単体テストを実行する。
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

BUILD_DIR="${BUILD_DIR:-build}"
if [[ ! -f "$BUILD_DIR/CTestTestfile.cmake" ]]; then
    echo "==> テストが未 configure のためビルドします"
    ./scripts/dev.sh
fi

echo "==> ctest --test-dir ${BUILD_DIR}"
ctest --test-dir "$BUILD_DIR" --output-on-failure
