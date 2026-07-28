#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) user_dir="$APPDATA/Code/User" ;;
    *)                    user_dir="$HOME/.config/Code/User" ;;
esac

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

echo "Done."
