#!/usr/bin/env bash
#
# install-gruebook.sh — take GRUE beyond the terminal (a "Gruebook").
#   • dynamic desktop wallpaper that walks the grue day→night curve (launchd, 20 min)
#   • custom "GRUE Light" theme for Zed and for bat
#   • macOS highlight + accent nudged toward grue
#
# Builds on the terminal theme: run ./grue/install-grue.sh first (needs grue-now.sh).
# Idempotent, reversible, macOS only. System appearance changes are opt-in and
# undoable (gruebook-appearance.sh --revert).
# ---------------------------------------------------------------------------
set -euo pipefail
bold(){ printf "\033[1m%s\033[0m\n" "$1"; }
info(){ printf "\033[1;34m==>\033[0m %s\n" "$1"; }
ok(){   printf "\033[1;32m ok\033[0m %s\n" "$1"; }
warn(){ printf "\033[1;33m !!\033[0m %s\n" "$1"; }
die(){  printf "\033[1;31mERR\033[0m %s\n" "$1"; exit 1; }

[[ "$(uname)" == "Darwin" ]] || die "macOS only."
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$HOME/.local/bin"; CFG="$HOME/.config"; GRUEC="$CFG/grue"
LA="$HOME/Library/LaunchAgents"; PLIST="$LA/com.gruebook.wallpaper.plist"
STATE="$HOME/.local/state/grue"
mkdir -p "$BIN" "$GRUEC" "$LA" "$STATE" "$CFG/zed/themes"

bold "1/6  Prerequisites"
if [[ ! -x "$BIN/grue-now.sh" ]]; then
  if [[ -f "$SRC/../grue/grue-now.sh" ]]; then cp "$SRC/../grue/grue-now.sh" "$BIN/grue-now.sh"; chmod +x "$BIN/grue-now.sh"; ok "grue-now.sh copied";
  else die "grue-now.sh not found — run ./grue/install-grue.sh first."; fi
else ok "grue-now.sh present"; fi
# Pillow for the wallpaper renderer
if ! python3 -c "import PIL" >/dev/null 2>&1; then
  info "installing Pillow"; pip3 install --break-system-packages --quiet pillow || pip3 install --quiet pillow || warn "Pillow install failed — wallpaper won't render"
else ok "Pillow present"; fi
# reliable wallpaper setter
command -v wallpaper >/dev/null 2>&1 || { command -v brew >/dev/null 2>&1 && { info "brew install wallpaper"; brew install wallpaper || warn "wallpaper CLI failed (will fall back to AppleScript)"; }; }

bold "2/6  Install gruebook scripts"
for f in gen-wallpaper.py gruebook-wallpaper.sh gruebook-appearance.sh; do
  cp "$SRC/$f" "$BIN/$f"; chmod +x "$BIN/$f"; done
ok "wallpaper + appearance scripts installed"

bold "3/6  Zed 'GRUE Light' theme"
cp "$SRC/zed-grue-theme.json" "$CFG/zed/themes/grue.json"
python3 - "$CFG/zed/settings.json" <<'PY'
import json, os, sys
p = sys.argv[1]; d = {}
if os.path.exists(p):
    try: d = json.load(open(p))
    except Exception: d = {}
d["theme"] = {"mode": "light", "light": "GRUE Light", "dark": "GRUE Light"}
os.makedirs(os.path.dirname(p), exist_ok=True)
json.dump(d, open(p, "w"), indent=2)
print("  zed settings -> GRUE Light")
PY
ok "Zed theme installed + selected"

bold "4/6  bat 'GRUE Light' theme"
if command -v bat >/dev/null 2>&1; then
  BATDIR="$(bat --config-dir)"; mkdir -p "$BATDIR/themes"
  cp "$SRC/grue.tmTheme" "$BATDIR/themes/GRUE.tmTheme"
  bat cache --build >/dev/null 2>&1 || warn "bat cache --build failed"
  printf 'export BAT_THEME="GRUE Light"\n' > "$GRUEC/gruebook-shell.zsh"
  ZSHRC="$HOME/.zshrc"; MARK="# >>> gruebook >>>"
  grep -qF "$MARK" "$ZSHRC" 2>/dev/null || { echo ""; echo "$MARK"; echo "source \"$GRUEC/gruebook-shell.zsh\""; echo "# <<< gruebook <<<"; } >> "$ZSHRC"
  ok "bat theme built + selected (overrides the GitHub stand-in)"
else warn "bat not installed — skipped"; fi

bold "5/6  Dynamic wallpaper"
"$BIN/gruebook-wallpaper.sh" && ok "wallpaper set to the current grue color" || warn "wallpaper first run had an issue (see $STATE/wallpaper.log)"
cat > "$PLIST" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.gruebook.wallpaper</string>
  <key>ProgramArguments</key><array><string>/bin/bash</string><string>$BIN/gruebook-wallpaper.sh</string></array>
  <key>RunAtLoad</key><true/>
  <key>StartInterval</key><integer>1200</integer>
  <key>ProcessType</key><string>Background</string>
  <key>StandardOutPath</key><string>$STATE/wallpaper.launchd.log</string>
  <key>StandardErrorPath</key><string>$STATE/wallpaper.launchd.log</string>
</dict></plist>
PL
launchctl unload "$PLIST" >/dev/null 2>&1 || true
launchctl load -w "$PLIST"
ok "wallpaper scheduled (every 20 min)"

bold "6/6  macOS appearance (highlight + accent)"
"$BIN/gruebook-appearance.sh" || warn "appearance step had an issue"

echo ""
bold "Gruebook applied. ✅  Log out/in so the accent + highlight fully take."
echo "  Revert appearance:  gruebook-appearance.sh --revert"
echo "  Stop the wallpaper: launchctl unload $PLIST"
echo "  Zed/bat: pick another theme anytime; the GRUE ones just sit in your themes dir."
warn "Honest limits: no arbitrary custom macOS accent (Blue is the nearest fixed choice);"
warn "wallpaper setting can be finicky on recent macOS — 'brew install wallpaper' makes it reliable."
