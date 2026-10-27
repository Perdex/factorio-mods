"""Render item icons: drill heads (wooden, unfired and fired clay), blade,
sand, clay and glass (64x64).

Usage: python3 item_gfx.py <output-dir>
"""
import math
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

out = sys.argv[1]
SS = 4
S = 64 * SS


def save(img, name):
    img.resize((64, 64), Image.LANCZOS).save(f"{out}/{name}.png", optimize=True)


def gear(d, cx, cy, r_out, r_in, teeth, fill, outline):
    pts = []
    for i in range(teeth * 2):
        a0 = math.pi * i / teeth
        r = r_out if i % 2 == 0 else r_in
        for da in (-0.12, 0.12):
            a = a0 + da
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    d.polygon(pts, fill=fill, outline=outline, width=SS * 2)


def wooden_drill_head():
    rng = random.Random(3)
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = S / 2
    gear(d, c, c, S * 0.46, S * 0.36, 10, (150, 104, 58, 255), (70, 44, 22, 255))
    # wood grain rings
    for k, r in enumerate((0.31, 0.25, 0.19, 0.13)):
        shade = (166 - k * 8, 118 - k * 6, 68 - k * 4, 255)
        d.ellipse([c - S * r, c - S * r * 0.95, c + S * r, c + S * r * 0.95], fill=shade, outline=(110, 74, 38, 255), width=SS)
    for _ in range(8):
        a = rng.uniform(0, 2 * math.pi)
        d.line([(c + S * 0.08 * math.cos(a), c + S * 0.08 * math.sin(a)),
                (c + S * 0.3 * math.cos(a), c + S * 0.3 * math.sin(a))], fill=(120, 82, 44, 255), width=SS)
    # iron-banded hub
    d.ellipse([c - S * 0.09, c - S * 0.09, c + S * 0.09, c + S * 0.09], fill=(90, 92, 96, 255), outline=(40, 40, 42, 255), width=SS * 2)
    d.ellipse([c - S * 0.04, c - S * 0.04, c + S * 0.04, c + S * 0.04], fill=(30, 30, 32, 255))
    return img


def pile(base, grain, seed, count, size):
    rng = random.Random(seed)
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # mound
    d.pieslice([S * 0.06, S * 0.3, S * 0.94, S * 1.3], 180, 360, fill=base)
    d.rectangle([S * 0.06, S * 0.78, S * 0.94, S * 0.82], fill=base)
    for _ in range(count):
        x = rng.uniform(0.12, 0.88)
        top = 0.8 - 0.48 * math.sqrt(max(0, 1 - ((x - 0.5) / 0.44) ** 2))
        y = rng.uniform(top + 0.02, 0.8)
        r = rng.uniform(*size)
        v = rng.randint(-20, 20)
        col = tuple(max(0, min(255, ch + v)) for ch in grain) + (255,)
        d.ellipse([S * (x - r), S * (y - r), S * (x + r), S * (y + r)], fill=col)
    return img.filter(ImageFilter.SMOOTH)


def clay():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # two moulded lumps
    d.rounded_rectangle([S * 0.1, S * 0.42, S * 0.62, S * 0.84], radius=S * 0.12, fill=(160, 88, 58, 255), outline=(96, 50, 32, 255), width=SS * 2)
    d.rounded_rectangle([S * 0.38, S * 0.24, S * 0.9, S * 0.7], radius=S * 0.12, fill=(178, 100, 66, 255), outline=(96, 50, 32, 255), width=SS * 2)
    d.arc([S * 0.46, S * 0.3, S * 0.8, S * 0.5], 200, 330, fill=(214, 140, 104, 255), width=SS * 3)
    d.arc([S * 0.18, S * 0.48, S * 0.5, S * 0.66], 200, 330, fill=(196, 122, 88, 255), width=SS * 3)
    return img


def blade():
    """Salvaged circular cutting blade."""
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = S / 2
    teeth = 16
    pts = []
    for i in range(teeth):
        a = 2 * math.pi * i / teeth
        pts.append((c + S * 0.46 * math.cos(a), c + S * 0.46 * math.sin(a)))
        b = a + 2 * math.pi / teeth * 0.7
        pts.append((c + S * 0.36 * math.cos(b), c + S * 0.36 * math.sin(b)))
    d.polygon(pts, fill=(176, 182, 190, 255), outline=(70, 74, 80, 255), width=SS * 2)
    d.ellipse([c - S * 0.3, c - S * 0.3, c + S * 0.3, c + S * 0.3], fill=(150, 156, 164, 255))
    # scorch and scratches from the crash
    d.pieslice([c - S * 0.3, c - S * 0.3, c + S * 0.3, c + S * 0.3], 200, 260, fill=(110, 100, 92, 255))
    for k in range(3):
        d.line([(c - S * 0.2, c + S * (0.05 + k * 0.06)), (c + S * 0.12, c + S * (0.12 + k * 0.05))], fill=(196, 202, 210, 255), width=SS)
    d.ellipse([c - S * 0.08, c - S * 0.08, c + S * 0.08, c + S * 0.08], fill=(60, 62, 66, 255), outline=(30, 30, 32, 255), width=SS * 2)
    return img


def clay_drill_head(fired):
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = S / 2
    if fired:
        body, edge, ring = (178, 92, 58, 255), (92, 44, 26, 255), (206, 120, 82, 255)
    else:
        body, edge, ring = (168, 132, 104, 255), (110, 84, 64, 255), (186, 152, 124, 255)
    gear(d, c, c, S * 0.46, S * 0.35, 9, body, edge)
    d.ellipse([c - S * 0.27, c - S * 0.27, c + S * 0.27, c + S * 0.27], fill=ring, outline=edge, width=SS * 2)
    if fired:
        # glaze highlight and the blade set into the clay
        d.arc([c - S * 0.22, c - S * 0.22, c + S * 0.22, c + S * 0.22], 200, 300, fill=(236, 170, 130, 255), width=SS * 3)
    else:
        # finger marks in the soft clay
        for k in range(3):
            d.arc([c - S * (0.12 + k * 0.05), c - S * 0.2, c + S * (0.12 + k * 0.05), c + S * 0.2], 20, 160, fill=(150, 116, 90, 255), width=SS)
    d.ellipse([c - S * 0.09, c - S * 0.09, c + S * 0.09, c + S * 0.09], fill=(176, 182, 190, 255), outline=(60, 62, 66, 255), width=SS * 2)
    return img


def glass():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for k, (x0, y0) in enumerate(((0.1, 0.3), (0.3, 0.14))):
        d.polygon([(S * x0, S * (y0 + 0.08)), (S * (x0 + 0.5), S * y0), (S * (x0 + 0.58), S * (y0 + 0.5)), (S * (x0 + 0.08), S * (y0 + 0.58))],
                  fill=(150, 210, 230, 170 + k * 40), outline=(70, 120, 140, 255))
        d.line([(S * (x0 + 0.14), S * (y0 + 0.16)), (S * (x0 + 0.3), S * (y0 + 0.12))], fill=(240, 250, 255, 255), width=SS * 3)
    return img


save(wooden_drill_head(), "wooden-drill-head")
save(clay_drill_head(False), "unfired-clay-drill-head")
save(clay_drill_head(True), "clay-drill-head")
save(glass(), "glass")
save(blade(), "blade")
save(pile((206, 178, 120, 255), (226, 198, 140), 5, 220, (0.012, 0.025)), "sand")
save(clay(), "clay")
