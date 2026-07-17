#!/usr/bin/env bash
#
# setup.sh — lean, modern, AI-forward macOS dev environment
# Safe to re-run: every step checks before installing (idempotent).
#
# Usage:
#   chmod +x setup.sh
#   ./setup.sh
#
# After it finishes, open a NEW terminal (or Ghostty) so shell changes load.
# ---------------------------------------------------------------------------

set -euo pipefail

# --- pretty logging --------------------------------------------------------
bold() { printf "\033[1m%s\033[0m\n" "$1"; }
info() { printf "\033[1;34m==>\033[0m %s\n" "$1"; }
ok()   { printf "\033[1;32m ok\033[0m %s\n" "$1"; }
warn() { printf "\033[1;33m !!\033[0m %s\n" "$1"; }

DOTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
bold "1/8  Homebrew"
# ---------------------------------------------------------------------------
if ! command -v brew >/dev/null 2>&1; then
  info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Add brew to PATH for this session (Apple Silicon default location)
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
else
  ok "Homebrew already installed"
fi
brew update

# helper: install a formula only if its binary is missing
brew_formula() { # $1 = formula, $2 = command to check
  if ! command -v "${2:-$1}" >/dev/null 2>&1; then
    info "brew install $1"
    brew install "$1"
  else
    ok "$1 present"
  fi
}
# helper: install a cask only if the app isn't already there
brew_cask() { # $1 = cask, $2 = /Applications/App.app to check
  if [[ -n "${2:-}" && -d "$2" ]]; then
    ok "$1 present"
  elif brew list --cask "$1" >/dev/null 2>&1; then
    ok "$1 present"
  else
    info "brew install --cask $1"
    brew install --cask "$1"
  fi
}

# ---------------------------------------------------------------------------
bold "2/8  Terminal + Nerd Font (Ghostty)"
# ---------------------------------------------------------------------------
brew_cask ghostty "/Applications/Ghostty.app"
# Iosevka — one open super-family everywhere. The Nerd patch gives Starship/eza their
# icon glyphs; Iosevka Aile is the proportional variant for editor UI (e.g. Zed).
for c in font-iosevka-term-nerd-font font-iosevka-aile; do
  if brew list --cask "$c" >/dev/null 2>&1; then
    ok "$c present"
  else
    info "Installing $c"
    brew install --cask "$c"
  fi
done

# ---------------------------------------------------------------------------
bold "3/8  Shell layer (Starship prompt + Zellij multiplexer)"
# ---------------------------------------------------------------------------
brew_formula starship
brew_formula zellij

# ---------------------------------------------------------------------------
bold "4/8  Modern CLI toolkit"
# ---------------------------------------------------------------------------
brew_formula eza          # modern `ls`
brew_formula bat          # modern `cat` w/ syntax highlight
brew_formula fd           # modern `find`
brew_formula ripgrep rg   # modern `grep`
brew_formula fzf          # fuzzy finder (ctrl-t files, alt-c dirs; atuin owns ctrl-r)
brew_formula zoxide       # smart `cd` (learns your dirs)
brew_formula git-delta delta   # beautiful git diffs
brew_formula jq           # JSON wrangling
brew_formula yq           # YAML/JSON/XML wrangling
brew_formula sd           # modern `sed` (find/replace)
brew_formula dust         # modern `du` (disk usage)
brew_formula bottom btm   # modern `top`/`htop`
brew_formula tealdeer tldr # concise man pages
brew_formula atuin        # magical shell history (searchable, synced)
brew_formula gh           # GitHub CLI
brew_formula lazygit      # git TUI
brew_formula direnv       # per-directory env vars
brew_formula shellcheck   # shell linter (powers this script's self-check)
brew_formula age          # modern file encryption

# 1Password CLI (op).
brew_cask 1password-cli ""

# Git clients (GUI):
# Sourcetree — free, full-featured Git GUI (Atlassian). One-time account at install;
# works with GitHub/any host afterward, no ongoing Atlassian tie.
brew_cask sourcetree "/Applications/Sourcetree.app"
# GitButler — Git client built around simultaneous / virtual branches (open source).
brew_cask gitbutler "/Applications/GitButler.app"

