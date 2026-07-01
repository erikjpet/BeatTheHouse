"""Generate the Beat the House logo in the game's dark-neon pixel style.

Emblem: an ace of spades (the winning hand you beat the house with), a poker
chip, and a die - flat neon fills with hard dark outlines like the item icons
in generate_icon_art.py, finished with a neon glow like the itch banner.

Outputs to builds/itch/images/:
  logo_mark.png   1024x1024  transparent - emblem only (icon/avatar)
  logo_full.png   1500x1650  transparent - emblem + wordmark
  cover.png        630x500   itch cover (logo on the dark scene bg)
"""

from pathlib import Path
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "builds" / "itch" / "images"
OUT.mkdir(parents=True, exist_ok=True)
random.seed(11)
np.random.seed(11)


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


OUTLINE = rgb("#05060a")
FIELD = rgb("#101427")
FRAME = rgb("#0096a6")
PINK = rgb("#ff2d78")
PINK2 = rgb("#ff6eb4")
CYAN = rgb("#00f5ff")
TEAL = rgb("#00ffd5")
AMBER = rgb("#ffb32d")
PURPLE2 = rgb("#c44dff")
SOFT = rgb("#d8e8ea")
WHITE = rgb("#ffffff")
NEONS = [PINK, CYAN, TEAL, PURPLE2, AMBER]
FONT_BOLD = "C:/Windows/Fonts/arialbd.ttf"


def mask_canvas(size):
    m = Image.new("L", size, 0)
    return m, ImageDraw.Draw(m)


def stamp(base, mask, fill, ow=6, outline=OUTLINE):
    """Composite a flat-filled shape with a hard dark outline (icon style)."""
    dil = mask
    for _ in range(ow):
        dil = dil.filter(ImageFilter.MaxFilter(3))
    base.paste(outline + (255,), (0, 0), dil)
    base.paste(fill + (255,), (0, 0), mask)


def spade_mask(size, cx, cy, s):
    m, d = mask_canvas(size)
    d.polygon([(cx, cy - s), (cx - 0.78 * s, cy + 0.30 * s), (cx + 0.78 * s, cy + 0.30 * s)], fill=255)
    d.ellipse([cx - 0.92 * s, cy - 0.20 * s, cx + 0.02 * s, cy + 0.55 * s], fill=255)
    d.ellipse([cx - 0.02 * s, cy - 0.20 * s, cx + 0.92 * s, cy + 0.55 * s], fill=255)
    d.polygon([(cx - 0.07 * s, cy + 0.10 * s), (cx - 0.40 * s, cy + 0.86 * s),
               (cx + 0.40 * s, cy + 0.86 * s), (cx + 0.07 * s, cy + 0.10 * s)], fill=255)
    return m


