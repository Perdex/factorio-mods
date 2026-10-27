"""Render the core drill (5x5) and the shaft it leaves behind (7x7).

Outputs into the given directory (64 px per tile, drawn at scale 0.5):
  core-drill.png          8-frame row of 384x384 frames (6x6 tiles centred on
                          the 5x5 drill, room for the derrick and shadow)
  core-drill-shadow.png   384x384
  core-drill-icon.png     64x64
  shaft-top-<axis>.png    448x448: 5x5 pit with stairs going down along two
                          opposite rims; transparent elsewhere
  shaft-bottom-<axis>.png 448x448: 5x5 landing with the same stairs arriving
                          from above; transparent elsewhere
axis "ns" has the stairs along the north and south edges, "we" along the west
and east. Shafts alternate axes by depth, so a layer that is both reached by
and dug from a shaft shows both without overlap: the top's pit covers the
landing floor, and each one's stairs sit on different edges.

Usage: python3 core_drill_gfx.py <output-dir>
"""
import math
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

out = sys.argv[1]
SS = 4
TILE = 64
FRAMES = 8


def canvas(tiles):
    size = tiles * TILE * SS
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def finish(img, tiles):
    return img.resize((tiles * TILE, tiles * TILE), Image.LANCZOS)


def shadow_of(img, offset=(10, 6), blur=2.0):
    size = img.size
    alpha = Image.new("L", size, 0)
    alpha.paste(img.split()[3], offset)
    alpha = alpha.filter(ImageFilter.GaussianBlur(blur))
    shadow = Image.new("LA", size, (0, 0))
    shadow.putalpha(alpha)
    return shadow


# --- core drill -------------------------------------------------------------

DRILL_CANVAS = 6  # tiles


def dpt(x, y):
    """Drill-local tiles (centre 0,0) to supersampled pixels."""
    c = DRILL_CANVAS / 2
    return (int((x + c) * TILE * SS), int((y + c) * TILE * SS))


