#!/usr/bin/env bash
#
# install-claude-backup.sh — one-time setup for encrypted, hourly cloud backups
# of Claude Code's local state (~/.claude + ~/.claude.json).
#
# Idempotent: safe to re-run. It installs deps, stores your passphrase in the
# Keychain, writes config, installs the backup script + hourly LaunchAgent, and
# runs the first backup. Run the bundle's files from the folder they live in.
#
# Usage:  chmod +x install-claude-backup.sh && ./install-claude-backup.sh
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
LOG_DIR="$HOME/.local/state/claude-backup"
LA_DIR="$HOME/Library/LaunchAgents"
PLIST="$LA_DIR/com.claude-backup.hourly.plist"
KEY_SERVICE="restic-claude-backup"

[[ "$(uname)" == "Darwin" ]] || die "This installer is macOS-only (uses Keychain + launchd)."
mkdir -p "$BIN" "$CONF_DIR" "$LOG_DIR" "$LA_DIR"

# ---------------------------------------------------------------------------
bold "1/6  Dependencies (restic, rclone)"
# ---------------------------------------------------------------------------
command -v brew >/dev/null 2>&1 || die "Homebrew required. Install it first (see setup.sh)."
for f in restic rclone; do
  if command -v "$f" >/dev/null 2>&1; then ok "$f present"; else info "brew install $f"; brew install "$f"; fi
done

