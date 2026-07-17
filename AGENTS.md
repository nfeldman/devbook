# Machine environment (devbook)

Context for AI coding agents working on this machine. These are **behavioral
rules, not a full inventory** — run `brew leaves`, `mise ls`, or `tldr <tool>`
for specifics. This file is the source of truth; `setup.sh` stages it to
`~/.dotfiles/AGENTS.md` and wires it into each agent's global config, so every
agent sees the same brief.

## Toolchains — always go through the version manager
- Runtimes are managed by **mise** (node LTS, python 3.12, go). Never assume a
  system version; the mise shims resolve the right one, and per-project pins
  live in a `mise.toml`.
- **Rust** uses rustup (`cargo`), **Lean** uses elan — not mise.
- A bare `java` on PATH may be a broken system stub; use the mise-provided JDK.

## Python — uv, never system pip
- Use **uv**: `uv init`, `uv add <pkg>`, `uv run <cmd>`. It owns the venv — do
  not `pip install` into the system interpreter or hand-roll `python -m venv`.

## Node — mise + corepack
- node LTS via mise; **bun** is available. Use `corepack` for pnpm/yarn.

## Prefer the modern CLIs (installed and expected)
- Search and inspect with **rg** (ripgrep) and **fd**, not grep/find. **bat**
  for cat, **eza** for ls, **sd** for sed, **jq**/**yq** for JSON/YAML,
  **delta** for diffs.
- GitHub via **gh**. Git TUI: **lazygit**.

## Containers, cloud, local models
- Docker is **OrbStack** (Docker + a local Kubernetes), not Docker Desktop.
  `kubectl`, `k9s`, and `helm` are present.
- Local LLMs run via **ollama** (`ollama run <model>`) — prefer it for
  offline / vendor-free inference.

## Secrets — never print, log, or commit them
- **1Password CLI** (`op`) for secrets in scripts; **age** for file encryption.
- No secret in a URL, a log line, or a commit. Read from `op` or the
  environment; don't echo the value.

## Conventions
- macOS on Apple Silicon (arm64), zsh. Homebrew lives at `/opt/homebrew`.
- Per-project env/secrets via **direnv** (`.envrc`, then `direnv allow`).
