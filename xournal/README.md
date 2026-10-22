# Xournal++ Graphite (Windows 10/11)

Run `./install.sh` in Git Bash and select **Xournal++ Graphite**, or include it through **Everything**. Save open documents and close Xournal++ before installing. Xournal++ must already be installed; this profile was captured and visually checked with Xournal++ `1.3.8+dev` on Windows.

The installer discovers a per-user or `Program Files` installation, then applies:

| Repository file | Destination | Content |
| --- | --- | --- |
| `Graphite.gpl` | `%LOCALAPPDATA%\xournalpp\palettes\Graphite.gpl` | Ten ink colors, white first, then blue, green, yellow, coral |
| `toolbar.ini` | Graphite Study section in `%LOCALAPPDATA%\xournalpp\toolbar.ini` | Short top bar, drawing tools and colors on the left, navigation and zoom below |
| `settings.xml` | `%LOCALAPPDATA%\xournalpp\settings.xml` | Full saved profile: `en_US`, dark mode, Lucide icons, page/canvas/selection colors, default tools, zoom and other preferences |
| `xournalpp.css` | Graphite block in the installation's `share\xournalpp\ui\xournalpp.css` | Neutral black and graphite surfaces for bars, sidebar, menus, popovers, hover and selected states |
| `pagetemplates.ini` | Graphite Grid/Diagram sections in the installation's `share\xournalpp\ui\pagetemplates.ini` | 5 mm writing grid and 10 mm diagram grid |

The script keeps existing toolbar presets and page templates, replacing only Graphite sections. It also replaces only its own Graphite CSS block. Re-running it does not duplicate those sections. Before changing a file, it writes a timestamped backup beside that file. The settings snapshot deliberately replaces the current Xournal++ preferences to reproduce the whole profile; the old settings are backed up.

The palette and LaTeX resource paths in the settings snapshot are rendered for the target PC. Installation discovery supports `%LOCALAPPDATA%\Programs\Xournal++`, `Program Files`, and `xournalpp.exe` on `PATH`. An explicit installation can be supplied with `powershell.exe -NoProfile -ExecutionPolicy Bypass -File xournal/install.ps1 -InstallDir 'C:\Path\To\Xournal++'`.

The Windows title bar and monitor DPI are controlled outside Xournal++'s CSS, so their exact pixels can vary across PCs. The profile uses automatic DPI detection. Xournal++ updates may replace files inside `share\xournalpp\ui`; re-run this option after an update.
