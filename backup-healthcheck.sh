#!/usr/bin/env bash
#
# backup-healthcheck.sh — the guardian. Fires a macOS notification if the backup
# hasn't succeeded recently, so silent failure can't quietly leave you exposed.
# Reads the success marker written by claude-backup.sh; needs no network or secrets.
# Run daily by its own LaunchAgent (separate from the backup, so it still fires
# even if the backup job itself is broken).
# ---------------------------------------------------------------------------
set -euo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"

STATE_DIR="${STATE_DIR:-$HOME/.local/state/claude-backup}"
MARKER="$STATE_DIR/last-success"
MAX_AGE_HOURS="${MAX_AGE_HOURS:-26}"          # allow a missed hourly run + slack
LOG="$STATE_DIR/healthcheck.log"
mkdir -p "$STATE_DIR"
log(){ printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$1" | tee -a "$LOG" >&2; }
notify(){ osascript -e "display notification \"$1\" with title \"⚠️ Backup health\" sound name \"Basso\"" >/dev/null 2>&1 || true; }

now="$(date +%s)"
if [[ ! -f "$MARKER" ]]; then
  log "ALERT: no successful backup recorded yet"
  notify "No successful backup yet. Run install-claude-backup.sh / check the log."
  exit 0
fi
last="$(cat "$MARKER" 2>/dev/null || echo 0)"
age_h=$(( (now - last) / 3600 ))
if (( age_h >= MAX_AGE_HOURS )); then
  log "ALERT: last backup was ${age_h}h ago (threshold ${MAX_AGE_HOURS}h)"
  notify "Last backup was ${age_h}h ago — backups may be stuck. Check ~/.local/state/claude-backup/backup.log"
else
  log "ok: last backup ${age_h}h ago"
fi
