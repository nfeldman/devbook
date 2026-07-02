#!/usr/bin/env bash
#
# gruebook-appearance.sh — nudge macOS system chrome toward GRUE.
#   • Highlight color (selection) → a custom grue teal-blue  (fully custom, supported)
#   • Accent color → Blue, the nearest of macOS's FIXED set (no arbitrary custom accent)
#   • Interface → Light (GRUE is light-first)
#
#   ./gruebook-appearance.sh            apply
#   ./gruebook-appearance.sh --revert   restore macOS defaults
#
# Note: some apps only pick up the change after logout/login (or relaunch).
# ---------------------------------------------------------------------------
set -euo pipefail

if [[ "${1:-}" == "--revert" ]]; then
  defaults delete -g AppleHighlightColor 2>/dev/null || true
  defaults delete -g AppleAccentColor 2>/dev/null || true
  echo "Reverted highlight + accent to macOS defaults. Log out/in to fully apply."
  exit 0
fi

# Highlight color: "R G B Name" in 0–1 floats. Grue-blue #2b7fc4 ≈ 0.169 0.498 0.769
defaults write -g AppleHighlightColor "0.169 0.498 0.769 Grue"
# Accent enum: 0 red · 1 orange · 2 yellow · 3 green · 4 blue · 5 purple · 6 pink
defaults write -g AppleAccentColor -int 4
# Light mode = absence of the Dark key
defaults delete -g AppleInterfaceStyle 2>/dev/null || true

echo "GRUE appearance applied: highlight → grue, accent → Blue (nearest fixed), Light mode."
echo "Log out and back in (or restart) so every app picks it up."
# Uncomment to refresh some UI now (will flicker Finder/Dock/menubar):
# killall Finder Dock SystemUIServer 2>/dev/null || true
