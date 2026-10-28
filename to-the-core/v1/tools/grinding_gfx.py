"""Render the grinder (2x2) and the winnower (3x3), 8-frame animations.

Drawn in the game's 3/4 view at 4x supersampling, 64 px per tile (scale 0.5).
Outputs into <out>:
  grinder.png          8 frames of 192x192 (3x3 tiles, footprint centred)
  grinder-icon.png     64x64
  winnower.png         8 frames of 256x320 (4x5 tiles; footprint centre 0.5
                       tiles below the frame centre)
  winnower-icon.png    64x64

Usage: python3 grinding_gfx.py <output-dir>
"""
import math
import sys

from PIL import Image, ImageDraw

out = sys.argv[1]
SS = 4
TILE = 64
FRAMES = 8
HEIGHT = 0.85


def projector(cx, cy):
    def P(x, y, z=0):
        return (int((x + cx) * TILE * SS), int((y + cy - z * HEIGHT) * TILE * SS))
    return P


def grinder_frame(frame):
    W = H = 3
    img = Image.new("RGBA", (W * TILE * SS, H * TILE * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    P = projector(1.5, 1.6)
    # brick base: top and front face
    d.polygon([P(-0.95, -0.85, 0.6), P(0.95, -0.85, 0.6), P(0.95, 0.95, 0.6), P(-0.95, 0.95, 0.6)], fill=(150, 78, 52), outline=(70, 34, 22))
    d.polygon([P(-0.95, 0.95, 0.6), P(0.95, 0.95, 0.6), P(0.95, 0.95, 0), P(-0.95, 0.95, 0)], fill=(124, 62, 42), outline=(70, 34, 22))
    for row in range(3):
        z = 0.2 * row
        d.line([P(-0.95, 0.95, z), P(0.95, 0.95, z)], fill=(90, 44, 28), width=SS * 2)
        for k in range(5):
            x = -0.95 + 0.4 * k + (0.2 if row % 2 else 0)
            d.line([P(x, 0.95, z), P(x, 0.95, z + 0.2)], fill=(90, 44, 28), width=SS)
    # millstone, turning
    c = P(0, 0.05, 0.75)
    r = 0.78 * TILE * SS
    d.ellipse([c[0] - r, c[1] - r * 0.55, c[0] + r, c[1] + r * 0.55], fill=(150, 144, 134), outline=(70, 66, 60), width=SS * 2)
    for k in range(8):
        a = 2 * math.pi * (k / 8 + frame / (FRAMES * 8))
        d.line([c, (c[0] + r * 0.95 * math.cos(a), c[1] + r * 0.52 * math.sin(a))], fill=(110, 104, 96), width=SS * 2)
    d.ellipse([c[0] - r * 0.2, c[1] - r * 0.12, c[0] + r * 0.2, c[1] + r * 0.12], fill=(60, 56, 50))
    # hopper above, feeding the stone in
    d.polygon([P(-0.35, -0.6, 1.6), P(0.35, -0.6, 1.6), P(0.15, -0.3, 1.0), P(-0.15, -0.3, 1.0)], fill=(128, 88, 50), outline=(64, 42, 22))
    d.line([P(0, -0.3, 1.0), P(0, 0.05, 0.8)], fill=(64, 42, 22), width=SS * 3)
    # dust falling out of the front spout
    d.polygon([P(-0.2, 0.95, 0.35), P(0.2, 0.95, 0.35), P(0.12, 1.1, 0.25), P(-0.12, 1.1, 0.25)], fill=(90, 90, 92))
    for k in range(4):
        y = 1.12 + ((frame + k * 2) % FRAMES) / FRAMES * 0.3
        d.ellipse([P(-0.06 + 0.04 * (k - 1.5), y - 0.03, 0.1), P(0.06 + 0.04 * (k - 1.5), y + 0.03, 0.1)], fill=(190, 182, 168))
    return img.resize((W * TILE, H * TILE), Image.LANCZOS)


def winnower_frame(frame):
    W, H = 4, 5
    img = Image.new("RGBA", (W * TILE * SS, H * TILE * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    P = projector(2, 3)
    # slatted timber tower
    top = 2.1
    d.polygon([P(-1.3, 1.3, top), P(1.3, 1.3, top), P(1.3, 1.3, 0), P(-1.3, 1.3, 0)], fill=(140, 98, 56), outline=(60, 40, 20))
    for k in range(8):
        z = 0.25 + k * 0.23
        d.line([P(-1.3, 1.3, z), P(1.3, 1.3, z)], fill=(70, 46, 24), width=SS * 3)
    # pyramid roof: back, sides, front
    apex = P(0, 0, top + 0.8)
    corners = {
        "nw": P(-1.45, -1.45, top), "ne": P(1.45, -1.45, top),
        "se": P(1.45, 1.45, top), "sw": P(-1.45, 1.45, top)
    }
    for a, b, shade in (("nw", "ne", (86, 58, 32)), ("ne", "se", (104, 70, 38)),
                        ("sw", "nw", (118, 80, 44)), ("sw", "se", (138, 94, 52))):
        d.polygon([corners[a], corners[b], apex], fill=shade, outline=(50, 32, 16))
    # sails on the front, turning in the wind
    hub = P(0, 1.35, 1.2)
    for k in range(4):
        a = 2 * math.pi * (k / 4 + frame / (FRAMES * 4))
        tip = (hub[0] + 1.0 * TILE * SS * math.cos(a), hub[1] + 1.0 * TILE * SS * math.sin(a))
        side = (math.cos(a + math.pi / 2), math.sin(a + math.pi / 2))
        w = 0.18 * TILE * SS
        d.polygon([(hub[0] + side[0] * w * 0.3, hub[1] + side[1] * w * 0.3), (tip[0] + side[0] * w, tip[1] + side[1] * w),
                   (tip[0], tip[1]), (hub[0], hub[1])], fill=(226, 214, 186), outline=(90, 76, 56))
        d.line([hub, tip], fill=(80, 56, 30), width=SS * 3)
    d.ellipse([hub[0] - SS * 10, hub[1] - SS * 10, hub[0] + SS * 10, hub[1] + SS * 10], fill=(60, 44, 28))
    # dust blowing off the top, drifting east
    for k in range(6):
        t = ((frame / FRAMES) + k / 6) % 1
        x, z = 0.3 + t * 1.5, top + 0.6 + t * 0.3
        r = 0.12 + t * 0.2
        c = P(x, -0.2, z)
        alpha = int(150 * (1 - t))
        d.ellipse([c[0] - r * TILE * SS, c[1] - r * TILE * SS * 0.7, c[0] + r * TILE * SS, c[1] + r * TILE * SS * 0.7],
                  fill=(214, 206, 190, alpha))
    return img.resize((W * TILE, H * TILE), Image.LANCZOS)


for name, make in (("grinder", grinder_frame), ("winnower", winnower_frame)):
    frames = [make(f) for f in range(FRAMES)]
    w, h = frames[0].size
    sheet = Image.new("RGBA", (w * FRAMES, h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f, (w * i, 0))
    sheet.save(f"{out}/{name}.png", optimize=True)
    side = min(w, h)
    frames[0].crop((0, h - side, side, h)).resize((64, 64), Image.LANCZOS).save(f"{out}/{name}-icon.png", optimize=True)
