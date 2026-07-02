# ---- PATH / Homebrew (Apple Silicon) --------------------------------------
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# ---- mise: language runtimes (node/python/go/rust) ------------------------
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

# ---- atuin: searchable shell history (ctrl-r) -----------------------------
if command -v atuin >/dev/null 2>&1; then
  eval "$(atuin init zsh)"
fi

# ---- fzf: fuzzy finder key bindings + completion --------------------------
if command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh) 2>/dev/null || true
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

# ---- git delta pager is configured in ~/.gitconfig (see README) -----------

# ---- zsh niceties ---------------------------------------------------------
setopt AUTO_CD              # type a dir name to cd into it
setopt HIST_IGNORE_ALL_DUPS
setopt SHARE_HISTORY
HISTSIZE=50000
SAVEHIST=50000
