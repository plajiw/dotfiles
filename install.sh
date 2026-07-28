#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) is_windows=1 ;;
    *)                    is_windows=0 ;;
esac

jetbrains_mono_dir="$repo_dir/fonts/JetBrainsMono"
nerd_font_dir="$repo_dir/fonts/JetBrainsMono-NerdFont"

tmp_dir=""
cleanup() {
    if [ -n "$tmp_dir" ]; then
        rm -rf "$tmp_dir"
    fi
}
trap cleanup EXIT

install_vscode_settings() {
    if [ "$is_windows" -eq 1 ]; then
        user_dir="$APPDATA/Code/User"
    else
        user_dir="$HOME/.config/Code/User"
    fi

    mkdir -p "$user_dir"

    for file in settings.json keybindings.json; do
        src="$repo_dir/vscode/$file"
        dest="$user_dir/$file"

        if [ -e "$dest" ]; then
            mv "$dest" "$dest.bak"
            echo "Backed up existing $file to $file.bak"
        fi

        cp "$src" "$dest"
        echo "Copied $file -> $dest"
    done
}

# resolve_latest_asset_url <owner/repo> <asset name regex>
resolve_latest_asset_url() {
    local repo="$1" pattern="$2"
    curl -fsSL "https://api.github.com/repos/$repo/releases/latest" \
        | grep -oE '"browser_download_url": *"[^"]+"' \
        | sed -E 's/.*"(https[^"]+)"/\1/' \
        | grep -E "$pattern" \
        | head -n1
}

# fetch_jetbrains_mono <dest_dir>
fetch_jetbrains_mono() {
    local dest_dir="$1" url

    url="$(resolve_latest_asset_url "JetBrains/JetBrainsMono" 'JetBrainsMono-[0-9.]+\.zip$')"
    if [ -z "$url" ]; then
        echo "Could not resolve the JetBrains Mono download URL." >&2
        return 1
    fi

    mkdir -p "$tmp_dir" "$dest_dir"
    echo "Downloading JetBrains Mono..."
    curl -L --progress-bar -o "$tmp_dir/JetBrainsMono.zip" "$url"
    unzip -o -j "$tmp_dir/JetBrainsMono.zip" "fonts/ttf/JetBrainsMono-*.ttf" -d "$dest_dir" >/dev/null
}

# fetch_nerd_font <dest_dir>
fetch_nerd_font() {
    local dest_dir="$1"
    local url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"

    mkdir -p "$tmp_dir" "$dest_dir"
    echo "Downloading JetBrainsMono Nerd Font..."
    curl -L --progress-bar -o "$tmp_dir/JetBrainsMonoNerdFont.zip" "$url"
    unzip -o -j "$tmp_dir/JetBrainsMonoNerdFont.zip" "JetBrainsMonoNerdFont-*.ttf" -d "$dest_dir" >/dev/null
}

# ensure_font_source <dir> <fetch_fn>
ensure_font_source() {
    local dir="$1" fetch_fn="$2"

    if ! ls "$dir"/*.ttf >/dev/null 2>&1; then
        echo "Font files not found in $dir, downloading..."
        tmp_dir="$(mktemp -d)"
        "$fetch_fn" "$dir"
    fi
}

# install_font_dir <src_dir> <family_label>
install_font_dir() {
    local src_dir="$1" family_label="$2" dest_dir font name

    if [ "$is_windows" -eq 1 ]; then
        dest_dir="$LOCALAPPDATA/Microsoft/Windows/Fonts"
        mkdir -p "$dest_dir"

        for font in "$src_dir"/*.ttf; do
            name="$(basename "$font")"
            cp "$font" "$dest_dir/$name"
            MSYS_NO_PATHCONV=1 reg add "HKCU\Software\Microsoft\Windows NT\CurrentVersion\Fonts" \
                /v "${name%.ttf} (TrueType)" /t REG_SZ /d "$name" /f >/dev/null
        done
        echo "Installed $family_label to $dest_dir"
    else
        dest_dir="$HOME/.local/share/fonts/$family_label"
        mkdir -p "$dest_dir"
        cp "$src_dir"/*.ttf "$dest_dir/"
        fc-cache -f "$dest_dir" >/dev/null
        echo "Installed $family_label to $dest_dir"
    fi
}

install_fonts() {
    echo ""
    echo "Which font do you want to install?"
    echo "  1) JetBrains Mono (editor font)"
    echo "  2) JetBrainsMono Nerd Font (terminal font)"
    echo "  3) Both"
    echo "  4) Skip"
    read -rp "Choice [1-4]: " font_choice

    case "$font_choice" in
        1)
            ensure_font_source "$jetbrains_mono_dir" fetch_jetbrains_mono
            install_font_dir "$jetbrains_mono_dir" "JetBrainsMono"
            ;;
        2)
            ensure_font_source "$nerd_font_dir" fetch_nerd_font
            install_font_dir "$nerd_font_dir" "JetBrainsMono-NerdFont"
            ;;
        3)
            ensure_font_source "$jetbrains_mono_dir" fetch_jetbrains_mono
            ensure_font_source "$nerd_font_dir" fetch_nerd_font
            install_font_dir "$jetbrains_mono_dir" "JetBrainsMono"
            install_font_dir "$nerd_font_dir" "JetBrainsMono-NerdFont"
            ;;
        4) echo "Skipped font installation." ;;
        *) echo "Invalid choice, skipping fonts." ;;
    esac
}

main_menu() {
    echo "What would you like to install?"
    echo "  1) VS Code configs (settings.json + keybindings.json)"
    echo "  2) Fonts"
    echo "  3) Everything"
    echo "  4) Exit"
    read -rp "Choice [1-4]: " choice

    case "$choice" in
        1) install_vscode_settings ;;
        2) install_fonts ;;
        3)
            install_vscode_settings
            install_fonts
            ;;
        4) echo "Exiting."; exit 0 ;;
        *) echo "Invalid choice."; main_menu ;;
    esac
}

main_menu

echo "Done."
