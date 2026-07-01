"""Generate the Beat the House logo in the game's pixel-art style.

Everything is drawn on a small logical grid (like the 32px item icons in
generate_icon_art.py) with flat neon fills and hard dark outlines, then
upscaled with nearest-neighbour so the pixels stay crisp. No gaussian glow.
The wordmark uses a hand-built 5x7 pixel font. No tagline.

Outputs to builds/itch/images/:
  logo_mark.png   ~1024   transparent - emblem only (icon/avatar)
  logo_full.png   ~1120   transparent - emblem + pixel wordmark
  cover.png        630x500 itch cover (logo on the dark scene bg)
"""

from pathlib import Path
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "builds" / "itch" / "images"
OUT.mkdir(parents=True, exist_ok=True)
random.seed(11)


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


OUTLINE = rgb("#05060a")
FIELD = rgb("#101427")
FRAME = rgb("#00c2d6")
PINK = rgb("#ff2d78")
PINK2 = rgb("#ff6eb4")
CYAN = rgb("#00f5ff")
TEAL = rgb("#00ffd5")
AMBER = rgb("#ffb32d")
PURPLE2 = rgb("#c44dff")
SOFT = rgb("#eaf2f4")
NEONS = [PINK, CYAN, TEAL, PURPLE2, AMBER]

PX = 7  # logical pixel -> output pixels


def L(size):
    m = Image.new("L", size, 0)
    return m, ImageDraw.Draw(m)


def dilate(mask, n):
    for _ in range(n):
        mask = mask.filter(ImageFilter.MaxFilter(3))
    return mask


def stamp(base, mask, fill, ow=1):
    base.paste(OUTLINE + (255,), (0, 0), dilate(mask, ow))
    base.paste(fill + (255,), (0, 0), mask)


def spade_mask(size, cx, cy, s):
    m, d = L(size)
    d.polygon([(cx, cy - s), (cx - 0.8 * s, cy + 0.28 * s), (cx + 0.8 * s, cy + 0.28 * s)], fill=255)
    d.ellipse([cx - 0.95 * s, cy - 0.15 * s, cx + 0.05 * s, cy + 0.5 * s], fill=255)
    d.ellipse([cx - 0.05 * s, cy - 0.15 * s, cx + 0.95 * s, cy + 0.5 * s], fill=255)
    d.polygon([(cx - 0.1 * s, cy + 0.1 * s), (cx - 0.42 * s, cy + 0.8 * s),
               (cx + 0.42 * s, cy + 0.8 * s), (cx + 0.1 * s, cy + 0.1 * s)], fill=255)
    return m


def neon_rim(rgba, inner=PINK, outer=CYAN):
    a = rgba.getchannel("A")
    out = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    out.paste(outer + (80,), (0, 0), dilate(a, 2))
    out.paste(inner + (150,), (0, 0), dilate(a, 1))
    return Image.alpha_composite(out, rgba)


def draw_card(em, cx, cy):
    w, h = 42, 58
    x0, y0 = cx - w // 2, cy - h // 2
    fm, fd = L(em.size)
    fd.rounded_rectangle([x0, y0, x0 + w, y0 + h], radius=5, fill=255)
    stamp(em, fm, FRAME, ow=1)
    im, idr = L(em.size)
    idr.rounded_rectangle([x0 + 3, y0 + 3, x0 + w - 3, y0 + h - 3], radius=3, fill=255)
    em.paste(FIELD + (255,), (0, 0), im)
    stamp(em, spade_mask(em.size, cx, cy + 1, 11), PINK, ow=1)
    hm, hd = L(em.size)
    hd.ellipse([cx - 5, cy - 9, cx - 1, cy - 5], fill=255)
    em.paste(PINK2 + (255,), (0, 0), hm)
    for (ox, oy) in [(x0 + 6, y0 + 6), (x0 + w - 6, y0 + h - 6)]:
        am, ad = L(em.size)
        ad.line([(ox - 2, oy + 3), (ox, oy - 3)], fill=255)
        ad.line([(ox, oy - 3), (ox + 2, oy + 3)], fill=255)
        ad.line([(ox - 1, oy + 1), (ox + 1, oy + 1)], fill=255)
        em.paste(CYAN + (255,), (0, 0), am)
        stamp(em, spade_mask(em.size, ox, oy + 6, 3), CYAN, ow=1)


def draw_chip(em, cx, cy, r):
    om, od = L(em.size)
    od.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    stamp(em, om, PINK, ow=1)
    d = ImageDraw.Draw(em)
    for k in range(8):
        ang = k * np.pi / 4
        x, y = cx + np.cos(ang) * (r - 3), cy + np.sin(ang) * (r - 3)
        d.rectangle([x - 2, y - 2, x + 2, y + 2], fill=CYAN + (255,), outline=OUTLINE + (255,))
    cm, cd = L(em.size)
    cd.ellipse([cx - r * 0.5, cy - r * 0.5, cx + r * 0.5, cy + r * 0.5], fill=255)
    stamp(em, cm, FIELD, ow=1)
    stamp(em, spade_mask(em.size, cx, cy, 6), PINK, ow=1)


