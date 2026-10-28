"""Render the tunnel bores: Mk1 (wood and clay bricks), Mk2 (steel, with belt
ports) and Mk3 (cooled, with a water inlet). 2x2 body, 4 directions, 8-frame cutter animation.

Drawn facing north at 4x supersampling, then rotated for the other directions.
Each frame is 256x256 px (64 px per tile, drawn at scale 0.5), i.e. 4x4 tiles
centred on the entity, so the cutter head can reach past the 2x2 body into the
wall in front. Output: <tier>-bore-<dir>.png (8 frames in a row),
<tier>-bore-<dir>-shadow.png and <tier>-bore-icon.png into the given directory.

Usage: python3 bore_gfx.py <output-dir>
"""
import math
import sys

from PIL import Image, ImageDraw, ImageFilter

out = sys.argv[1]
SS = 4
FRAME = 256
S = FRAME * SS
# Body-local coordinates: (0, 0)..(128, 128) is the 2x2 footprint.
ORIGIN = (FRAME - 128) / 2
FRAMES = 8


def px(v):
    return int(round((v + ORIGIN) * SS))


def pt(x, y):
    return (px(x), px(y))


def hull_layer(img, draw):
    # tracks
    for x0 in (4, 108):
        draw.rounded_rectangle([px(x0), px(12), px(x0 + 16), px(124)], radius=4 * SS, fill=(38, 38, 40))
        for y in range(14, 122, 7):
            draw.rectangle([px(x0 + 1), px(y), px(x0 + 15), px(y + 3)], fill=(70, 70, 72))
    # body
    draw.rounded_rectangle([px(16), px(16), px(112), px(122)], radius=8 * SS, fill=(86, 90, 96), outline=(30, 30, 32), width=2 * SS)
    draw.rounded_rectangle([px(22), px(30), px(106), px(116)], radius=6 * SS, fill=(110, 114, 120))
    # hazard band at the front, under the cutter mount
    band = Image.new("RGBA", (96 * SS, 12 * SS), (230, 180, 40, 255))
    band_draw = ImageDraw.Draw(band)
    for i in range(-2, 12):
        x = i * 9
        band_draw.polygon([(x * SS, 12 * SS), ((x + 5) * SS, 12 * SS), ((x + 17) * SS, 0), ((x + 12) * SS, 0)], fill=(30, 30, 30))
    img.paste(band, pt(16, 16))
    draw.rectangle([px(16), px(16), px(112), px(28)], outline=(30, 30, 32), width=2 * SS)
    # cutter arm
    draw.rectangle([px(54), px(4), px(74), px(30)], fill=(64, 66, 70), outline=(30, 30, 32), width=2 * SS)
    # engine block / exhaust
    draw.rounded_rectangle([px(42), px(48), px(86), px(88)], radius=4 * SS, fill=(70, 74, 80), outline=(40, 40, 44), width=2 * SS)
    for y in (56, 64, 72, 80):
        draw.line([px(48), px(y), px(80), px(y)], fill=(50, 52, 56), width=2 * SS)
    draw.ellipse([px(90), px(42), px(100), px(52)], fill=(40, 40, 40), outline=(20, 20, 20), width=SS)
    # rear ports for the belt lanes: input (blue, left) and output (green, right)
    draw.rounded_rectangle([px(24), px(100), px(56), px(118)], radius=3 * SS, fill=(60, 130, 190), outline=(25, 45, 70), width=2 * SS)
    draw.rounded_rectangle([px(72), px(100), px(104), px(118)], radius=3 * SS, fill=(70, 160, 90), outline=(25, 60, 35), width=2 * SS)
    draw.polygon([pt(40, 103), pt(33, 115), pt(47, 115)], fill=(210, 230, 250))
    draw.polygon([pt(88, 115), pt(81, 103), pt(95, 103)], fill=(215, 245, 220))


