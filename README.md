# plajiw dotfiles

My personal development and study environment: VS Code, Git, fonts, and a Xournal++ Graphite profile.

## Install

Requires Git Bash on Windows, or any bash shell on Linux.

```bash
./install.sh
```

This opens a menu to choose what to install:

- **VS Code configs** — copies `vscode/settings.json` and `vscode/keybindings.json` into VS Code's User folder. Any existing files there are backed up with a `.bak` suffix first.
- **Git config** — links `git/gitconfig` (sets `core.editor = code --wait`) into your global git config via `git config --global include.path`, without touching the rest of `~/.gitconfig`.
- **Fonts** — installs `JetBrains Mono` (editor font) and/or `JetBrainsMono Nerd Font` (terminal font, used for icons/glyphs) for the current user. On Windows this copies the `.ttf` files to the per-user Fonts folder and registers them; on Linux it copies them to `~/.local/share/fonts` and refreshes the font cache. If the `.ttf` files aren't present in `fonts/`, they're downloaded automatically (with a progress bar) from the official JetBrains Mono and Nerd Fonts GitHub releases.
- **Xournal++ Graphite** — on Windows 10/11, installs the complete Graphite profile: neutral dark UI CSS, the ten-color ink palette, the Graphite Study toolbar, Graphite Grid/Diagram page templates, and the saved Xournal++ preferences (including English locale and dark page). Close Xournal++ before running it. Existing files that change are backed up with a timestamped `.bak-*` suffix. See [xournal/README.md](xournal/README.md) for locations and details.

`Everything` includes Xournal++ on Windows. The Xournal++ option is currently skipped on macOS and Linux.