# Firefox — the independent, non-Chromium engine: cross-engine dev testing, and an
# anti-monoculture daily driver (same posture as MODELS.md, applied to browsers).
brew_cask firefox "/Applications/Firefox.app"

# ---------------------------------------------------------------------------
bold "5/8  Language runtimes (mise) + Python tooling (uv)"
# ---------------------------------------------------------------------------
brew_formula mise
brew_formula uv           # ultrafast Python package/project manager (Astral)
brew_formula elan-init elan  # official Lean toolchain manager; same role as rustup, see below

# rustup — official Rust toolchain manager (boring + reliable; see below).
# It's KEG-ONLY in Homebrew (never linked into PATH), so guard on its keg path:
# a `command -v` check would reinstall forever and the setup below would no-op.
RUSTUP_BIN="$(brew --prefix)/opt/rustup/bin"
if [[ -x "$RUSTUP_BIN/rustup" ]]; then
  ok "rustup present"
else
  info "brew install rustup"
  brew install rustup
fi

# Install common runtimes via mise (global defaults). Re-running is a no-op.
if command -v mise >/dev/null 2>&1; then
  info "Installing global runtimes via mise (node, python, go)..."
  mise use -g node@lts    || warn "mise node failed"
  mise use -g python@3.12 || warn "mise python failed"
  mise use -g go@latest   || warn "mise go failed"
  # mise use -g does NOT affect this non-interactive shell's PATH. Add the shims dir
  # now so the runtimes it installed resolve later in THIS script.
  export PATH="$HOME/.local/share/mise/shims:$PATH"
  hash -r 2>/dev/null || true
fi

# Rust via rustup, not mise: mise's rust support is finicky; rustup is canonical.
# Called by keg path (keg-only); the zshrc block puts this dir on PATH for shells.
if [[ -x "$RUSTUP_BIN/rustup" ]]; then
  info "Setting up Rust stable via rustup"
  "$RUSTUP_BIN/rustup" default stable >/dev/null 2>&1 || "$RUSTUP_BIN/rustup" toolchain install stable || warn "rustup stable failed"
else
  warn "rustup missing at $RUSTUP_BIN — skipping Rust setup"
fi

# Lean via elan, not mise: elan is canonical and auto-switches toolchains from a
# project's lean-toolchain file (which mise ignores). `stable` = latest Lean 4.
if command -v elan >/dev/null 2>&1; then
  info "Setting up Lean stable via elan"
  elan default stable >/dev/null 2>&1 || elan toolchain install stable || warn "elan stable failed"
fi

# ---------------------------------------------------------------------------
bold "6/8  Containers / DevOps (OrbStack + kube tools)"
# ---------------------------------------------------------------------------
brew_cask orbstack "/Applications/OrbStack.app"  # fast, light Docker Desktop replacement (Docker + K8s)
brew_formula kubectl      # kubernetes CLI
brew_formula k9s          # kubernetes TUI
brew_formula helm         # kubernetes package manager

# ---------------------------------------------------------------------------
bold "7/8  AI-forward tooling"
# ---------------------------------------------------------------------------
brew_cask ollama "/Applications/Ollama.app"      # local, vendor-free LLM runtime
brew_cask zed "/Applications/Zed.app"            # fast, AI-native editor (optional; VS Code/Cursor also fine)

# Claude Code — Anthropic's recommended install is the native binary (signed,
# auto-updating, no Node dependency; lands in ~/.local/bin, which the zshrc block
# puts on PATH). The brew cask (claude-code) also exists but lags and doesn't
# auto-update, so we take the official path. npm is the deprecated legacy route.
if ! command -v claude >/dev/null 2>&1 && [[ ! -x "$HOME/.local/bin/claude" ]]; then
  info "Installing Claude Code (native installer)"
  curl -fsSL https://claude.ai/install.sh | bash || warn "Claude Code install failed"
else
  ok "Claude Code present"
fi

