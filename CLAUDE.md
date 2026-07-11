# devbook

One-script macOS dev environment (`setup.sh`) plus the dotfiles it stages.
Philosophy: lean, modern, AI-forward, anti-lock-in (see `MODELS.md`). Every
intervention must be reversible and legible.

## Hard rules

- `setup.sh` stays **idempotent** (safe to re-run, checks before installing)
  and must pass `shellcheck -s bash -S warning` with **zero findings** — it
  self-lints at the end of every run and the README promises a clean pass.
- Every install line carries a one-line "why" comment. Match the existing voice.
- Reversibility: anything touching user files must back up first or be undoable
  by removing one marker/line (see the `~/.zshrc` marker block and the
  `include.path` pattern for git config).
- Keep `README.md` in sync with `setup.sh`: the files table, the "what gets
  installed" lists, and the post-install steps mirror the script. Change one,
  change the other in the same edit.
- `main` is deps-only; backup-system work lives on the `feature/backup` branch.

## Toolchain conventions

- Runtimes via mise (node / python / go) — **except** Rust (rustup) and Lean
  (elan): the canonical manager wins wherever it honors per-project toolchain
  files that mise would ignore.
- Dotfiles are staged to `~/.dotfiles` and symlinked; the files in this repo
  are the source of truth.

## Before shipping a change

1. Run the `machine-steward` subagent (`.claude/agents/machine-steward.md`;
   persona in `machine-steward-reviewer.md`) on any change to `setup.sh` or the
   staged dotfiles. Apply blocker/high findings before finishing.
2. `bash -n setup.sh` and `shellcheck -s bash -S warning setup.sh` must pass.
3. Validate, don't assert — run the tricky helper in isolation if unsure.
