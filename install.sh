#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) os="windows" ;;
    Darwin*)              os="macos" ;;
    *)                    os="linux" ;;
esac
is_windows=0
if [ "$os" = "windows" ]; then
    is_windows=1
fi

jetbrains_mono_dir="$repo_dir/fonts/JetBrainsMono"
nerd_font_dir="$repo_dir/fonts/JetBrainsMono-NerdFont"

tmp_dir=""
cleanup() {
    if [ -n "$tmp_dir" ]; then
        rm -rf "$tmp_dir"
    fi
    tput cnorm 2>/dev/null || true
}
trap cleanup EXIT

# ---- styling helpers ----------------------------------------------------
bold=""; dim=""; reset=""; cyan=""; green=""; yellow=""; red=""
if [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
    bold="$(tput bold)"; dim="$(tput dim)"; reset="$(tput sgr0)"
    cyan="$(tput setaf 6)"; green="$(tput setaf 2)"
    yellow="$(tput setaf 3)"; red="$(tput setaf 1)"
fi

log_info()    { echo "${cyan}➜${reset} $*"; }
log_success() { echo "${green}✓${reset} $*"; }
log_warn()    { echo "${yellow}⚠${reset} $*" >&2; }
log_error()   { echo "${red}✗${reset} $*" >&2; }
header()      { echo ""; echo "${bold}$*${reset}"; }

# select_menu <title> <option> [option...]
# Arrow-key driven menu when stdin is a TTY, numbered fallback otherwise.
# Sets $REPLY_INDEX (0-based) to the chosen option.
select_menu() {
    local title="$1"; shift
    local options=("$@")
    local count=${#options[@]}
    local selected=0 key rest i

    header "$title"

    if [ ! -t 0 ]; then
        for i in "${!options[@]}"; do
            echo "  $((i + 1))) ${options[$i]}"
        done
        read -rp "Choice [1-$count]: " reply
        REPLY_INDEX=$((reply - 1))
        return
    fi

    tput civis 2>/dev/null || true
    while true; do
        for i in "${!options[@]}"; do
            if [ "$i" -eq "$selected" ]; then
                printf "  %s❯ %s%s\n" "${cyan}${bold}" "${options[$i]}" "${reset}"
            else
                printf "    %s\n" "${options[$i]}"
            fi
        done

        IFS= read -rsn1 key
        if [[ $key == $'\x1b' ]]; then
            IFS= read -rsn2 -t 0.05 rest || true
            key+="$rest"
        fi

        case "$key" in
            $'\x1b[A') selected=$(((selected - 1 + count) % count)) ;;
            $'\x1b[B') selected=$(((selected + 1) % count)) ;;
            "") break ;;
        esac

        printf "\033[%dA" "$count"
    done
    tput cnorm 2>/dev/null || true
    REPLY_INDEX=$selected
}

# progress_bar <current> <total> <label>
progress_bar() {
    local current="$1" total="$2" label="$3" width=30
    local filled=$((current * width / total))
    local empty=$((width - filled))
    printf "\r  %s%s [" "$cyan$bold" "$label"
    printf "%0.s#" $(seq 1 "$filled") 2>/dev/null
    printf "%0.s-" $(seq 1 "$empty") 2>/dev/null
    printf "] %d%%%s" $((current * 100 / total)) "$reset"
    if [ "$current" -eq "$total" ]; then
        echo ""
    fi
}

# ---- vscode settings ------------------------------------------------------
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
            log_warn "Backed up existing $file to $file.bak"
        fi

        cp "$src" "$dest"
        log_success "Copied $file -> $dest"
    done
}

# ---- git config -------------------------------------------------------------
install_git_config() {
    if ! command -v git >/dev/null 2>&1; then
        log_error "git not found, skipping git config."
        return
    fi

    git config --global include.path "$repo_dir/git/gitconfig"
    log_success "Linked git/gitconfig via include.path (core.editor = code --wait)"
}

# ---- fonts -----------------------------------------------------------------
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
        log_error "Could not resolve the JetBrains Mono download URL."
        return 1
    fi

    mkdir -p "$tmp_dir" "$dest_dir"
    log_info "Downloading JetBrains Mono..."
    curl -L --progress-bar -o "$tmp_dir/JetBrainsMono.zip" "$url"
    unzip -o -j "$tmp_dir/JetBrainsMono.zip" "fonts/ttf/JetBrainsMono-*.ttf" -d "$dest_dir" >/dev/null
    curl -fsSL -o "$dest_dir/LICENSE" "https://raw.githubusercontent.com/JetBrains/JetBrainsMono/master/OFL.txt" || true
}

