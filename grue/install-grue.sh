#!/usr/bin/env bash
#
# install-grue.sh — apply the GRUE theme across the terminal surfaces.
# Idempotent, reversible: it timestamps a backup of anything it overwrites, and
# GRUE_STATIC=1 disables the time-driven accent. macOS only (launchd + sed -i '').
#
#   ./install-grue.sh            # install + schedule the daily accent
#   GRUE_STATIC=1 ./install-grue.sh   # install a fixed daytime palette, no clock
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
LA="$HOME/Library/LaunchAgents"; PLIST="$LA/com.grue.phase.plist"
STATE="$HOME/.local/state/grue"
mkdir -p "$BIN" "$CFG/ghostty" "$CFG/zellij/themes" "$GRUEC" "$LA" "$STATE"

backup(){ [[ -e "$1" && ! -L "$1" ]] && cp "$1" "$1.pre-grue.$(date +%s)" && warn "backed up $1"; return 0; }

bold "1/6  Iosevka fonts"
if command -v brew >/dev/null 2>&1; then
  for c in font-iosevka-term-nerd-font font-iosevka font-iosevka-aile; do
    brew list --cask "$c" >/dev/null 2>&1 && ok "$c present" || { info "brew install --cask $c"; brew install --cask "$c" || warn "$c failed"; }
  done
else warn "Homebrew missing — install Iosevka (Term + Aile) yourself for the type to render."; fi

bold "2/6  Accent scripts"
cp "$SRC/grue-now.sh" "$BIN/grue-now.sh";   chmod +x "$BIN/grue-now.sh"
cp "$SRC/grue-phase.sh" "$BIN/grue-phase.sh"; chmod +x "$BIN/grue-phase.sh"
ok "installed grue-now.sh + grue-phase.sh"

bold "3/6  Surface configs"
backup "$CFG/ghostty/config";   cp "$SRC/ghostty-grue.config" "$CFG/ghostty/config"; ok "ghostty"
backup "$CFG/starship.toml";    cp "$SRC/starship-grue.toml"  "$CFG/starship.toml";  ok "starship"
cp "$SRC/zellij-grue.kdl" "$CFG/zellij/themes/grue.kdl"; ok "zellij theme"
# point zellij at the grue theme
ZC="$CFG/zellij/config.kdl"; touch "$ZC"
if grep -qE '^\s*theme\s+' "$ZC"; then sed -i '' -E 's|^\s*theme\s+.*|theme "grue"|' "$ZC"; else printf '\ntheme "grue"\n' >> "$ZC"; fi
ok "zellij → theme grue"
cp "$SRC/gitconfig-grue.ini" "$GRUEC/gitconfig-grue.ini"
if ! git config --global --get-all include.path 2>/dev/null | grep -q "grue/gitconfig-grue.ini"; then
  git config --global --add include.path "$GRUEC/gitconfig-grue.ini"; ok "git include → delta/grue"
else ok "git include present"; fi
cp "$SRC/grue-shell.zsh" "$GRUEC/grue-shell.zsh"
ZSHRC="$HOME/.zshrc"; MARK="# >>> grue >>>"
if ! grep -qF "$MARK" "$ZSHRC" 2>/dev/null; then
  { echo ""; echo "$MARK"; echo "source \"$GRUEC/grue-shell.zsh\""; echo "# <<< grue <<<"; } >> "$ZSHRC"; ok "zshrc sources grue-shell"
else ok "zshrc already sources grue-shell"; fi
# Zed: copy only if the user has no settings yet (never clobber JSON)
if [[ -d "$CFG/zed" && -f "$CFG/zed/settings.json" ]]; then
  warn "Zed settings exist — merge $SRC/zed-grue-settings.json by hand (JSON not auto-merged)."
else mkdir -p "$CFG/zed"; cp "$SRC/zed-grue-settings.json" "$CFG/zed/settings.json"; ok "zed settings"; fi

bold "4/6  Prime the accent"
"$BIN/grue-phase.sh" || warn "grue-phase first run reported an issue (see $STATE/phase.log)"
ok "accent set to $("$BIN/grue-now.sh")"

bold "5/6  Schedule the daily gradient"
if [[ "${GRUE_STATIC:-0}" == "1" ]]; then
  warn "GRUE_STATIC=1 — skipping the launchd timer; accent pinned to daytime green."
else
  cat > "$PLIST" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.grue.phase</string>
  <key>ProgramArguments</key><array><string>/bin/bash</string><string>$BIN/grue-phase.sh</string></array>
  <key>RunAtLoad</key><true/>
  <key>StartInterval</key><integer>1200</integer>
  <key>ProcessType</key><string>Background</string>
  <key>StandardOutPath</key><string>$STATE/phase.launchd.log</string>
  <key>StandardErrorPath</key><string>$STATE/phase.launchd.log</string>
</dict></plist>
PL
  launchctl unload "$PLIST" >/dev/null 2>&1 || true
  launchctl load -w "$PLIST"
  ok "launchd com.grue.phase loaded (every 20 min)"
fi

bold "6/6  Done ✅"
echo "  • Reload a live Ghostty window: Cmd+Shift+,  (new windows pick it up automatically)"
echo "  • Open a new shell so Starship + eza + bat env load."
echo "  • Revert: restore the *.pre-grue.* backups; 'launchctl unload $PLIST'; remove the ~/.zshrc grue block."
echo "  • Freeze the color: GRUE_STATIC=1 in your env (accent stays daytime green)."
warn "Requires the Iosevka fonts installed above to render the type as intended."
