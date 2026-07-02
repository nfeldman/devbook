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
# Nerd Font gives Starship/eza their icons and glyphs
if ! brew list --cask font-jetbrains-mono-nerd-font >/dev/null 2>&1; then
  info "Installing JetBrainsMono Nerd Font"
  brew install --cask font-jetbrains-mono-nerd-font
else
  ok "JetBrainsMono Nerd Font present"
fi

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
brew_formula fzf          # fuzzy finder (ctrl-r, ctrl-t)
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
brew_formula age          # modern file encryption (backups, vault exports)

# 1Password CLI (`op`) — used by the optional vault-export escape hatch.
brew_cask 1password-cli ""

# ---------------------------------------------------------------------------
bold "5/8  Language runtimes (mise) + Python tooling (uv)"
# ---------------------------------------------------------------------------
brew_formula mise
brew_formula uv           # ultrafast Python package/project manager (Astral)
brew_formula rustup       # official Rust toolchain manager (boring + reliable; see below)

# Install common runtimes via mise (global defaults). Re-running is a no-op.
if command -v mise >/dev/null 2>&1; then
  info "Installing global runtimes via mise (node, python, go)..."
  mise use -g node@lts    || warn "mise node failed"
  mise use -g python@3.12 || warn "mise python failed"
  mise use -g go@latest   || warn "mise go failed"
  # mise use -g does NOT affect this non-interactive shell's PATH. Add the shims dir
  # now so `node`/`npm` resolve for the AI-tooling step later in THIS script.
  export PATH="$HOME/.local/share/mise/shims:$PATH"
  hash -r 2>/dev/null || true
fi

# Rust via rustup, not mise: mise's rust support is finicky; rustup is canonical.
if command -v rustup >/dev/null 2>&1; then
  info "Setting up Rust stable via rustup"
  rustup default stable >/dev/null 2>&1 || rustup toolchain install stable || warn "rustup stable failed"
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
brew_cask ollama "/Applications/Ollama.app"      # local LLM runtime (for later)
brew_cask zed "/Applications/Zed.app"            # fast, AI-native editor (optional; VS Code/Cursor also fine)

# Claude Code (needs node from mise; installs the CLI globally)
if command -v npm >/dev/null 2>&1; then
  if ! command -v claude >/dev/null 2>&1; then
    info "Installing Claude Code CLI (npm -g @anthropic-ai/claude-code)"
    npm install -g @anthropic-ai/claude-code || warn "Claude Code install failed"
  else
    ok "Claude Code present"
  fi
else
  warn "npm not on PATH yet — open a new shell and run: npm install -g @anthropic-ai/claude-code"
fi

# aider — terminal AI pair programmer, installed as an isolated uv tool
if command -v uv >/dev/null 2>&1; then
  if ! command -v aider >/dev/null 2>&1; then
    info "Installing aider (uv tool install aider-chat)"
    uv tool install aider-chat || warn "aider install failed"
  else
    ok "aider present"
  fi
fi

# ---------------------------------------------------------------------------
bold "8/8  Wiring up dotfiles"
# ---------------------------------------------------------------------------
# Stage the config into a STABLE home for the symlinks. If we linked straight from
# $DOTDIR (wherever you happened to run this), moving/deleting that folder would
# dangle every link. Copying into ~/.dotfiles makes the source durable — and it's a
# natural git repo later. (Verified failure mode: a symlink to a moved source breaks.)
DOTREPO="$HOME/.dotfiles"
mkdir -p "$DOTREPO" "$HOME/.config" "$HOME/.config/ghostty" "$HOME/.config/zellij"
info "Staging dotfiles into $DOTREPO"
for f in starship.toml ghostty.config zellij.kdl zshrc-additions.zsh; do
  [[ -f "$DOTDIR/$f" ]] && cp "$DOTDIR/$f" "$DOTREPO/$f"
done

link() { # $1 = source (in $DOTREPO), $2 = destination
  if [[ -f "$1" ]]; then
    if [[ -e "$2" && ! -L "$2" ]]; then
      cp "$2" "$2.backup.$(date +%s)" && warn "backed up existing $2"
    fi
    ln -sf "$1" "$2" && ok "linked $(basename "$2")"
  fi
}

link "$DOTREPO/starship.toml"  "$HOME/.config/starship.toml"
link "$DOTREPO/ghostty.config" "$HOME/.config/ghostty/config"
link "$DOTREPO/zellij.kdl"     "$HOME/.config/zellij/config.kdl"

# Append the shell-init block to ~/.zshrc exactly once (content is embedded, so it
# survives even if $DOTREPO later moves).
ZSHRC="$HOME/.zshrc"
MARKER="# >>> dev-env setup >>>"
if ! grep -qF "$MARKER" "$ZSHRC" 2>/dev/null; then
  info "Appending init block to ~/.zshrc"
  {
    echo ""
    echo "$MARKER"
    cat "$DOTREPO/zshrc-additions.zsh"
    echo "# <<< dev-env setup <<<"
  } >> "$ZSHRC"
else
  ok "~/.zshrc already configured"
fi

# Provenance: record what this run touched (conservator habit — cheap, legible).
MANIFEST="$HOME/.config/dev-env/manifest.txt"
mkdir -p "$(dirname "$MANIFEST")"
{
  echo "--- dev-env setup run: $(date) ---"
  echo "ran from:        $DOTDIR"
  echo "staged dotfiles: $DOTREPO"
  command -v brew >/dev/null 2>&1 && echo "brew:            $(brew --version | head -1)"
} >> "$MANIFEST"
ok "recorded run in $MANIFEST"

# --- Optional self-check: lint THIS script with shellcheck (non-fatal) ---------
# shellcheck is installed in step 4, so this runs from the first invocation onward.
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
echo "  2) Set Ghostty's font to 'JetBrainsMono Nerd Font' if it didn't auto-apply."
echo "  3) Run 'mise doctor' and 'atuin register' (optional history sync)."
echo "  4) 'ollama pull llama3.2' when you want a local model."
echo "  5) 'claude' to start Claude Code in any project."
