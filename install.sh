#!/usr/bin/env bash
# =============================================================================
# Lightbird — Thunderbird Theme Installer (Linux & macOS)
# For Windows use install.ps1 instead.
#
# Usage:
#   bash install.sh            # interactive — confirm before installing
#   bash install.sh -y         # non-interactive
#   bash install.sh --uninstall
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Terminal colours ──────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
    RED='\033[0;31m' GREEN='\033[0;32m' CYAN='\033[0;36m' BOLD='\033[1m' NC='\033[0m'
else
    RED='' GREEN='' CYAN='' BOLD='' NC=''
fi

die()  { echo -e "${RED}Error: ${*}${NC}" >&2; exit 1; }
ok()   { echo -e "${GREEN}  ✓ ${*}${NC}"; }
hdr()  { echo -e "\n${BOLD}${*}${NC}"; }

# ── Parse arguments ───────────────────────────────────────────────────────────
YES=0; UNINSTALL=0
for arg in "$@"; do
    case "$arg" in
        -y|--yes)    YES=1 ;;
        --uninstall) UNINSTALL=1 ;;
        -h|--help)   echo "Usage: bash install.sh [-y] [--uninstall]"; exit 0 ;;
        *)           die "Unknown argument: $arg  (try --help)" ;;
    esac
done

# ── Detect OS ─────────────────────────────────────────────────────────────────
case "$(uname -s)" in
    Linux*)  OS=linux ;;
    Darwin*) OS=macos ;;
    *)       die "This script is for Linux and macOS.\n  On Windows, run: powershell -ExecutionPolicy Bypass -File install.ps1" ;;
esac

# ── Thunderbird data directory ────────────────────────────────────────────────
case "$OS" in
    linux) TB_DIR="${HOME}/.thunderbird" ;;
    macos) TB_DIR="${HOME}/Library/Thunderbird" ;;
esac

[[ -d "$TB_DIR" ]] \
    || die "Thunderbird directory not found: $TB_DIR\n  Open Thunderbird at least once to create a profile, then re-run."

# ── Locate the default profile ────────────────────────────────────────────────
PROFILES_INI="${TB_DIR}/profiles.ini"
[[ -f "$PROFILES_INI" ]] || die "profiles.ini not found: $PROFILES_INI"

