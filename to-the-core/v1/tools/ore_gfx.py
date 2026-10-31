"""Render the icons of the metal-rich rock in the walls and the granules
ground out of it (64x64 each).

Outputs into <out>:
  iron-rich-rock.png    the base game's stones, greyer, flecked with iron
  copper-rich-rock.png  the same, flecked with copper
  iron-granules.png     a heap of small iron pellets
  copper-granules.png   the same in copper

Usage: python3 ore_gfx.py <output-dir> [base stone icon]
"""
import math
import random
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageOps

out = sys.argv[1]
# The base game's stone icon, which the iron-rich rock is drawn from.
stone_icon = sys.argv[2] if len(sys.argv) > 2 else \
    "/mnt/games/SteamLibrary/steamapps/common/Factorio/data/base/graphics/icons/stone.png"
SS = 4
C = 64 * SS


def rock_polygon(cx, cy, r, seed, points=11):
    rng = random.Random(seed)
    return [(cx + math.cos(2 * math.pi * i / points) * r * rng.uniform(0.75, 1.05),
             cy + math.sin(2 * math.pi * i / points) * r * rng.uniform(0.7, 0.95)) for i in range(points)]


def rich_rock(stone_icon, colour):
    """The base game's stone icon, a little greyer, flecked with one ore's
    colour, the flecks following the stones' own shading."""
    stone = Image.open(stone_icon).convert("RGBA").crop((0, 0, 64, 64)).resize((C, C), Image.LANCZOS)
    grey = ImageOps.grayscale(stone).convert("RGBA")
    img = Image.blend(stone, grey, 0.45)
    img.putalpha(stone.getchannel("A"))
    alpha = stone.getchannel("A").load()
    shade = ImageOps.grayscale(stone).load()
    flecks = Image.new("RGBA", (C, C), (0, 0, 0, 0))
    d = ImageDraw.Draw(flecks)
    rng = random.Random(7)
    for count in (18,):
        placed = 0
        while placed < count:
            x, y = rng.uniform(C * 0.1, C * 0.9), rng.uniform(C * 0.1, C * 0.9)
            if alpha[int(x), int(y)] < 250:
                continue
            s = rng.uniform(C * 0.018, C * 0.035)
            d.polygon(rock_polygon(x, y, s, rng.randint(0, 999), 6), fill=colour)
            placed += 1
    # Shade the flecks like the stone under them, so they sit in its surface,
    # and keep them on the stone.
    fpx = flecks.load()
    for y in range(C):
        for x in range(C):
            r, g, b, a = fpx[x, y]
            if a:
                k = 0.45 + shade[x, y] / 255 * 0.9
                fpx[x, y] = (min(255, int(r * k)), min(255, int(g * k)), min(255, int(b * k)),
                             min(int(a * 0.85), alpha[x, y]))
    img.alpha_composite(flecks)
    return img


def granules(light, dark, seed):
    img = Image.new("RGBA", (C, C), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rng = random.Random(seed)
    # A low heap: pellets packed tighter and higher towards the middle.
    pellets = []
    for _ in range(110):
        x = rng.gauss(0.5, 0.2)
        top = 0.9 - 0.62 * math.exp(-((x - 0.5) / 0.26) ** 2)
        y = rng.uniform(top, 0.9)
        pellets.append((y, x))
    for y, x in sorted(pellets):
        r = C * rng.uniform(0.05, 0.075)
        cx, cy = x * C, y * C
        d.ellipse([cx - r, cy - r * 0.85, cx + r, cy + r * 0.85], fill=dark)
        d.ellipse([cx - r * 0.8, cy - r * 0.8, cx + r * 0.5, cy + r * 0.4], fill=light)
    return img


def save(img, name):
    img.filter(ImageFilter.GaussianBlur(SS * 0.3)).resize((64, 64), Image.LANCZOS).save(f"{out}/{name}.png", optimize=True)


save(rich_rock(stone_icon, (92, 112, 138)), "iron-rich-rock")
save(rich_rock(stone_icon, (196, 112, 58)), "copper-rich-rock")
save(granules((150, 160, 172), (64, 70, 80), 1), "iron-granules")
save(granules((226, 140, 82), (120, 62, 30), 2), "copper-granules")