# fetch_nerd_font <dest_dir>
fetch_nerd_font() {
    local dest_dir="$1"
    local url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"

    mkdir -p "$tmp_dir" "$dest_dir"
    log_info "Downloading JetBrainsMono Nerd Font..."
    curl -L --progress-bar -o "$tmp_dir/JetBrainsMonoNerdFont.zip" "$url"
    unzip -o -j "$tmp_dir/JetBrainsMonoNerdFont.zip" "JetBrainsMonoNerdFont-*.ttf" -d "$dest_dir" >/dev/null
    curl -fsSL -o "$dest_dir/LICENSE" "https://raw.githubusercontent.com/ryanoasis/nerd-fonts/master/LICENSE" || true
}

# ensure_font_source <dir> <fetch_fn>
ensure_font_source() {
    local dir="$1" fetch_fn="$2"

    if ! ls "$dir"/*.ttf >/dev/null 2>&1; then
        log_info "Font files not found in $dir, downloading..."
        tmp_dir="$(mktemp -d)"
        "$fetch_fn" "$dir"
    fi
}

# register_windows_fonts <windows-path...> -- loads fonts into the current
# session (AddFontResource) and broadcasts WM_FONTCHANGE so already-open
# apps pick them up immediately, no logoff/reboot needed. This only affects
# runtime activation; the registry entry (done separately) is what makes it
# survive a reboot. Prints any error to stderr and returns non-zero if
# PowerShell/Add-Type is unavailable (e.g. locked-down corporate policy) --
# the font still works after the next login even if this fails.
register_windows_fonts() {
    local win_paths=("$@") p ps_list="" ps_err

    if ! command -v powershell.exe >/dev/null 2>&1; then
        echo "powershell.exe not found" >&2
        return 1
    fi

    for p in "${win_paths[@]}"; do
        ps_list+="'${p//\'/\'\'}',"
    done

    if ! ps_err="$(powershell.exe -NoProfile -Command "
        \$ErrorActionPreference = 'Stop'
        Add-Type -Namespace Win32 -Name Font -MemberDefinition '
            [DllImport(\"gdi32.dll\")] public static extern int AddFontResource(string lpFileName);
            [DllImport(\"user32.dll\")] public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, IntPtr lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
        '
        foreach (\$p in @(${ps_list%,})) { [Win32.Font]::AddFontResource(\$p) | Out-Null }
        \$result = [UIntPtr]::Zero
        [Win32.Font]::SendMessageTimeout([IntPtr]0xffff, 0x1D, [UIntPtr]::Zero, [IntPtr]::Zero, 2, 1000, [ref]\$result) | Out-Null
    " 2>&1)"; then
        echo "$ps_err" >&2
        return 1
    fi
}

# install_font_dir <src_dir> <family_label>
install_font_dir() {
    local src_dir="$1" family_label="$2" dest_dir font name installed=0 skipped=0
    shopt -s nullglob
    local fonts=("$src_dir"/*.ttf) total=${#fonts[@]}
    shopt -u nullglob

    if [ "$total" -eq 0 ]; then
        log_warn "No .ttf files found in $src_dir, skipping $family_label."
        return
    fi

    case "$os" in
        windows) dest_dir="$LOCALAPPDATA/Microsoft/Windows/Fonts" ;;
        macos)   dest_dir="$HOME/Library/Fonts" ;;
        *)       dest_dir="$HOME/.local/share/fonts/$family_label" ;;
    esac
    mkdir -p "$dest_dir"

    if [ "$is_windows" -eq 1 ]; then
        local missing=() n=0
        for font in "${fonts[@]}"; do
            n=$((n + 1))
            if [ -e "$dest_dir/$(basename "$font")" ]; then
                skipped=$((skipped + 1))
            else
                missing+=("$font")
            fi
            progress_bar "$n" "$total" "$family_label"
        done

        if [ "${#missing[@]}" -eq 0 ]; then
            log_success "$family_label: already installed ($total/$total) -> $dest_dir"
            return
        fi

        local win_paths=()
        for font in "${missing[@]}"; do
            name="$(basename "$font")"
            if ! cp "$font" "$dest_dir/$name" 2>/dev/null; then
                log_warn "Could not copy $name (in use?), skipping."
                continue
            fi
            MSYS_NO_PATHCONV=1 reg add "HKCU\Software\Microsoft\Windows NT\CurrentVersion\Fonts" \
                /v "${name%.ttf} (TrueType)" /t REG_SZ /d "$name" /f >/dev/null 2>&1 || true
            win_paths+=("$(cygpath -w "$dest_dir/$name")")
            installed=$((installed + 1))
        done

        if [ "${#win_paths[@]}" -gt 0 ]; then
            local ps_error=""
            if ! ps_error="$(register_windows_fonts "${win_paths[@]}" 2>&1)"; then
                log_warn "Could not activate fonts for this session ($ps_error) -- they'll be available after your next login."
            fi
        fi

        if [ "$installed" -lt "${#missing[@]}" ]; then
            log_warn "$((${#missing[@]} - installed)) font(s) could not be copied."
        fi
        log_success "$family_label: $installed installed, $skipped already present -> $dest_dir"
        return
    fi

    local n=0 note=""
    for font in "${fonts[@]}"; do
        name="$(basename "$font")"
        n=$((n + 1))
        note=""

        if [ -e "$dest_dir/$name" ]; then
            skipped=$((skipped + 1))
            note="already installed"
        elif cp "$font" "$dest_dir/$name" 2>/dev/null; then
            installed=$((installed + 1))
        else
            note="in use, skipped"
        fi

        progress_bar "$n" "$total" "$family_label"
        if [ -n "$note" ]; then
            printf "  %s(%s: %s)%s\n" "$dim" "$name" "$note" "$reset"
        fi
    done

    if [ "$os" = "linux" ] && command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f "$dest_dir" >/dev/null 2>&1 || true
    fi

    log_success "$family_label: $installed installed, $skipped already present -> $dest_dir"
}

install_fonts() {
    select_menu "Which font do you want to install?" \
        "JetBrains Mono (editor font)" \
        "JetBrainsMono Nerd Font (terminal font)" \
        "Both" \
        "Skip"

    case "$REPLY_INDEX" in
        0)
            ensure_font_source "$jetbrains_mono_dir" fetch_jetbrains_mono
            install_font_dir "$jetbrains_mono_dir" "JetBrainsMono"
            ;;
        1)
            ensure_font_source "$nerd_font_dir" fetch_nerd_font
            install_font_dir "$nerd_font_dir" "JetBrainsMono-NerdFont"
            ;;
        2)
            ensure_font_source "$jetbrains_mono_dir" fetch_jetbrains_mono
            ensure_font_source "$nerd_font_dir" fetch_nerd_font
            install_font_dir "$jetbrains_mono_dir" "JetBrainsMono"
            install_font_dir "$nerd_font_dir" "JetBrainsMono-NerdFont"
            ;;
        3) log_info "Skipped font installation." ;;
        *) log_warn "Invalid choice, skipping fonts." ;;
    esac
}

main_menu() {
    select_menu "What would you like to install?" \
        "VS Code configs (settings.json + keybindings.json)" \
        "Git config (core.editor = code --wait)" \
        "Fonts" \
        "Everything" \
        "Exit"

    case "$REPLY_INDEX" in
        0) install_vscode_settings ;;
        1) install_git_config ;;
        2) install_fonts ;;
        3)
            install_vscode_settings
            install_git_config
            install_fonts
            ;;
        4) log_info "Exiting."; exit 0 ;;
        *) log_warn "Invalid choice."; main_menu ;;
    esac
}

banner() {
    cat <<'EOF'
       ░██               ░██        ░████ ░██░██
       ░██               ░██       ░██       ░██
 ░████████  ░███████  ░████████ ░████████ ░██░██  ░███████   ░███████
░██    ░██ ░██    ░██    ░██       ░██    ░██░██ ░██    ░██ ░██
░██    ░██ ░██    ░██    ░██       ░██    ░██░██ ░█████████  ░███████
░██   ░███ ░██    ░██    ░██       ░██    ░██░██ ░██               ░██
 ░█████░██  ░███████      ░████    ░██    ░██░██  ░███████   ░███████

EOF
}

if [ -t 1 ]; then
    clear 2>/dev/null || printf '\033c'
fi

echo "${cyan}${bold}$(banner)${reset}"
main_menu

echo ""
log_success "Done."
log_info "Restart VS Code (and any open terminals) so the new settings/fonts take effect."
