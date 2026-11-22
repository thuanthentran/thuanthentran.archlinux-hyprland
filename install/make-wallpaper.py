#!/usr/bin/env python3
# Writes the default wallpaper (config/hypr/.config/hypr/wallpapers/default.png):
#   python3 install/make-wallpaper.py config/hypr/.config/hypr/wallpapers/default.png
# Pure Python (zlib + struct), no image library needed; takes ~10 s.
# Minimal wallpaper: near-black, a soft green glow from the lower left, a faint white one
# top right, light grain (also breaks up banding in the gradients).
import zlib, struct, random, math, sys
W, H = 2560, 1600
base = (10, 11, 10)
glows = [  # (cx, cy, radius, colour, strength) in fractions of the width
    (0.10, 0.95, 0.85, (74, 222, 128), 0.38),
    (0.92, -0.05, 0.60, (255, 255, 255), 0.05),
]
random.seed(7)
rows = []
for y in range(H):
    row = bytearray([0])
    fy = y / W
    for x in range(W):
        fx = x / W
        r, g, b = base
        for cx, cy, rad, col, k in glows:
            d = math.hypot(fx - cx, fy - cy) / rad
            if d < 1:
                a = k * (1 - d) ** 1.8
                r += (col[0] - r) * a; g += (col[1] - g) * a; b += (col[2] - b) * a
        n = random.random() * 3 - 1.5
        row += bytes((max(0, min(255, int(r + n + 0.5))), max(0, min(255, int(g + n + 0.5))), max(0, min(255, int(b + n + 0.5)))))
    rows.append(bytes(row))
def chunk(t, d):
    return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', W, H, 8, 2, 0, 0, 0)) \
    + chunk(b'IDAT', zlib.compress(b''.join(rows), 9)) + chunk(b'IEND', b'')
open(sys.argv[1], 'wb').write(png)