# Strategy 1: [Install...] section — the profile Thunderbird actually launched last
_find_profile_install() {
    awk -v tb="$TB_DIR" '
        /^\[Install/  { install=1; next }
        /^\[/         { install=0 }
        install && /^Default=/ {
            p = substr($0, 9)
            # relative if it does not start with / or a drive letter
            if (p !~ /^\// && p !~ /^[A-Za-z]:/) print tb "/" p
            else print p
            exit
        }
    ' "$PROFILES_INI"
}

# Strategy 2: [Profile...] section with Default=1
_find_profile_python() {
    python3 - "$PROFILES_INI" "$TB_DIR" 2>/dev/null <<'PYEOF'
import configparser, sys
ini, tb = sys.argv[1], sys.argv[2]
c = configparser.RawConfigParser()
c.read(ini)
for s in c.sections():
    if not s.startswith('Profile'): continue
    if c.has_option(s,'Default') and c.get(s,'Default')=='1' and c.has_option(s,'Path'):
        p = c.get(s,'Path')
        rel = not (c.has_option(s,'IsRelative') and c.get(s,'IsRelative')=='0')
        print(tb.rstrip('/')+'/'+p if rel else p)
        sys.exit(0)
sys.exit(1)
PYEOF
}

_find_profile_awk() {
    awk -v tb="$TB_DIR" '
        /^\[Profile/ { path=""; isrel=1; def=0 }
        /^\[/        { if (!/^\[Profile/) { path=""; def=0 } }
        /^Path=/     { path=substr($0,6) }
        /^IsRelative=0$/ { isrel=0 }
        /^Default=1$/ { def=1 }
        def && path  { print (isrel ? tb"/"path : path); exit }
    ' "$PROFILES_INI"
}

# Strategy 3: newest *.default-release or *.default folder
_find_profile_newest() {
    ls -dt "${TB_DIR}"/*.default-release "${TB_DIR}"/*.default 2>/dev/null | head -1
}

PROFILE_DIR="$(_find_profile_install)"
[[ -n "$PROFILE_DIR" && -d "$PROFILE_DIR" ]] || {
    command -v python3 &>/dev/null && PROFILE_DIR="$(_find_profile_python)"
}
[[ -n "$PROFILE_DIR" ]] || PROFILE_DIR="$(_find_profile_awk)"
[[ -n "$PROFILE_DIR" ]] || PROFILE_DIR="$(_find_profile_newest)"

[[ -n "$PROFILE_DIR" && -d "$PROFILE_DIR" ]] \
    || die "Could not find a Thunderbird profile.\n  Open Thunderbird once to create a profile, then re-run."

CHROME_DIR="${PROFILE_DIR}/chrome"

# ── Print summary and confirm ─────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Lightbird — Thunderbird Theme Installer${NC}"
echo "  OS      : $OS"
echo "  Profile : $PROFILE_DIR"
echo "  Action  : $([ $UNINSTALL -eq 1 ] && echo uninstall || echo install)"
echo ""

if [[ $YES -eq 0 ]]; then
    read -rp "  Proceed? [Y/n] " _ans
    case "${_ans:-y}" in [Yy]*|"") ;; *) echo "Aborted."; exit 0 ;; esac
fi

# ── Uninstall ─────────────────────────────────────────────────────────────────
if [[ $UNINSTALL -eq 1 ]]; then
    hdr "Removing theme files..."
    rm -rf "${CHROME_DIR}/lightbird"      && ok "Removed lightbird/"
    rm -rf "${CHROME_DIR}/images"         && ok "Removed images/"
    rm -f  "${CHROME_DIR}/userChrome.css" && ok "Removed userChrome.css"
    rm -f  "${CHROME_DIR}/userContent.css"&& ok "Removed userContent.css"
    echo ""
    echo -e "${BOLD}${GREEN}✓ Lightbird uninstalled. Restart Thunderbird.${NC}"
    exit 0
fi

# ── Install ───────────────────────────────────────────────────────────────────
hdr "Installing theme files..."
mkdir -p "$CHROME_DIR"

cp    "${SCRIPT_DIR}/userChrome.css"  "${CHROME_DIR}/userChrome.css"  && ok "userChrome.css"
cp    "${SCRIPT_DIR}/userContent.css" "${CHROME_DIR}/userContent.css" && ok "userContent.css"
rm -rf "${CHROME_DIR}/lightbird" && cp -r "${SCRIPT_DIR}/lightbird" "${CHROME_DIR}/lightbird" && ok "lightbird/"
rm -rf "${CHROME_DIR}/images"    && cp -r "${SCRIPT_DIR}/images"    "${CHROME_DIR}/images"    && ok "images/"

# ── Merge user.js ─────────────────────────────────────────────────────────────
hdr "Installing preferences..."
SRC_JS="${SCRIPT_DIR}/user.js"
DST_JS="${PROFILE_DIR}/user.js"

if [[ ! -f "$DST_JS" ]]; then
    cp "$SRC_JS" "$DST_JS" && ok "Created user.js"
else
    _added=0
    while IFS= read -r _line; do
        _trim="${_line#"${_line%%[![:space:]]*}"}"
        [[ -z "$_trim" ]] && continue
        case "$_trim" in /\**|//*|\**) continue ;; esac
        _key=$(printf '%s\n' "$_line" | sed -n 's/.*user_pref(\("[^"]*"\).*/\1/p')
        [[ -z "$_key" ]] && continue
        if ! grep -qF "$_key" "$DST_JS"; then
            printf '%s\n' "$_line" >> "$DST_JS"
            _added=$(( _added + 1 ))
        fi
    done < "$SRC_JS"
    [[ $_added -gt 0 ]] && ok "Merged $_added new preference(s) into user.js" || ok "user.js already up to date"
fi

echo ""
echo -e "${BOLD}${GREEN}✓ Lightbird installed! Restart Thunderbird to apply the theme.${NC}"
echo ""
