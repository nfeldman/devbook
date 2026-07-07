# GRUE — terminal theme (implementation)

The GRUE spec (see `grue-style-guide.html`) made real across the terminal surfaces:
a luminous glass field, petrol ink, liminal accents, and one clock-bound accent that
crosses green→teal→blue by day and collapses to inky blue-black at the very end of dusk.

## Files

| File | Goes to | What it is |
|------|---------|------------|
| `grue-now.sh` | `~/.local/bin/` | prints the grue accent hex for right now |
| `grue-phase.sh` | `~/.local/bin/` | writes that hex into the marked config lines (launchd, 20 min) |
| `ghostty-grue.config` | `~/.config/ghostty/config` | glass field, palette, grue cursor |
| `starship-grue.toml` | `~/.config/starship.toml` | prompt-as-dashboard, grue caret |
| `zellij-grue.kdl` | `~/.config/zellij/themes/grue.kdl` | glass theme |
| `gitconfig-grue.ini` | `~/.config/grue/` (git include) | delta light diff colors |
| `grue-shell.zsh` | `~/.config/grue/` (sourced) | eza taxonomy + `BAT_THEME` |
| `zed-grue-settings.json` | `~/.config/zed/settings.json` | light, Iosevka, ligatures |
| `install-grue.sh` | — | applies it all, idempotent + reversible |

## Prerequisites

The tools from `setup.sh` (Ghostty, Starship, Zellij, bat, delta, eza, Zed) plus the
**Iosevka** fonts, which `install-grue.sh` installs: `font-iosevka-term-nerd-font`
(patched with icon glyphs so Starship/eza icons render), plus `font-iosevka` and
`font-iosevka-aile` (UI). If `"IosevkaTerm Nerd Font"` doesn't resolve, check the exact
installed name with `fc-list | grep -i iosevka | grep -i nerd`.

## Install

```bash
chmod +x install-grue.sh
./install-grue.sh
```

Then reload a live Ghostty window with **Cmd+Shift+,** and open a new shell.

## How "dynamic" actually works (honest)

Terminals render static frames — they can't animate. So the grue gradient is stepped,
and only where each tool allows:

- **Starship caret — live.** Starship re-reads its config every prompt, so `grue-phase`
  rewriting the `grue` palette value shows up on your *next prompt*. This is the real,
  visible day→night shift.
- **Ghostty cursor — new windows.** The cursor color updates in the file; live windows
  need Cmd+Shift+, (no accessibility hacks to force a reload).
- **Zellij / bat / delta / eza / Zed — static** glass palette. Driving these per-minute
  would need hot-reload none of them offer; not worth the fragility.

`grue-phase` runs every 20 minutes via `com.grue.phase`. To freeze the color entirely,
set `GRUE_STATIC=1` (accent pins to daytime green, timer skipped).

## Revert

**One shot:** `./uninstall-grue.sh` (repo root) removes GRUE *and* the Gruebook, restoring the
pre-GRUE configs. Manual steps below if you prefer to pick and choose.

Everything is backed up and reversible:

- Restore the `*.pre-grue.*` files `install-grue.sh` wrote next to each config.
- `launchctl unload ~/Library/LaunchAgents/com.grue.phase.plist`
- Remove the `# >>> grue >>>` block from `~/.zshrc` and the delta `include.path` from `~/.gitconfig`.

## Themes & limits

- Zed and bat use a light base here (One Light / GitHub). Install `gruebook/` for the
  full custom **GRUE Light** themes for both.
- Per-app ligature disabling in diffs isn't possible; pick an Iosevka feature set without
  the offending ligature if a diff arrow reads wrong.
