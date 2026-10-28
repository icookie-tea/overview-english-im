#!/usr/bin/env bash
#
# Install / uninstall this GNOME Shell extension for the current user.
#
#   ./install.sh              copy the extension into the user's extensions dir
#   ./install.sh --dev        symlink this repository instead of copying it
#   ./install.sh --uninstall  remove the installed extension
#
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

UUID="$(sed -n 's/^[[:space:]]*"uuid"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' metadata.json | head -n 1)"
EXTENSIONS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/gnome-shell/extensions"
TARGET_DIR="$EXTENSIONS_DIR/$UUID"
SCHEMA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/glib-2.0/schemas"

mode="copy"      # copy | link
action="install" # install | uninstall

usage() {
    cat <<EOF
用法: ./install.sh [选项]

  --dev         以符号链接方式安装（改完代码注销重登即可，方便开发）
  --copy        复制文件安装（默认）
  --uninstall   卸载已安装的扩展
  -h, --help    显示本帮助

扩展 UUID: ${UUID:-未知}
安装目录:  $TARGET_DIR
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --dev) mode="link" ;;
        --copy) mode="copy" ;;
        --uninstall) action="uninstall" ;;
        -h | --help) usage; exit 0 ;;
        *) echo "未知选项: $1" >&2; usage; exit 1 ;;
    esac
    shift
done

if [ ! -f metadata.json ]; then
    echo "错误: 请在扩展目录里运行此脚本（找不到 metadata.json）" >&2
    exit 1
fi

if [ -z "$UUID" ]; then
    echo "错误: 无法从 metadata.json 读取 uuid" >&2
    exit 1
fi

# glib-compile-schemas 不在普通 PATH 里时，去 nix store 的 glib -dev 输出里找。
find_glib_compile_schemas() {
    command -v glib-compile-schemas 2>/dev/null && return 0
    for candidate in /nix/store/*-glib-2*-dev/bin/glib-compile-schemas; do
        [ -x "$candidate" ] && { echo "$candidate"; return 0; }
    done
    return 1
}

GLIB_COMPILE_SCHEMAS="$(find_glib_compile_schemas || true)"

compile_schemas() {
    if [ -z "$GLIB_COMPILE_SCHEMAS" ]; then
        echo "错误: 找不到 glib-compile-schemas（nix 里在 glib 的 -dev 输出）" >&2
        echo "      nix shell nixpkgs#glib.dev -c bash ./install.sh" >&2
        exit 1
    fi
    "$GLIB_COMPILE_SCHEMAS" --strict "$1"
    # 也放进用户 schema 目录，prefs 进程与其它进程才看得到。
    mkdir -p "$SCHEMA_DIR"
    cp "$1"/*.xml "$SCHEMA_DIR/"
    "$GLIB_COMPILE_SCHEMAS" "$SCHEMA_DIR"
}

enabled_list() {
    gsettings get org.gnome.shell enabled-extensions
}

is_enabled() {
    enabled_list | grep -q "'$UUID'"
}

enable_extension() {
    # 运行中的 shell 扫不到新 UUID 时，gnome-extensions enable 会静默成功但什么也没做，
    # 所以要看 enabled-extensions 里到底有没有它。
    if command -v gnome-extensions >/dev/null 2>&1; then
        gnome-extensions enable "$UUID" >/dev/null 2>&1 || true
        if is_enabled; then
            echo "已启用: $UUID"
            return
        fi
    fi

    current="$(enabled_list)"
    case "$current" in
        "@as []" | "[]") merged="['$UUID']" ;;
        *) merged="${current%]}"; merged="$merged, '$UUID']" ;;
    esac
    gsettings set org.gnome.shell enabled-extensions "$merged"
    echo "已写入用户设置，登录后自动启用: $UUID"
}

disable_extension() {
    command -v gnome-extensions >/dev/null 2>&1 || return 0
    gnome-extensions disable "$1" >/dev/null 2>&1 || true
}

install_extension() {
    mkdir -p "$EXTENSIONS_DIR"
    rm -rf "$TARGET_DIR"

    if [ "$mode" = "link" ]; then
        compile_schemas "$SCRIPT_DIR/schemas"
        ln -s "$SCRIPT_DIR" "$TARGET_DIR"
        echo "已符号链接: $TARGET_DIR -> $SCRIPT_DIR"
    else
        mkdir -p "$TARGET_DIR"
        cp metadata.json extension.js prefs.js "$TARGET_DIR/"
        cp -r schemas "$TARGET_DIR/schemas"
        compile_schemas "$TARGET_DIR/schemas"
        echo "已复制到: $TARGET_DIR"
    fi

    enable_extension

    cat <<EOF

提示: GNOME Shell 不会热加载扩展代码。
  - 新 UUID 首次启用可能要在扩展应用里打开一次，或注销重新登录；
  - 之后改代码需要注销重新登录（Wayland）。
EOF
}

uninstall_extension() {
    disable_extension "$UUID"

    if [ -e "$TARGET_DIR" ] || [ -L "$TARGET_DIR" ]; then
        rm -rf "$TARGET_DIR"
        echo "已卸载: $TARGET_DIR"
    else
        echo "未安装: $TARGET_DIR"
    fi
}

case "$action" in
    install) install_extension ;;
    uninstall) uninstall_extension ;;
esac