def build_card():
    cw, ch = 460, 650
    card = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    fm, fd = mask_canvas((cw, ch))
    fd.rounded_rectangle([0, 0, cw - 1, ch - 1], radius=46, fill=255)
    stamp(card, fm, FRAME, ow=3)
    inner, ind = mask_canvas((cw, ch))
    ind.rounded_rectangle([22, 22, cw - 23, ch - 23], radius=30, fill=255)
    card.paste(FIELD + (255,), (0, 0), inner)
    d = ImageDraw.Draw(card)
    d.rounded_rectangle([22, 22, cw - 23, ch - 23], radius=30, outline=OUTLINE + (255,), width=3)

    stamp(card, spade_mask((cw, ch), cw // 2, ch // 2 - 6, 150), PINK, ow=6)
    hi, hid = mask_canvas((cw, ch))
    hid.ellipse([cw // 2 - 60, ch // 2 - 120, cw // 2 - 6, ch // 2 - 66], fill=255)
    card.paste(PINK2 + (255,), (0, 0), hi)

    a_font = ImageFont.truetype(FONT_BOLD, 96)
    for (ax, ay, rot) in [(58, 40, 0), (cw - 58, ch - 40, 180)]:
        tag = Image.new("RGBA", (150, 210), (0, 0, 0, 0))
        td = ImageDraw.Draw(tag)
        td.text((20, 6), "A", font=a_font, fill=CYAN + (255,))
        sm = spade_mask((150, 210), 62, 150, 34)
        stamp(tag, sm, CYAN, ow=3)
        tag = tag.rotate(rot, expand=False, resample=Image.BICUBIC)
        card.paste(tag, (int(ax - 62), int(ay - (150 if rot == 0 else 60))), tag)
    return card


def build_chip(diameter=340):
    s = diameter
    chip = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    outer, od = mask_canvas((s, s))
    od.ellipse([6, 6, s - 7, s - 7], fill=255)
    stamp(chip, outer, PINK, ow=6)
    d = ImageDraw.Draw(chip)
    cx = cy = s / 2
    r = s / 2 - 8
    for k in range(8):
        ang = k * (np.pi / 4)
        x, y = cx + np.cos(ang) * (r - 14), cy + np.sin(ang) * (r - 14)
        d.ellipse([x - 20, y - 20, x + 20, y + 20], fill=CYAN + (255,), outline=OUTLINE + (255,), width=3)
    core, cod = mask_canvas((s, s))
    cod.ellipse([s * 0.24, s * 0.24, s * 0.76, s * 0.76], fill=255)
    stamp(chip, core, FIELD, ow=4)
    stamp(chip, spade_mask((s, s), int(cx), int(cy - 4), 62), PINK, ow=4)
    return chip


def build_die(s=250):
    die = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    fm, fd = mask_canvas((s, s))
    fd.rounded_rectangle([8, 8, s - 9, s - 9], radius=44, fill=255)
    stamp(die, fm, TEAL, ow=6)
    inner, ind = mask_canvas((s, s))
    ind.rounded_rectangle([30, 30, s - 31, s - 31], radius=28, fill=255)
    die.paste(FIELD + (255,), (0, 0), inner)
    d = ImageDraw.Draw(die)
    d.rounded_rectangle([30, 30, s - 31, s - 31], radius=28, outline=OUTLINE + (255,), width=3)
    pr = 20
    for (px, py) in [(0.32, 0.32), (0.68, 0.32), (0.5, 0.5), (0.32, 0.68), (0.68, 0.68)]:
        x, y = s * px, s * py
        d.ellipse([x - pr, y - pr, x + pr, y + pr], fill=CYAN + (255,), outline=OUTLINE + (255,), width=3)
    return die


def neon_finish(crisp, halo_colors):
    s = crisp.size
    out = Image.new("RGBA", s, (0, 0, 0, 0))
    halo = Image.new("RGBA", s, (0, 0, 0, 0))
    hd = ImageDraw.Draw(halo)
    cx, cy = s[0] / 2, s[1] / 2
    for i, col in enumerate(halo_colors):
        rr = min(s) * (0.44 - i * 0.06)
        hd.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=col + (40,))
    halo = halo.filter(ImageFilter.GaussianBlur(90))
    glow = crisp.filter(ImageFilter.GaussianBlur(14))
    out = Image.alpha_composite(out, halo)
    out = Image.alpha_composite(out, glow)
    out = Image.alpha_composite(out, glow)
    out = Image.alpha_composite(out, crisp)
    return out


def build_emblem(size=1024):
    crisp = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    c = size / 2
    chip = build_chip(int(size * 0.40))
    crisp.paste(chip, (int(c - size * 0.40), int(c - size * 0.08)), chip)
    die = build_die(int(size * 0.26))
    die = die.rotate(-10, expand=True, resample=Image.BICUBIC)
    crisp.paste(die, (int(c + size * 0.10), int(c + size * 0.10)), die)
    card = build_card()
    card = card.rotate(11, expand=True, resample=Image.BICUBIC)
    crisp.paste(card, (int(c - card.width / 2 + size * 0.02), int(c - card.height / 2 - size * 0.06)), card)
    return neon_finish(crisp, [PINK, CYAN])


def tracked_width(font, text, tr):
    return sum(font.getlength(ch) + tr for ch in text) - tr


def draw_tracked(draw, pos, text, font, fill, tr):
    x, y = pos
    for ch in text:
        draw.text((x, y), ch, font=font, fill=fill)
        x += font.getlength(ch) + tr


def make_wordmark(width, title_px=150, sub_px=40, tagline="A SEEDABLE CASINO ROGUELIKE"):
    maxw = width * 0.9
    title, tr = "BEAT THE HOUSE", int(title_px * 0.08)
    tf = ImageFont.truetype(FONT_BOLD, title_px)
    while tracked_width(tf, title, tr) > maxw and title_px > 12:
        title_px -= 4
        tr = int(title_px * 0.08)
        tf = ImageFont.truetype(FONT_BOLD, title_px)
    h = int(title_px * 1.32)
    layer = Image.new("RGBA", (width, h), (0, 0, 0, 0))
    tw = tracked_width(tf, title, tr)
    tx, ty = (width - tw) / 2, int(title_px * 0.06)

    glow = Image.new("RGBA", (width, h), (0, 0, 0, 0))
    draw_tracked(ImageDraw.Draw(glow), (tx, ty), title, tf, PINK + (255,), tr)
    layer = Image.alpha_composite(layer, glow.filter(ImageFilter.GaussianBlur(18)))
    layer = Image.alpha_composite(layer, glow.filter(ImageFilter.GaussianBlur(7)))
    d = ImageDraw.Draw(layer)
    draw_tracked(d, (tx, ty), title, tf, SOFT + (255,), tr)
    return layer


def scene_bg(w, h):
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.sqrt((xx - w * 0.5) ** 2 + (yy - h * 0.42) ** 2)
    d /= d.max()
    t = np.clip(d ** 1.3, 0, 1)[..., None]
    arr = np.array(rgb("#10152a"), np.float32) * (1 - t) + np.array(rgb("#05060a"), np.float32) * t
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    bok = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bok)
    rnd = random.Random(4)
    for _ in range(int(w * h / 9000)):
        x, y = rnd.randint(0, w), rnd.randint(0, h)
        r = rnd.randint(4, 16)
        bd.ellipse([x - r, y - r, x + r, y + r], fill=rnd.choice(NEONS) + (rnd.randint(30, 80),))
    return Image.alpha_composite(img, bok.filter(ImageFilter.GaussianBlur(6)))


def main():
    emblem = build_emblem(1024)
    emblem.save(OUT / "logo_mark.png")

    W = 1500
    full = Image.new("RGBA", (W, 1650), (0, 0, 0, 0))
    em = emblem.resize((940, 940), Image.LANCZOS)
    full.paste(em, ((W - 940) // 2, 20), em)
    wm = make_wordmark(W, title_px=168, sub_px=44)
    full.paste(wm, (0, 980), wm)
    full.save(OUT / "logo_full.png")

    cw, ch = 630, 500
    cover = scene_bg(cw, ch)
    em2 = emblem.resize((300, 300), Image.LANCZOS)
    cover.paste(em2, ((cw - 300) // 2, 26), em2)
    wm2 = make_wordmark(cw, title_px=60, sub_px=17)
    cover.paste(wm2, (0, 320), wm2)
    cover.convert("RGB").save(OUT / "cover.png")

    for p in sorted(OUT.glob("logo_*.png")) + [OUT / "cover.png"]:
        print(f"  {p.relative_to(ROOT)}  ({p.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
