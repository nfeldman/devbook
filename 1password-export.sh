#!/usr/bin/env bash
#
# 1password-export.sh — your independence-from-1Password escape hatch.
#
# Exports your 1Password data and encrypts it with `age` using a PUBLIC key only,
# so this machine can create backups but cannot read them. The matching private
# key lives on your offline recovery card (see ROOT-SECRETS-CARD.txt). Encrypted
# exports land in the restic backup, giving you an importable copy of your vault
# that depends on neither 1Password the company nor this Mac.
#
# Two modes:
#   • Automatic  — `1password-export.sh`      dumps your items to JSON via `op`.
#   • Gold copy  — `1password-export.sh FILE.1pux`  encrypts a manual GUI export
#                  (perfect fidelity — the format KeePassXC/Bitwarden import).
#
# Note: the `op` CLI cannot produce a .1pux (that's GUI-only), so the automatic
# mode is a JSON item dump. Do a manual .1pux now and then for a full-fidelity copy.
# ---------------------------------------------------------------------------
set -euo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"

CONF_DIR="${CLAUDE_BACKUP_CONF_DIR:-$HOME/.config/claude-backup}"
CONF="${VAULT_EXPORT_CONF:-$CONF_DIR/vault-export.env}"
# shellcheck source=/dev/null
[[ -f "$CONF" ]] && source "$CONF"
: "${AGE_RECIPIENT:?Set AGE_RECIPIENT (age1... public key) in $CONF — run install-vault-export.sh}"

OUT_DIR="${VAULT_EXPORT_DIR:-$HOME/.local/state/claude-backup/vault-exports}"
STATE_DIR="${STATE_DIR:-$HOME/.local/state/claude-backup}"
KEEP="${KEEP_EXPORTS:-12}"
mkdir -p "$OUT_DIR"
LOG="$STATE_DIR/vault-export.log"
log(){ printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$1" | tee -a "$LOG" >&2; }

command -v age >/dev/null 2>&1 || { log "ERROR: age not installed"; exit 1; }

TS="$(date '+%Y%m%dT%H%M%S')"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT   # plaintext lives here only, wiped on exit

encrypt_to_backup(){ # $1 = plaintext file, $2 = output basename
  age -r "$AGE_RECIPIENT" -o "$OUT_DIR/$2.age" "$1"
  log "encrypted -> $OUT_DIR/$2.age"
}

prune(){
  # keep newest $KEEP of each kind
  for pat in '1password-*.json.age' '1password-*.1pux.age'; do
    # shellcheck disable=SC2012
    ls -1t "$OUT_DIR"/$pat 2>/dev/null | tail -n +"$((KEEP+1))" | while IFS= read -r old; do
      rm -f "$old" && log "pruned $(basename "$old")"
    done
  done
}

# --- Mode 1: encrypt a manual .1pux (gold-fidelity, importable) -------------
if [[ "${1:-}" == *.1pux ]]; then
  [[ -f "$1" ]] || { log "ERROR: no such file: $1"; exit 1; }
  cp "$1" "$TMP/gold.1pux"
  encrypt_to_backup "$TMP/gold.1pux" "1password-$TS.1pux"
  prune
  log "done (encrypted provided .1pux). You may now delete the plaintext: $1"
  exit 0
fi

# --- Mode 2: automatic JSON item dump via op --------------------------------
command -v op >/dev/null 2>&1 || { log "ERROR: 1Password CLI (op) not installed"; exit 1; }
command -v jq >/dev/null 2>&1 || { log "ERROR: jq not installed"; exit 1; }

# Needs an unlocked session. With the desktop-app integration that's Touch ID;
# in an unattended login-agent run it only works while 1Password is unlocked.
if ! op whoami >/dev/null 2>&1; then
  log "1Password locked / not signed in — skipping (unlock it, then re-run). Non-fatal."
  exit 0
fi

log "exporting items via op (reveals concealed fields into the encrypted copy)..."
op item list --format=json 2>/dev/null | jq -r '.[].id' > "$TMP/ids.txt" || { log "ERROR: op item list failed"; exit 1; }
: > "$TMP/items.ndjson"
count=0
while IFS= read -r id; do
  [[ -z "$id" ]] && continue
  if op item get "$id" --format=json --reveal >> "$TMP/items.ndjson" 2>/dev/null; then
    count=$((count+1))
  else
    log "warn: could not read item $id (skipped)"
  fi
done < "$TMP/ids.txt"

op vault list --format=json > "$TMP/vaults.json" 2>/dev/null || echo '[]' > "$TMP/vaults.json"
jq -s --slurpfile v "$TMP/vaults.json" \
   '{exported_at: (now|todate), vaults: $v[0], item_count: length, items: .}' \
   "$TMP/items.ndjson" > "$TMP/dump.json"

encrypt_to_backup "$TMP/dump.json" "1password-$TS.json"
prune
log "done ($count items exported + encrypted)"
