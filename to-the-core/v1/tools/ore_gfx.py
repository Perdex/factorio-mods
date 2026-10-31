"""Render the icons of the metal-rich rock in the walls and the granules
ground out of it (64x64 each).

Outputs into <out>:
  iron-rich-rock.png    the base game's stones, the two small ones iron
  copper-rich-rock.png  the same, the two small ones copper
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


def stones(alpha):
    """The separate stones in an icon's alpha mask, as sets of pixels,
    smallest first."""
    w, h = alpha.size
    px = alpha.load()
    seen, found = set(), []
    for y in range(h):
        for x in range(w):
            if px[x, y] < 128 or (x, y) in seen:
                continue
            stone, todo = set(), [(x, y)]
            seen.add((x, y))
            while todo:
                cx, cy = todo.pop()
                stone.add((cx, cy))
                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen and px[nx, ny] >= 128:
                        seen.add((nx, ny))
                        todo.append((nx, ny))
            found.append(stone)
    return sorted(found, key=len)


def rich_rock(stone_icon, colour):
    """The base game's stone icon, the big stones as they are and the two
    small ones in the corners in an ore's colour, keeping their shading."""
    img = Image.open(stone_icon).convert("RGBA").crop((0, 0, 64, 64))
    shade = ImageOps.grayscale(img).load()
    alpha = img.getchannel("A")
    px = img.load()
    nodules = stones(alpha)[:2]
    # Grow each nodule by its soft edge, so the anti-aliased rim is recoloured too.
    apx = alpha.load()
    for stone in nodules:
        rim = {(x + dx, y + dy) for x, y in stone for dx in (-1, 0, 1) for dy in (-1, 0, 1)}
        mean = sum(shade[x, y] for x, y in stone) / len(stone)
        for x, y in rim:
            if 0 <= x < 64 and 0 <= y < 64 and apx[x, y] > 0:
                k = shade[x, y] / mean
                r, g, b = (min(255, int(c * k)) for c in colour)
                px[x, y] = (r, g, b, apx[x, y])
    return img.resize((C, C), Image.LANCZOS)


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


save(rich_rock(stone_icon, (112, 124, 142)), "iron-rich-rock")
save(rich_rock(stone_icon, (206, 112, 52)), "copper-rich-rock")
save(granules((150, 160, 172), (64, 70, 80), 1), "iron-granules")
save(granules((226, 140, 82), (120, 62, 30), 2), "copper-granules")
