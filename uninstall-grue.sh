#!/usr/bin/env bash
#
# uninstall-grue.sh — remove all GRUE / Gruebook visual customizations.
# Reverses install-grue.sh and install-gruebook.sh. Best-effort and idempotent:
# it restores the pre-GRUE Ghostty/Starship configs from their timestamped
# backups, reverts macOS appearance, unloads the theme LaunchAgents, and removes
# the installed theme files/scripts. It does NOT touch the encrypted backup system.
# macOS only.
# ---------------------------------------------------------------------------
set -uo pipefail   # not -e: we want to finish cleanup even if a step is absent
ok(){   printf "\033[1;32m ok\033[0m %s\n" "$1"; }
warn(){ printf "\033[1;33m !!\033[0m %s\n" "$1"; }
bold(){ printf "\033[1m%s\033[0m\n" "$1"; }

CFG="$HOME/.config"; BIN="$HOME/.local/bin"; LA="$HOME/Library/LaunchAgents"; ZSHRC="$HOME/.zshrc"

bold "1/9  Stop + remove the theme LaunchAgents (backup agents left alone)"
for L in com.grue.phase com.gruebook.wallpaper; do
  P="$LA/$L.plist"
  if [ -f "$P" ]; then launchctl unload "$P" 2>/dev/null; rm -f "$P"; ok "removed $L"; fi
done

bold "2/9  Revert macOS appearance (highlight + accent)"
if [ -x "$BIN/gruebook-appearance.sh" ]; then
  "$BIN/gruebook-appearance.sh" --revert 2>/dev/null || true
else
  defaults delete -g AppleHighlightColor 2>/dev/null || true
  defaults delete -g AppleAccentColor 2>/dev/null || true
fi
ok "highlight + accent reset (log out/in to fully apply)"

bold "3/9  Restore Ghostty + Starship from pre-GRUE backups"
restore(){ # $1 = target
  local t="$1" b
  b="$(ls -1t "$t".pre-grue.* 2>/dev/null | head -1)"
  if [ -n "$b" ]; then cp "$b" "$t"; ok "restored $t"; else warn "no backup for $t — re-run setup.sh or edit by hand"; fi
}
restore "$CFG/ghostty/config"
restore "$CFG/starship.toml"

bold "4/9  Zellij: drop the grue theme"
[ -f "$CFG/zellij/config.kdl" ] && sed -i '' -E '/^[[:space:]]*theme[[:space:]]+"grue"/d' "$CFG/zellij/config.kdl" 2>/dev/null && ok "unset zellij theme"
rm -f "$CFG/zellij/themes/grue.kdl"

bold "5/9  git: remove the delta include"
git config --global --unset-all include.path "$CFG/grue/gitconfig-grue.ini" 2>/dev/null && ok "removed git include" || true

bold "6/9  Zed: remove GRUE theme, reset to a stock light theme"
rm -f "$CFG/zed/themes/grue.json"
if [ -f "$CFG/zed/settings.json" ]; then
  python3 - "$CFG/zed/settings.json" <<'PY' 2>/dev/null && ok "Zed theme reset to One Light (edit settings.json to taste)" || warn "edit ~/.config/zed/settings.json theme by hand"
import json, sys
p = sys.argv[1]
try: d = json.load(open(p))
except Exception: sys.exit(1)
d["theme"] = {"mode": "light", "light": "One Light", "dark": "One Dark"}
json.dump(d, open(p, "w"), indent=2)
PY
fi

bold "7/9  bat: remove GRUE theme"
if command -v bat >/dev/null 2>&1; then
  BATDIR="$(bat --config-dir 2>/dev/null)"
  [ -n "$BATDIR" ] && rm -f "$BATDIR/themes/GRUE.tmTheme" && bat cache --build >/dev/null 2>&1 || true
  ok "bat theme removed"
fi

bold "8/9  Remove the ~/.zshrc blocks (grue + gruebook)"
for M in grue gruebook; do
  sed -i '' "/# >>> $M >>>/,/# <<< $M <<</d" "$ZSHRC" 2>/dev/null && ok "removed ~/.zshrc $M block" || true
done

bold "9/9  Remove installed scripts + config"
rm -f "$BIN/grue-now.sh" "$BIN/grue-phase.sh" \
      "$BIN/gen-wallpaper.py" "$BIN/gruebook-wallpaper.sh" "$BIN/gruebook-appearance.sh"
rm -rf "$CFG/grue" "$HOME/.local/state/grue"
ok "removed grue scripts, config, and state"

echo ""
bold "Done. ✅  GRUE / Gruebook removed."
echo "  • Ghostty: Cmd+Shift+, to reload (or reopen)."
echo "  • Open a new shell so the reverted zsh loads."
echo "  • Wallpaper: set one in System Settings — the grue wallpaper is no longer refreshed."
echo "  • Log out/in so the accent + highlight fully reset."
echo "  • Fonts (Iosevka) and the encrypted backup system are left in place."
