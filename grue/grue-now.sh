#!/usr/bin/env bash
#
# grue-now.sh — print the GRUE accent color for the current moment.
# A hex on the green→teal→blue gradient by day, collapsing to inky blue-black
# at the very end of dusk. Goodman's predicate, made a function of the clock.
#
#   GRUE_STATIC=1  → always the daytime green (#17b58a); disables time behavior.
#
# Used by grue-phase.sh (which writes it into the theme files) and callable alone.
# ---------------------------------------------------------------------------
set -euo pipefail

if [[ "${GRUE_STATIC:-0}" == "1" ]]; then echo "#17b58a"; exit 0; fi

# minutes since local midnight
now_min=$(( 10#$(date +%H) * 60 + 10#$(date +%M) ))

# Control stops (minutes → RGB). Interpolated linearly between neighbours.
#  05:30 inky · 06:30 dawn-green · 12:00 teal · 18:00 blue · 21:00 deep ·
#  22:30 indigo · 23:30 inky
awk -v m="$now_min" 'BEGIN{
  n = split("0 330 390 720 1080 1260 1350 1410 1440", t, " ");
      split("10 10 47 26 43 36 22 10 10",  r, " ");
      split("16 16 191 154 127 90 48 16 16", g, " ");
      split("24 24 152 160 196 160 92 24 24", b, " ");
  for (i = 1; i < n; i++) {
    if (m >= t[i] && m <= t[i+1]) {
      f = (t[i+1] == t[i]) ? 0 : (m - t[i]) / (t[i+1] - t[i]);
      R = r[i] + (r[i+1]-r[i]) * f;
      G = g[i] + (g[i+1]-g[i]) * f;
      B = b[i] + (b[i+1]-b[i]) * f;
      printf("#%02x%02x%02x\n", int(R+0.5), int(G+0.5), int(B+0.5));
      exit;
    }
  }
  print "#17b58a";   # fallback
}'
