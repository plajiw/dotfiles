# plajiw dotfiles

My personal VS Code configuration: editor/terminal settings, keybindings, and the fonts they reference.

## Install

Requires Git Bash on Windows, or any bash shell on Linux.

```bash
./install.sh
```

This opens a menu to choose what to install:

- **VS Code configs** — copies `vscode/settings.json` and `vscode/keybindings.json` into VS Code's User folder. Any existing files there are backed up with a `.bak` suffix first.
- **Git config** — links `git/gitconfig` (sets `core.editor = code --wait`) into your global git config via `git config --global include.path`, without touching the rest of `~/.gitconfig`.
- **Fonts** — installs `JetBrains Mono` (editor font) and/or `JetBrainsMono Nerd Font` (terminal font, used for icons/glyphs) for the current user. On Windows this copies the `.ttf` files to the per-user Fonts folder and registers them; on Linux it copies them to `~/.local/share/fonts` and refreshes the font cache. If the `.ttf` files aren't present in `fonts/`, they're downloaded automatically (with a progress bar) from the official JetBrains Mono and Nerd Fonts GitHub releases.
