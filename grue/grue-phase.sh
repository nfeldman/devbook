#!/usr/bin/env bash
#
# grue-phase.sh — step the GRUE accent through the day.
# Computes the current grue hex (grue-now.sh) and writes it into the marked
# accent lines of the theme files. Starship re-reads its config every prompt, so
# the prompt accent updates live on the next prompt; Ghostty/Zellij pick it up on
# their next new window/reload (see GRUE-README — smooth motion isn't possible in
# a terminal, this is the honest stepped approximation).
#
# Run by launchd every ~20 min. Reversible: GRUE_STATIC=1 pins the daytime green.
# ---------------------------------------------------------------------------
set -euo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"

BIN="${GRUE_BIN:-$HOME/.local/bin}"
CFG="$HOME/.config"
STATE="$HOME/.local/state/grue"; mkdir -p "$STATE"
LOG="$STATE/phase.log"
log(){ printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$1" >>"$LOG"; }

HEX="$("$BIN/grue-now.sh")"
[[ "$HEX" =~ ^#[0-9a-fA-F]{6}$ ]] || { log "ERROR bad hex '$HEX'"; exit 1; }

# In-place edit of a "# GRUE_ACCENT"-marked line. macOS sed needs the '' arg.
set_marked(){ # $1 file, $2 sed-ERE that captures pre/post around the value
  local f="$1" expr="$2"
  [[ -f "$f" ]] || return 0
  sed -i '' -E "$expr" "$f" && log "updated $(basename "$(dirname "$f")")/$(basename "$f") → $HEX"
}

# Starship: palette line ->  grue = "#rrggbb"   # GRUE_ACCENT
set_marked "$CFG/starship.toml" "s|^([[:space:]]*grue[[:space:]]*=[[:space:]]*\")#?[0-9a-fA-F]*(\".*# GRUE_ACCENT.*)$|\1${HEX}\2|"

# Ghostty: match the cursor-color key by name (Ghostty has no inline comments).
set_marked "$CFG/ghostty/config" "s|^cursor-color = .*|cursor-color = ${HEX}|"

# Zellij, bat, delta, eza, Zed stay STATIC (a single glass palette) — only the
# Starship prompt accent is live, plus Ghostty's cursor on new windows. That's the
# honest reach of "dynamic" in a terminal; the rest would need hot-reload nobody offers.

# Ghostty won't hot-reload a live window without the reload keybind; new windows
# will use the new value. (No accessibility hacks here.)
log "phase applied ($HEX)"
