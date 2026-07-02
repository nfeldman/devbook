#!/usr/bin/env bash
#
# install-vault-export.sh — one-time setup of the 1Password escape hatch.
#
# Generates an age keypair, keeps only the PUBLIC key on this Mac (so the machine
# can encrypt exports but never decrypt them), shows you the PRIVATE key ONCE to
# put on your offline recovery card, then installs + schedules 1password-export.sh.
# Idempotent. macOS-only (launchd).
# ---------------------------------------------------------------------------
set -euo pipefail
bold(){ printf "\033[1m%s\033[0m\n" "$1"; }
info(){ printf "\033[1;34m==>\033[0m %s\n" "$1"; }
ok(){   printf "\033[1;32m ok\033[0m %s\n" "$1"; }
warn(){ printf "\033[1;33m !!\033[0m %s\n" "$1"; }
die(){  printf "\033[1;31mERR\033[0m %s\n" "$1"; exit 1; }

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$HOME/.local/bin"
CONF_DIR="$HOME/.config/claude-backup"
STATE_DIR="$HOME/.local/state/claude-backup"
OUT_DIR="$STATE_DIR/vault-exports"
LA_DIR="$HOME/Library/LaunchAgents"
PLIST="$LA_DIR/com.claude-backup.vault-export.plist"
CONF="$CONF_DIR/vault-export.env"
[[ "$(uname)" == "Darwin" ]] || die "macOS-only."
mkdir -p "$BIN" "$CONF_DIR" "$OUT_DIR" "$LA_DIR"

bold "1/5  Dependencies (age, 1password-cli)"
command -v brew >/dev/null 2>&1 || die "Homebrew required (run setup.sh first)."
command -v age >/dev/null 2>&1 || { info "brew install age"; brew install age; }
command -v op  >/dev/null 2>&1 || { info "brew install --cask 1password-cli"; brew install --cask 1password-cli; }
ok "deps ready"

bold "2/5  age recovery keypair"
if [[ -f "$CONF" ]] && grep -q '^AGE_RECIPIENT=age1' "$CONF"; then
  ok "age recipient already configured (left as-is)"
else
  TMPK="$(mktemp)"; TMPE="$(mktemp)"
  age-keygen -o "$TMPK" 2>"$TMPE"
  PUB="$(grep -oE 'age1[0-9a-z]+' "$TMPK" | head -1)"
  [[ -n "$PUB" ]] || PUB="$(grep -oE 'age1[0-9a-z]+' "$TMPE" | head -1)"
  PRIV="$(grep -oE 'AGE-SECRET-KEY-[0-9A-Z-]+' "$TMPK" | head -1)"
  [[ -n "$PUB" && -n "$PRIV" ]] || { rm -f "$TMPK" "$TMPE"; die "age-keygen failed"; }
  echo "AGE_RECIPIENT=$PUB" > "$CONF"
  echo ""
  bold "════════════════════════════════════════════════════════════════════"
  bold "  age PRIVATE KEY — the ONLY thing that can decrypt your vault exports."
  bold "  Write it on your offline recovery card NOW. It is shown once."
  echo ""
  echo "    $PRIV"
  echo ""
  bold "  (Public key stored on this Mac: $PUB)"
  bold "════════════════════════════════════════════════════════════════════"
  read -r -p "Type 'saved' once it's on your offline card: " c
  [[ "$c" == "saved" ]] || { rm -f "$TMPK" "$TMPE" "$CONF"; die "Aborted so you don't lose the key."; }
  # Wipe the private key from disk — the Mac keeps only the public recipient.
  command -v gshred >/dev/null 2>&1 && gshred -u "$TMPK" 2>/dev/null || rm -f "$TMPK"
  rm -f "$TMPE"
  ok "recipient saved to $CONF; private key wiped from this machine"
fi

bold "3/5  Wire into the restic backup"
cp "$SRC/1password-export.sh" "$BIN/1password-export.sh"; chmod +x "$BIN/1password-export.sh"
ok "installed $BIN/1password-export.sh"
# Ensure the encrypted exports get picked up by the main backup.
if [[ -f "$CONF_DIR/sources.txt" ]] && ! grep -q 'vault-exports' "$CONF_DIR/sources.txt"; then
  echo "~/.local/state/claude-backup/vault-exports   # encrypted 1Password exports" >> "$CONF_DIR/sources.txt"
  ok "added vault-exports to sources.txt"
else
  ok "sources.txt already covers vault-exports (or not yet created — main installer will)"
fi

bold "4/5  Schedule (login + daily)"
cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.claude-backup.vault-export</string>
  <key>ProgramArguments</key>
  <array><string>/bin/bash</string><string>$BIN/1password-export.sh</string></array>
  <key>RunAtLoad</key><true/>
  <key>StartInterval</key><integer>86400</integer>
  <key>ProcessType</key><string>Background</string>
  <key>StandardOutPath</key><string>$STATE_DIR/vault-export.launchd.log</string>
  <key>StandardErrorPath</key><string>$STATE_DIR/vault-export.launchd.log</string>
</dict>
</plist>
PLIST
launchctl unload "$PLIST" >/dev/null 2>&1 || true
launchctl load -w "$PLIST"
ok "LaunchAgent loaded (runs at login + daily; skips when 1Password is locked)"

bold "5/5  First export"
info "Enable the 1Password app's CLI integration (Settings ▸ Developer ▸ 'Integrate with 1Password CLI'),"
info "make sure 1Password is UNLOCKED, then this first run will produce an encrypted export."
if "$BIN/1password-export.sh"; then ok "first export attempted (see $STATE_DIR/vault-export.log)"; else warn "first run reported an issue — check the log"; fi

echo ""
bold "Done. ✅"
echo "  • Automatic JSON exports: at login + daily, encrypted, into the backup."
echo "  • Gold-fidelity copy: occasionally do a manual .1pux (1Password ▸ File ▸ Export),"
echo "    then:  1password-export.sh ~/Downloads/export.1pux   (encrypts + files it, then delete the plaintext)."
echo "  • To DECRYPT during recovery:  age -d -i <your-offline-private-key-file> file.json.age"
warn "Reminder: the age private key exists ONLY on your offline card now. Lose it = exports unreadable."
