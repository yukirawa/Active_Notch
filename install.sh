#!/usr/bin/env bash
# ActiveNotch: ワンコマンド導入スクリプト
#
#   1. ディストリビューションを判定してビルド依存を導入 (--no-deps で省略可)
#   2. CMake で Release ビルド
#   3. バイナリ / デスクトップエントリ / systemd --user ユニット / アイコンを配置
#   4. systemd --user で有効化 (--autostart なら XDG 自動起動ファイルを使用)
#   5. 輝度制御・任意依存の案内を表示
#
# 使い方:
#   ./install.sh                # root なら /usr/local、一般ユーザーなら ~/.local
#   ./install.sh --user         # ~/.local に導入 (sudo 不要)
#   ./install.sh --system       # /usr/local に導入 (sudo を使用)
#   ./install.sh --autostart    # systemd ではなく XDG 自動起動を使う
#   ./install.sh --no-deps      # 依存導入をスキップ
#   ./install.sh --no-service   # 自動起動の有効化をスキップ
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

APP_ID="dev.yukirawa.activenotch"
SERVICE_NAME="activenotch.service"
BINARY_NAME="activenotch"

MODE="auto"          # auto | user | system
PREFIX=""
BUILD_DIR="$ROOT_DIR/build-install"
INSTALL_DEPS=1
ENABLE_SERVICE=1
USE_SYSTEMD=1

# ---- 表示ヘルパ ------------------------------------------------------------
info()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
ok()    { printf '\033[1;32m✅\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m⚠\033[0m %s\n' "$*" >&2; }
die()   { printf '\033[1;31m❌\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
    sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --user)       MODE="user" ;;
        --system)     MODE="system" ;;
        --prefix)     PREFIX="${2:?--prefix にはパスが必要です}"; shift ;;
        --prefix=*)   PREFIX="${1#*=}" ;;
        --build-dir)  BUILD_DIR="${2:?--build-dir にはパスが必要です}"; shift ;;
        --no-deps)    INSTALL_DEPS=0 ;;
        --no-service) ENABLE_SERVICE=0 ;;
        --autostart)  USE_SYSTEMD=0 ;;
        --systemd)    USE_SYSTEMD=1 ;;
        -h|--help)    usage; exit 0 ;;
        *)            die "不明な引数: $1 (--help を参照)" ;;
    esac
    shift
done

# ---- 導入先の決定 ----------------------------------------------------------
if [[ -z "$PREFIX" ]]; then
    case "$MODE" in
        user)   PREFIX="$HOME/.local" ;;
        system) PREFIX="/usr/local" ;;
        auto)
            if [[ "$EUID" -eq 0 ]]; then
                PREFIX="/usr/local"; MODE="system"
            else
                PREFIX="$HOME/.local"; MODE="user"
            fi
            ;;
    esac
fi
if [[ "$PREFIX" == "$HOME/.local" ]]; then
    MODE="user"
fi

# 書き込みに sudo が必要か判定する。
SUDO=""
if [[ "$EUID" -ne 0 ]]; then
    parent="$PREFIX"
    while [[ ! -e "$parent" ]]; do parent="$(dirname "$parent")"; done
    if [[ ! -w "$parent" ]]; then
        command -v sudo >/dev/null 2>&1 || die "$PREFIX に書き込めません (sudo がありません)"
        SUDO="sudo"
    fi
fi
as_root() { if [[ -n "$SUDO" ]]; then $SUDO "$@"; else "$@"; fi; }

info "導入先: $PREFIX (モード: $MODE)"

# ---- 依存パッケージ --------------------------------------------------------
install_deps_arch() {
    as_root pacman -S --needed --noconfirm \
        base-devel cmake ninja pkgconf wayland \
        qt6-base qt6-declarative qt6-wayland qt6-svg \
        layer-shell-qt \
        kf6-kconfig kf6-kcalendarcore kf6-kholidays \
        kf6-bluez-qt kf6-kservice kf6-ki18n
}

install_deps_debian() {
    as_root apt-get update
    as_root apt-get install -y \
        build-essential cmake ninja-build pkg-config libwayland-dev \
        qt6-base-dev qt6-declarative-dev qt6-wayland-dev qt6-svg-dev \
        liblayershellqtinterface-dev \
        libkf6config-dev libkf6calendarcore-dev libkf6holidays-dev \
        libkf6bluezqt-dev libkf6service-dev libkf6i18n-dev
}

install_deps_fedora() {
    as_root dnf install -y \
        gcc-c++ cmake ninja-build pkgconf-pkg-config wayland-devel \
        qt6-qtbase-devel qt6-qtdeclarative-devel qt6-qtwayland-devel qt6-qtsvg-devel \
        layer-shell-qt-devel \
        kf6-kconfig-devel kf6-kcalendarcore-devel kf6-kholidays-devel \
        kf6-bluez-qt-devel kf6-kservice-devel kf6-ki18n-devel
}

if [[ "$INSTALL_DEPS" -eq 1 ]]; then
    info "ビルド依存を確認・導入します"
    if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        DISTRO_ID="${ID:-}"
        DISTRO_LIKE="${ID_LIKE:-}"
    else
        DISTRO_ID=""; DISTRO_LIKE=""
    fi
    case " $DISTRO_ID $DISTRO_LIKE " in
        *" arch "*|*" endeavouros "*|*" manjaro "*)
            install_deps_arch ;;
        *" debian "*|*" ubuntu "*)
            install_deps_debian ;;
        *" fedora "*|*" rhel "*|*" centos "*)
            install_deps_fedora ;;
        *)
            warn "未対応のディストリビューション (${DISTRO_ID:-unknown})。"
            warn "依存は手動で導入してください。README の「依存関係」を参照。"
            ;;
    esac
    ok "依存の確認が完了しました"
