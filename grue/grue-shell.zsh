# GRUE shell integration  →  sourced from ~/.zshrc by install-grue.sh
# bat: closest bundled light theme (a custom GRUE .tmTheme can replace this later).
export BAT_THEME="GitHub"

# eza: colour-as-taxonomy on the GRUE palette (truecolor 38;2;R;G;B).
#   directories = slate · executables = jade · symlinks = pewter · .md = warm
export EZA_COLORS="di=38;2;63;111;134:ex=38;2;15;138;112:ln=38;2;110;121;147:\
*.md=38;2;138;106;36:*.toml=38;2;110;121;147:ur=38;2;31;42;43:uw=38;2;187;69;41:\
ux=38;2;15;138;112:gx=38;2;15;138;112:sn=38;2;123;148;152:sb=38;2;123;148;152"

# Expose the current grue accent to anything that wants it (updated per shell).
export GRUE_ACCENT="$("$HOME/.local/bin/grue-now.sh" 2>/dev/null || echo '#2b7fc4')"
