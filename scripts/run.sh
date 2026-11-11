#!/usr/bin/env bash
# ActiveNotch: Wayland セッションでアプリを起動する。
# バイナリが無ければビルドしてからフォアグラウンドで exec する。
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
    echo "❌ Wayland セッションではありません (WAYLAND_DISPLAY が未設定)。" >&2
    echo "   KDE Plasma 6 (Wayland) のセッションで実行してください。" >&2
    exit 1
fi

BINARY="${BUILD_DIR:-build}/activenotch"
NEEDS_BUILD=0
if [[ ! -x "$BINARY" ]]; then
    NEEDS_BUILD=1
elif [[ -n "$(find src qml CMakeLists.txt -newer "$BINARY" -print -quit 2>/dev/null)" ]]; then
    echo "==> ソースがバイナリより新しいためビルドします"
    NEEDS_BUILD=1
fi

if (( NEEDS_BUILD )); then
    ./scripts/dev.sh
fi

echo "==> ActiveNotch を起動 (Ctrl+C で終了)"
# Qt のログは既定で journald へ行くため、端末では stderr へ強制する。
export QT_FORCE_STDERR_LOGGING=1
exec "$BINARY" "$@"
