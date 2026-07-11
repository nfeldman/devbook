# Lean, modern, AI-forward macOS dev environment

A one-shot setup for a fresh Mac. Run one script and you get a fast terminal, a
polished shell, modern CLI tools, polyglot language runtimes, container tooling,
and local + agentic AI tools. Everything is chosen to be lightweight and current
as of mid-2026.

## How to run

Clone (or copy) this folder anywhere, then:

```bash
chmod +x setup.sh
./setup.sh
```

Run it in a local, interactive terminal — the first run installs Homebrew, which
asks for your password once.

The script is **idempotent** — safe to run again anytime. It checks before
installing, backs up any config it would overwrite, and maintains a single
marked block in `~/.zshrc` that re-runs refresh in place — so re-running
`./setup.sh` always delivers the latest shell config too.

It also **self-lints**: it installs `shellcheck` and runs it against itself at the
end (non-fatal — warnings print but never abort the run). Skip that pass with
`SKIP_SELFCHECK=1 ./setup.sh`.

When it finishes: **quit and reopen your terminal (or open Ghostty)** so the
shell changes load.

## Files in this bundle

| File | Goes to | What it is |
|------|---------|------------|
| `setup.sh` | — | The installer. Run this. |
| `starship.toml` | `~/.config/starship.toml` | Prompt config (git, language versions, k8s context). |
| `ghostty.config` | `~/.config/ghostty/config` | Terminal font, theme, keybinds. |
| `zellij.kdl` | `~/.config/zellij/config.kdl` | Terminal multiplexer config. |
| `zshrc-additions.zsh` | sourced from `~/.zshrc` | Shell init (mise, starship, zoxide, atuin, fzf, aliases). |
| `gitconfig-devbook` | included from `~/.gitconfig` | Git defaults: delta pager, zdiff3, modern QoL flags. |
| `MODELS.md` | — | Model-sovereignty posture: local-first AI, swappable vendors. |
| `machine-steward-reviewer.md` | — | Reusable reviewer persona for infra changes (see below). |
| `CLAUDE.md` + `.claude/agents/` | — | Wires Claude Code into this repo's conventions and reviewer. |

`setup.sh` symlinks the configs into place for you (staged via `~/.dotfiles`),
and wires `gitconfig-devbook` in with a single reversible `include.path` line —
your own `~/.gitconfig` settings always win over it.

## What gets installed and why

**Terminal & shell**
- **Ghostty** — GPU-accelerated, native macOS terminal. Fast, minimal config. Your iTerm2 replacement.
- **IosevkaTerm Nerd Font** — open, feature-rich patched font so prompt/file icons render.
- **Starship** — fast, informative prompt (git state, language versions, k8s context).
- **Zellij** — terminal multiplexer (panes, tabs, detachable sessions). Friendlier than tmux; keybinds show on screen.

**Modern CLI toolkit** (drop-in upgrades for old Unix tools)
- `eza` (ls), `bat` (cat), `fd` (find), `ripgrep`/`rg` (grep), `sd` (sed), `dust` (du), `bottom`/`btm` (top)
- `fzf` fuzzy finder (ctrl-t), `zoxide` smart cd (`z`), `atuin` searchable history (owns ctrl-r)
- `git-delta` pretty diffs, `lazygit` git TUI, `gh` GitHub CLI; **Sourcetree** & **GitButler** (Git GUIs)
- `jq`/`yq` for JSON/YAML, `direnv` per-project env, `tldr` concise man pages
- `age` modern file encryption, `op` (1Password CLI) for secrets in scripts

