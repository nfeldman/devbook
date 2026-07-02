# START HERE — Mac dev environment + encrypted backup

A lean, modern, AI-forward macOS dev setup plus a client-side-encrypted backup that
makes a drowned laptop recoverable. This file is the map: what's in the bundle, what
it installs, what it can and can't do, and how to rebuild from nothing.

---

## The bundle (run order)

| # | File | What it does |
|---|------|--------------|
| 1 | `setup.sh` | Installs the whole toolchain + writes your dotfiles. Idempotent. |
| 2 | `README.md` | Details on the dev setup and per-project workflow. |
| 3 | `starship.toml`, `ghostty.config`, `zellij.kdl`, `zshrc-additions.zsh` | Configs `setup.sh` stages into `~/.dotfiles` and symlinks. |
| 4 | `install-claude-backup.sh` | One-time setup of the encrypted hourly backup. |
| 5 | `claude-backup.sh` + `.sources.txt` + `.excludes.txt` + `.plist` | The backup job, what it includes/excludes, and its schedule. |
| 6 | `CLAUDE-BACKUP.md` | Backup details + the bare-metal **restore** procedure. |
| 7 | `install-vault-export.sh` + `1password-export.sh` | Optional: encrypted 1Password exports so you're never locked into the company. |
| 8 | `ROOT-SECRETS-CARD.txt` | Fill-in offline card for the handful of keys that unlock everything. |
| 9 | `restore.sh` | Catastrophe recovery on a blank Mac — guided, one command. |
| 10 | `backup-healthcheck.sh` | Daily staleness alarm (installed by the backup installer). |
| 11 | `machine-steward-reviewer.md` | Reusable reviewer persona for validating scripts/configs. |

**Fresh Mac, in order:** `./setup.sh` → (optional) `./install-claude-backup.sh` →
(optional) `./install-vault-export.sh`. Then fill in `ROOT-SECRETS-CARD.txt`, print it,
and delete the digital copy.

**Recovery day (blank Mac):** get this folder onto the machine, run `./restore.sh`,
and supply the two secrets from your card when prompted.

**Automated upkeep (already running):**
- Local `launchd`: hourly backup, daily healthcheck (notifies if backups go stale), login+daily 1Password export.
- Cowork scheduled tasks: monthly gold-export nudge, quarterly restore-test nudge.

> **Portability note:** this is a self-contained folder — copy it anywhere and it
> works. Everything is namespaced `claude-backup`. Packaging it as a public GitHub
> repo (rename, LICENSE, one bootstrap entrypoint) is a deferred step; nothing here
> blocks it.

---

## 1) Everything `setup.sh` installs automatically

**Package manager & terminal**
- Homebrew · Ghostty (terminal) · JetBrainsMono Nerd Font

**Shell layer**
- Starship (prompt) · Zellij (multiplexer) · zsh config appended to `~/.zshrc`

**Modern CLI toolkit**
- eza · bat · fd · ripgrep (rg) · fzf · zoxide · git-delta · jq · yq · sd · dust ·
  bottom (btm) · tealdeer (tldr) · atuin · gh · lazygit · direnv · shellcheck

**Language runtimes**
- mise (manages Node LTS, Python 3.12, Go) · uv (Python packaging) · rustup (Rust stable)

**Containers / DevOps**
- OrbStack (Docker + local K8s) · kubectl · k9s · helm

**AI-forward**
- Ollama (local models) · Zed (editor) · Claude Code (npm global) · aider (uv tool)

**Secrets / crypto**
- age (file encryption) · 1password-cli (`op`, powers the vault-export escape hatch)

**Dotfiles written**
- `~/.dotfiles/` (staged sources) → symlinks at `~/.config/starship.toml`,
  `~/.config/ghostty/config`, `~/.config/zellij/config.kdl`; an init block in
  `~/.zshrc`; a provenance line in `~/.config/dev-env/manifest.txt`.

---

