# ---- PATH / Homebrew (Apple Silicon) --------------------------------------
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi
# ~/.local/bin — where native installers land (Claude Code, uv-installed tools).
export PATH="$HOME/.local/bin:$PATH"
# rustup is keg-only in Homebrew — its keg bin holds the rustup/cargo/rustc shims.
if [[ -d "${HOMEBREW_PREFIX:-/opt/homebrew}/opt/rustup/bin" ]]; then
  export PATH="${HOMEBREW_PREFIX:-/opt/homebrew}/opt/rustup/bin:$PATH"
fi

# ---- mise: language runtimes (node/python/go; rust=rustup, lean=elan) -----
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi

# ---- Starship prompt ------------------------------------------------------
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

# ---- zoxide: smarter cd (use `z <dir>`, `zi` for interactive) -------------
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# ---- fzf: fuzzy finder (ctrl-t files, alt-c dirs) --------------------------
if command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh) 2>/dev/null || true
fi

# ---- atuin: searchable shell history — owns ctrl-r --------------------------
# Loaded AFTER fzf on purpose: both bind ctrl-r and the last binding wins.
if command -v atuin >/dev/null 2>&1; then
  eval "$(atuin init zsh)"
fi

# ---- direnv: per-project env vars -----------------------------------------
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

# ---- Aliases: modern CLI replacements -------------------------------------
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --group-directories-first --icons=auto'
  alias ll='eza -lh --group-directories-first --icons=auto --git'
  alias la='eza -lah --group-directories-first --icons=auto --git'
  alias lt='eza --tree --level=2 --icons=auto'
fi
command -v bat  >/dev/null 2>&1 && alias cat='bat --paging=never'
command -v dust >/dev/null 2>&1 && alias du='dust'
command -v btm  >/dev/null 2>&1 && alias top='btm'
command -v lazygit >/dev/null 2>&1 && alias lg='lazygit'
alias g='git'
alias k='kubectl'

# ---- One-command maintenance ----------------------------------------------
# Refresh the core layers: brew packages (most tools), mise runtimes, Rust.
alias dev-up='brew update && brew upgrade && mise upgrade && rustup update'

# ---- agents-here: one AGENTS.md, every agent — for the CURRENT repo ---------
# Machine-wide context is wired globally by setup.sh. This is PER-PROJECT: it
# writes a starter AGENTS.md (if absent) and points the tools that insist on
# their own filename at it, so Claude Code and Copilot read the same file. Zed,
# Cursor, and Codex read AGENTS.md natively, so they need nothing. Existing REAL
# files are never clobbered — it skips them so you can merge by hand.
agents-here() {
  emulate -L zsh
  if [[ ! -f AGENTS.md ]]; then
    cat > AGENTS.md <<'EOF'
# Project context for AI agents

<!-- One file, read by every coding agent. Describe how THIS repo is built,
     tested, and run, plus any conventions an agent should follow. -->
EOF
    print "created AGENTS.md"
  fi
  local t want
  for t in CLAUDE.md .github/copilot-instructions.md; do
    # relative link so the checkout stays portable across machines
    [[ "$t" == */* ]] && want="../AGENTS.md" || want="AGENTS.md"
    if [[ -e "$t" && ! -L "$t" ]]; then
      print "skip $t (real file — merge into AGENTS.md by hand)"
      continue
    fi
    # provenance: don't silently repoint someone else's symlink
    [[ -L "$t" && "$(readlink "$t")" != "$want" ]] && print "repointing $t (was -> $(readlink "$t"))"
    mkdir -p "${t:h}"
    ln -sf "$want" "$t"
    print "linked $t -> AGENTS.md"
  done
}

# ---- git defaults (delta pager, zdiff3) live in ----------------------------
# ---- ~/.dotfiles/gitconfig-devbook, wired in via include.path by setup.sh --

# ---- zsh niceties ---------------------------------------------------------
setopt AUTO_CD              # type a dir name to cd into it
setopt HIST_IGNORE_ALL_DUPS
setopt SHARE_HISTORY
HISTSIZE=50000
SAVEHIST=50000
