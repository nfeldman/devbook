#!/usr/bin/env bash
#
# claude-backup.sh — client-side-encrypted backup of the things a fresh Mac can't
# regenerate on its own:
#   • the Claude desktop app's local sessions + MCP config (device-tied, not cloud)
#   • your dev environment's valuable offline files (SSH/GPG keys, shell history,
#     tool configs, git config, package-manager auth)
#   • a reproducibility manifest (Brewfile + tool lists) to rebuild everything else
#
# restic encrypts client-side, then pushes through an rclone remote to your cloud.
# The provider only ever sees ENCRYPTED blobs. Recovery needs YOUR restic passphrase.
# Because this now includes private keys, that passphrase protects your keys too —
# keep it strong and keep a copy in your password manager (see CLAUDE-BACKUP.md).
#
# Runs hourly via a launchd LaunchAgent; also safe to run by hand.
# ---------------------------------------------------------------------------
set -euo pipefail

# launchd hands scripts a minimal PATH — make Homebrew tools resolvable.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

# --- Config ----------------------------------------------------------------
CONF_DIR="${CLAUDE_BACKUP_CONF_DIR:-$HOME/.config/claude-backup}"
CONF="${CLAUDE_BACKUP_CONF:-$CONF_DIR/env}"
# shellcheck source=/dev/null
[[ -f "$CONF" ]] && source "$CONF"

: "${RCLONE_REMOTE:?Set RCLONE_REMOTE in $CONF (e.g. RCLONE_REMOTE=gdrive)}"
: "${RESTIC_REPO_PATH:=claude-backup}"
export RESTIC_REPOSITORY="rclone:${RCLONE_REMOTE}:${RESTIC_REPO_PATH}"
export RESTIC_PASSWORD_COMMAND="${RESTIC_PASSWORD_COMMAND:-security find-generic-password -s restic-claude-backup -w}"

STATE_DIR="${STATE_DIR:-$HOME/.local/state/claude-backup}"
MANIFEST_DIR="$STATE_DIR/manifests"
mkdir -p "$MANIFEST_DIR"
LOG="$STATE_DIR/backup.log"
log(){ printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$1" | tee -a "$LOG" >&2; }

SOURCES_FILE="${SOURCES_FILE:-$CONF_DIR/sources.txt}"
EXCLUDES="${EXCLUDES_FILE:-$CONF_DIR/excludes.txt}"

# --- Reproducibility manifest ----------------------------------------------
# Snapshot the *lists* of installed things, so anything we deliberately DON'T
# store as bytes (Homebrew Cellar, language toolchains, models) can be rebuilt.
gen_manifests(){
  local d="$MANIFEST_DIR"
  command -v brew  >/dev/null 2>&1 && brew bundle dump --file="$d/Brewfile" --force --describe >/dev/null 2>&1 || true
  command -v mise  >/dev/null 2>&1 && mise ls -g              >"$d/mise-global.txt"      2>/dev/null || true
  command -v npm   >/dev/null 2>&1 && npm ls -g --depth=0     >"$d/npm-global.txt"       2>/dev/null || true
  command -v uv    >/dev/null 2>&1 && uv tool list            >"$d/uv-tools.txt"         2>/dev/null || true
  command -v cargo >/dev/null 2>&1 && cargo install --list    >"$d/cargo-installed.txt"  2>/dev/null || true
  command -v gh    >/dev/null 2>&1 && gh extension list       >"$d/gh-extensions.txt"    2>/dev/null || true
  command -v code  >/dev/null 2>&1 && code --list-extensions  >"$d/vscode-extensions.txt" 2>/dev/null || true
  command -v zed   >/dev/null 2>&1 && zed --version           >"$d/zed-version.txt"      2>/dev/null || true
  date > "$d/generated-at.txt"
}
gen_manifests
log "manifests refreshed in $MANIFEST_DIR"

# --- Assemble sources from sources.txt -------------------------------------
# One path per line; '#' starts a comment; ~ and $HOME are expanded; missing
# paths are skipped (so the same list works on any machine).
SOURCES=()
if [[ -f "$SOURCES_FILE" ]]; then
  while IFS= read -r raw || [[ -n "$raw" ]]; do
    line="${raw%%#*}"                                   # strip inline comment
    line="${line#"${line%%[![:space:]]*}"}"             # ltrim
    line="${line%"${line##*[![:space:]]}"}"             # rtrim
    [[ -z "$line" ]] && continue
    line="${line/#\~/$HOME}"                            # leading ~
    line="${line//\$HOME/$HOME}"                        # literal $HOME
    if [[ -e "$line" ]]; then SOURCES+=("$line"); else log "skip (absent): $line"; fi
  done < "$SOURCES_FILE"
fi
# Always include the freshly-generated manifests.
SOURCES+=("$MANIFEST_DIR")

if [[ ${#SOURCES[@]} -eq 0 ]]; then log "no sources found; exiting cleanly"; exit 0; fi

# --- Preflight -------------------------------------------------------------
command -v restic >/dev/null 2>&1 || { log "ERROR: restic not installed"; exit 1; }
command -v rclone >/dev/null 2>&1 || { log "ERROR: rclone not installed"; exit 1; }
rclone listremotes 2>/dev/null | grep -qx "${RCLONE_REMOTE}:" || {
  log "ERROR: rclone remote '${RCLONE_REMOTE}:' not configured — run: rclone config"; exit 1; }

# `restic cat config` succeeds only if the repo exists AND the passphrase is right.
if ! restic cat config >/dev/null 2>&1; then
  log "no repo yet — initializing $RESTIC_REPOSITORY"
  restic init >>"$LOG" 2>&1 || { log "ERROR: restic init failed (check remote + passphrase)"; exit 1; }
fi

# --- Backup ----------------------------------------------------------------
log "backup start (${#SOURCES[@]} source path(s))"
BK_ARGS=(backup "${SOURCES[@]}" --tag claude-backup
         --host "$(scutil --get LocalHostName 2>/dev/null || hostname -s)")
[[ -f "$EXCLUDES" ]] && BK_ARGS+=(--exclude-file "$EXCLUDES")
# Absolute excludes for the giants (an exclude-file can't expand ~/$HOME).
BK_ARGS+=(--exclude "$HOME/.ollama/models"
          --exclude "$HOME/.orbstack/data")
if restic "${BK_ARGS[@]}" >>"$LOG" 2>&1; then
  log "backup OK"
else
  log "ERROR: backup failed"; exit 1
fi

# --- Retention -------------------------------------------------------------
if restic forget --tag claude-backup \
      --keep-hourly 24 --keep-daily 14 --keep-weekly 8 --keep-monthly 12 \
      --prune >>"$LOG" 2>&1; then
  log "forget/prune OK"
else
  log "WARN: forget/prune failed (non-fatal; snapshot is safe)"
fi

# Success marker for the healthcheck (staleness alarm reads this file's mtime).
date +%s > "$STATE_DIR/last-success"
log "done"