def draw_die(em, cx, cy, s):
    x0, y0 = cx - s // 2, cy - s // 2
    fm, fd = L(em.size)
    fd.rounded_rectangle([x0, y0, x0 + s, y0 + s], radius=4, fill=255)
    stamp(em, fm, TEAL, ow=1)
    im, idr = L(em.size)
    idr.rounded_rectangle([x0 + 3, y0 + 3, x0 + s - 3, y0 + s - 3], radius=2, fill=255)
    em.paste(FIELD + (255,), (0, 0), im)
    d = ImageDraw.Draw(em)
    for (px, py) in [(0.3, 0.3), (0.7, 0.3), (0.5, 0.5), (0.3, 0.7), (0.7, 0.7)]:
        x, y = x0 + s * px, y0 + s * py
        d.ellipse([x - 1.6, y - 1.6, x + 1.6, y + 1.6], fill=CYAN + (255,), outline=OUTLINE + (255,))


def build_emblem():
    ew, eh = 138, 116
    em = Image.new("RGBA", (ew, eh), (0, 0, 0, 0))
    draw_chip(em, 42, 66, 19)
    draw_card(em, 74, 56)
    draw_die(em, 100, 84, 22)
    return neon_rim(em)


GLYPHS = {
    "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    "B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
    "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
    "H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
    "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
    "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
    "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
    "U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
    " ": ["00000", "00000", "00000", "00000", "00000", "00000", "00000"],
}


def text_mask(text, gs):
    adv = 6 * gs
    width = adv * len(text)
    m, d = L((width, 7 * gs))
    for i, ch in enumerate(text):
        rows = GLYPHS[ch]
        for r, row in enumerate(rows):
            for c, bit in enumerate(row):
                if bit == "1":
                    x, y = i * adv + c * gs, r * gs
                    d.rectangle([x, y, x + gs - 1, y + gs - 1], fill=255)
    return m, width, 7 * gs


def build_wordmark(gs=3):
    lines = ["BEAT THE", "HOUSE"]
    masks = [text_mask(t.rstrip(), gs) for t in lines]
    ww = max(w for _, w, _ in masks)
    lh = 7 * gs
    gap = 2 * gs
    wh = lh * len(lines) + gap * (len(lines) - 1)
    layer = Image.new("RGBA", (ww + 4 * gs, wh + 4 * gs), (0, 0, 0, 0))
    for i, (m, w, h) in enumerate(masks):
        full, _ = L(layer.size)
        ox = (layer.size[0] - w) // 2
        oy = 2 * gs + i * (lh + gap)
        full.paste(m, (ox, oy))
        stamp(layer, full, SOFT, ow=1)
    return neon_rim(layer, inner=PINK, outer=CYAN)


def scale(img, factor):
    return img.resize((img.width * factor, img.height * factor), Image.NEAREST)


def scene_bg(w, h):
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.sqrt((xx - w * 0.5) ** 2 + (yy - h * 0.42) ** 2)
    d /= d.max()
    t = np.clip(d ** 1.3, 0, 1)[..., None]
    arr = np.array(rgb("#10152a"), np.float32) * (1 - t) + np.array(rgb("#05060a"), np.float32) * t
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    bok, bd = Image.new("RGBA", (w, h), (0, 0, 0, 0)), None
    bd = ImageDraw.Draw(bok)
    rnd = random.Random(4)
    for _ in range(int(w * h / 9000)):
        x, y = rnd.randint(0, w), rnd.randint(0, h)
        r = rnd.randint(4, 16)
        bd.ellipse([x - r, y - r, x + r, y + r], fill=rnd.choice(NEONS) + (rnd.randint(30, 80),))
    return Image.alpha_composite(img, bok.filter(ImageFilter.GaussianBlur(6)))


def main():
    emblem = build_emblem()
    wordmark = build_wordmark(gs=3)

    mark = scale(emblem, PX)
    pad = Image.new("RGBA", (max(mark.size),) * 2, (0, 0, 0, 0))
    pad.paste(mark, ((pad.width - mark.width) // 2, (pad.height - mark.height) // 2), mark)
    pad.save(OUT / "logo_mark.png")

    em_big, wm_big = scale(emblem, PX), scale(wordmark, PX)
    fw = max(em_big.width, wm_big.width) + 40
    fh = em_big.height + wm_big.height + 30
    full = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
    full.paste(em_big, ((fw - em_big.width) // 2, 0), em_big)
    full.paste(wm_big, ((fw - wm_big.width) // 2, em_big.height + 20), wm_big)
    full.save(OUT / "logo_full.png")

    cw, ch = 630, 500
    cover = scene_bg(cw, ch)
    em_c, wm_c = scale(emblem, 2), scale(wordmark, 2)
    total_h = em_c.height + wm_c.height + 16
    top = (ch - total_h) // 2
    cover.paste(em_c, ((cw - em_c.width) // 2, top), em_c)
    cover.paste(wm_c, ((cw - wm_c.width) // 2, top + em_c.height + 16), wm_c)
    cover.convert("RGB").save(OUT / "cover.png")

    for p in sorted(OUT.glob("logo_*.png")) + [OUT / "cover.png"]:
        im = Image.open(p)
        print(f"  {p.relative_to(ROOT)}  {im.size}  ({p.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
