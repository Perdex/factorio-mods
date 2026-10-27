"""Render the one-way transfer entities between floors (1x1 tile each).

Outputs into <out>:
  item-chute-top.png / item-chute-bottom.png        96x96 (sprite + room)
  downpipe-top.png / downpipe-bottom.png            96x96
  item-chute-icon.png / downpipe-icon.png           64x64
The top ends sit on the upper floor and swallow things; the bottom ends hang
out of the ceiling of the floor below and drop them. Drawn at 64 px per tile
(scale 0.5) on a 1.5-tile canvas so rims and spouts can overhang.

Usage: python3 transfer_gfx.py <output-dir>
"""
import sys

from PIL import Image, ImageDraw

out = sys.argv[1]
SS = 4
C = 96 * SS          # canvas
T = 64 * SS          # one tile
O = (C - T) / 2      # tile origin inside the canvas


def p(x, y):
    """Tile-local fractions (0..1) to supersampled canvas pixels."""
    return (O + x * T, O + y * T)


def box(x0, y0, x1, y1):
    return [p(x0, y0), p(x1, y1)]


def down_arrow(d, cx, cy, size, color):
    d.polygon([p(cx - size, cy - size * 0.4), p(cx + size, cy - size * 0.4), p(cx, cy + size * 0.7)], fill=color, outline=(30, 26, 20))


def finish(img, size=96):
    return img.resize((size, size), Image.LANCZOS)


def chute_top():
    img = Image.new("RGBA", (C, C), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # stone collar with a wooden hopper funnelling into a dark hole
    d.rounded_rectangle(box(0.04, 0.04, 0.96, 0.96), radius=SS * 8, fill=(116, 106, 94), outline=(52, 46, 40), width=SS * 3)
    d.polygon([p(0.12, 0.12), p(0.88, 0.12), p(0.66, 0.4), p(0.34, 0.4)], fill=(150, 108, 64))
    d.polygon([p(0.88, 0.12), p(0.88, 0.88), p(0.62, 0.62), p(0.66, 0.4)], fill=(124, 86, 50))
    d.polygon([p(0.12, 0.88), p(0.88, 0.88), p(0.62, 0.62), p(0.38, 0.62)], fill=(104, 72, 40))
    d.polygon([p(0.12, 0.12), p(0.34, 0.4), p(0.38, 0.62), p(0.12, 0.88)], fill=(136, 96, 56))
    d.rectangle(box(0.34, 0.4, 0.66, 0.62), fill=(10, 9, 8))
    for x in (0.12, 0.88):
        d.line([p(x, 0.12), p(x, 0.88)], fill=(70, 48, 26), width=SS * 3)
    down_arrow(d, 0.5, 0.5, 0.1, (236, 194, 70))
    return finish(img)


def chute_bottom():
    img = Image.new("RGBA", (C, C), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # wooden chute coming out of the ceiling (above the tile) into a catch box
    d.polygon([p(0.3, -0.25), p(0.7, -0.25), p(0.66, 0.3), p(0.34, 0.3)], fill=(124, 86, 50), outline=(70, 48, 26))
    d.rounded_rectangle(box(0.06, 0.22, 0.94, 0.96), radius=SS * 6, fill=(140, 100, 60), outline=(70, 48, 26), width=SS * 3)
    d.rectangle(box(0.16, 0.34, 0.84, 0.86), fill=(84, 58, 34))
    for k in range(3):
        y = 0.34 + 0.17 * (k + 1)
        d.line([p(0.06, y), p(0.94, y)], fill=(112, 78, 44), width=SS * 2)
    down_arrow(d, 0.5, 0.05, 0.08, (236, 194, 70))
    return finish(img)


def pipe_collar(d, glass_y0, glass_y1):
    d.rounded_rectangle(box(0.3, glass_y0 - 0.06, 0.7, glass_y1 + 0.06), radius=SS * 4, fill=(118, 122, 128), outline=(48, 50, 54), width=SS * 2)
    d.rectangle(box(0.38, glass_y0, 0.62, glass_y1), fill=(120, 190, 220))
    d.line([p(0.42, glass_y0 + 0.03), p(0.42, glass_y1 - 0.03)], fill=(230, 245, 255), width=SS * 2)


def downpipe_top():
    img = Image.new("RGBA", (C, C), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # flanged pipe end set into the floor, with a sight glass
    d.ellipse(box(0.1, 0.1, 0.9, 0.9), fill=(98, 102, 108), outline=(40, 42, 46), width=SS * 3)
    for a in range(8):
        import math
        ang = a * math.pi / 4
        x, y = 0.5 + 0.33 * math.cos(ang), 0.5 + 0.33 * math.sin(ang)
        d.ellipse(box(x - 0.035, y - 0.035, x + 0.035, y + 0.035), fill=(60, 62, 66))
    d.ellipse(box(0.26, 0.26, 0.74, 0.74), fill=(36, 38, 42))
    d.ellipse(box(0.32, 0.32, 0.68, 0.68), fill=(80, 150, 190))
    d.arc(box(0.36, 0.36, 0.64, 0.64), 200, 290, fill=(220, 240, 255), width=SS * 3)
    down_arrow(d, 0.5, 0.52, 0.11, (236, 194, 70))
    return finish(img)


def downpipe_bottom():
    img = Image.new("RGBA", (C, C), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # pipe coming down out of the ceiling into a flanged outlet
    d.rectangle(box(0.34, -0.25, 0.66, 0.6), fill=(110, 114, 120), outline=(48, 50, 54), width=SS * 2)
    pipe_collar(d, 0.0, 0.32)
    d.ellipse(box(0.12, 0.42, 0.88, 0.96), fill=(98, 102, 108), outline=(40, 42, 46), width=SS * 3)
    d.ellipse(box(0.3, 0.55, 0.7, 0.85), fill=(60, 64, 70))
    down_arrow(d, 0.5, 0.68, 0.1, (236, 194, 70))
    return finish(img)


for name, make in (("item-chute-top", chute_top), ("item-chute-bottom", chute_bottom),
                   ("downpipe-top", downpipe_top), ("downpipe-bottom", downpipe_bottom)):
    make().save(f"{out}/{name}.png", optimize=True)

chute_top().crop((16, 16, 80, 80)).save(f"{out}/item-chute-icon.png", optimize=True)
downpipe_bottom().crop((16, 10, 80, 74)).save(f"{out}/downpipe-icon.png", optimize=True)
