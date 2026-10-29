"""Render the one-way transfer entities between floors (1x1 tile each).

Outputs into <out>:
  downpipe-top.png / downpipe-bottom.png            96x96 (sprite + room)
  lift-pump-top.png / lift-pump-bottom.png          96x96
  power-connector-icon.png                          64x64
The pipe down's top end sits on the upper floor and swallows fluid; its
bottom end hangs out of the ceiling of the floor below. The pipe from below
uses the same shapes with the arrows turned around. Belt ends use the base
game's underground belt sprites. Drawn at 64 px per tile
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


def down_arrow(d, cx, cy, size, color, up=False):
    s = -1 if up else 1
    d.polygon([p(cx - size, cy - s * size * 0.4), p(cx + size, cy - s * size * 0.4), p(cx, cy + s * size * 0.7)], fill=color, outline=(30, 26, 20))


def finish(img, size=96):
    return img.resize((size, size), Image.LANCZOS)


def pipe_collar(d, glass_y0, glass_y1):
    d.rounded_rectangle(box(0.3, glass_y0 - 0.06, 0.7, glass_y1 + 0.06), radius=SS * 4, fill=(118, 122, 128), outline=(48, 50, 54), width=SS * 2)
    d.rectangle(box(0.38, glass_y0, 0.62, glass_y1), fill=(120, 190, 220))
    d.line([p(0.42, glass_y0 + 0.03), p(0.42, glass_y1 - 0.03)], fill=(230, 245, 255), width=SS * 2)


def downpipe_top(up=False):
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
    down_arrow(d, 0.5, 0.52, 0.11, (236, 194, 70), up)
    return finish(img)


def downpipe_bottom(up=False):
    img = Image.new("RGBA", (C, C), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # pipe coming down out of the ceiling into a flanged outlet
    d.rectangle(box(0.34, -0.25, 0.66, 0.6), fill=(110, 114, 120), outline=(48, 50, 54), width=SS * 2)
    pipe_collar(d, 0.0, 0.32)
    d.ellipse(box(0.12, 0.42, 0.88, 0.96), fill=(98, 102, 108), outline=(40, 42, 46), width=SS * 3)
    d.ellipse(box(0.3, 0.55, 0.7, 0.85), fill=(60, 64, 70))
    down_arrow(d, 0.5, 0.68, 0.1, (236, 194, 70), up)
    return finish(img)


for name, make in (("downpipe-top", downpipe_top), ("downpipe-bottom", downpipe_bottom)):
    make().save(f"{out}/{name}.png", optimize=True)
for name, make in (("lift-pump-top", downpipe_top), ("lift-pump-bottom", downpipe_bottom)):
    make(up=True).save(f"{out}/{name}.png", optimize=True)

def power_icon():
    img = Image.new("RGBA", (C, C), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # a pole with a lightning bolt going down into a floor plate
    d.rectangle(box(0.42, 0.0, 0.58, 0.8), fill=(130, 100, 70), outline=(60, 44, 28), width=SS * 2)
    d.rectangle(box(0.18, 0.1, 0.82, 0.22), fill=(150, 120, 86), outline=(60, 44, 28), width=SS * 2)
    d.ellipse(box(0.12, 0.72, 0.88, 1.0), fill=(98, 102, 108), outline=(40, 42, 46), width=SS * 3)
    d.polygon([p(0.62, 0.28), p(0.4, 0.56), p(0.52, 0.56), p(0.4, 0.86), p(0.68, 0.5), p(0.55, 0.5), p(0.66, 0.28)],
              fill=(250, 210, 60), outline=(90, 60, 10))
    return finish(img)


power_icon().crop((16, 16, 80, 80)).save(f"{out}/power-connector-icon.png", optimize=True)
