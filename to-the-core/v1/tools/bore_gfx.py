"""Render the Mk1 tunnel bore: 2x2 body, 4 directions, 8-frame cutter animation.

Drawn facing north at 4x supersampling, then rotated for the other directions.
Each frame is 256x256 px (64 px per tile, drawn at scale 0.5), i.e. 4x4 tiles
centred on the entity, so the cutter head can reach past the 2x2 body into the
wall in front. Output: mk1-bore-<dir>.png (8 frames in a row),
mk1-bore-<dir>-shadow.png and mk1-bore-icon.png into the given directory.

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
    # rear ports: input (blue, left) and output (green, right)
    draw.rounded_rectangle([px(24), px(100), px(56), px(118)], radius=3 * SS, fill=(60, 130, 190), outline=(25, 45, 70), width=2 * SS)
    draw.rounded_rectangle([px(72), px(100), px(104), px(118)], radius=3 * SS, fill=(70, 160, 90), outline=(25, 60, 35), width=2 * SS)
    draw.polygon([pt(40, 103), pt(33, 115), pt(47, 115)], fill=(210, 230, 250))
    draw.polygon([pt(88, 115), pt(81, 103), pt(95, 103)], fill=(215, 245, 220))


def cutter_layer(draw, frame):
    # Centre sits at the front edge of the body; the head reaches ~0.6 tiles past it.
    cx, cy, r = 64, -10, 30
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


def frame_image(frame):
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    hull_layer(img, draw)
    cutter_layer(draw, frame)
    return img.resize((FRAME, FRAME), Image.LANCZOS)


def shadow_image(img):
    canvas = Image.new("L", (FRAME, FRAME), 0)
    canvas.paste(img.split()[3], (6, 4))
    canvas = canvas.filter(ImageFilter.GaussianBlur(1.5))
    shadow = Image.new("LA", (FRAME, FRAME), (0, 0))
    shadow.putalpha(canvas)
    return shadow


frames = [frame_image(f) for f in range(FRAMES)]
for name, angle in (("north", 0), ("east", -90), ("south", 180), ("west", 90)):
    sheet = Image.new("RGBA", (FRAME * FRAMES, FRAME), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f.rotate(angle), (FRAME * i, 0))
    sheet.save(f"{out}/mk1-bore-{name}.png", optimize=True)
    shadow_image(frames[0].rotate(angle)).save(f"{out}/mk1-bore-{name}-shadow.png", optimize=True)

# 64x64 icon facing east: crop to the body plus cutter.
icon = frames[0].rotate(-90).crop((32, 32, 224, 224)).resize((64, 64), Image.LANCZOS)
icon.save(f"{out}/mk1-bore-icon.png", optimize=True)
