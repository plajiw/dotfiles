param(
    [string]$InstallDir,
    [string]$ConfigDir
)

$ErrorActionPreference = 'Stop'

if (-not $IsWindows -and $PSVersionTable.PSEdition -eq 'Core') {
    throw 'The Graphite profile currently supports Windows 10/11 only.'
}

$profileDir = $PSScriptRoot
$localAppData = [Environment]::GetFolderPath('LocalApplicationData')
if (-not $ConfigDir) {
    $ConfigDir = Join-Path $localAppData 'xournalpp'
}

function Find-XournalInstall {
    param([string]$RequestedPath)

    $candidates = @()
    if ($RequestedPath) { $candidates += $RequestedPath }
    if (-not $RequestedPath) {
        $candidates += (Join-Path $localAppData 'Programs\Xournal++')
        if ($env:ProgramFiles) { $candidates += (Join-Path $env:ProgramFiles 'Xournal++') }
        if (${env:ProgramFiles(x86)}) { $candidates += (Join-Path ${env:ProgramFiles(x86)} 'Xournal++') }
        $command = Get-Command 'xournalpp.exe' -ErrorAction SilentlyContinue
        if ($command) { $candidates += (Split-Path -Parent (Split-Path -Parent $command.Source)) }
    }

    foreach ($candidate in $candidates) {
        if (-not $candidate) { continue }
        $ui = Join-Path $candidate 'share\xournalpp\ui'
        if ((Test-Path -LiteralPath (Join-Path $ui 'xournalpp.css')) -and
            (Test-Path -LiteralPath (Join-Path $ui 'pagetemplates.ini')) -and
            (Test-Path -LiteralPath (Join-Path $ui 'iconsLucide-dark'))) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    throw 'Xournal++ installation not found (or Lucide icons unavailable). Install Xournal++ 1.3+ or pass -InstallDir.'
}

$InstallDir = Find-XournalInstall $InstallDir
$uiDir = Join-Path $InstallDir 'share\xournalpp\ui'
$paletteDir = Join-Path $ConfigDir 'palettes'
$isLiveConfig = [IO.Path]::GetFullPath($ConfigDir).TrimEnd('\') -ieq
    [IO.Path]::GetFullPath((Join-Path $localAppData 'xournalpp')).TrimEnd('\')
if ($isLiveConfig -and (Get-Process -Name 'xournalpp' -ErrorAction SilentlyContinue)) {
    throw 'Close Xournal++ (save any open document) before applying Graphite, then run this option again.'
}
if (-not (Test-Path -LiteralPath (Join-Path $InstallDir 'share\xournalpp\resources\default_template.tex'))) {
    throw 'The Xournal++ LaTeX template is missing from this installation.'
}

# Check shared-resource write access before changing the user profile.
$writeProbe = Join-Path $uiDir ".graphite-write-test-$PID"
try {
    [IO.File]::WriteAllText($writeProbe, '')
} catch {
    throw "Cannot write to $uiDir. Re-run from an elevated PowerShell if Xournal++ is installed for all users."
} finally {
    if (Test-Path -LiteralPath $writeProbe) { Remove-Item -LiteralPath $writeProbe -Force }
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Write-ProfileFile {
    param([string]$Path, [string]$Content)

    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    if (Test-Path -LiteralPath $Path) {
        if ([IO.File]::ReadAllText($Path) -ceq $Content) {
            Write-Host "Already current: $Path"
            return
        }
        Copy-Item -LiteralPath $Path -Destination "$Path.bak-$stamp"
    }
    [IO.File]::WriteAllText($Path, $Content, $utf8)
    Write-Host "Updated: $Path"
}

function Remove-IniSection {
    param([string]$Content, [string]$Name)
    $pattern = '(?ms)^\[' + [regex]::Escape($Name) + '\][^\r\n]*\r?\n.*?(?=^\[|\z)'
    return [regex]::Replace($Content, $pattern, '')
}

# Capture all Xournal preferences, not only the visible toolbar/theme toggles.
# The two installation-specific absolute paths are rendered for this machine.
$settingsTemplate = [IO.File]::ReadAllText((Join-Path $profileDir 'settings.xml'))
$palettePath = Join-Path $paletteDir 'Graphite.gpl'
$latexPath = Join-Path $InstallDir 'share\xournalpp\resources\default_template.tex'
$settings = $settingsTemplate.Replace('__GRAPHITE_PALETTE__',
    [System.Security.SecurityElement]::Escape($palettePath)).Replace('__XOURNAL_LATEX_TEMPLATE__',
    [System.Security.SecurityElement]::Escape($latexPath))
if ($settings.Contains('__GRAPHITE_PALETTE__') -or $settings.Contains('__XOURNAL_LATEX_TEMPLATE__')) {
    throw 'Unresolved path in Xournal++ settings template.'
}
[xml]$null = $settings

$palette = [IO.File]::ReadAllText((Join-Path $profileDir 'Graphite.gpl'))
$toolbarProfile = [IO.File]::ReadAllText((Join-Path $profileDir 'toolbar.ini')).Trim()
$cssProfile = [IO.File]::ReadAllText((Join-Path $profileDir 'xournalpp.css')).Trim()
$pagesProfile = [IO.File]::ReadAllText((Join-Path $profileDir 'pagetemplates.ini')).Trim()

$toolbarPath = Join-Path $ConfigDir 'toolbar.ini'
if (Test-Path -LiteralPath $toolbarPath) {
    $toolbar = [IO.File]::ReadAllText($toolbarPath)
} else {
    $toolbar = [IO.File]::ReadAllText((Join-Path $uiDir 'toolbar.ini'))
}
$toolbar = (Remove-IniSection $toolbar 'Graphite Study').TrimEnd() + "`r`n`r`n" + $toolbarProfile + "`r`n"

$cssPath = Join-Path $uiDir 'xournalpp.css'
$css = [IO.File]::ReadAllText($cssPath)
$css = [regex]::Replace($css,
    '(?s)/\* BEGIN DOTFILES GRAPHITE STUDY \*/.*?/\* END DOTFILES GRAPHITE STUDY \*/\s*', '')
# Remove the unmarked block applied during the original interactive setup.
$legacyCss = $css.IndexOf('/* Graphite Study: neutral dark surfaces, consistent across GTK panels. */')
if ($legacyCss -ge 0) { $css = $css.Substring(0, $legacyCss) }
$css = $css.TrimEnd() + "`r`n`r`n/* BEGIN DOTFILES GRAPHITE STUDY */`r`n" +
    $cssProfile + "`r`n/* END DOTFILES GRAPHITE STUDY */`r`n"

$pagesPath = Join-Path $uiDir 'pagetemplates.ini'
$pages = [IO.File]::ReadAllText($pagesPath)
$pages = Remove-IniSection $pages 'graphiteGrid'
$pages = Remove-IniSection $pages 'graphiteDiagram'
$pages = $pages.TrimEnd() + "`r`n`r`n" + $pagesProfile + "`r`n"

Write-ProfileFile $palettePath $palette
Write-ProfileFile $toolbarPath $toolbar
Write-ProfileFile $cssPath $css
Write-ProfileFile $pagesPath $pages
Write-ProfileFile (Join-Path $ConfigDir 'settings.xml') $settings

Write-Host 'Graphite is installed. Launch Xournal++ to load the profile.'