def cooled_hull_layer(img, draw):
    """Mk3: 3 tiles wide (192 px body), coolant tank, water inlet in the
    middle of its back between the belt ports."""
    # tracks
    for x0 in (4, 172):
        draw.rounded_rectangle([px(x0), px(12), px(x0 + 16), px(124)], radius=4 * SS, fill=(38, 38, 40))
        for y in range(14, 122, 7):
            draw.rectangle([px(x0 + 1), px(y), px(x0 + 15), px(y + 3)], fill=(70, 70, 72))
    # body
    draw.rounded_rectangle([px(16), px(16), px(176), px(122)], radius=8 * SS, fill=(70, 82, 100), outline=(30, 30, 32), width=2 * SS)
    draw.rounded_rectangle([px(22), px(30), px(170), px(98)], radius=6 * SS, fill=(84, 98, 120))
    band = Image.new("RGBA", (160 * SS, 12 * SS), (230, 180, 40, 255))
    band_draw = ImageDraw.Draw(band)
    for i in range(-2, 20):
        x = i * 9
        band_draw.polygon([(x * SS, 12 * SS), ((x + 5) * SS, 12 * SS), ((x + 17) * SS, 0), ((x + 12) * SS, 0)], fill=(30, 30, 30))
    img.paste(band, pt(16, 16))
    draw.rectangle([px(16), px(16), px(176), px(28)], outline=(30, 30, 32), width=2 * SS)
    # two cutter arms
    for cx in (52, 140):
        draw.rectangle([px(cx - 10), px(4), px(cx + 10), px(30)], fill=(64, 66, 70), outline=(30, 30, 32), width=2 * SS)
    # coolant tank across the middle
    draw.rounded_rectangle([px(40), px(40), px(152), px(88)], radius=12 * SS, fill=(70, 150, 190), outline=(24, 50, 70), width=2 * SS)
    draw.rounded_rectangle([px(48), px(46), px(70), px(82)], radius=5 * SS, fill=(150, 210, 235))
    for y in (52, 64, 76):
        draw.line([px(42), px(y), px(150), px(y)], fill=(40, 90, 120), width=SS)
    # rear: supply port (left), water inlet (middle), output port (right)
    draw.rounded_rectangle([px(24), px(100), px(60), px(118)], radius=3 * SS, fill=(60, 130, 190), outline=(25, 45, 70), width=2 * SS)
    draw.rounded_rectangle([px(132), px(100), px(168), px(118)], radius=3 * SS, fill=(70, 160, 90), outline=(25, 60, 35), width=2 * SS)
    draw.polygon([pt(42, 103), pt(35, 115), pt(49, 115)], fill=(210, 230, 250))
    draw.polygon([pt(150, 115), pt(143, 103), pt(157, 103)], fill=(215, 245, 220))
    draw.rectangle([px(84), px(96), px(108), px(128)], fill=(110, 114, 120), outline=(40, 42, 46), width=2 * SS)
    draw.rectangle([px(80), px(122), px(112), px(128)], fill=(80, 84, 90))
    draw.ellipse([px(90), px(102), px(102), px(114)], fill=(80, 150, 190))


def wooden_hull_layer(img, draw):
    """Mk1: a timber sledge with a clay-brick firebox, no belt ports."""
    # runners
    for x0 in (6, 108):
        draw.rounded_rectangle([px(x0), px(14), px(x0 + 14), px(124)], radius=5 * SS, fill=(92, 62, 34), outline=(52, 34, 18), width=2 * SS)
    # plank deck
    draw.rounded_rectangle([px(16), px(18), px(112), px(122)], radius=4 * SS, fill=(150, 104, 58), outline=(70, 46, 24), width=2 * SS)
    for x in range(20, 112, 12):
        draw.line([px(x), px(20), px(x), px(120)], fill=(118, 80, 42), width=2 * SS)
    for y in (30, 74, 112):
        for x in range(22, 110, 12):
            draw.ellipse([px(x + 2), px(y - 1), px(x + 4), px(y + 1)], fill=(60, 44, 30))
    # cutter frame
    draw.rectangle([px(54), px(4), px(74), px(30)], fill=(120, 84, 46), outline=(60, 40, 20), width=2 * SS)
    draw.rectangle([px(18), px(18), px(110), px(28)], fill=(128, 88, 48), outline=(60, 40, 20), width=2 * SS)
    # clay-brick firebox with a chimney
    draw.rectangle([px(36), px(50), px(92), px(100)], fill=(168, 84, 56), outline=(80, 38, 24), width=2 * SS)
    for row, y in enumerate(range(50, 100, 8)):
        draw.line([px(36), px(y), px(92), px(y)], fill=(122, 60, 40), width=SS)
        offset = 0 if row % 2 == 0 else 7
        for x in range(36 + offset, 92, 14):
            draw.line([px(x), px(y), px(x), px(min(y + 8, 100))], fill=(122, 60, 40), width=SS)
    draw.rectangle([px(54), px(86), px(74), px(98)], fill=(40, 20, 12))
    draw.rectangle([px(56), px(88), px(72), px(96)], fill=(230, 120, 40))
    draw.ellipse([px(88), px(36), px(102), px(50)], fill=(150, 76, 52), outline=(70, 34, 22), width=2 * SS)
    draw.ellipse([px(91), px(39), px(99), px(47)], fill=(30, 26, 24))


