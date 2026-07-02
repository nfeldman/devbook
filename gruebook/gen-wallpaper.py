#!/usr/bin/env python3
"""gen-wallpaper.py — render a calm GRUE desktop for a given accent hex.

A glass field with a gentle vertical wash toward a muted version of the current
grue accent, plus a soft corner glow. Subtle by design — a desktop, not a poster.

    gen-wallpaper.py "#2b7fc4" out.png [WIDTH HEIGHT]
"""
import sys, math
try:
    from PIL import Image
except ImportError:
    sys.stderr.write("Pillow required: pip3 install --break-system-packages pillow\n")
    sys.exit(1)

GLASS = (238, 243, 242)  # #eef3f2

def hex2rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))

def main():
    hexc = sys.argv[1] if len(sys.argv) > 1 else "#2b7fc4"
    out  = sys.argv[2] if len(sys.argv) > 2 else "grue-wallpaper.png"
    W = int(sys.argv[3]) if len(sys.argv) > 3 else 3840
    H = int(sys.argv[4]) if len(sys.argv) > 4 else 2160
    accent = hex2rgb(hexc)

    top = GLASS
    bottom = mix(GLASS, accent, 0.20)      # subtle — the field stays light

    # Vertical gradient built cheaply as a 1×H strip, then stretched to W×H.
    strip = Image.new("RGB", (1, H))
    for y in range(H):
        t = y / (H - 1)
        te = t * t * (3 - 2 * t)           # smoothstep
        strip.putpixel((0, y), mix(top, bottom, te))
    img = strip.resize((W, H))

    # Soft corner glow of the accent (low alpha), built small and stretched.
    S = 288
    glow = Image.new("L", (S, S), 0)
    cx, cy = S * 0.74, S * 0.74
    for j in range(S):
        for i in range(S):
            d = math.hypot(i - cx, j - cy) / (S * 0.62)
            v = max(0.0, 1.0 - d)
            glow.putpixel((i, j), int(70 * v * v))   # peak ~27% opacity
    glow = glow.resize((W, H))
    overlay = Image.new("RGB", (W, H), accent)
    img = Image.composite(overlay, img, glow)

    img.save(out)
    print(out)

if __name__ == "__main__":
    main()