**Language runtimes**
- **mise** — polyglot version manager (replaces nvm/pyenv/rbenv/g). Rust-fast, one tool for Node, Python, and Go. Installs Node LTS, Python 3.12, and Go globally; override per-project with a `mise.toml`. (Rust uses **rustup**; Lean uses **elan**.)
- **uv** — Astral's ultrafast Python package/project manager. Use it for venvs and dependencies (`uv init`, `uv add`, `uv run`). Great for ML/AI work.
- **elan** — official Lean toolchain manager (rustup's equivalent for Lean). Installs latest stable Lean 4 globally and auto-switches to whatever a project's `lean-toolchain` file pins.

**Containers / DevOps**
- **OrbStack** — fast, light Docker Desktop replacement (Docker + a local Kubernetes). Big battery/RAM win.
- `kubectl`, `k9s` (cluster TUI), `helm`.

**AI-forward**
- **Ollama** — run LLMs locally, vendor-free (`ollama pull qwen3-coder:30b`, `ollama run ...`). Your sovereign default; see `MODELS.md` for picks by RAM tier.
- **Claude Code** — Anthropic's agentic CLI, installed via the official native installer (signed, auto-updating, no Node dependency). Run `claude` in any repo. The one intentional vendor tool, balanced by keeping everything else local-capable.
- **Zed** — fast, AI-native editor (its assistant can point at your local Ollama too).
- No cloud-agent CLI is installed by default — add a neutral one later (e.g. **opencode**: open source, bring-your-own-model), pointed at Ollama first. See `MODELS.md`.

## Recommended post-install steps

1. **Ghostty font**: if it didn't auto-apply, set font to `IosevkaTerm Nerd Font` (already in `ghostty.config`).
2. **git**: nothing to do — `setup.sh` wires `gitconfig-devbook` (delta pager,
   zdiff3 conflicts, `push.autoSetupRemote`, rerere, histogram diffs)
   into your global config via one `include.path` line. To undo it all:
   `git config --global --unset include.path ~/.dotfiles/gitconfig-devbook`.
3. **mise**: run `mise doctor` to confirm it's wired up. Per project, `mise use node@22` etc. writes a `mise.toml`.
4. **atuin** (optional): `atuin register` to sync/encrypt history across machines, or just use it locally.
5. **Ollama**: `ollama pull qwen3-coder:30b` (32 GB RAM; see `MODELS.md` for the 16 GB and 64 GB+ picks).
6. **Claude Code**: run `claude` in a project and follow the login prompt.

## Per-project workflow (the modern flow)

- **Node/TS**: `mise use node@lts` → `npm create vite@latest` or `pnpm`, etc.
- **Python/ML**: `uv init myproj && cd myproj && uv add pandas torch` → `uv run python ...`. No manual venv activation.
- **Go**: `mise use go@latest` → `go mod init`.
- **Rust**: rustup already set stable as default → `cargo new`.
- **Lean**: `lake new myproj` → `lake build`. elan picks the toolchain from the project's `lean-toolchain` file automatically.
- **Env vars/secrets**: drop a `.envrc` in the project (`direnv allow`) — auto-loads on `cd`.

## Keeping it current

- `dev-up` (alias installed by the zshrc block) refreshes everything in one go:
  brew packages, mise runtimes, and the Rust toolchain.
- Re-running `./setup.sh` anytime picks up new additions to this repo — it's idempotent.

## Reviewing changes with AI (dogfooding)

This repo carries its own reviewer. `machine-steward-reviewer.md` is a
steward + conservator persona for auditing infra changes, and
`.claude/agents/machine-steward.md` registers it as a Claude Code subagent —
so inside `claude`, any change to `setup.sh` or the dotfiles gets reviewed for
correctness, idempotency, reversibility, and key-custody issues before it
ships. `CLAUDE.md` makes that the default workflow rather than a thing to remember.

## Notes & swaps

- Prefer **WezTerm** over Ghostty? Replace the Ghostty line with `brew_cask wezterm` and skip `ghostty.config`.
- Don't want Zed? Delete the `brew_cask zed` line.
- Want tmux instead of Zellij? Swap `brew_formula zellij` for `brew_formula tmux` (configs differ).
- Everything here is Homebrew-managed: `brew upgrade` keeps it all current.
