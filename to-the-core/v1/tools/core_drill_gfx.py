"""Render the core drill (5x5) and the shaft it leaves behind (7x7).

Outputs into the given directory (64 px per tile, drawn at scale 0.5):
  core-drill.png          8-frame row of 384x512 frames (6x8 tiles; the 5x5
                          footprint centre is 1 tile below the frame centre)
  core-drill-shadow.png   576x512, slanted east from the same ground line
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

# Frames are 6 tiles wide and 8 tall: the 5x5 footprint sits low in the frame
# (centre 1 tile below the frame's centre) so the rig can rise above it.
DRILL_W, DRILL_H = 6, 8
GROUND_CX, GROUND_CY = 3, 5      # footprint centre in frame tiles
HEIGHT = 0.85                    # screen tiles per tile of height (3/4 view)


def P(x, y, z=0):
    """Ground position (tiles from the drill centre) and height to pixels."""
    return (int((x + GROUND_CX) * TILE * SS), int((y + GROUND_CY - z * HEIGHT) * TILE * SS))


def beam(d, a, b, width, fill, edge):
    d.line([P(*a), P(*b)], fill=edge, width=int(width * TILE * SS) + SS * 4)
    d.line([P(*a), P(*b)], fill=fill, width=int(width * TILE * SS))


def leg(d, corner):
    sx, sy = corner
    foot, top = (sx * 2.25, sy * 2.25, 0), (sx * 1.45, sy * 1.45, 3.1)
    beam(d, foot, top, 0.2, (84, 82, 80), (34, 32, 30))
    d.ellipse([P(sx * 2.25 - 0.3, sy * 2.25 - 0.18), P(sx * 2.25 + 0.3, sy * 2.25 + 0.18)], fill=(70, 56, 44))


def top_beam(d, a, b):
    beam(d, (a[0], a[1], 3.1), (b[0], b[1], 3.1), 0.16, (96, 94, 92), (34, 32, 30))


def auger(d, frame):
    """The huge drill head: a spiral cone boring into the ground."""
    top_z, bottom_z = 2.7, -0.3
    steps = 80

    def radius(t):
        return 1.95 * (1 - t) ** 0.8 + 0.12

    # core of the cone, back to front so the light falls from the left
    for i in range(steps):
        t = i / steps
        z = top_z - (top_z - bottom_z) * t
        r = radius(t) * 0.85
        shade = int(120 - 50 * t)
        d.ellipse([P(-r, -r * 0.3, z), P(r, r * 0.3, z)], fill=(shade, int(shade * 0.82), int(shade * 0.6)))
    # spiral flights turning with the frame: continuous lines on the front
    turns = 3.5
    for k in range(2):
        points = []
        for i in range(steps * 4 + 1):
            t = i / (steps * 4)
            z = top_z - (top_z - bottom_z) * t
            angle = 2 * math.pi * (t * turns + k / 2 + frame / (FRAMES * 2))
            front = math.sin(angle)
            r = radius(t)
            if front > -0.15:
                points.append((P(r * math.cos(angle), r * 0.3 * front, z), front))
            elif points:
                draw_flight(d, points)
                points = []
        if points:
            draw_flight(d, points)
    # cutting tip
    d.polygon([P(-0.25, 0, 0.0), P(0.25, 0, 0.0), P(0, 0.15, -0.45)], fill=(205, 205, 210), outline=(80, 80, 84))


def draw_flight(d, points):
    for (a, fa), (b, fb) in zip(points, points[1:]):
        light = 0.5 + 0.5 * max(fa, 0)
        g = int(215 * light)
        d.line([a, b], fill=(int(g * 0.5), int(g * 0.42), int(g * 0.3)), width=SS * 16)
        d.line([a, b], fill=(g, int(g * 0.86), int(g * 0.62)), width=SS * 10)


def gearbox(d, frame):
    # housing on the back beam, driving the auger through a shaft
    d.rectangle([P(-0.12, 0, 3.6), P(0.12, 0, 2.6)], fill=(150, 150, 156), outline=(60, 60, 64))
    d.rounded_rectangle([P(-0.95, -1.45, 4.15), P(0.95, -1.45, 3.1)], radius=SS * 6, fill=(108, 110, 116), outline=(40, 40, 44), width=SS * 2)
    beam(d, (0, -1.45, 3.75), (0, 0, 3.75), 0.2, (96, 98, 104), (40, 40, 44))
    for cx, cz, r, teeth, sign in ((-0.55, 3.62, 0.42, 10, 1), (0.2, 3.5, 0.3, 8, -1), (0.68, 3.78, 0.24, 7, 1)):
        center = P(cx, -1.3, cz)
        rr = r * TILE * SS
        pts = []
        for i in range(teeth * 2):
            ang = math.pi * i / teeth + sign * frame * 2 * math.pi / (FRAMES * teeth)
            rad = rr if i % 2 == 0 else rr * 0.8
            pts.append((center[0] + rad * math.cos(ang), center[1] + rad * math.sin(ang) * 0.9))
        d.polygon(pts, fill=(176, 136, 62), outline=(80, 60, 26))
        d.ellipse([center[0] - rr * 0.3, center[1] - rr * 0.3, center[0] + rr * 0.3, center[1] + rr * 0.3], fill=(90, 70, 30))


def firebox(d):
    # rusty hopper and firebox on the left, like the burner mining drill's
    d.polygon([P(-2.4, -0.7, 2.2), P(-1.3, -0.7, 2.2), P(-1.4, 0.5, 1.3), P(-2.3, 0.5, 1.3)], fill=(150, 84, 46), outline=(70, 38, 20))
    d.polygon([P(-2.3, 0.5, 1.3), P(-1.4, 0.5, 1.3), P(-1.4, 0.5, 0.4), P(-2.3, 0.5, 0.4)], fill=(122, 66, 36), outline=(70, 38, 20))
    d.rectangle([P(-2.1, 0.5, 1.05), P(-1.6, 0.5, 0.7)], fill=(40, 20, 12))
    d.rectangle([P(-2.03, 0.5, 0.98), P(-1.67, 0.5, 0.76)], fill=(240, 130, 40))
    d.rectangle([P(-2.15, -0.6, 3.4), P(-1.9, -0.6, 2.2)], fill=(70, 66, 62), outline=(30, 28, 26))


def drill_frame(frame):
    img = Image.new("RGBA", (DRILL_W * TILE * SS, DRILL_H * TILE * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # churned earth around the bore hole
    d.ellipse([P(-2.4, -1.8), P(2.4, 2.2)], fill=(76, 62, 48, 255))
    d.ellipse([P(-1.5, -0.9), P(1.5, 1.2)], fill=(44, 34, 26, 255))
    for corner in ((-1, -1), (1, -1)):
        leg(d, corner)
    top_beam(d, (-1.45, -1.45), (1.45, -1.45))
    gearbox(d, frame)
    auger(d, frame)
    firebox(d)
    top_beam(d, (-1.45, -1.45), (-1.45, 1.45))
    top_beam(d, (1.45, -1.45), (1.45, 1.45))
    for corner in ((-1, 1), (1, 1)):
        leg(d, corner)
    top_beam(d, (-1.45, 1.45), (1.45, 1.45))
    return img.resize((DRILL_W * TILE, DRILL_H * TILE), Image.LANCZOS)


def drill_shadow(img):
    """The rig's silhouette slanted to the east along the ground."""
    w, h = img.size
    ground = GROUND_CY * TILE + 2.5 * TILE
    k = 0.45
    alpha = img.split()[3].transform((w + 3 * TILE, h), Image.AFFINE, (1, k, -k * ground, 0, 1, 0), Image.BILINEAR)
    alpha = alpha.filter(ImageFilter.GaussianBlur(2))
    shadow = Image.new("LA", alpha.size, (0, 0))
    shadow.putalpha(alpha.point(lambda a: a * 0.6))
    return shadow


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