## 2) Features & limits

**Features**
- One-command, idempotent setup; safe to re-run (checks before installing, backs up
  configs before overwriting, appends to `~/.zshrc` exactly once).
- Self-linting: `setup.sh` runs `shellcheck` on itself each run (non-fatal).
- Symlink source is durable (`~/.dotfiles`), so relocating the run folder won't dangle.
- Backup is **client-side encrypted** (restic): the cloud sees only ciphertext; only
  your passphrase decrypts. Hourly, incremental, auto-pruned, runs via launchd.
- Backup captures the irreplaceable set (Claude Cowork sessions, SSH/GPG keys, git &
  package auth, shell history, configs) **plus** a Brewfile/tool-list manifest to
  rebuild the bulky, regenerable rest.
- **1Password independence layer** (optional): scheduled, `age`-encrypted exports of
  your vault land in the backup, encrypted with a key whose private half lives only on
  your offline card — so you can leave 1Password (→ KeePassXC/Bitwarden) anytime and are
  never hostage to the company or a lapsed subscription.

**Limits (honest)**
- **I can't run installs on your Mac from here** — my shell is a sandbox and I'm
  blocked from typing into your Terminal. You run the two scripts; I assembled + tested them.
- **Backup setup is interactive once**: `rclone config` needs a browser OAuth, and you
  set the passphrase by hand. After that it's invisible.
- **Hourly window**: up to ~1h of new work at risk between snapshots (tune in the plist).
- **Two secrets live off-machine**: the restic passphrase and how to re-auth the cloud
  account. Lose both and the backup is unrecoverable *by design*.
- **Scope is the dev environment, not the whole Mac**: macOS system settings, FileVault
  state, app licenses, browser profiles, and non-dev apps are **not** in the backup.
- Validation here used syntax checks + mock-binary runs (no network in the sandbox to
  install real `restic`/`brew`); run `setup.sh`'s built-in shellcheck on the Mac for a
  second pass.

---

## 3) Clean machine → "fell off the boat" — is restore optional and near-seamless?

**Short answer: yes, for the dev environment — and it's optional.** `setup.sh` alone
gives you a fully functioning fresh environment. Restore is the extra step that brings
back *your* state so the new Mac is barely distinguishable from the lost one.

**The runbook (fresh Mac → recovered):**
1. `./setup.sh` — reinstalls every tool + your dotfiles.
2. `./install-claude-backup.sh` — reconnects the cloud remote (browser re-auth) and puts
   your passphrase back in the Keychain (from your password manager).
3. `restic restore latest --target ~/restore` — pull the encrypted snapshot.
4. Move pieces home: `~/.ssh`, `~/.gnupg`, `~/.gitconfig`, `~/.config`, `~/.local/share/atuin`,
   and `~/Library/Application Support/Claude` (Cowork sessions). Fix `~/.ssh` perms.
5. `brew bundle --file .../manifests/Brewfile` — reconcile any package drift from the manifest.

**After that you have back:** your Cowork sessions + outputs, working SSH keys and
GitHub/npm/cargo auth (git just works), your shell history, prompt, terminal, and tool
configs, and your exact package set.

**What restore does NOT bring back (the honest gaps):**
- Regular Claude chats/Projects/memory — but those return by simply **logging in**
  (they're in your Anthropic cloud account, never local).
- macOS system preferences, FileVault, Wi-Fi/keychain items outside this scope, app
  licenses, and any app not covered by the sources list.
- Language toolchains/models as *bytes* — they're **rebuilt** (not restored) from the
  Brewfile + tool lists, which is faster to keep current and smaller to store.

So: for "get me coding again on a new Mac, indistinguishable from before" — **yes**,
this is that. For "bit-perfect clone of the entire machine" — that's a full disk image
(Time Machine / a cloned APFS volume), which is a different tool and out of scope here.
Say the word if you want a Time Machine or `restic`-whole-home layer added alongside.
