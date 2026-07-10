# Lean, modern, AI-forward macOS dev environment

A one-shot setup for a fresh Mac. Run one script and you get a fast terminal, a
polished shell, modern CLI tools, polyglot language runtimes, container tooling,
and local + agentic AI tools. Everything is chosen to be lightweight and current
as of mid-2026.

## How to run

Put all five files in the same folder, then:

```bash
chmod +x setup.sh
./setup.sh
```

The script is **idempotent** — safe to run again anytime. It checks before
installing, backs up any config it would overwrite, and only appends its shell
block to `~/.zshrc` once.

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
| `zshrc-additions.zsh` | appended to `~/.zshrc` | Shell init (mise, starship, zoxide, atuin, fzf, aliases). |

`setup.sh` symlinks the configs into place for you.

## What gets installed and why

**Terminal & shell**
- **Ghostty** — GPU-accelerated, native macOS terminal. Fast, minimal config. Your iTerm2 replacement.
- **IosevkaTerm Nerd Font** — open, feature-rich patched font so prompt/file icons render.
- **Starship** — fast, informative prompt (git state, language versions, k8s context).
- **Zellij** — terminal multiplexer (panes, tabs, detachable sessions). Friendlier than tmux; keybinds show on screen.

**Modern CLI toolkit** (drop-in upgrades for old Unix tools)
- `eza` (ls), `bat` (cat), `fd` (find), `ripgrep`/`rg` (grep), `sd` (sed), `dust` (du), `bottom`/`btm` (top)
- `fzf` fuzzy finder, `zoxide` smart cd (`z`), `atuin` searchable history
- `git-delta` pretty diffs, `lazygit` git TUI, `gh` GitHub CLI; **Sourcetree** & **GitButler** (Git GUIs)
- `jq`/`yq` for JSON/YAML, `direnv` per-project env, `tldr` concise man pages

**Language runtimes**
- **mise** — polyglot version manager (replaces nvm/pyenv/rbenv/g). Rust-fast, one tool for Node, Python, and Go. Installs Node LTS, Python 3.12, and Go globally; override per-project with a `mise.toml`. (Rust uses **rustup**.)
- **uv** — Astral's ultrafast Python package/project manager. Use it for venvs and dependencies (`uv init`, `uv add`, `uv run`). Great for ML/AI work.

**Containers / DevOps**
- **OrbStack** — fast, light Docker Desktop replacement (Docker + a local Kubernetes). Big battery/RAM win.
- `kubectl`, `k9s` (cluster TUI), `helm`.

**AI-forward**
- **Ollama** — run LLMs locally, vendor-free (`ollama pull qwen2.5-coder`, `ollama run ...`). Your sovereign default; see `MODELS.md`.
- **Claude Code** — Anthropic's agentic CLI. Run `claude` in any repo. The one intentional vendor tool, balanced by keeping everything else local-capable.
- **Zed** — fast, AI-native editor (its assistant can point at your local Ollama too).
- No cloud-agent CLI (e.g. aider) is installed by default — add one later, pointed at Ollama first, if you want it. See `MODELS.md`.

## Recommended post-install steps

1. **Ghostty font**: if it didn't auto-apply, set font to `IosevkaTerm Nerd Font` (already in `ghostty.config`).
2. **git + delta**: add this to `~/.gitconfig` so diffs use delta:
   ```ini
   [core]
       pager = delta
   [interactive]
       diffFilter = delta --color-only
   [delta]
       navigate = true
       line-numbers = true
   [merge]
       conflictstyle = zdiff3
   ```
3. **mise**: run `mise doctor` to confirm it's wired up. Per project, `mise use node@22` etc. writes a `mise.toml`.
4. **atuin** (optional): `atuin register` to sync/encrypt history across machines, or just use it locally.
5. **Ollama**: `ollama pull qwen2.5-coder` (a local, vendor-free coding model; `:14b`/`:32b` if you have the RAM). See `MODELS.md`.
6. **Claude Code**: run `claude` in a project and follow the login prompt.

## Per-project workflow (the modern flow)

- **Node/TS**: `mise use node@lts` → `npm create vite@latest` or `pnpm`, etc.
- **Python/ML**: `uv init myproj && cd myproj && uv add pandas torch` → `uv run python ...`. No manual venv activation.
- **Go**: `mise use go@latest` → `go mod init`.
- **Rust**: `mise use rust@latest` → `cargo new`.
- **Env vars/secrets**: drop a `.envrc` in the project (`direnv allow`) — auto-loads on `cd`.

## Notes & swaps

- Prefer **WezTerm** over Ghostty? Replace the Ghostty line with `brew_cask wezterm` and skip `ghostty.config`.
- Don't want Zed? Delete the `brew_cask zed` line.
- Want tmux instead of Zellij? Swap `brew_formula zellij` for `brew_formula tmux` (configs differ).
- Everything here is Homebrew-managed: `brew upgrade` keeps it all current.