# Each stairway's box (canvas tiles) and which end of it is high; as in
# shared/shaft.lua: "ns" north (down eastward) and south (down westward), "we"
# east (down southward) and west (down northward).
STAIRWAYS = {
    "ns": [((1, 0.1, 6, 1), "x", "start"), ((1, 6, 6, 6.9), "x", "end")],
    "we": [((6, 1, 6.9, 6), "y", "start"), ((0.1, 1, 1, 6), "y", "end")],
}
STEPS = 6
DROP = 0.5   # screen tiles the low end of a pit's stairs sinks
RISE = 0.5   # screen tiles the high end of a landing's stairs stands up


def step_level(i, high_end):
    """How far down step i is, 0 at the high end to 1 at the low end."""
    t = (i + 0.5) / STEPS
    return t if high_end == "start" else 1 - t


def stairs(d, axis, descending):
    """Stairways in the 3/4 view. Into a pit (descending) each step sinks
    lower, with the cut rock wall showing above it; on a landing each step
    stands higher toward the high end on a face of rock below it."""
    for (x0, y0, x1, y1), along, high_end in STAIRWAYS[axis]:
        length = (x1 - x0) if along == "x" else (y1 - y0)
        for i in range(STEPS):
            level = step_level(i, high_end)
            if along == "x":
                xa, xb = x0 + length * i / STEPS, x0 + length * (i + 1) / STEPS
                ya, yb = y0, y1
            else:
                xa, xb = x0, x1
                ya, yb = y0 + length * i / STEPS, y0 + length * (i + 1) / STEPS
            if descending:
                dy = level * DROP
                shade = int(150 - 105 * level)
                # the cut: rock wall above the sunken step
                d.rectangle([spt(xa, ya), spt(xb, ya + dy)], fill=(58, 50, 42))
                tread = (xa, ya + dy, xb, yb + dy * 0.6)
            else:
                dy = (1 - level) * RISE
                shade = int(205 - 95 * level)
                # the face under the raised step
                d.rectangle([spt(xa, yb - dy), spt(xb, yb)], fill=(int(shade * 0.45), int(shade * 0.4), int(shade * 0.34)))
                tread = (xa, ya - dy * 0.4, xb, yb - dy)
            color = (shade, int(shade * 0.9), int(shade * 0.78))
            d.rectangle([spt(tread[0], tread[1]), spt(tread[2], tread[3])], fill=color)
            # nosing: the light edge of each tread
            if along == "x":
                nose = tread[0] if high_end == "end" else tread[2]
                d.line([spt(nose, tread[1]), spt(nose, tread[3])], fill=(min(255, shade + 45),) * 3, width=SS * 2)
            else:
                d.line([spt(tread[0], tread[3]), spt(tread[2], tread[3])], fill=(min(255, shade + 45),) * 3, width=SS * 2)