def drill_frame(frame):
    img, d = canvas(DRILL_CANVAS)
    w = SS * 2
    # base frame
    d.rounded_rectangle([dpt(-2.4, -2.4), dpt(2.4, 2.4)], radius=TILE * SS // 6, fill=(78, 82, 88), outline=(28, 28, 30), width=w)
    d.rounded_rectangle([dpt(-2.15, -2.15), dpt(2.15, 2.15)], radius=TILE * SS // 8, fill=(96, 100, 106))
    # deck grating
    for i in range(-8, 9):
        x = i * 0.25
        d.line([dpt(x, -2.1), dpt(x, 2.1)], fill=(84, 88, 94), width=SS)
    # hazard corner pads
    for sx in (-1, 1):
        for sy in (-1, 1):
            x0, y0 = sx * 2.2, sy * 2.2
            d.rectangle([dpt(min(x0, x0 - sx * 0.7), min(y0, y0 - sy * 0.7)), dpt(max(x0, x0 - sx * 0.7), max(y0, y0 - sy * 0.7))], fill=(230, 180, 40), outline=(30, 30, 30), width=w)
            for k in range(3):
                o = 0.2 + k * 0.22
                d.line([dpt(x0 - sx * o, y0), dpt(x0, y0 - sy * o)], fill=(30, 30, 30), width=w * 2)
    # burner engine on the south edge with exhaust stack
    d.rounded_rectangle([dpt(-1.3, 1.45), dpt(1.3, 2.1)], radius=SS * 6, fill=(70, 74, 80), outline=(36, 36, 40), width=w)
    for k in range(5):
        x = -1.1 + k * 0.5
        d.line([dpt(x, 1.55), dpt(x, 2.0)], fill=(52, 54, 58), width=w)
    d.ellipse([dpt(1.55, 1.5), dpt(1.95, 1.9)], fill=(36, 36, 36), outline=(18, 18, 18), width=w)
    # rotary table
    d.ellipse([dpt(-1.35, -1.35), dpt(1.35, 1.35)], fill=(46, 46, 50), outline=(24, 24, 26), width=w)
    d.ellipse([dpt(-1.15, -1.15), dpt(1.15, 1.15)], fill=(150, 120, 60), outline=(60, 48, 26), width=w)
    spin = 2 * math.pi * frame / (FRAMES * 6)
    for i in range(6):
        a = spin + 2 * math.pi * i / 6
        d.line([dpt(0.25 * math.cos(a), 0.25 * math.sin(a)), dpt(1.05 * math.cos(a), 1.05 * math.sin(a))], fill=(82, 64, 30), width=w * 3)
        bx, by = 0.95 * math.cos(a + 0.5), 0.95 * math.sin(a + 0.5)
        d.ellipse([dpt(bx - 0.06, by - 0.06), dpt(bx + 0.06, by + 0.06)], fill=(200, 200, 205))
    # kelly (square drive) turning with the table
    corners = [(0.32 * math.cos(spin + math.pi / 4 + k * math.pi / 2), 0.32 * math.sin(spin + math.pi / 4 + k * math.pi / 2)) for k in range(4)]
    d.polygon([dpt(*c) for c in corners], fill=(200, 200, 205), outline=(40, 40, 40))
    # derrick: legs from the deck corners up to a crown block above the table
    crown = (0.0, -1.1)
    for sx in (-1, 1):
        for sy in (-1, 1):
            d.line([dpt(sx * 1.85, sy * 1.85), dpt(crown[0] + sx * 0.3, crown[1] + sy * 0.3)], fill=(190, 140, 40), width=w * 3)
    for t in (0.3, 0.6):
        pts = []
        for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            x = sx * 1.85 + (crown[0] + sx * 0.3 - sx * 1.85) * t
            y = sy * 1.85 + (crown[1] + sy * 0.3 - sy * 1.85) * t
            pts.append(dpt(x, y))
        d.line(pts + [pts[0]], fill=(170, 124, 36), width=w * 2)
    d.rectangle([dpt(crown[0] - 0.35, crown[1] - 0.35), dpt(crown[0] + 0.35, crown[1] + 0.35)], fill=(120, 90, 30), outline=(40, 30, 10), width=w)
    d.ellipse([dpt(crown[0] - 0.15, crown[1] - 0.15), dpt(crown[0] + 0.15, crown[1] + 0.15)], fill=(60, 60, 60))
    return finish(img, DRILL_CANVAS)


# --- shaft ------------------------------------------------------------------

SHAFT = 7  # tiles


def spt(x, y):
    """Shaft-local tiles (top-left corner 0,0) to supersampled pixels."""
    return (int(x * TILE * SS), int(y * TILE * SS))


def rough_rect(d, x0, y0, x1, y1, fill, jitter, rng, step=0.25):
    """Irregular rock-edged rectangle."""
    pts = []
    x = x0
    while x < x1:
        pts.append(spt(x, y0 + rng.uniform(-jitter, jitter)))
        x += step
    y = y0
    while y < y1:
        pts.append(spt(x1 + rng.uniform(-jitter, jitter), y))
        y += step
    x = x1
    while x > x0:
        pts.append(spt(x, y1 + rng.uniform(-jitter, jitter)))
        x -= step
    y = y1
    while y > y0:
        pts.append(spt(x0 + rng.uniform(-jitter, jitter), y))
        y -= step
    d.polygon(pts, fill=fill)


def strip(d, x0, y0, x1, y1, axis, high_end, low_shade, high_shade, steps=6):
    """Stair strip filling the box, running along `axis` ("x" or "y").

    high_end is "start" or "end" of the axis; shades go from high to low end.
    """
    length = (x1 - x0) if axis == "x" else (y1 - y0)
    for i in range(steps):
        t = (i + 0.5) / steps
        height = 1 - t if high_end == "start" else t
        shade = int(low_shade + (high_shade - low_shade) * height)
        color = (shade, int(shade * 0.9), int(shade * 0.78))
        if axis == "x":
            a, b = (x0 + length * i / steps, y0), (x0 + length * (i + 1) / steps, y1)
            nose = a[0] if high_end == "start" else b[0]
            d.rectangle([spt(*a), spt(*b)], fill=color)
            d.line([spt(nose, y0), spt(nose, y1)], fill=(min(255, shade + 45),) * 3, width=SS * 2)
        else:
            a, b = (x0, y0 + length * i / steps), (x1, y0 + length * (i + 1) / steps)
            nose = a[1] if high_end == "start" else b[1]
            d.rectangle([spt(*a), spt(*b)], fill=color)
            d.line([spt(x0, nose), spt(x1, nose)], fill=(min(255, shade + 45),) * 3, width=SS * 2)


def edge(d, x0, y0, x1, y1, color):
    d.rectangle([spt(x0, y0), spt(x1, y1)], fill=color)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def pit(d, rng):
    """5x5 hole seen at the game's 3/4 angle: the far (north) wall face fills
    the upper part, the side walls are thin wedges, and the darkness opens up
    at the bottom, under the near rim."""
    rough_rect(d, 1, 1, 6, 6, (92, 82, 70), 0.08, rng)
    top, floor, bottom = 1.18, 3.9, 5.86
    left, right = 1.16, 5.84
    # far wall face: lit at the rim, darkening with depth
    steps = 40
    for i in range(steps):
        t0, t1 = i / steps, (i + 1) / steps
        shade = lerp((104, 92, 78), (24, 21, 18), t0 ** 0.8)
        d.rectangle([spt(left, top + (floor - top) * t0), spt(right, top + (floor - top) * t1 + 0.01)], fill=shade)
    # strata and cracks running down the face
    for _ in range(12):
        x = rng.uniform(left + 0.3, right - 0.3)
        y0 = rng.uniform(top + 0.05, top + 0.8)
        length = rng.uniform(0.6, floor - y0)
        shade = lerp((70, 62, 53), (20, 18, 16), (y0 + length - top) / (floor - top))
        d.line([spt(x, y0), spt(x + rng.uniform(-0.12, 0.12), y0 + length)], fill=shade, width=SS)
    for _ in range(6):
        y = rng.uniform(top + 0.3, floor - 0.6)
        d.line(jagged_line(left + 0.4, right - 0.4, y, rng), fill=lerp((60, 53, 45), (22, 20, 17), (y - top) / (floor - top)), width=SS * 2)
    # darkness below the face, fading in over its last stretch
    d.rectangle([spt(left, floor), spt(right, bottom)], fill=(6, 5, 5))
    for i in range(12):
        t = i / 12
        y = floor - 0.45 + 0.45 * t
        d.rectangle([spt(left, y), spt(right, y + 0.05)], fill=lerp((24, 21, 18), (6, 5, 5), t))
    # side walls: thin wedges seen edge-on, tapering with depth
    for x_rim, x_in in ((left, left + 0.42), (right, right - 0.42)):
        d.polygon([spt(x_rim, top), spt(x_in, top + 0.25), spt(x_rim + (x_in - x_rim) * 0.35, floor + 0.4), spt(x_rim, bottom)], fill=(46, 41, 35))
        d.line([spt(x_rim, top), spt(x_in, top + 0.25), spt(x_rim + (x_in - x_rim) * 0.35, floor + 0.4)], fill=(78, 70, 60), width=SS * 2)
    # near rim: only its top edge shows, catching the light
    d.line(jagged_line(left, right, bottom, rng), fill=(140, 126, 108), width=SS * 3)
    d.line(jagged_line(left, right, top, rng), fill=(118, 106, 90), width=SS * 2)


def jagged_line(x0, x1, y, rng, step=0.25):
    pts = []
    x = x0
    while x < x1:
        pts.append(spt(x, y + rng.uniform(-0.04, 0.04)))
        x += step
    pts.append(spt(x1, y))
    return pts


def top_stairs(d, axis, low_shade, high_shade):
    """The two stairways of a shaft, high to low as in shared/shaft.lua."""
    if axis == "ns":
        strip(d, 1, 0.1, 6, 1, "x", "start", low_shade, high_shade)   # north: down eastward
        strip(d, 1, 6, 6, 6.9, "x", "end", low_shade, high_shade)     # south: down westward
    else:
        strip(d, 6, 1, 6.9, 6, "y", "start", low_shade, high_shade)   # east: down southward
        strip(d, 0.1, 1, 1, 6, "y", "end", low_shade, high_shade)     # west: down northward


# Centre line of each stairway from its high end to its low end.
STAIR_LINES = {
    "ns": [((1.3, 0.55), (5.7, 0.55)), ((5.7, 6.45), (1.3, 6.45))],
    "we": [((6.45, 1.3), (6.45, 5.7)), ((0.55, 5.7), (0.55, 1.3))],
}


def stair_arrows(d, axis, down):
    """Two chevrons per stairway, pointing down it (top) or up it (bottom)."""
    for high, low in STAIR_LINES[axis]:
        start, end = (high, low) if down else (low, high)
        length = math.dist(start, end)
        u = ((end[0] - start[0]) / length, (end[1] - start[1]) / length)
        n = (-u[1], u[0])
        for t in (0.35, 0.65):
            p = (start[0] + (end[0] - start[0]) * t, start[1] + (end[1] - start[1]) * t)
            tip = (p[0] + u[0] * 0.17, p[1] + u[1] * 0.17)
            wings = [(p[0] - u[0] * 0.13 + n[0] * k * 0.24, p[1] - u[1] * 0.13 + n[1] * k * 0.24) for k in (-1, 1)]
            points = [spt(*wings[0]), spt(*tip), spt(*wings[1])]
            d.line(points, fill=(30, 26, 20), width=SS * 7, joint="curve")
            d.line(points, fill=(236, 194, 70), width=SS * 4, joint="curve")


def stair_walls(d, axis, outer, inner):
    if axis == "ns":
        edge(d, 1, 0, 6, 0.12, outer)
        edge(d, 1, 6.88, 6, 7, outer)
        if inner:
            edge(d, 1, 0.92, 6, 1.04, inner)
            edge(d, 1, 5.96, 6, 6.08, inner)
    else:
        edge(d, 6.88, 1, 7, 6, outer)
        edge(d, 0, 1, 0.12, 6, outer)
        if inner:
            edge(d, 5.96, 1, 6.08, 6, inner)
            edge(d, 0.92, 1, 1.04, 6, inner)


# Stairs follow shared/shaft.lua: "ns" along the north and south rims, "we"
# along the east and west ones. The pit and landing are drawn the same for
# both, since the view angle doesn't turn with the stairs.
def shaft_top(axis):
    rng = random.Random(7)
    img, d = canvas(SHAFT)
    pit(d, rng)
    top_stairs(d, axis, 45, 150)
    stair_walls(d, axis, (52, 46, 40), (20, 18, 16))
    stair_arrows(d, axis, down=True)
    return finish(img, SHAFT)


def shaft_bottom(axis):
    rng = random.Random(11)
    img, d = canvas(SHAFT)
    rough_rect(d, 0.9, 1, 6.1, 6, (104, 92, 78), 0.06, rng)
    rough_rect(d, 1.15, 1.15, 5.85, 5.85, (122, 108, 92), 0.05, rng)
    # light falling down the shaft
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([spt(1.8, 1.8), spt(5.2, 5.2)], fill=(200, 185, 150, 70))
    glow = glow.filter(ImageFilter.GaussianBlur(TILE * SS * 0.4))
    img.alpha_composite(glow)
    d = ImageDraw.Draw(img)
    for _ in range(70):
        x, y = rng.uniform(1.3, 5.7), rng.uniform(1.3, 5.7)
        r = rng.uniform(0.03, 0.09)
        g = rng.randint(70, 110)
        d.ellipse([spt(x - r, y - r), spt(x + r, y + r)], fill=(g, int(g * 0.9), int(g * 0.8)))
    # the same stairs arriving from above: they rise along the shaft wall,
    # brightening toward the light
    top_stairs(d, axis, 110, 205)
    stair_walls(d, axis, (40, 36, 32), None)
    stair_arrows(d, axis, down=False)
    return finish(img, SHAFT)


frames = [drill_frame(f) for f in range(FRAMES)]
size = DRILL_CANVAS * TILE
sheet = Image.new("RGBA", (size * FRAMES, size), (0, 0, 0, 0))
for i, f in enumerate(frames):
    sheet.paste(f, (size * i, 0))
sheet.save(f"{out}/core-drill.png", optimize=True)
shadow_of(frames[0]).save(f"{out}/core-drill-shadow.png", optimize=True)
frames[0].crop((16, 16, size - 16, size - 16)).resize((64, 64), Image.LANCZOS).save(f"{out}/core-drill-icon.png", optimize=True)
for axis in ("ns", "we"):
    shaft_top(axis).save(f"{out}/shaft-top-{axis}.png", optimize=True)
    shaft_bottom(axis).save(f"{out}/shaft-bottom-{axis}.png", optimize=True)