# No cloud-agent tool installed by default (model sovereignty — see MODELS.md).
# Ollama is your local, vendor-free runtime. Suggested coding model:
#   ollama pull qwen3-coder:30b      # 32GB RAM; see MODELS.md for 16GB/64GB picks
# Add a neutral agent later if you want one (e.g. opencode — open source,
# bring-your-own-model), pointed at Ollama first.

# ---------------------------------------------------------------------------
bold "8/8  Wiring up dotfiles"
# ---------------------------------------------------------------------------
# Stage config into a stable ~/.dotfiles home so the symlinks have a durable source
# (and a natural git repo).
DOTREPO="$HOME/.dotfiles"
mkdir -p "$DOTREPO" "$HOME/.config" "$HOME/.config/ghostty" "$HOME/.config/zellij"
info "Staging dotfiles into $DOTREPO"
for f in starship.toml ghostty.config zellij.kdl zshrc-additions.zsh gitconfig-devbook AGENTS.md; do
  [[ -f "$DOTDIR/$f" ]] && cp "$DOTDIR/$f" "$DOTREPO/$f"
done

link() { # $1 = source (in $DOTREPO), $2 = destination
  if [[ -f "$1" ]]; then
    if [[ -e "$2" && ! -L "$2" ]]; then
      cp "$2" "$2.backup.$(date +%s)" && warn "backed up existing $2"
    elif [[ -L "$2" && "$(readlink "$2")" != "$1" ]]; then
      # Provenance: don't silently repoint someone else's symlink (e.g. another
      # dotfiles manager) — say what it used to point at so it can be restored.
      warn "repointing symlink $2 (was → $(readlink "$2"))"
    fi
    ln -sf "$1" "$2" && ok "linked $(basename "$2")"
  fi
}

# helper: keep ONE marked block current inside a file (creating the file if
# absent). Everything outside the START/END markers is left untouched; re-running
# replaces the block in place (idempotent), and deleting the block cleanly
# reverses it — the same contract as the ~/.zshrc block below.
ensure_marked_block() { # $1=file $2=start $3=end $4=payload
  local file="$1" start="$2" end="$3" payload="$4"
  mkdir -p "$(dirname "$file")"
  touch "$file"
  local had=0
  grep -qF "$start" "$file" 2>/dev/null && had=1
  if [[ "$had" == "1" ]]; then
    local tmp; tmp="$(mktemp)"
    awk -v s="$start" -v e="$end" '$0==s{skip=1} !skip{print} $0==e{skip=0}' "$file" > "$tmp"
    cat "$tmp" > "$file"   # cat-over, not mv: keeps the file's inode/permissions
    rm -f "$tmp"
  fi
  {
    if [[ "$had" == "0" && -s "$file" ]]; then echo ""; fi
    printf '%s\n' "$start"
    printf '%s\n' "$payload"
    printf '%s\n' "$end"
  } >> "$file"
}

link "$DOTREPO/starship.toml"  "$HOME/.config/starship.toml"
link "$DOTREPO/ghostty.config" "$HOME/.config/ghostty/config"
link "$DOTREPO/zellij.kdl"     "$HOME/.config/zellij/config.kdl"

# Git defaults (delta pager, zdiff3, modern QoL) live in gitconfig-devbook so
# ~/.gitconfig itself stays yours. Wiring it in is ONE reversible include line;
# your own ~/.gitconfig settings still override anything in the include.
if command -v git >/dev/null 2>&1; then
  if git config --global --get-all include.path 2>/dev/null | grep -qF "$DOTREPO/gitconfig-devbook"; then
    ok "git include already wired"
  else
    info "Adding include.path $DOTREPO/gitconfig-devbook to git global config"
    git config --global --add include.path "$DOTREPO/gitconfig-devbook"
  fi
fi

