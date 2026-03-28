# =============================================================================
# Lightbird — Thunderbird Theme Installer (Windows)
#
# Usage (from PowerShell):
#   powershell -ExecutionPolicy Bypass -File install.ps1
#   powershell -ExecutionPolicy Bypass -File install.ps1 -Yes
#   powershell -ExecutionPolicy Bypass -File install.ps1 -Uninstall
# =============================================================================

param(
    [switch]$Yes,
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Ok($msg)  { Write-Host "  OK $msg" -ForegroundColor Green }
function Err($msg) { Write-Host "Error: $msg" -ForegroundColor Red; exit 1 }
function Hdr($msg) { Write-Host "`n$msg" -ForegroundColor Cyan }

# ── Locate Thunderbird data directory ─────────────────────────────────────────
$TbDir = Join-Path $env:APPDATA 'Thunderbird'
if (-not (Test-Path $TbDir)) {
    Err "Thunderbird directory not found: $TbDir`n  Open Thunderbird at least once to create a profile, then re-run."
}

# ── Locate the default profile ────────────────────────────────────────────────
$ProfilesIni = Join-Path $TbDir 'profiles.ini'
if (-not (Test-Path $ProfilesIni)) {
    Err "profiles.ini not found: $ProfilesIni"
}

# Parse profiles.ini.
# Modern Thunderbird writes an [Install<hash>] section whose Default= key
# points to the profile that was last actually launched — prefer that over
# the legacy Default=1 flag inside [Profile...] sections, which can point
# to an old .default folder that is no longer used.
$lines = Get-Content $ProfilesIni

# Strategy 1: [Install...] section — most reliable
$installDefault = $null
$inInstall = $false
foreach ($line in $lines) {
    $line = $line.Trim()
    if ($line -match '^\[Install')          { $inInstall = $true; continue }
    if ($line -match '^\[')                 { $inInstall = $false; continue }
    if ($inInstall -and $line -match '^Default=(.+)') { $installDefault = $Matches[1]; break }
}

$ProfileDir = $null
if ($installDefault) {
    # Path may be relative (Profiles/xxx) or absolute
    $candidate = if ([System.IO.Path]::IsPathRooted($installDefault)) {
        $installDefault
    } else {
        Join-Path $TbDir $installDefault
    }
    if (Test-Path $candidate) { $ProfileDir = $candidate }
}

# Strategy 2: [Profile...] section with Default=1
if (-not $ProfileDir) {
    $currentPath = $null; $currentIsRelative = $true; $currentDefault = $false
    foreach ($line in $lines) {
        $line = $line.Trim()
        if ($line -match '^\[Profile') {
            if ($currentDefault -and $currentPath) {
                $ProfileDir = if ($currentIsRelative) { Join-Path $TbDir $currentPath } else { $currentPath }
                break
            }
            $currentPath = $null; $currentIsRelative = $true; $currentDefault = $false
        }
        elseif ($line -match '^Path=(.+)')  { $currentPath      = $Matches[1] }
        elseif ($line -eq 'IsRelative=0')   { $currentIsRelative = $false }
        elseif ($line -eq 'Default=1')      { $currentDefault   = $true }
    }
    if (-not $ProfileDir -and $currentDefault -and $currentPath) {
        $ProfileDir = if ($currentIsRelative) { Join-Path $TbDir $currentPath } else { $currentPath }
    }
}

# Strategy 3: newest *.default-release or *.default folder
if (-not $ProfileDir) {
    $ProfileDir = Get-ChildItem $TbDir -Directory |
        Where-Object { $_.Name -match '\.(default-release|default)$' } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -ExpandProperty FullName -First 1
}

if (-not $ProfileDir -or -not (Test-Path $ProfileDir)) {
    Err "Could not find a Thunderbird profile.`n  Open Thunderbird once to create a profile, then re-run."
}

$ChromeDir = Join-Path $ProfileDir 'chrome'

# ── Print summary and confirm ─────────────────────────────────────────────────
Write-Host ""
Write-Host "Lightbird — Thunderbird Theme Installer" -ForegroundColor White
Write-Host "  Profile : $ProfileDir"
Write-Host "  Action  : $(if ($Uninstall) { 'uninstall' } else { 'install' })"
Write-Host ""

if (-not $Yes) {
    $ans = Read-Host "  Proceed? [Y/n]"
    if ($ans -and $ans -notmatch '^[Yy]') { Write-Host "Aborted."; exit 0 }
}

# ── Uninstall ─────────────────────────────────────────────────────────────────
if ($Uninstall) {
    Hdr "Removing theme files..."
    @('lightbird', 'images') | ForEach-Object {
        $p = Join-Path $ChromeDir $_
        if (Test-Path $p) { Remove-Item $p -Recurse -Force; Ok "Removed $_/" }
    }
    @('userChrome.css', 'userContent.css') | ForEach-Object {
        $p = Join-Path $ChromeDir $_
        if (Test-Path $p) { Remove-Item $p -Force; Ok "Removed $_" }
    }
    Write-Host "`nLightbird uninstalled. Restart Thunderbird." -ForegroundColor Green
    exit 0
}

# ── Install ───────────────────────────────────────────────────────────────────
Hdr "Installing theme files..."
New-Item -ItemType Directory -Force -Path $ChromeDir | Out-Null

Copy-Item (Join-Path $ScriptDir 'userChrome.css')  (Join-Path $ChromeDir 'userChrome.css')  -Force; Ok "userChrome.css"
Copy-Item (Join-Path $ScriptDir 'userContent.css') (Join-Path $ChromeDir 'userContent.css') -Force; Ok "userContent.css"

$dst = Join-Path $ChromeDir 'lightbird'
if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
Copy-Item (Join-Path $ScriptDir 'lightbird') $dst -Recurse -Force; Ok "lightbird/"

$dst = Join-Path $ChromeDir 'images'
if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
Copy-Item (Join-Path $ScriptDir 'images') $dst -Recurse -Force; Ok "images/"

# ── Install patched extensions ────────────────────────────────────────────────
$ExtSrc = Join-Path $ScriptDir 'extensions'
if (Test-Path $ExtSrc) {
    $ExtDir = Join-Path $ProfileDir 'extensions'
    New-Item -ItemType Directory -Force -Path $ExtDir | Out-Null
    Get-ChildItem $ExtSrc -Filter '*.xpi' | ForEach-Object {
        Copy-Item $_.FullName (Join-Path $ExtDir $_.Name) -Force
        Ok "extension: $($_.Name)"
    }
}

# ── Merge user.js ─────────────────────────────────────────────────────────────
Hdr "Installing preferences..."
$SrcJs = Join-Path $ScriptDir 'user.js'
$DstJs = Join-Path $ProfileDir 'user.js'

if (-not (Test-Path $DstJs)) {
    Copy-Item $SrcJs $DstJs; Ok "Created user.js"
} else {
    $existing = Get-Content $DstJs -Raw
    $added = 0
    foreach ($line in Get-Content $SrcJs) {
        $trimmed = $line.Trim()
        if (-not $trimmed) { continue }
        if ($trimmed -match '^(/\*|\*|//)') { continue }
        if ($trimmed -match 'user_pref\("([^"]+)"') {
            $key = $Matches[1]
            if ($existing -notmatch [regex]::Escape($key)) {
                Add-Content $DstJs $line
                $added++
            }
        }
    }
    if ($added -gt 0) { Ok "Merged $added new preference(s) into user.js" }
    else              { Ok "user.js already up to date" }
}

Write-Host "`nLightbird installed! Restart Thunderbird to apply the theme." -ForegroundColor Green
Write-Host ""
Write-Host "  Tip: for a translucent titlebar, open Advanced Preferences and set:" -ForegroundColor DarkGray
Write-Host "    widget.windows.mica                  = true" -ForegroundColor DarkGray
Write-Host "    widget.windows.mica.toplevel-backdrop = 2  (Acrylic) or 1 (Mica)" -ForegroundColor DarkGray
Write-Host ""
