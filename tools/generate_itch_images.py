"""Generate itch.io page images (banner, background, embed background) that
match Beat the House's dark-neon palette. Colors mirror scripts/ui/visual_style.gd.

Outputs PNGs to builds/itch/images/ (gitignored) ready to upload on itch.io:
  banner.png      1920x480   - page header image
  background.png  1920x1080  - page background (kept dark/low-contrast for readability)
  embed_bg.png    1920x1080  - background behind the game embed frame
"""

from pathlib import Path
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "builds" / "itch" / "images"
OUT.mkdir(parents=True, exist_ok=True)

random.seed(7)
np.random.seed(7)


def rgb(hex_value):
    hex_value = hex_value.lstrip("#")
    return tuple(int(hex_value[i:i + 2], 16) for i in (0, 2, 4))


BG = rgb("#05060a")
CORE = rgb("#10152a")
PINK = rgb("#ff2d78")
CYAN = rgb("#00f5ff")
TEAL = rgb("#00ffd5")
PURPLE2 = rgb("#c44dff")
AMBER = rgb("#ffb32d")
ORANGE = rgb("#ff6a27")
SOFT = rgb("#d8e8ea")
NEONS = [PINK, CYAN, TEAL, PURPLE2, AMBER, ORANGE]

FONT_BOLD = "C:/Windows/Fonts/arialbd.ttf"


def radial_base(w, h, inner, outer, cx=0.5, cy=0.5, power=1.3):
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    dx = xx - cx * w
    dy = yy - cy * h
    d = np.sqrt(dx * dx + dy * dy)
    d /= d.max()
    t = np.clip(d ** power, 0, 1)[..., None]
    inner = np.array(inner, np.float32)
    outer = np.array(outer, np.float32)
    return inner * (1 - t) + outer * t


def to_img(arr):
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB").convert("RGBA")


def add_noise(img, amt=2):
    arr = np.asarray(img).astype(np.int16)
    noise = np.random.randint(-amt, amt + 1, arr[..., :3].shape)
    arr[..., :3] = np.clip(arr[..., :3] + noise, 0, 255)
    return Image.fromarray(arr.astype(np.uint8), img.mode)


def glow_layer(size, draws, blur):
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for fn in draws:
        fn(d)
    return layer.filter(ImageFilter.GaussianBlur(blur))


def bokeh(size, n, radii, alpha_range, seed=1):
    rnd = random.Random(seed)
    w, h = size
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for _ in range(n):
        x, y = rnd.randint(0, w), rnd.randint(0, h)
        r = rnd.randint(*radii)
        c = rnd.choice(NEONS)
        a = rnd.randint(*alpha_range)
        d.ellipse([x - r, y - r, x + r, y + r], fill=c + (a,))
    return layer.filter(ImageFilter.GaussianBlur(6))


def tracked_width(font, text, tracking):
    return sum(font.getlength(ch) + tracking for ch in text) - tracking


def draw_tracked(draw, pos, text, font, fill, tracking):
    x, y = pos
    for ch in text:
        draw.text((x, y), ch, font=font, fill=fill)
        x += font.getlength(ch) + tracking


def make_banner():
    w, h = 1920, 480
    img = to_img(radial_base(w, h, CORE, BG, cy=0.42, power=1.15))
    img = Image.alpha_composite(img, bokeh((w, h), 46, (6, 26), (30, 95), seed=3))
    img = Image.alpha_composite(img, glow_layer(
        (w, h), [lambda d: d.ellipse([-200, h - 30, w + 200, h + 190], fill=CYAN + (38,))], 70))

    title_font = ImageFont.truetype(FONT_BOLD, 128)
    sub_font = ImageFont.truetype(FONT_BOLD, 30)
    title, tr = "BEAT THE HOUSE", 10
    tw = tracked_width(title_font, title, tr)
    tx, ty = (w - tw) / 2, h * 0.28

    img = Image.alpha_composite(img, glow_layer(
        (w, h), [lambda d: draw_tracked(d, (tx, ty), title, title_font, CYAN + (150,), tr)], 34))
    img = Image.alpha_composite(img, glow_layer(
        (w, h), [lambda d: draw_tracked(d, (tx, ty), title, title_font, PINK + (255,), tr)], 16))
    d = ImageDraw.Draw(img)
    draw_tracked(d, (tx, ty), title, title_font, SOFT + (255,), tr)

    sub, sr = "A SEEDABLE CASINO ROGUELIKE", 8
    sw = tracked_width(sub_font, sub, sr)
    sx, sy = (w - sw) / 2, ty + 158
    draw_tracked(d, (sx, sy), sub, sub_font, CYAN + (235,), sr)

    ry = sy + 54
    img = Image.alpha_composite(img, glow_layer(
        (w, h), [lambda dd: dd.line([(w / 2 - 250, ry), (w / 2 + 250, ry)], fill=PINK + (255,), width=4)], 4))
    ImageDraw.Draw(img).line([(w / 2 - 250, ry), (w / 2 + 250, ry)], fill=PINK + (255,), width=2)

    add_noise(img.convert("RGB")).save(OUT / "banner.png")


def make_background():
    w, h = 1920, 1080
    img = to_img(radial_base(w, h, rgb("#0a0e1e"), rgb("#040409"), cy=0.4, power=1.5))
    img = Image.alpha_composite(img, glow_layer((w, h), [
        lambda d: d.line([(-100, 220), (w * 0.62, -120)], fill=PINK + (48,), width=130),
        lambda d: d.line([(w * 0.5, h + 120), (w + 120, h * 0.4)], fill=CYAN + (42,), width=150),
    ], 130))
    img = Image.alpha_composite(img, bokeh((w, h), 28, (4, 15), (14, 38), seed=9))

    vig = radial_base(w, h, (255, 255, 255), (66, 66, 78), power=1.6) / 255.0
    arr = np.asarray(img)[..., :3].astype(np.float32) * vig
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")
    add_noise(img).save(OUT / "background.png")


def make_embed_bg():
    w, h = 1920, 1080
    img = to_img(radial_base(w, h, rgb("#080a12"), rgb("#04040a"), power=1.7))
    img = Image.alpha_composite(img, glow_layer(
        (w, h), [lambda d: d.ellipse([w * 0.5 - 620, h * 0.5 - 380, w * 0.5 + 620, h * 0.5 + 380], fill=TEAL + (30,))], 170))
    img = Image.alpha_composite(img, glow_layer(
        (w, h), [lambda d: d.ellipse([w * 0.5 - 440, h * 0.5 - 290, w * 0.5 + 440, h * 0.5 + 290], fill=CYAN + (20,))], 150))

    fw, fh = 1320, 770
    fx, fy = (w - fw) / 2, (h - fh) / 2
    img = Image.alpha_composite(img, glow_layer(
        (w, h), [lambda d: d.rounded_rectangle([fx, fy, fx + fw, fy + fh], radius=18, outline=PINK + (70,), width=4)], 7))
    add_noise(img.convert("RGB")).save(OUT / "embed_bg.png")


if __name__ == "__main__":
    make_banner()
    make_background()
    make_embed_bg()
    for p in sorted(OUT.glob("*.png")):
        print(f"  {p.relative_to(ROOT)}  ({p.stat().st_size // 1024} KB)")
    print(f"Done. Images in: {OUT}")
