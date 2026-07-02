#!/usr/bin/env bash
#
# gruebook-wallpaper.sh — set the desktop to the current GRUE color.
# Renders a fresh glass+grue wallpaper for the moment (grue-now.sh) and applies it.
# Run every ~20 min by launchd, so the desktop walks the same day→night curve as
# the prompt. This is the "the whole Mac is grue" piece.
# ---------------------------------------------------------------------------
set -euo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"

BIN="${GRUE_BIN:-$HOME/.local/bin}"
STATE="$HOME/.local/state/grue"; OUT="$STATE/wallpaper"; mkdir -p "$OUT"
LOG="$STATE/wallpaper.log"
log(){ printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$1" >>"$LOG"; }

command -v python3 >/dev/null 2>&1 || { log "ERROR python3 missing"; exit 1; }
HEX="$("$BIN/grue-now.sh" 2>/dev/null || echo '#2b7fc4')"

# New filename each run — macOS caches wallpaper by path, so reusing one won't refresh.
IMG="$OUT/grue-$(date +%s).png"
if ! python3 "$BIN/gen-wallpaper.py" "$HEX" "$IMG" >/dev/null 2>&1; then
  log "ERROR gen-wallpaper failed (Pillow installed?)"; exit 1
fi

# Prefer the reliable `wallpaper` CLI; fall back to AppleScript (flaky on Sonoma+).
if command -v wallpaper >/dev/null 2>&1; then
  wallpaper set "$IMG" && log "set via wallpaper CLI ($HEX)"
else
  osascript -e "tell application \"System Events\" to set picture of every desktop to \"$IMG\"" \
    && log "set via osascript ($HEX)" || log "WARN could not set wallpaper (install: brew install wallpaper)"
fi

# Keep only the newest 12 rendered frames.
ls -1t "$OUT"/grue-*.png 2>/dev/null | tail -n +13 | while IFS= read -r old; do rm -f "$old"; done
