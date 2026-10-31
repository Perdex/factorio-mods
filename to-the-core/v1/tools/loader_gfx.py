"""Render the structure of the mod's 1x1 loader (the bores' and the core
drill's): a low box over the half of the tile against the machine, a few
pixels past the middle so it meets the belt, with an arrow on top the way
items flow; the belt end shows in the other half.

Output: loader-structure.png, 4 frames (north, east, south, west) of
128x128 px (two tiles at scale 0.5, the tile in the middle, like the base
belts' frames) in two rows, input then output loaders. The box reaches down
as far as the belt beside it: a belt running east-west hangs its front edge
13 px below its tile, one running north-south 2 px. The game
picks an output loader's frame by the opposite of the way it faces, so in
both rows the machine is on the frame's own side: input arrows point at it,
output arrows away. Drawn in screen space, so the box's front face is always
at its bottom edge.

Usage: python3 loader_gfx.py <output-dir>
"""
import sys

from PIL import Image, ImageDraw

out = sys.argv[1]
SS = 4
T = 64 * SS          # one tile
F = 2 * T            # a frame: the tile in the middle of a 2x2-tile canvas
O = T // 2           # the tile's top-left corner within the frame
PAST = 3 * SS        # how far the box reaches past the middle, over the belt
FACE = 6 * SS        # height of the box's front face where it meets the belt
MARGIN = 4 * SS      # inset from the tile's sides
# How far below its tile a belt's lowest pixels hang, by the belt's axis.
BELT_DROP = {"ew": 13 * SS, "ns": 2 * SS}

# Frame directions as unit vectors on screen: north, east, south, west.
VECTORS = [(0, -1), (1, 0), (0, 1), (-1, 0)]


def frame(direction, toward_machine):
    """The box on the side of `direction`; the arrow towards that side, or
    away from it."""
    img = Image.new("RGBA", (F, F), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    dx, dy = VECTORS[direction]
    half = T // 2
    # In tile coordinates: the box's sides x0..x1, the top of its top face,
    # and the ground line its front face reaches down to, as low as the belt
    # beside it.
    if dx == 0:
        # North-south belt: the box covers the machine's half.
        x0, x1 = MARGIN, T - MARGIN
        if dy < 0:
            top, ground, face = -FACE, half + PAST, FACE
        else:
            top, ground, face = half - PAST - FACE, T + BELT_DROP["ns"], FACE
    else:
        # East-west belt: the box runs the belt's width, its front face as
        # tall as the belt's.
        x0, x1 = (0, half + PAST) if dx < 0 else (half - PAST, T)
        top, ground, face = 0, T + BELT_DROP["ew"], BELT_DROP["ew"]
    x0, x1, top, ground = x0 + O, x1 + O, top + O, ground + O
    top_bottom = ground - face
    w = 2 * SS
    # One box: the outline round it all, the top (rounded only at the back)
    # and the darker front face down to the ground.
    d.rounded_rectangle([x0, top, x1, ground], radius=4 * SS, fill=(36, 36, 40), corners=(True, True, False, False))
    d.rounded_rectangle([x0 + w, top + w, x1 - w, top_bottom], radius=3 * SS, fill=(150, 152, 156),
                        corners=(True, True, False, False))
    d.rectangle([x0 + w, top_bottom + w // 2, x1 - w, ground - w], fill=(96, 98, 102))
    for x in (x0 + 7 * SS, x1 - 7 * SS):
        for y in (top + 7 * SS, top_bottom - 7 * SS):
            if top + 4 * SS < y < top_bottom - 4 * SS:
                d.ellipse([x - 2 * SS, y - 2 * SS, x + 2 * SS, y + 2 * SS], fill=(60, 60, 64))
    # Arrow on top, pointing along (ax, ay).
    ax, ay = (dx, dy) if toward_machine else (-dx, -dy)
    cx, cy = (x0 + x1) / 2, (top + top_bottom) / 2
    s = 8 * SS
    px, py = -ay, ax  # perpendicular
    tip = (cx + ax * s, cy + ay * s)
    back = (cx - ax * s * 0.6, cy - ay * s * 0.6)
    notch = (cx - ax * s * 0.1, cy - ay * s * 0.1)
    d.polygon([tip, (back[0] + px * s, back[1] + py * s), notch, (back[0] - px * s, back[1] - py * s)],
              fill=(240, 200, 60), outline=(40, 34, 10))
    return img


sheet = Image.new("RGBA", (4 * F, 2 * F), (0, 0, 0, 0))
for row, toward_machine in enumerate((True, False)):
    for direction in range(4):
        sheet.paste(frame(direction, toward_machine), (direction * F, row * F))
sheet.resize((4 * 128, 2 * 128), Image.LANCZOS).save(f"{out}/loader-structure.png", optimize=True)
