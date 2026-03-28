#!/usr/bin/env bash
# =============================================================================
# Lightbird — Thunderbird Theme Installer
# Supports: Linux · macOS · Windows (Git Bash / MINGW / MSYS2)
#
# Usage:
#   bash install.sh          # interactive — confirm before installing
#   bash install.sh -y       # non-interactive — install without prompting
#   bash install.sh --uninstall   # remove theme files from chrome/
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Terminal colours (suppressed when stdout is not a tty) ────────────────────
if [[ -t 1 ]]; then
    RED='\033[0;31m' GREEN='\033[0;32m' CYAN='\033[0;36m' BOLD='\033[1m' NC='\033[0m'
else
    RED='' GREEN='' CYAN='' BOLD='' NC=''
fi

die()  { echo -e "${RED}Error: ${*}${NC}" >&2; exit 1; }
ok()   { echo -e "${GREEN}  ✓ ${*}${NC}"; }
info() { echo -e "${CYAN}  → ${*}${NC}"; }
hdr()  { echo -e "\n${BOLD}${*}${NC}"; }

# ── Parse arguments ───────────────────────────────────────────────────────────
YES=0; UNINSTALL=0
for arg in "$@"; do
    case "$arg" in
        -y|--yes)        YES=1 ;;
        --uninstall)     UNINSTALL=1 ;;
        -h|--help)
            echo "Usage: bash install.sh [-y|--yes] [--uninstall]"
            exit 0 ;;
        *)  die "Unknown argument: $arg  (try --help)" ;;
    esac
done

# ── Detect OS ─────────────────────────────────────────────────────────────────
case "$(uname -s)" in
    Linux*)               OS=linux   ;;
    Darwin*)              OS=macos   ;;
    MINGW*|MSYS*|CYGWIN*) OS=windows ;;
    *) die "Unsupported OS: $(uname -s)\n  Supported: Linux, macOS, Windows (Git Bash / MSYS2 / Cygwin)" ;;
esac

# ── Thunderbird data directory ────────────────────────────────────────────────
case "$OS" in
    linux)
        TB_DIR="${HOME}/.thunderbird"
        ;;
    macos)
        TB_DIR="${HOME}/Library/Thunderbird"
        ;;
    windows)
        [[ -n "${APPDATA:-}" ]] \
            || die "APPDATA is not set.\n  Run this script from Git Bash, MSYS2, or Cygwin."
        if command -v cygpath &>/dev/null; then
            # -m = mixed format: C:/Users/... (forward slashes, Windows drive letter)
            # This works with both MSYS2 bash tools AND Windows-native Python3.
            # Do NOT use -u here: /c/Users/... paths confuse Windows-native Python3.
            TB_DIR="$(cygpath -m "${APPDATA}")/Thunderbird"
        else
            # Simple backslash swap — APPDATA is already C:\Users\..., just normalise slashes
            TB_DIR="${APPDATA//\\//}/Thunderbird"
        fi
        ;;
esac

[[ -d "$TB_DIR" ]] \
    || die "Thunderbird directory not found: $TB_DIR\n  Open Thunderbird at least once to create a profile, then re-run."

# ── Locate the default profile ────────────────────────────────────────────────
PROFILES_INI="${TB_DIR}/profiles.ini"
[[ -f "$PROFILES_INI" ]] || die "profiles.ini not found: $PROFILES_INI"

# Strategy 1: Python 3 — most reliable cross-platform INI parser
_find_profile_python() {
    python3 - "$PROFILES_INI" "$TB_DIR" 2>/dev/null <<'PYEOF'
import configparser, sys
ini, tb = sys.argv[1], sys.argv[2]
c = configparser.RawConfigParser()
c.read(ini)
for section in c.sections():
    if not section.startswith('Profile'):
        continue
    if c.has_option(section, 'Default') and c.get(section, 'Default') == '1' \
            and c.has_option(section, 'Path'):
        p      = c.get(section, 'Path')
        is_rel = not (c.has_option(section, 'IsRelative')
                      and c.get(section, 'IsRelative') == '0')
        # Use explicit string join with / — os.path.join uses \ on Windows
        result = tb.rstrip('/\\') + '/' + p if is_rel else p
        print(result.replace('\\', '/'))
        sys.exit(0)
sys.exit(1)
PYEOF
}

