#!/usr/bin/env bash
#
# restore.sh — guided catastrophe recovery on a fresh/blank Mac.
#
# Automates everything that CAN be safely automated, and stops to ask you for the
# two secrets that live ONLY on your offline ROOT-SECRETS-CARD:
#   • the restic passphrase   • (later) the age private key for 1Password exports
# It never invents or stores those — that's the whole security model.
#
# Usage on the new machine:
#   1) get this bundle onto the Mac (git clone your repo, or copy the folder)
#   2) chmod +x restore.sh && ./restore.sh
# ---------------------------------------------------------------------------
set -euo pipefail
bold(){ printf "\033[1m%s\033[0m\n" "$1"; }
info(){ printf "\033[1;34m==>\033[0m %s\n" "$1"; }
ok(){   printf "\033[1;32m ok\033[0m %s\n" "$1"; }
warn(){ printf "\033[1;33m !!\033[0m %s\n" "$1"; }
die(){  printf "\033[1;31mERR\033[0m %s\n" "$1"; exit 1; }
ask(){ read -r -p "$1 " REPLY; echo "$REPLY"; }

[[ "$(uname)" == "Darwin" ]] || die "macOS-only."
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESTORE_DIR="$HOME/restore"

bold "Catastrophe recovery — this walks you through, using your offline card."
echo "Have your ROOT-SECRETS-CARD in hand. Nothing here is stored; you type secrets when asked."
echo ""

# --- 1. Base tools ---------------------------------------------------------
bold "1/7  Tools"
if ! command -v brew >/dev/null 2>&1; then
  info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  [[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
fi
for f in restic rclone age; do command -v "$f" >/dev/null 2>&1 || { info "brew install $f"; brew install "$f"; }; done
ok "restic / rclone / age present"

# --- 2. Cloud remote -------------------------------------------------------
bold "2/7  Reconnect the cloud"
REMOTE="$(ask "rclone remote NAME used for the backup (e.g. gdrive):")"
[[ -n "$REMOTE" ]] || die "no remote name"
if ! rclone listremotes 2>/dev/null | grep -qx "${REMOTE}:"; then
  warn "Remote '${REMOTE}:' not configured — launching 'rclone config' (re-authorize the cloud account)."
  read -r -p "Press Enter to run rclone config..." _; rclone config
  rclone listremotes 2>/dev/null | grep -qx "${REMOTE}:" || die "remote still missing"
fi
REPO_PATH="$(ask "restic repo path [claude-backup]:")"; REPO_PATH="${REPO_PATH:-claude-backup}"
export RESTIC_REPOSITORY="rclone:${REMOTE}:${REPO_PATH}"
ok "repo: $RESTIC_REPOSITORY"

# --- 3. Passphrase (from the card) -----------------------------------------
bold "3/7  restic passphrase (from your offline card)"
read -r -s -p "Paste restic passphrase (hidden): " RESTIC_PASSWORD; echo
export RESTIC_PASSWORD
restic cat config >/dev/null 2>&1 || die "Could not open the repo — wrong passphrase or remote."
ok "repo opened"

# --- 4. Inspect + restore --------------------------------------------------
bold "4/7  Snapshots"
restic snapshots || die "could not list snapshots"
SNAP="$(ask "Snapshot to restore [latest]:")"; SNAP="${SNAP:-latest}"
mkdir -p "$RESTORE_DIR"
info "Restoring $SNAP to $RESTORE_DIR (nothing is overwritten in place)..."
restic restore "$SNAP" --target "$RESTORE_DIR" || die "restore failed"
ok "restored into $RESTORE_DIR"
RHOME="$(/bin/ls -d "$RESTORE_DIR"/Users/* 2>/dev/null | head -1 || true)"
[[ -n "$RHOME" ]] && ok "your restored home is: $RHOME"

# --- 5. Move pieces back (with consent) ------------------------------------
bold "5/7  Move restored files into place"
echo "This copies restored data over your (fresh) home dir. On a blank Mac that's safe."
if [[ "$(ask "Proceed with assisted copy-back? [y/N]:")" == [yY]* && -n "${RHOME:-}" ]]; then
  copyback(){ # $1 = path under restored home (e.g. .ssh)
    if [[ -e "$RHOME/$1" ]]; then cp -a "$RHOME/$1" "$HOME/$(dirname "$1")/" 2>/dev/null && ok "restored ~/$1" || warn "skip ~/$1"; fi
  }
  copyback ".ssh"; copyback ".gnupg"; copyback ".gitconfig"; copyback ".gitignore_global"
  copyback ".zshrc"; copyback ".zprofile"; copyback ".dotfiles"; copyback ".config"
  copyback ".local/share/atuin"; copyback ".npmrc"; copyback "Claude"
  # Claude desktop app data (path has a space)
  if [[ -d "$RHOME/Library/Application Support/Claude" ]]; then
    mkdir -p "$HOME/Library/Application Support"
    cp -a "$RHOME/Library/Application Support/Claude" "$HOME/Library/Application Support/" && ok "restored Claude desktop data"
  fi
  chmod 700 "$HOME/.ssh" "$HOME/.gnupg" 2>/dev/null || true
  chmod 600 "$HOME/.ssh/"* 2>/dev/null || true
  ok "copy-back done; SSH/GPG perms fixed"
else
  warn "Skipped auto copy-back. Files are in $RESTORE_DIR — move them by hand."
fi

# --- 6. Rebuild the rest from the manifest ---------------------------------
bold "6/7  Rebuild toolchain from the Brewfile"
BREWFILE="$RHOME/.local/state/claude-backup/manifests/Brewfile"
if [[ -f "$BREWFILE" ]]; then
  info "Found Brewfile. This reinstalls all your Homebrew apps/tools."
  [[ "$(ask "Run 'brew bundle' now? [y/N]:")" == [yY]* ]] && brew bundle --file="$BREWFILE" || warn "skipped; run later: brew bundle --file=\"$BREWFILE\""
else
  warn "No Brewfile found in the snapshot — run setup.sh to rebuild tools instead."
fi

# --- 7. What's left (needs YOU) --------------------------------------------
bold "7/7  Manual finishers"
cat <<EOF
  • 1Password exports: decrypt with your OFFLINE age private key:
      age -d -i <privkey-file> "$RHOME"/.local/state/claude-backup/vault-exports/<newest>.1pux.age > ~/vault.1pux
      ...then import into 1Password (or KeePassXC/Bitwarden).
  • Re-run install-claude-backup.sh to re-arm hourly backups on THIS machine
    (re-stores the passphrase in the new Keychain).
  • Re-run install-vault-export.sh only if you want a NEW age key; otherwise keep the old one.
  • Scheduled reminders: they restored as files under ~/Claude/Scheduled — open Cowork,
    sign in, and confirm they re-appear/re-arm.
  • Turn FileVault back on; sign into your Apple account.
EOF
bold "Recovery scaffolding complete. Verify, then delete $RESTORE_DIR when satisfied."