def cutter_layer(draw, frame, cx=64):
    # Centre sits at the front edge of the body; the head reaches ~0.6 tiles past it.
    cy, r = -10, 30
    draw.ellipse([px(cx - r - 3), px(cy - r - 3), px(cx + r + 3), px(cy + r + 3)], fill=(40, 40, 42))
    teeth = 14
    for i in range(teeth):
        a = 2 * math.pi * (i / teeth + frame / (FRAMES * teeth))
        tip = (cx + (r + 4) * math.cos(a), cy + (r + 4) * math.sin(a))
        b1 = (cx + (r - 6) * math.cos(a - 0.16), cy + (r - 6) * math.sin(a - 0.16))
        b2 = (cx + (r - 6) * math.cos(a + 0.16), cy + (r - 6) * math.sin(a + 0.16))
        draw.polygon([pt(*tip), pt(*b1), pt(*b2)], fill=(200, 200, 205))
    draw.ellipse([px(cx - r + 4), px(cy - r + 4), px(cx + r - 4), px(cy + r - 4)], fill=(150, 120, 60), outline=(60, 50, 30), width=2 * SS)
    for i in range(5):
        a = 2 * math.pi * (i / 5 + frame / (FRAMES * 5))
        draw.line([pt(cx, cy), pt(cx + (r - 6) * math.cos(a), cy + (r - 6) * math.sin(a))], fill=(80, 64, 32), width=4 * SS)
    draw.ellipse([px(cx - 7), px(cy - 7), px(cx + 7), px(cy + 7)], fill=(230, 180, 40), outline=(40, 40, 40), width=2 * SS)


def frame_image(frame, hull, width=2):
    """A frame (width + 2) tiles across and 4 along; wide bores get one cutter
    per outer tile."""
    across = (width + 2) * 64
    img = Image.new("RGBA", (across * SS, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    hull(img, draw)
    for cx in ((64,) if width == 2 else (52, 140)):
        cutter_layer(draw, frame, cx)
    return img.resize((across, FRAME), Image.LANCZOS)


def shadow_image(img):
    canvas = Image.new("L", img.size, 0)
    canvas.paste(img.split()[3], (6, 4))
    canvas = canvas.filter(ImageFilter.GaussianBlur(1.5))
    shadow = Image.new("LA", img.size, (0, 0))
    shadow.putalpha(canvas)
    return shadow


for tier, hull, width in (("mk1", wooden_hull_layer, 2), ("mk2", hull_layer, 2), ("mk3", cooled_hull_layer, 3)):
    frames = [frame_image(f, hull, width) for f in range(FRAMES)]
    for name, angle in (("north", 0), ("east", -90), ("south", 180), ("west", 90)):
        turned = [f.rotate(angle, expand=True) for f in frames]
        w, h = turned[0].size
        sheet = Image.new("RGBA", (w * FRAMES, h), (0, 0, 0, 0))
        for i, f in enumerate(turned):
            sheet.paste(f, (w * i, 0))
        sheet.save(f"{out}/{tier}-bore-{name}.png", optimize=True)
        shadow_image(turned[0]).save(f"{out}/{tier}-bore-{name}-shadow.png", optimize=True)

    # 64x64 icon facing east: crop to the body plus cutter.
    east = frames[0].rotate(-90, expand=True)
    w, h = east.size
    side = min(w, h) - 64
    icon = east.crop(((w - side) // 2, (h - side) // 2, (w + side) // 2, (h + side) // 2)).resize((64, 64), Image.LANCZOS)
    icon.save(f"{out}/{tier}-bore-icon.png", optimize=True)