# Strategy 2: awk — portable fallback, no external deps beyond awk
_find_profile_awk() {
    awk -v tb="$TB_DIR" '
        /^\[Profile/  { path=""; isrel=1; def=0 }
        /^\[/         { if (!/^\[Profile/) { path=""; def=0 } }
        /^Path=/      { path = substr($0, 6) }
        /^IsRelative=0$/ { isrel = 0 }
        /^IsRelative=1$/ { isrel = 1 }
        /^Default=1$/ { def = 1 }
        def && path   { print (isrel ? tb "/" path : path); exit }
    ' "$PROFILES_INI"
}

# Strategy 3: newest *.default-release or *.default directory
_find_profile_newest() {
    ls -dt "${TB_DIR}"/*.default-release "${TB_DIR}"/*.default 2>/dev/null | head -1
}

PROFILE_DIR=""
command -v python3 &>/dev/null && PROFILE_DIR="$(_find_profile_python)"
[[ -n "$PROFILE_DIR" ]]         || PROFILE_DIR="$(_find_profile_awk)"
[[ -n "$PROFILE_DIR" ]]         || PROFILE_DIR="$(_find_profile_newest)"

[[ -n "$PROFILE_DIR" && -d "$PROFILE_DIR" ]] \
    || die "Could not find a Thunderbird profile.\n  Open Thunderbird once to create a profile, then re-run."

CHROME_DIR="${PROFILE_DIR}/chrome"

# ── Print summary and confirm ─────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Lightbird — Thunderbird Theme Installer${NC}"
echo "  OS      : $OS"
echo "  Profile : $PROFILE_DIR"
if [[ $UNINSTALL -eq 1 ]]; then
    echo "  Action  : uninstall"
else
    echo "  Action  : install"
fi
echo ""

if [[ $YES -eq 0 ]]; then
    read -rp "  Proceed? [Y/n] " _ans
    case "${_ans:-y}" in
        [Yy]*|"") ;;
        *) echo "Aborted."; exit 0 ;;
    esac
fi

# ── Uninstall path ────────────────────────────────────────────────────────────
if [[ $UNINSTALL -eq 1 ]]; then
    hdr "Removing theme files..."
    rm -rf  "${CHROME_DIR}/lightbird"   && ok "Removed lightbird/"
    rm -rf  "${CHROME_DIR}/images"      && ok "Removed images/"
    rm -f   "${CHROME_DIR}/userChrome.css"  && ok "Removed userChrome.css"
    rm -f   "${CHROME_DIR}/userContent.css" && ok "Removed userContent.css"
    echo ""
    echo -e "${BOLD}${GREEN}✓ Lightbird uninstalled. Restart Thunderbird.${NC}"
    exit 0
fi

# ── Install ───────────────────────────────────────────────────────────────────
hdr "Installing theme files..."
mkdir -p "$CHROME_DIR"

# userChrome.css — chrome UI stylesheet
cp "${SCRIPT_DIR}/userChrome.css"  "${CHROME_DIR}/userChrome.css"
ok "userChrome.css"

# userContent.css — content-page overrides (message reader, add-ons, etc.)
cp "${SCRIPT_DIR}/userContent.css" "${CHROME_DIR}/userContent.css"
ok "userContent.css"

# lightbird/ — component library (CSS + font/icon assets)
rm -rf "${CHROME_DIR}/lightbird"
cp -r  "${SCRIPT_DIR}/lightbird"  "${CHROME_DIR}/lightbird"
ok "lightbird/ component library"

# images/ — wallpaper and icon images referenced by userChrome.css
rm -rf "${CHROME_DIR}/images"
cp -r  "${SCRIPT_DIR}/images"     "${CHROME_DIR}/images"
ok "images/"

# ── Install / merge user.js preferences ──────────────────────────────────────
hdr "Installing preferences..."

SRC_JS="${SCRIPT_DIR}/user.js"
DST_JS="${PROFILE_DIR}/user.js"

if [[ ! -f "$DST_JS" ]]; then
    cp "$SRC_JS" "$DST_JS"
    ok "Created user.js"
else
    _added=0
    while IFS= read -r _line; do
        # Skip blank lines and comment-only lines
        _trim="${_line#"${_line%%[![:space:]]*}"}"
        [[ -z "$_trim" ]] && continue
        case "$_trim" in /\**|//*|\**) continue ;; esac

        # Extract the pref key:  user_pref("some.pref.name", ...)  →  "some.pref.name"
        _key=$(printf '%s\n' "$_line" | sed -n 's/.*user_pref(\("[^"]*"\).*/\1/p')
        [[ -z "$_key" ]] && continue

        # Append only if this key is not already present in the destination
        if ! grep -qF "$_key" "$DST_JS"; then
            printf '%s\n' "$_line" >> "$DST_JS"
            _added=$(( _added + 1 ))
        fi
    done < "$SRC_JS"

    if [[ $_added -gt 0 ]]; then
        ok "Merged $_added new preference(s) into user.js"
    else
        ok "user.js already up to date"
    fi
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}✓ Lightbird installed! Restart Thunderbird to apply the theme.${NC}"

if [[ "$OS" == "windows" ]]; then
    echo ""
    echo "  Windows tip — for a translucent titlebar, open Advanced Preferences and set:"
    echo "    widget.windows.mica                   = true"
    echo "    widget.windows.mica.toplevel-backdrop  = 2   (Acrylic) or 1 (Mica)"
    echo "  Requires: System theme — auto in Thunderbird settings."
fi
echo ""
