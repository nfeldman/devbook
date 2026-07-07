# Gruebook — GRUE beyond the terminal

Take the GRUE identity out of the shell and across the desktop. This is the honest
extent of "make my whole Mac grue": the high-leverage touchpoints macOS actually lets
you theme, not a fantasy OS repaint.

## What it does

- **Dynamic wallpaper** — a glass desktop tinted by the *current* grue accent, re-rendered
  every 20 min so it walks the same green→blue→inky curve as your prompt. The concept
  escapes the terminal onto the whole screen. (`gen-wallpaper.py` + `gruebook-wallpaper.sh`)
- **Zed** — a **GRUE Light** theme (glass field, petrol ink, brass/slate/jade, ember,
  warm current-line).
- **bat** — a **GRUE Light** `.tmTheme`.
- **macOS appearance** — custom **highlight** color (grue), **accent** set to Blue (the
  nearest of macOS's fixed set), Light mode.

## Install

Run the terminal theme first (it provides `grue-now.sh`), then the gruebook:

```bash
./grue/install-grue.sh
./gruebook/install-gruebook.sh
```

Log out and back in so the accent/highlight fully apply.

## Honest limits

- **No arbitrary custom accent.** macOS accent is a fixed set — we pick Blue as nearest.
  The **highlight** color *can* be fully custom, so selections read grue.
- **Wallpaper setting is finicky on recent macOS.** `install-gruebook.sh` installs the
  `wallpaper` CLI for reliability; without it, it falls back to AppleScript, which Sonoma+
  sometimes ignores.
- **System chrome can't be recolored** (menu bar internals, traffic lights, login screen) —
  that would need hacks; out of scope by design.
- Browser theming is out of scope.

## Reverse it

**One shot:** `./uninstall-grue.sh` (repo root) removes the whole GRUE + Gruebook layer.
Manual steps below if you prefer.

- Appearance: `gruebook-appearance.sh --revert`
- Wallpaper: `launchctl unload ~/Library/LaunchAgents/com.gruebook.wallpaper.plist`, then set any wallpaper.
- Zed / bat: choose another theme; the GRUE themes just sit in your themes dirs.
- Remove the `# >>> gruebook >>>` block from `~/.zshrc`.

## Freeze the color

`GRUE_STATIC=1` (in your env) pins the accent — and therefore the wallpaper — to daytime green.