else
    info "依存導入をスキップしました (--no-deps)"
fi

# ---- ビルド ----------------------------------------------------------------
info "CMake で Release ビルドします: $BUILD_DIR"
cmake -S "$ROOT_DIR" -B "$BUILD_DIR" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$PREFIX"
cmake --build "$BUILD_DIR" --parallel

# ---- 配置 ------------------------------------------------------------------
info "ファイルを $PREFIX へ配置します"
as_root cmake --install "$BUILD_DIR" --prefix "$PREFIX"

BINDIR="$PREFIX/bin"
if [[ "$PREFIX" == "/usr" ]]; then
    DATADIR="/usr/share"
    SYSCONFDIR="/etc"
elif [[ "$PREFIX" == "/usr/local" ]]; then
    DATADIR="/usr/local/share"
    SYSCONFDIR="/usr/local/etc"
else
    DATADIR="$PREFIX/share"
    SYSCONFDIR="$PREFIX/etc"
fi

# 自動起動: systemd を使わない場合のみ XDG autostart を配置する。
# (両方有効にすると二重起動になるため。アプリ側にも二重起動ガードあり)
if [[ "$USE_SYSTEMD" -eq 0 ]]; then
    if [[ "$MODE" == "user" ]]; then
        autostart_dir="$HOME/.config/autostart"
        mkdir -p "$autostart_dir"
        install -m 0644 "$BUILD_DIR/$APP_ID.desktop" "$autostart_dir/$APP_ID.desktop"
    else
        as_root install -Dm644 "$BUILD_DIR/$APP_ID.desktop" "/etc/xdg/autostart/$APP_ID.desktop"
    fi
    ok "XDG 自動起動ファイルを配置しました"
else
    # systemd に切り替えるとき、以前の XDG 自動起動ファイルが残っていると
    # 二重起動になるため削除する。
    rm -f "$HOME/.config/autostart/$APP_ID.desktop" 2>/dev/null || true
    [[ "$MODE" != "user" ]] && as_root rm -f "/etc/xdg/autostart/$APP_ID.desktop" || true
fi

# ---- 自動起動の有効化 ------------------------------------------------------
run_user_systemctl() {
    # root 実行時に SUDO_USER の systemd --user を操作する。
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

if [[ "$ENABLE_SERVICE" -eq 1 && "$USE_SYSTEMD" -eq 1 ]]; then
    info "systemd --user サービスを有効化します"
    # 旧プロセスが残っていると新しいバイナリに置き換わらないため停止する。
    pkill -x "$BINARY_NAME" 2>/dev/null || true
    if run_user_systemctl daemon-reload \
        && run_user_systemctl enable --now "$SERVICE_NAME"; then
        ok "systemd --user で $SERVICE_NAME を有効化しました"
    else
        warn "systemd --user の有効化に失敗しました (グラフィカルセッション外?)"
        warn "ログイン後に次を実行してください:"
        warn "  systemctl --user daemon-reload && systemctl --user enable --now $SERVICE_NAME"
    fi
elif [[ "$ENABLE_SERVICE" -eq 1 ]]; then
    info "XDG 自動起動を使用します (systemd は無効化します)"
    run_user_systemctl disable --now "$SERVICE_NAME" 2>/dev/null || true
    pkill -x "$BINARY_NAME" 2>/dev/null || true
    if [[ "$MODE" == "user" ]]; then
        nohup "$BINDIR/$BINARY_NAME" >/dev/null 2>&1 &
        ok "ActiveNotch を起動しました"
    fi
else
    info "自動起動の有効化をスキップしました (--no-service)"
fi

# ---- 事後案内 --------------------------------------------------------------
UNINSTALL_HINT="./uninstall.sh"
[[ "$MODE" == "user" ]] && UNINSTALL_HINT="./uninstall.sh --user"

cat <<EOF

$(ok "ActiveNotch の導入が完了しました")

  実行ファイル : $BINDIR/$BINARY_NAME
  設定ファイル : \${XDG_CONFIG_HOME:-~/.config}/activenotch/activenotchrc
  ログ確認     : journalctl --user -u activenotch -f
  手動起動     : $BINDIR/$BINARY_NAME
  停止         : systemctl --user stop activenotch

【輝度スライダーが動かない場合】
  BrightnessService は logind (Session.SetBrightness) を優先し、
  失敗時は /sys/class/backlight/*/brightness へ直接書き込みます。
  直接書き込みには video グループへの所属が必要です:
      sudo usermod -aG video "\$USER"   # 再ログインが必要
  それでも失敗する場合は udev ルールで権限を付与してください:
      /etc/udev/rules.d/90-backlight.rules
      ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chgrp video /sys/class/backlight/%k/brightness", RUN+="/bin/chmod g+w /sys/class/backlight/%k/brightness"

【任意依存 (無くても起動しますが一部機能が無効になります)】
  wpctl (PipeWire/WirePlumber) : 音量制御
  NetworkManager               : Wi-Fi / 有線の表示・接続
  BlueZ                        : Bluetooth の表示・接続
  wl-clipboard                 : クリップボード履歴 (wl-paste / wl-copy)
  KWin スクリプト有効         : 全画面アプリ検出 (システム設定 → ウィンドウ管理)

アンインストール: $UNINSTALL_HINT
EOF
