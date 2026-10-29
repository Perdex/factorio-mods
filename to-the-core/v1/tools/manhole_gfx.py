"""Render the manhole: a ragged 2x2 hole in the ground, rimmed with broken
stone, dark all the way down.

Outputs into <out>:
  manhole.png         160x160 (2 tiles + room for the rim, scale 0.5)
  manhole-icon.png    64x64

Usage: python3 manhole_gfx.py <output-dir>
"""
import math
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

out = sys.argv[1]
SS = 4
C = 160 * SS         # canvas
T = 64 * SS          # one tile
CX = CY = C / 2


def ragged(radius, wobble, seed, points=48):
    rng = random.Random(seed)
    poly = []
    for i in range(points):
        a = 2 * math.pi * i / points
        r = radius * (1 + rng.uniform(-wobble, wobble))
        poly.append((CX + math.cos(a) * r, CY + math.sin(a) * r * 0.92))
    return poly


def manhole():
    img = Image.new("RGBA", (C, C), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Broken stone rim, then the walls of the hole getting darker inwards.
    d.polygon(ragged(T * 1.08, 0.08, 1), fill=(96, 84, 70))
    d.polygon(ragged(T * 0.98, 0.07, 2), fill=(70, 60, 50))
    for step, shade in enumerate((44, 30, 18, 8)):
        d.polygon(ragged(T * (0.86 - step * 0.14), 0.06, 3 + step), fill=(shade, shade - 4, shade - 8))
    # A few loose stones on the rim.
    rng = random.Random(9)
    for _ in range(14):
        a = rng.uniform(0, 2 * math.pi)
        r = T * rng.uniform(0.96, 1.1)
        x, y = CX + math.cos(a) * r, CY + math.sin(a) * r * 0.92
        s = T * rng.uniform(0.04, 0.08)
        tone = rng.randint(100, 135)
        d.ellipse([x - s, y - s * 0.8, x + s, y + s * 0.8], fill=(tone, tone - 10, tone - 22), outline=(50, 44, 36))
    img = img.filter(ImageFilter.GaussianBlur(SS * 0.6))
    return img


big = manhole()
big.resize((160, 160), Image.LANCZOS).save(f"{out}/manhole.png", optimize=True)
icon = big.crop((int(CX - T * 1.15), int(CY - T * 1.15), int(CX + T * 1.15), int(CY + T * 1.15)))
icon.resize((64, 64), Image.LANCZOS).save(f"{out}/manhole-icon.png", optimize=True)