# ~/.zshrc gets a small marked block that SOURCES the staged copy, so re-running
# setup.sh always delivers zshrc updates (an embedded copy goes stale forever).
# On re-run the old marked block — including older embedded ones — is replaced
# in place; everything outside the markers is untouched.
ZSHRC="$HOME/.zshrc"
MARKER_START="# >>> dev-env setup >>>"
MARKER_END="# <<< dev-env setup <<<"
HAD_BLOCK=0
if grep -qF "$MARKER_START" "$ZSHRC" 2>/dev/null; then
  HAD_BLOCK=1
  info "Refreshing dev-env block in .zshrc"
  TMP="$(mktemp)"
  awk -v s="$MARKER_START" -v e="$MARKER_END" '$0==s{skip=1} !skip{print} $0==e{skip=0}' "$ZSHRC" > "$TMP"
  cat "$TMP" > "$ZSHRC"   # cat-over, not mv: keeps ~/.zshrc's inode and permissions
  rm -f "$TMP"
else
  info "Adding dev-env block to .zshrc"
fi
{
  if [[ "$HAD_BLOCK" == "0" ]]; then echo ""; fi
  echo "$MARKER_START"
  echo '# Shell init lives in the staged dotfiles; setup.sh refreshes it on each run.'
  echo '[[ -f "$HOME/.dotfiles/zshrc-additions.zsh" ]] && source "$HOME/.dotfiles/zshrc-additions.zsh"'
  echo "$MARKER_END"
} >> "$ZSHRC"
ok "zshrc block sources $DOTREPO/zshrc-additions.zsh"

# AI agent context: make the staged AGENTS.md the machine-wide brief every agent
# reads. Claude Code loads ~/.claude/CLAUDE.md (user memory) and honors @path
# imports, so ONE marked block pulls in the staged file — your own global memory
# in that file (if any) stays put, and removing the block undoes it. HTML-comment
# markers stay invisible in the rendered markdown. Zed/Cursor/Codex read an
# AGENTS.md natively (per-repo); the `agents-here` shell helper fans it out there.
if [[ -f "$DOTREPO/AGENTS.md" ]]; then
  ensure_marked_block "$HOME/.claude/CLAUDE.md" \
    "<!-- >>> dev-env agents >>> -->" \
    "<!-- <<< dev-env agents <<< -->" \
    "@$DOTREPO/AGENTS.md"
  ok "Claude Code user memory imports $DOTREPO/AGENTS.md"
fi

# Provenance: record what this run touched (conservator habit — cheap, legible).
MANIFEST="$HOME/.config/dev-env/manifest.txt"
mkdir -p "$(dirname "$MANIFEST")"
{
  echo "--- dev-env setup run: $(date) ---"
  echo "ran from:        $DOTDIR"
  echo "staged dotfiles: $DOTREPO"
  command -v brew >/dev/null 2>&1 && echo "brew:            $(brew --version | head -1)"
  # Record what the two curl-installed tools (brew above, claude here) resolved to.
  command -v claude >/dev/null 2>&1 && echo "claude:          $(claude --version 2>/dev/null | head -1)" || true
} >> "$MANIFEST"
ok "recorded run in $MANIFEST"

# --- Optional self-check: lint THIS script with shellcheck (non-fatal) ---------
# The shellcheck linter is installed in step 4, so this runs from the first run onward.
# Skip with:  SKIP_SELFCHECK=1 ./setup.sh
if [[ "${SKIP_SELFCHECK:-0}" == "1" ]]; then
  ok "self-check skipped (SKIP_SELFCHECK=1)"
elif command -v shellcheck >/dev/null 2>&1; then
  info "Self-check: shellcheck $(basename "$0")"
  if shellcheck -s bash -S warning "$0"; then
    ok "shellcheck: clean (no warnings or errors)"
  else
    warn "shellcheck flagged items above — non-fatal; review before trusting a change."
  fi
else
  warn "shellcheck not on PATH yet; re-run to self-lint (or 'brew install shellcheck')."
fi

echo ""
bold "Done. ✅"
echo "Next steps:"
echo "  1) Quit and reopen your terminal (or launch Ghostty)."
echo "  2) Font: IosevkaTerm Nerd Font everywhere."
echo "  3) Run 'mise doctor' and 'atuin register' (optional history sync)."
echo "  4) 'ollama pull qwen3-coder:30b' for a local, vendor-free coding model (see MODELS.md for your RAM tier)."
echo "  5) 'claude' to start Claude Code (the one intentional vendor tool) in any project."
