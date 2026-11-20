#!/usr/bin/env python3
"""0.17 — Génère les habillages d'interface des 10 âges (textures 9-tranches) et leurs sons d'interface.

Tout est produit par code (Pillow + module wave), donc original et sans licence tierce.
Usage : python3 -I tools/generate-ui-skins.py   (depuis sillons/sillons)
Sorties : interface/ui_skins/age_XX/{panel.png, button.png, tap.wav, open.wav, alert.wav, age.wav}
Les couleurs de fond reprennent les jetons d'AgeTheme (interface/age_theme.gd) : la recette ui_theme
mesure le contraste réel sur le centre de chaque texture.
"""
import math
import random
import struct
import wave
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1] / "interface" / "ui_skins"
SS = 4  # suréchantillonnage pour des bords lissés

# fond (bg), surface (boutons), bordure, accent — doivent rester alignés avec AgeTheme.TOKENS
AGES = {
    1: dict(bg=(31, 26, 21), surface=(58, 46, 34), border=(138, 106, 62), accent=(217, 162, 74), style="stone", radius=5),
    2: dict(bg=(36, 26, 36), surface=(59, 42, 58), border=(184, 147, 74), accent=(212, 176, 98), style="parchment", radius=7),
    3: dict(bg=(28, 29, 32), surface=(52, 54, 59), border=(120, 122, 128), accent=(200, 68, 59), style="iron", radius=4),
    4: dict(bg=(27, 23, 18), surface=(52, 44, 33), border=(181, 118, 60), accent=(208, 138, 74), style="brass", radius=6),
    5: dict(bg=(15, 26, 51), surface=(28, 44, 82), border=(212, 175, 55), accent=(230, 197, 90), style="gilded", radius=9),
    6: dict(bg=(21, 22, 15), surface=(46, 50, 31), border=(200, 178, 122), accent=(217, 194, 126), style="steel", radius=2),
    7: dict(bg=(11, 16, 12), surface=(26, 34, 28), border=(63, 207, 106), accent=(255, 176, 0), style="console", radius=3),
    8: dict(bg=(13, 20, 38), surface=(23, 34, 61), border=(47, 208, 230), accent=(56, 217, 240), style="flat", radius=6),
    9: dict(bg=(12, 18, 27), surface=(28, 41, 56), border=(159, 232, 255), accent=(127, 227, 255), style="glass", radius=14),
    10: dict(bg=(10, 9, 22), surface=(28, 25, 52), border=(180, 156, 255), accent=(195, 166, 255), style="nextgen", radius=20),
}


def rounded_mask(size, radius, jitter=0.0, seed=0):
    w, h = size
    img = Image.new("L", (w * SS, h * SS), 0)
    d = ImageDraw.Draw(img)
    if jitter <= 0:
        d.rounded_rectangle([0, 0, w * SS - 1, h * SS - 1], radius=radius * SS, fill=255)
    else:
        rnd = random.Random(seed)
        pts = []
        steps = 18
        for side in range(4):
            for i in range(steps):
                t = i / steps
                if side == 0:
                    x, y = t * w, 0
                elif side == 1:
                    x, y = w, t * h
                elif side == 2:
                    x, y = w - t * w, h
                else:
                    x, y = 0, h - t * h
                inset = rnd.uniform(0, jitter)
                cx, cy = w / 2, h / 2
                vx, vy = cx - x, cy - y
                n = math.hypot(vx, vy) or 1.0
                pts.append(((x + vx / n * inset) * SS, (y + vy / n * inset) * SS))
        d.polygon(pts, fill=255)
    return img.resize(size, Image.LANCZOS)


