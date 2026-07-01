"""Generate the Beat the House logo from the game's actual art assets.

The emblem is a symmetrical, mirrored row of real game-icon tiles from
assets/art/games (cards - dice - roulette - dice - cards), scaled with
nearest-neighbour so the pixel art stays crisp, finished with a soft neon
glow, over the smooth neon "BEAT THE HOUSE" wordmark. No tagline.

Outputs to builds/itch/images/:
  logo_mark.png   1024x1024  transparent - roulette mark (icon/avatar)
  logo_full.png   transparent - symmetrical emblem + wordmark
  cover.png        630x500   itch cover (logo on the dark scene bg)
"""

from pathlib import Path
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "assets" / "art"
OUT = ROOT / "builds" / "itch" / "images"
OUT.mkdir(parents=True, exist_ok=True)
random.seed(11)


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


PINK = rgb("#ff2d78")
CYAN = rgb("#00f5ff")
TEAL = rgb("#00ffd5")
PURPLE2 = rgb("#c44dff")
AMBER = rgb("#ffb32d")
SOFT = rgb("#d8e8ea")
NEONS = [PINK, CYAN, TEAL, PURPLE2, AMBER]
FONT_BOLD = "C:/Windows/Fonts/arialbd.ttf"


def tile(rel, k, flip=False):
    im = Image.open(ART / rel).convert("RGBA")
    im = im.resize((im.width * k, im.height * k), Image.NEAREST)
    return ImageOps.mirror(im) if flip else im


def finish(em, halo=True):
    a = em.getchannel("A")
    rim = Image.new("RGBA", em.size, (0, 0, 0, 0))
    rim.paste(CYAN + (110,), (0, 0), a)
    rim = rim.filter(ImageFilter.GaussianBlur(max(6, em.width // 90)))
    out = Image.new("RGBA", em.size, (0, 0, 0, 0))
    if halo:
        h = Image.new("RGBA", em.size, (0, 0, 0, 0))
        hd = ImageDraw.Draw(h)
        cx, cy = em.size[0] / 2, em.size[1] / 2
        hd.ellipse([cx - em.width * 0.40, cy - em.height * 0.55,
                    cx + em.width * 0.40, cy + em.height * 0.55], fill=PINK + (26,))
        hd.ellipse([cx - em.width * 0.26, cy - em.height * 0.36,
                    cx + em.width * 0.26, cy + em.height * 0.36], fill=CYAN + (24,))
        out = Image.alpha_composite(out, h.filter(ImageFilter.GaussianBlur(max(30, em.width // 18))))
    out = Image.alpha_composite(out, rim)
    out = Image.alpha_composite(out, em)
    return out


def build_emblem(k_side, k_center, gap, pad=None):
    order = [("games/cards.png", k_side, False), ("games/dice.png", k_side, False),
             ("games/slot.png", k_center, False),
             ("games/dice.png", k_side, True), ("games/cards.png", k_side, True)]
    tiles = [(tile(rel, k, flip)) for rel, k, flip in order]
    row_w = sum(t.width for t in tiles) + gap * (len(tiles) - 1)
    row_h = max(t.height for t in tiles)
    if pad is None:
        pad = row_h // 3
    em = Image.new("RGBA", (row_w + pad * 2, row_h + pad * 2), (0, 0, 0, 0))
    x = pad
    for t in tiles:
        em.alpha_composite(t, (x, pad + (row_h - t.height) // 2))
        x += t.width + gap
    return finish(em)


def build_mark(size=1024):
    k = (size - 120) // 32
    roul = tile("games/roulette.png", k)
    em = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    em.alpha_composite(roul, ((size - roul.width) // 2, (size - roul.height) // 2))
    return finish(em)


def tracked_width(font, text, tr):
    return sum(font.getlength(ch) + tr for ch in text) - tr


def draw_tracked(draw, pos, text, font, fill, tr):
    x, y = pos
    for ch in text:
        draw.text((x, y), ch, font=font, fill=fill)
        x += font.getlength(ch) + tr


def make_wordmark(width, title_px=200):
    maxw = width * 0.92
    title, tr = "BEAT THE HOUSE", int(title_px * 0.08)
    tf = ImageFont.truetype(FONT_BOLD, title_px)
    while tracked_width(tf, title, tr) > maxw and title_px > 12:
        title_px -= 4
        tr = int(title_px * 0.08)
        tf = ImageFont.truetype(FONT_BOLD, title_px)
    h = int(title_px * 1.34)
    layer = Image.new("RGBA", (width, h), (0, 0, 0, 0))
    tw = tracked_width(tf, title, tr)
    tx, ty = (width - tw) / 2, int(title_px * 0.08)
    glow = Image.new("RGBA", (width, h), (0, 0, 0, 0))
    draw_tracked(ImageDraw.Draw(glow), (tx, ty), title, tf, PINK + (255,), tr)
    layer = Image.alpha_composite(layer, glow.filter(ImageFilter.GaussianBlur(18)))
    layer = Image.alpha_composite(layer, glow.filter(ImageFilter.GaussianBlur(7)))
    d = ImageDraw.Draw(layer)
    draw_tracked(d, (tx, ty), title, tf, SOFT + (255,), tr)
    return layer


def neon_rule(width, length, color=PINK):
    layer = Image.new("RGBA", (width, 28), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    x0, x1 = (width - length) // 2, (width + length) // 2
    d.line([(x0, 14), (x1, 14)], fill=color + (255,), width=4)
    d.ellipse([x0 - 5, 9, x0 + 5, 19], fill=CYAN + (255,))
    d.ellipse([x1 - 5, 9, x1 + 5, 19], fill=CYAN + (255,))
    return Image.alpha_composite(layer.filter(ImageFilter.GaussianBlur(4)), layer)


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


def compose(emblem, wordmark, width):
    rule = neon_rule(width, int(width * 0.30))
    gap1, gap2 = int(width * 0.005), int(width * 0.02)
    h = emblem.height + gap1 + rule.height + gap2 + wordmark.height
    canvas = Image.new("RGBA", (width, h), (0, 0, 0, 0))
    y = 0
    canvas.alpha_composite(emblem, ((width - emblem.width) // 2, y)); y += emblem.height + gap1
    canvas.alpha_composite(rule, (0, y)); y += rule.height + gap2
    canvas.alpha_composite(wordmark, ((width - wordmark.width) // 2, y))
    return canvas


def main():
    build_mark(1024).save(OUT / "logo_mark.png")

    emblem = build_emblem(k_side=7, k_center=9, gap=26)
    W = emblem.width
    full = compose(emblem, make_wordmark(W, title_px=210), W)
    full.save(OUT / "logo_full.png")

    cw, ch = 630, 500
    cover = scene_bg(cw, ch)
    em_c = build_emblem(k_side=3, k_center=4, gap=12)
    lockup = compose(em_c, make_wordmark(min(cw - 40, em_c.width), title_px=64), max(em_c.width, cw - 40))
    scale = min((cw - 40) / lockup.width, (ch - 40) / lockup.height, 1.0)
    if scale < 1.0:
        lockup = lockup.resize((int(lockup.width * scale), int(lockup.height * scale)), Image.LANCZOS)
    cover.alpha_composite(lockup, ((cw - lockup.width) // 2, (ch - lockup.height) // 2))
    cover.convert("RGB").save(OUT / "cover.png")

    for p in sorted(OUT.glob("logo_*.png")) + [OUT / "cover.png"]:
        im = Image.open(p)
        print(f"  {p.relative_to(ROOT)}  {im.size}  ({p.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