def stair_offset(from_high, descending):
    """Screen drop of a stairway's centre at fraction `from_high` along it."""
    return from_high * DROP * 0.8 if descending else -(1 - from_high) * RISE * 0.7


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
            p = (p[0], p[1] + stair_offset(t if down else 1 - t, down))
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
    stairs(d, axis, descending=True)
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
    stairs(d, axis, descending=False)
    stair_walls(d, axis, (40, 36, 32), None)
    stair_arrows(d, axis, down=False)
    return finish(img, SHAFT)


frames = [drill_frame(f) for f in range(FRAMES)]
fw, fh = DRILL_W * TILE, DRILL_H * TILE
sheet = Image.new("RGBA", (fw * FRAMES, fh), (0, 0, 0, 0))
for i, f in enumerate(frames):
    sheet.paste(f, (fw * i, 0))
sheet.save(f"{out}/core-drill.png", optimize=True)
drill_shadow(frames[0]).save(f"{out}/core-drill-shadow.png", optimize=True)
icon_box = (0, int(0.6 * TILE), fw, int(0.6 * TILE) + fw)
frames[0].crop(icon_box).resize((64, 64), Image.LANCZOS).save(f"{out}/core-drill-icon.png", optimize=True)
for axis in ("ns", "we"):
    shaft_top(axis).save(f"{out}/shaft-top-{axis}.png", optimize=True)
    shaft_bottom(axis).save(f"{out}/shaft-bottom-{axis}.png", optimize=True)