def noise_fill(size, base, amp, seed, grain=1):
    rnd = random.Random(seed)
    w, h = size
    small = Image.new("RGB", (max(1, w // grain), max(1, h // grain)))
    px = small.load()
    for y in range(small.size[1]):
        for x in range(small.size[0]):
            n = rnd.uniform(-amp, amp)
            px[x, y] = tuple(max(0, min(255, int(c + n))) for c in base)
    return small.resize(size, Image.BILINEAR)


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def skin(age, cfg, size, margin, fill_key):
    w = h = size
    style = cfg["style"]
    base = cfg[fill_key]
    border = cfg["border"]
    seed = age * 101 + size
    img = noise_fill((w, h), base, {"stone": 4, "parchment": 3, "iron": 2, "brass": 2, "gilded": 2, "steel": 2}.get(style, 1), seed, 2)
    d = ImageDraw.Draw(img)
    radius = cfg["radius"] if style not in ("stone",) else 3
    if style == "stone":
        for _ in range(size // 6):
            rnd = random.Random(seed + _)
            x = rnd.randrange(0, w); y = rnd.randrange(0, h)
            d.line([(x, y), (x + rnd.randrange(-6, 7), y + rnd.randrange(-6, 7))], fill=mix(base, (0, 0, 0), 0.25), width=1)
        for i in range(4):
            col = mix(border, base, i / 4.0)
            d.rectangle([i, i, w - 1 - i, h - 1 - i], outline=col)
    elif style == "parchment":
        d.rectangle([1, 1, w - 2, h - 2], outline=border, width=2)
        d.rectangle([5, 5, w - 6, h - 6], outline=mix(border, base, 0.45), width=1)
        for cx, cy in ((5, 5), (w - 6, 5), (5, h - 6), (w - 6, h - 6)):
            d.rectangle([cx - 2, cy - 2, cx + 2, cy + 2], fill=border)
    elif style == "iron":
        for i in range(4):
            d.rectangle([i, i, w - 1 - i, h - 1 - i], outline=mix((150, 152, 158), (40, 41, 45), i / 3.0))
        for cx, cy in ((7, 7), (w - 8, 7), (7, h - 8), (w - 8, h - 8)):
            d.ellipse([cx - 2, cy - 2, cx + 2, cy + 2], fill=(170, 172, 178), outline=(30, 30, 34))
        d.line([(8, 4), (w - 9, 4)], fill=cfg["accent"], width=1)
    elif style == "brass":
        d.rectangle([0, 0, w - 1, h - 1], outline=mix(border, (255, 230, 180), 0.35), width=1)
        d.line([(1, 1), (w - 2, 1)], fill=mix(border, (255, 240, 200), 0.5), width=2)
        d.line([(1, h - 2), (w - 2, h - 2)], fill=mix(border, (0, 0, 0), 0.5), width=2)
        d.line([(1, 1), (1, h - 2)], fill=mix(border, (255, 240, 200), 0.3), width=2)
        d.line([(w - 2, 1), (w - 2, h - 2)], fill=mix(border, (0, 0, 0), 0.4), width=2)
        for cx, cy in ((6, 6), (w - 7, 6), (6, h - 7), (w - 7, h - 7)):
            d.ellipse([cx - 2, cy - 2, cx + 2, cy + 2], outline=border)
            d.line([(cx - 1, cy), (cx + 1, cy)], fill=border)
    elif style == "gilded":
        d.rounded_rectangle([0, 0, w - 1, h - 1], radius=radius, outline=border, width=3)
        d.rounded_rectangle([5, 5, w - 6, h - 6], radius=max(1, radius - 4), outline=mix(border, base, 0.55), width=1)
        for cx, cy in ((w // 2, 2), (w // 2, h - 3), (2, h // 2), (w - 3, h // 2)):
            d.polygon([(cx, cy - 2), (cx + 2, cy), (cx, cy + 2), (cx - 2, cy)], fill=(250, 232, 160))
    elif style == "steel":
        c = 7
        d.polygon([(c, 0), (w - 1 - c, 0), (w - 1, c), (w - 1, h - 1 - c), (w - 1 - c, h - 1), (c, h - 1), (0, h - 1 - c), (0, c)], outline=border)
        d.line([(c, 3), (w - 1 - c, 3)], fill=mix(border, base, 0.5))
        for x in range(c + 6, w - c - 6, 10):
            d.line([(x, h - 4), (x + 4, h - 4)], fill=mix(border, base, 0.4))
    elif style == "console":
        for y in range(0, h, 3):
            d.line([(0, y), (w - 1, y)], fill=mix(base, (0, 0, 0), 0.18))
        d.rounded_rectangle([0, 0, w - 1, h - 1], radius=radius, outline=mix(border, base, 0.35), width=1)
        L = 9
        for (x0, y0, sx, sy) in ((1, 1, 1, 1), (w - 2, 1, -1, 1), (1, h - 2, 1, -1), (w - 2, h - 2, -1, -1)):
            d.line([(x0, y0), (x0 + sx * L, y0)], fill=border, width=2)
            d.line([(x0, y0), (x0, y0 + sy * L)], fill=border, width=2)
    elif style == "glass":
        for y in range(h):
            t = y / max(1, h - 1)
            d.line([(0, y), (w - 1, y)], fill=mix(mix(base, (255, 255, 255), 0.06), base, min(1.0, t * 2.2)))
        d.rounded_rectangle([0, 0, w - 1, h - 1], radius=radius, outline=mix(border, base, 0.15), width=1)
        d.line([(radius, 1), (w - 1 - radius, 1)], fill=mix(border, (255, 255, 255), 0.4))
    elif style == "nextgen":
        for y in range(h):
            t = y / max(1, h - 1)
            d.line([(0, y), (w - 1, y)], fill=mix(mix(base, (90, 60, 160), 0.10), base, min(1.0, t * 1.6)))
        # liseré irisé : la teinte tourne le long du contour
        hi = Image.new("RGB", (w * SS, h * SS), (0, 0, 0))
        hd = ImageDraw.Draw(hi)
        for i in range(w * SS):
            hue = (i / (w * SS)) * 2 * math.pi
            col = (int(150 + 80 * math.cos(hue)), int(140 + 80 * math.cos(hue + 2.1)), int(230 + 25 * math.cos(hue + 4.2)))
            hd.line([(i, 0), (i, h * SS)], fill=col)
        ring = Image.new("L", (w * SS, h * SS), 0)
        rd = ImageDraw.Draw(ring)
        rd.rounded_rectangle([0, 0, w * SS - 1, h * SS - 1], radius=radius * SS, outline=255, width=int(1.6 * SS))
        hi = hi.resize((w, h), Image.LANCZOS)
        ring = ring.resize((w, h), Image.LANCZOS)
        img.paste(hi, (0, 0), ring)
    elif style == "flat":
        d.rounded_rectangle([0, 0, w - 1, h - 1], radius=radius, outline=border, width=1)
    mask = rounded_mask((w, h), radius, jitter=2.2 if style == "stone" else 0.0, seed=seed)
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


# ---------------------------------------------------------------- sons

RATE = 22050


def write_wav(path, samples):
    with wave.open(str(path), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767 * 0.5)) for s in samples))


def env(i, n, attack=0.004, release=1.0):
    t = i / RATE
    a = min(1.0, t / attack) if attack > 0 else 1.0
    return a * math.exp(-t / max(0.001, release * n / RATE / 4.0))


def tone(freqs, dur, release=1.0, noise=0.0, sweep=0.0, seed=0, square=False, breath=False):
    rnd = random.Random(seed)
    n = int(RATE * dur)
    out = []
    lp = 0.0
    for i in range(n):
        t = i / RATE
        s = 0.0
        for k, f in enumerate(freqs):
            ff = f * (1.0 + sweep * t / dur)
            v = math.sin(2 * math.pi * ff * t)
            if square:
                v = 1.0 if v > 0 else -1.0
            s += v / (k + 1)
        if noise > 0:
            lp = lp * 0.82 + rnd.uniform(-1, 1) * 0.18
            s = s * (1 - noise) + lp * noise * 3.0
        e = env(i, n, release=release)
        if breath:
            e = math.sin(math.pi * i / n) ** 1.5
        out.append(s * e * 0.55)
    return out


def sounds_for(age):
    a = age
    tap = {
        1: tone([180, 360], 0.09, noise=0.7, seed=1),
        2: tone([1800, 2700], 0.16, release=1.2),
        3: tone([600, 1200], 0.12, noise=0.5, seed=3, square=True),
        4: tone([900], 0.03, noise=0.6, seed=4) + [0.0] * 500 + tone([1100], 0.03, noise=0.6, seed=5),
        5: tone([440, 660], 0.13, release=1.4),
        6: tone([90, 180], 0.11, noise=0.6, seed=6),
        7: tone([1000], 0.07, release=2.0),
        8: tone([2000], 0.03, square=True),
        9: tone([700], 0.16, noise=0.9, seed=9, breath=True),
        10: tone([600], 0.09, sweep=1.0),
    }[a]
    open_ = tone([300 + 60 * a, 450 + 90 * a], 0.18, sweep=0.4, noise=0.4 if a <= 4 or a == 6 else 0.0, seed=a * 7, breath=a >= 9)
    alert = tone([520 + 30 * a], 0.12, release=1.5) + [0.0] * 600 + tone([780 + 45 * a], 0.16, release=1.5, square=(a == 7 or a == 8))
    fanfare = []
    base = [196, 220, 247, 262, 294, 330, 349, 392, 440, 494][a - 1]
    for k, mult in enumerate([1.0, 1.25, 1.5, 2.0]):
        fanfare += tone([base * mult, base * mult * 2], 0.26 if k < 3 else 0.5, release=1.6, noise=0.25 if a <= 3 else 0.0, seed=a * 13 + k, square=(a == 7))
    return {"tap": tap, "open": open_, "alert": alert, "age": fanfare}


def main():
    for age, cfg in AGES.items():
        folder = ROOT / ("age_%02d" % age)
        folder.mkdir(parents=True, exist_ok=True)
        skin(age, cfg, 96, 24, "bg").save(folder / "panel.png", optimize=True)
        skin(age, cfg, 48, 14, "surface").save(folder / "button.png", optimize=True)
        for name, samples in sounds_for(age).items():
            write_wav(folder / (name + ".wav"), samples)
    total = sum(p.stat().st_size for p in ROOT.rglob("*") if p.is_file() and p.suffix in (".png", ".wav"))
    print("UI_SKINS=PASS ages=%d octets=%d" % (len(AGES), total))


if __name__ == "__main__":
    main()
