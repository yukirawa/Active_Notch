#!/usr/bin/env bash
# ActiveNotch: アンインストールスクリプト
#
#   install.sh が配置したファイルと systemd --user ユニットを削除する。
#   設定ファイル (~/.config/activenotch) は --purge を指定した場合のみ削除する。
#
# 使い方:
#   ./uninstall.sh              # install.sh と同じ既定 (root=/usr/local, 一般=~/.local)
#   ./uninstall.sh --user       # ~/.local から削除
#   ./uninstall.sh --system     # /usr/local から削除 (sudo を使用)
#   ./uninstall.sh --purge      # 設定ファイルも削除
set -euo pipefail

APP_ID="dev.yukirawa.activenotch"
SERVICE_NAME="activenotch.service"
BINARY_NAME="activenotch"

MODE="auto"
PREFIX=""
PURGE=0

info() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m✅\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m⚠\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m❌\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
    sed -n '2,11p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --user)     MODE="user" ;;
        --system)   MODE="system" ;;
        --prefix)   PREFIX="${2:?--prefix にはパスが必要です}"; shift ;;
        --prefix=*) PREFIX="${1#*=}" ;;
        --purge)    PURGE=1 ;;
        -h|--help)  usage; exit 0 ;;
        *)          die "不明な引数: $1 (--help を参照)" ;;
    esac
    shift
done

if [[ -z "$PREFIX" ]]; then
    case "$MODE" in
        user)   PREFIX="$HOME/.local" ;;
        system) PREFIX="/usr/local" ;;
        auto)
            if [[ "$EUID" -eq 0 ]]; then PREFIX="/usr/local"; else PREFIX="$HOME/.local"; fi
            ;;
    esac
fi
[[ "$PREFIX" == "$HOME/.local" ]] && MODE="user"

SUDO=""
if [[ "$EUID" -ne 0 ]]; then
    parent="$PREFIX"
    while [[ ! -e "$parent" ]]; do parent="$(dirname "$parent")"; done
    if [[ ! -w "$parent" ]]; then
        command -v sudo >/dev/null 2>&1 || die "$PREFIX を変更できません (sudo がありません)"
        SUDO="sudo"
    fi
fi
as_root() { if [[ -n "$SUDO" ]]; then $SUDO "$@"; else "$@"; fi; }

run_user_systemctl() {
    if [[ "$EUID" -eq 0 ]]; then
        local target="${SUDO_USER:-}"
        if [[ -z "$target" || "$target" == "root" ]]; then
            return 1
        fi
        local uid
        uid="$(id -u "$target")"
        sudo -u "$target" \
            XDG_RUNTIME_DIR="/run/user/$uid" \
            DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
            systemctl --user "$@"
    else
        systemctl --user "$@"
    fi
}

info "削除対象: $PREFIX (モード: $MODE)"

if [[ "$PREFIX" == "/usr" ]]; then
    DATADIR="/usr/share"
elif [[ "$PREFIX" == "/usr/local" ]]; then
    DATADIR="/usr/local/share"
else
    DATADIR="$PREFIX/share"
fi

# ---- サービス停止・無効化 --------------------------------------------------
# この prefix にユニットが無い場合は、別の場所に導入されたサービスを
# 誤って停止しないよう触らない (テスト用の一時 prefix 対策)。
if [[ -e "$DATADIR/systemd/user/$SERVICE_NAME" ]]; then
    if run_user_systemctl disable --now "$SERVICE_NAME" 2>/dev/null; then
        ok "systemd --user サービスを停止・無効化しました"
    else
        info "systemd --user サービスは稼働していません (スキップ)"
    fi
fi
pkill -x "$BINARY_NAME" 2>/dev/null || true

# ---- ファイル削除 ----------------------------------------------------------

remove_file() {
    local path="$1"
    if [[ -e "$path" || -L "$path" ]]; then
        as_root rm -f "$path"
        echo "  removed: $path"
    fi
}

remove_file "$PREFIX/bin/$BINARY_NAME"
remove_file "$DATADIR/applications/$APP_ID.desktop"
remove_file "$DATADIR/systemd/user/$SERVICE_NAME"
remove_file "$DATADIR/icons/hicolor/scalable/apps/$APP_ID.svg"
remove_file "$HOME/.config/autostart/$APP_ID.desktop"
if [[ "$MODE" != "user" ]]; then
    remove_file "/etc/xdg/autostart/$APP_ID.desktop"
fi

# 空になった systemd ユーザーディレクトリは残す (他ユニットが入っている場合がある)。

run_user_systemctl daemon-reload 2>/dev/null || true

# ---- 設定ファイル ----------------------------------------------------------
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/activenotch"
if [[ "$PURGE" -eq 1 ]]; then
    if [[ -d "$CONFIG_DIR" ]]; then
        rm -rf "$CONFIG_DIR"
        ok "設定ファイルを削除しました: $CONFIG_DIR"
    fi
else
    info "設定ファイルは保持しています: $CONFIG_DIR (削除するには --purge)"
fi

ok "ActiveNotch をアンインストールしました"