# ---------------------------------------------------------------------------
bold "2/6  rclone remote"
# ---------------------------------------------------------------------------
mapfile -t REMOTES < <(rclone listremotes 2>/dev/null | sed 's/:$//')
if [[ ${#REMOTES[@]} -gt 0 ]]; then
  echo "Existing rclone remotes: ${REMOTES[*]}"
fi
read -r -p "Which rclone remote should hold the backups? (name only, e.g. gdrive) " RCLONE_REMOTE
[[ -n "${RCLONE_REMOTE:-}" ]] || die "No remote name given."
if ! rclone listremotes 2>/dev/null | grep -qx "${RCLONE_REMOTE}:"; then
  warn "Remote '${RCLONE_REMOTE}:' doesn't exist yet."
  echo "   Launching 'rclone config' — create a remote named exactly '${RCLONE_REMOTE}'."
  read -r -p "   Press Enter to run 'rclone config' (or Ctrl-C to abort)... " _
  rclone config
  rclone listremotes 2>/dev/null | grep -qx "${RCLONE_REMOTE}:" || die "Remote '${RCLONE_REMOTE}:' still not found."
fi
ok "using remote ${RCLONE_REMOTE}:"

# ---------------------------------------------------------------------------
bold "3/6  Encryption passphrase (macOS Keychain)"
# ---------------------------------------------------------------------------
# This passphrase is the ONE secret that lets anyone decrypt the backup. It is
# stored in your login Keychain and never written to disk in plaintext.
if security find-generic-password -s "$KEY_SERVICE" >/dev/null 2>&1; then
  ok "passphrase already in Keychain (service: $KEY_SERVICE)"
else
  echo "No passphrase found. Enter one, or leave blank to generate a strong random one."
  read -r -s -p "Passphrase (hidden): " PASS1; echo
  if [[ -z "$PASS1" ]]; then
    PASS1="$(LC_ALL=C tr -dc 'A-Za-z0-9_-' </dev/urandom | head -c 40)"
    bold "Generated passphrase — SAVE THIS NOW in your password manager:"
    echo "    $PASS1"
    read -r -p "Type 'saved' once you've stored it: " CONFIRM
    [[ "$CONFIRM" == "saved" ]] || die "Aborted so you don't lock yourself out."
  else
    read -r -s -p "Confirm passphrase: " PASS2; echo
    [[ "$PASS1" == "$PASS2" ]] || die "Passphrases didn't match."
  fi
  security add-generic-password -a "$USER" -s "$KEY_SERVICE" -w "$PASS1" -U
  unset PASS1 PASS2
  ok "passphrase stored in Keychain"
  warn "Make sure a copy also lives in your password manager — if this Mac is gone,"
  warn "the Keychain is gone too, and WITHOUT the passphrase the backup is unrecoverable."
fi

# ---------------------------------------------------------------------------
bold "4/6  Config + exclude list"
# ---------------------------------------------------------------------------
cat > "$CONF_DIR/env" <<EOF
# claude-backup config. Edit here, not in the script.
RCLONE_REMOTE=$RCLONE_REMOTE
RESTIC_REPO_PATH=claude-backup
EOF
ok "wrote $CONF_DIR/env"
if [[ -f "$SRC/claude-backup.excludes.txt" ]]; then
  cp "$SRC/claude-backup.excludes.txt" "$CONF_DIR/excludes.txt"; ok "wrote $CONF_DIR/excludes.txt"
fi
# sources.txt is user-editable — don't clobber a customized one on re-run.
if [[ -f "$CONF_DIR/sources.txt" ]]; then
  ok "sources.txt already present (left as-is)"
elif [[ -f "$SRC/claude-backup.sources.txt" ]]; then
  cp "$SRC/claude-backup.sources.txt" "$CONF_DIR/sources.txt"; ok "wrote $CONF_DIR/sources.txt"
fi
mkdir -p "$LOG_DIR/manifests"; ok "manifests dir ready"

# ---------------------------------------------------------------------------
bold "5/6  Install script + hourly LaunchAgent"
# ---------------------------------------------------------------------------
cp "$SRC/claude-backup.sh" "$BIN/claude-backup.sh"
chmod +x "$BIN/claude-backup.sh"
ok "installed $BIN/claude-backup.sh"

# Template the plist with real absolute paths.
sed -e "s|__SCRIPT__|$BIN/claude-backup.sh|g" \
    -e "s|__LOG__|$LOG_DIR/launchd.log|g" \
    "$SRC/com.claude-backup.hourly.plist" > "$PLIST"
ok "wrote $PLIST"

# Reload cleanly (idempotent).
launchctl unload "$PLIST" >/dev/null 2>&1 || true
launchctl load -w "$PLIST"
ok "LaunchAgent loaded (hourly + at login)"

# Healthcheck agent — separate job so it still fires if the backup itself breaks.
if [[ -f "$SRC/backup-healthcheck.sh" ]]; then
  cp "$SRC/backup-healthcheck.sh" "$BIN/backup-healthcheck.sh"; chmod +x "$BIN/backup-healthcheck.sh"
  HC_PLIST="$LA_DIR/com.claude-backup.healthcheck.plist"
  cat > "$HC_PLIST" <<HCPLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.claude-backup.healthcheck</string>
  <key>ProgramArguments</key>
  <array><string>/bin/bash</string><string>$BIN/backup-healthcheck.sh</string></array>
  <key>RunAtLoad</key><true/>
  <key>StartInterval</key><integer>86400</integer>
  <key>ProcessType</key><string>Background</string>
  <key>StandardOutPath</key><string>$LOG_DIR/healthcheck.launchd.log</string>
  <key>StandardErrorPath</key><string>$LOG_DIR/healthcheck.launchd.log</string>
</dict>
</plist>
HCPLIST
  launchctl unload "$HC_PLIST" >/dev/null 2>&1 || true
  launchctl load -w "$HC_PLIST"
  ok "healthcheck agent loaded (daily; notifies if backups go stale)"
fi

# ---------------------------------------------------------------------------
bold "6/6  First backup"
# ---------------------------------------------------------------------------
info "Running the first backup now (this also initializes the encrypted repo)..."
if "$BIN/claude-backup.sh"; then
  ok "first backup complete"
else
  die "First backup failed — check $LOG_DIR/backup.log"
fi

echo ""
bold "Done. ✅  Backups run hourly."
echo "  • Verify snapshots:  RCLONE_REMOTE=$RCLONE_REMOTE \\"
echo "      RESTIC_REPOSITORY=rclone:$RCLONE_REMOTE:claude-backup \\"
echo "      RESTIC_PASSWORD_COMMAND='security find-generic-password -s $KEY_SERVICE -w' restic snapshots"
echo "  • Logs:              $LOG_DIR/backup.log"
echo "  • Restore steps:     see CLAUDE-BACKUP.md"
echo ""
warn "Two things must live in your password manager (not just this Mac):"
warn "  1) the restic passphrase   2) how to re-auth the '$RCLONE_REMOTE' cloud account"
