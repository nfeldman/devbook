# Claude Desktop — encrypted cloud backup

Hourly, client-side-encrypted backups of the Claude **desktop app's** local-only
state. The cloud provider stores **only encrypted blobs**; decrypting requires *your*
passphrase. Written recovery-first: the restore section is the point of all of this.

## What's backed up

Everything a fresh Mac can't regenerate on its own. The full list lives in
`~/.config/claude-backup/sources.txt` (edit it freely). By default:

**Claude desktop app** — `~/Library/Application Support/Claude/`
- `local-agent-mode-sessions/` — your **Cowork / in-app agent sessions + outputs**
  *(device-tied; not synced to any cloud)*
- `claude_desktop_config.json` — MCP / connector setup

**Identity & keys (irreplaceable)** — `~/.ssh`, `~/.gnupg`, `~/.config/gh`
(GitHub auth), `~/.npmrc`, `~/.cargo/credentials.toml`

**Config & history** — `~/.zshrc`, `~/.gitconfig`, `~/.dotfiles`, `~/.config`
(starship, ghostty, zellij, mise, atuin, uv, zed…), `~/.local/share/atuin` (shell
history), `~/.ollama` (keys/manifests)

**Reproducibility manifest** — auto-generated each run into
`~/.local/state/claude-backup/manifests/`: a **Brewfile** plus lists of your mise,
npm, uv, cargo, and editor extensions. This is how the *bulky* stuff we deliberately
DON'T store (Homebrew Cellar, language toolchains, Ollama models) gets rebuilt.

> ⚠️ Because this now includes your **private SSH/GPG keys**, the restic passphrase
> is the single thing standing between an attacker and your keys. Keep it strong and
> keep it only in your password manager + Keychain.

**Excluded** (regenerable bulk): Electron caches, `node_modules`, `.rustup/toolchains`,
`.cargo/registry`, `.local/share/mise/installs`, `__pycache__`, `.venv`, `~/.ollama/models`,
`~/.orbstack/data`, logs, `.DS_Store`. Edit `~/.config/claude-backup/excludes.txt`.

**Already safe without this backup:** your regular Claude conversations, Projects, and
memory live in your **Anthropic cloud account** and return when you log in.

## How it works

`restic` (encryption + snapshots) → `rclone` remote → your cloud (Drive/Dropbox/etc.).

- **Encryption is client-side.** restic encrypts before anything leaves the Mac, so the
  provider never sees plaintext. Sovereignty comes entirely from the passphrase.
- **Passphrase** lives in the **macOS Keychain** (service `restic-claude-backup`), fetched
  at run time — never written to disk in plaintext.
- **Schedule**: a launchd LaunchAgent (`com.claude-backup.hourly`) runs hourly and at login.
- **Retention**: 24 hourly, 14 daily, 8 weekly, 12 monthly snapshots, then prune.

## Install (one time)

```bash
chmod +x install-claude-backup.sh
./install-claude-backup.sh
```

It installs `restic`+`rclone`, helps you create/confirm the rclone remote, stores the
passphrase in Keychain, writes config, installs the hourly LaunchAgent, and runs the
first backup. Idempotent — safe to re-run.

## ⚠️ Two secrets you must keep OFF this machine

If the Mac is at the bottom of the ocean, the Keychain and the rclone config went with
it. Recovery then depends on two things that must **also** live in your password manager:

1. **The restic passphrase.** Without it the backup is mathematically unrecoverable.
   There is no reset, no support line, no backdoor. That's the feature.
2. **How to re-authorize the cloud account** the `rclone` remote points at (the account
   login / OAuth). The encrypted data is useless if you can't reach it.

Store both now. Everything else can be rebuilt.

## Restore — on a fresh/bare Mac

```bash
# 1. Install the tools
brew install restic rclone

# 2. Re-create the rclone remote (same NAME you used before, e.g. gdrive)
rclone config          # authorize the cloud account again

# 3. Point restic at the repo and give it the passphrase (from your password manager)
export RESTIC_REPOSITORY="rclone:gdrive:claude-backup"     # adjust remote name if different
export RESTIC_PASSWORD="<your restic passphrase>"

# 4. See what's there
restic snapshots

# 5. Restore the latest snapshot to a scratch dir (never straight over live data)
restic restore latest --target ~/restore

# 6. restic recreates the full original paths under the target, e.g.:
#      ~/restore/Users/<you>/Library/Application Support/Claude/   (Cowork sessions + MCP)
#      ~/restore/Users/<you>/.ssh   .gnupg   .gitconfig   .config   ...
#    Quit the Claude app, then copy each piece back to its real home:
#      cp -R "~/restore/Users/<you>/.ssh"     ~/.ssh
#      cp -R "~/restore/Users/<you>/.config"  ~/.config
#      cp -R "~/restore/Users/<you>/Library/Application Support/Claude" \
#            ~/Library/Application\ Support/Claude
#
# 7. Fix key permissions (SSH refuses loose perms):
chmod 700 ~/.ssh ~/.gnupg 2>/dev/null; chmod 600 ~/.ssh/* 2>/dev/null

# 8. Rebuild the bulky stuff from the manifest (Homebrew, toolchains, models):
#      brew bundle --file="~/restore/Users/<you>/.local/state/claude-backup/manifests/Brewfile"
```

Restore to a scratch target and move pieces in deliberately — the conservator's rule:
never let a restore overwrite live state you haven't looked at.

## Operate

- **Verify it's running:** `launchctl list | grep claude-backup`
- **Watch a run:** `tail -f ~/.local/state/claude-backup/backup.log`
- **Force a backup now:** `~/.local/bin/claude-backup.sh`
- **List snapshots:** set the three env vars above (use the Keychain command for the
  password: `RESTIC_PASSWORD_COMMAND='security find-generic-password -s restic-claude-backup -w'`) then `restic snapshots`
- **Restore-test quarterly.** A backup you've never restored is a hypothesis, not a backup.
- **Pause/remove:** `launchctl unload ~/Library/LaunchAgents/com.claude-backup.hourly.plist`

## Notes / honest limits

- **Hourly** means up to ~1 hour of new Cowork work could be lost in a crash. Bump to
  every 15 min by lowering `StartInterval` in the plist (then reload it) if that matters.
- **The app should be quietly closed or idle during a backup** for the cleanest snapshot
  of its databases. A live snapshot is still fine for the session outputs/config; worst
  case a mid-write DB file is caught, and restic keeps the prior good snapshot regardless.
- restic uses a repo lock; overlapping runs are safe. A killed run may leave a stale lock —
  clear with `restic unlock` if a run complains.
- This backs up the Claude **desktop app** (`~/Library/Application Support/Claude/`).
  Your regular chats/Projects/memory are safe in your cloud account regardless; this is
  about the local Cowork sessions and MCP config.
