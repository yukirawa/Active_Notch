#!/usr/bin/env bash
# ActiveNotch: 稼働中のインスタンスを停止する (未起動でも成功)。
set -euo pipefail

if pkill -x activenotch 2>/dev/null; then
    echo "✅ activenotch を停止しました"
else
    echo "ℹ activenotch は起動していません"
fi
exit 0
