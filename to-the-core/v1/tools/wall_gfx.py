"""Render cliff-face pieces for tunnel walls.

A wall is a void (solid rock) tile next to open ground. It gets one face piece
per open side and a small corner piece per open diagonal not already covered by
a face. Seen from above at Factorio's angle, a south face (open ground to the
south) shows the full rock face; north faces are only the rock's top lip; east
and west faces are narrow side faces. The rock top itself stays black.

Outputs <out>/tunnel-wall-<piece>.png for pieces n, e, s, w, ne, se, sw, nw:
each a row of VARIANTS 64x64 frames (one tile at scale 0.5).

Usage: python3 wall_gfx.py <output-dir>
"""
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

out = sys.argv[1]
SS = 4
T = 64 * SS
VARIANTS = 4


def rock(rng, base):
    v = rng.randint(-14, 14)
    return (max(0, base[0] + v), max(0, base[1] + v), max(0, base[2] + v), 255)


def jagged(rng, start, end, steps, amount):
    """Points from start to end with perpendicular jitter (axis-aligned lines)."""
    (x0, y0), (x1, y1) = start, end
    pts = []
    for i in range(steps + 1):
        t = i / steps
        x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
        j = rng.uniform(-amount, amount) if 0 < i < steps else 0
        pts.append((x + j, y) if x0 == x1 else (x, y + j))
    return pts


def south_face(rng):
    """Open ground to the south: full rock face across the lower tile."""
    img = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    top = jagged(rng, (0, T * 0.22), (T, T * 0.22), 8, T * 0.06)
    d.polygon(top + [(T, T), (0, T)], fill=(78, 68, 58, 255))
    # vertical strata and cracks, lighter toward the base
    for _ in range(14):
        x = rng.uniform(0, T)
        y0 = rng.uniform(T * 0.25, T * 0.5)
        w = rng.uniform(T * 0.04, T * 0.12)
        shade = rock(rng, (100, 88, 74))
        d.polygon([(x, y0), (x + w, y0 + rng.uniform(-8, 8) * SS), (x + w * 0.8, T), (x - w * 0.2, T)], fill=shade)
    for _ in range(5):
        x = rng.uniform(T * 0.1, T * 0.9)
        d.line([(x, T * 0.3), (x + rng.uniform(-10, 10) * SS, T * 0.95)], fill=(40, 34, 28, 255), width=SS * 2)
    # lit lip along the top edge, shadowed base, rubble
    d.line(top, fill=(150, 136, 118, 255), width=SS * 3)
    d.rectangle([0, T * 0.9, T, T], fill=(52, 45, 38, 255))
    for _ in range(6):
        x, r = rng.uniform(0, T), rng.uniform(2, 5) * SS
        d.ellipse([x - r, T - r * 1.6, x + r, T], fill=rock(rng, (96, 86, 74)))
    return img


def north_face(rng):
    """Open ground to the north: just the rock's top lip at the tile edge."""
    img = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    edge = jagged(rng, (0, T * 0.14), (T, T * 0.14), 8, T * 0.05)
    d.polygon([(0, 0), (T, 0)] + edge[::-1], fill=(66, 58, 50, 255))
    d.line(edge, fill=(34, 30, 26, 255), width=SS * 3)
    d.line([(0, SS), (T, SS)], fill=(120, 108, 94, 255), width=SS * 2)
    return img


def side_face(rng):
    """Open ground to the east: a narrow face along the right edge."""
    img = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    edge = jagged(rng, (T * 0.68, 0), (T * 0.68, T), 8, T * 0.06)
    d.polygon(edge + [(T, T), (T, 0)], fill=(72, 63, 54, 255))
    for _ in range(6):
        y = rng.uniform(0, T)
        d.line([(T * 0.72, y), (T, y + rng.uniform(-6, 6) * SS)], fill=rock(rng, (92, 81, 68)), width=SS * 3)
    d.line(edge, fill=(128, 115, 99, 255), width=SS * 2)
    return img


def corner(rng):
    """Open ground diagonally to the south-east: a small rock spur."""
    img = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pts = [(T, T * rng.uniform(0.5, 0.62)), (T * rng.uniform(0.72, 0.8), T * 0.72), (T * rng.uniform(0.5, 0.62), T)]
    d.polygon(pts + [(T, T)], fill=(76, 67, 57, 255))
    d.line(pts, fill=(130, 117, 100, 255), width=SS * 2)
    return img


def sheet(make, transform, seed):
    rng = random.Random(seed)
    row = Image.new("RGBA", (64 * VARIANTS, 64), (0, 0, 0, 0))
    for i in range(VARIANTS):
        frame = transform(make(rng)).filter(ImageFilter.SMOOTH)
        row.paste(frame.resize((64, 64), Image.LANCZOS), (64 * i, 0))
    return row


identity = lambda im: im
mirror = lambda im: im.transpose(Image.FLIP_LEFT_RIGHT)
flip = lambda im: im.transpose(Image.FLIP_TOP_BOTTOM)
pieces = {
    "s": (south_face, identity),
    "n": (north_face, identity),
    "e": (side_face, identity),
    "w": (side_face, mirror),
    "se": (corner, identity),
    "sw": (corner, mirror),
    "ne": (corner, flip),
    "nw": (corner, lambda im: mirror(flip(im))),
}
for seed, (name, (make, transform)) in enumerate(pieces.items()):
    sheet(make, transform, seed).save(f"{out}/tunnel-wall-{name}.png", optimize=True)
