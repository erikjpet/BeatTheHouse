"""Generate the Log #3.3 social promo card from the existing icon art system."""

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate_icon_art as gen

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets" / "art" / "promo"
CANVAS = (1280, 720)

FEATURES = [
    ("Better low-end stability", "stability"),
    ("Starting home location", ROOT / "assets/art/map_icons/house.png"),
    ("Containers", ROOT / "assets/art/items/trunk.png"),
    ("World map travel", ROOT / "assets/art/items/roadside_map.png"),
    ("Audio fix on web", "audio"),
    ("Misc bug fixes", "wrench"),
]


def icon_stability():
    image, d = gen.new_icon()
    gen.ellipse(d, (7, 9, 25, 27), gen.BLUE)
    d.arc((7, 9, 25, 27), 180, 360, fill=gen.CYAN, width=2)
    for angle_x, angle_y, color in ((9, 14, gen.PINK), (15, 10, gen.AMBER), (22, 14, gen.TEAL)):
        d.rectangle((angle_x, angle_y, angle_x + 1, angle_y + 1), fill=color)
    gen.line(d, (16, 19, 21, 13), gen.YELLOW, width=2)
    gen.ellipse(d, (14, 17, 18, 21), gen.SOFT)
    gen.glint(d, 24, 8)
    return image


def icon_audio():
    image, d = gen.new_icon()
    gen.poly(d, [(7, 13), (12, 13), (17, 8), (17, 24), (12, 19), (7, 19)], gen.SOFT)
    d.arc((15, 10, 24, 22), 300, 60, fill=gen.CYAN, width=2)
    d.arc((13, 7, 28, 25), 300, 60, fill=gen.TEAL, width=2)
    gen.pip(d, 24, 8, gen.PINK)
    gen.glint(d, 26, 22, gen.AMBER)
    return image


def icon_wrench():
    image, d = gen.new_icon()
    gen.line(d, (10, 22, 20, 12), gen.METAL, width=3)
    gen.ellipse(d, (17, 6, 27, 16), gen.METAL)
    gen.ellipse(d, (21, 8, 27, 14), gen.FIELD)
    d.rectangle((24, 6, 27, 9), fill=gen.FIELD)
    gen.ellipse(d, (7, 19, 13, 25), gen.METAL)
    gen.pip(d, 9, 21, gen.PINK)
    gen.glint(d, 24, 20, gen.YELLOW)
    return image


DRAWN = {"stability": icon_stability, "audio": icon_audio, "wrench": icon_wrench}


def load_feature_icon(source, size):
    if isinstance(source, Path):
        image = Image.open(source).convert("RGBA")
    else:
        image = DRAWN[source]()
    return image.resize((size, size), Image.NEAREST)


def pixel_text(text, scale, fill):
    font = ImageFont.load_default()
    probe = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
    box = probe.textbbox((0, 0), text, font=font)
    pad = 1
    small = Image.new("RGBA", (box[2] - box[0] + pad * 2, box[3] - box[1] + pad * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(small)
    d.text((pad - box[0], pad - box[1]), text, font=font, fill=fill)
    return small.resize((small.width * scale, small.height * scale), Image.NEAREST)


def paste_text(canvas, text, scale, fill, x, y, shadow=True, center_x=None):
    rendered = pixel_text(text, scale, fill)
    if center_x is not None:
        x = center_x - rendered.width // 2
    if shadow:
        dark = pixel_text(text, scale, gen.BLACK)
        canvas.alpha_composite(dark, (x + scale, y + scale))
    canvas.alpha_composite(rendered, (x, y))
    return rendered.size


def build():
    canvas = Image.new("RGBA", CANVAS, gen.BLACK)

    backdrop = Image.open(ROOT / "assets/art/map_backgrounds/cyberpunk_city_overhead.png").convert("RGBA")
    backdrop = backdrop.resize((1280, 854), Image.NEAREST).crop((0, 60, 1280, 780))
    backdrop = Image.blend(Image.new("RGBA", CANVAS, gen.BLACK), backdrop, 0.42)
    canvas.alpha_composite(backdrop, (0, 0))

    d = ImageDraw.Draw(canvas)
    for y in range(0, 720, 4):
        d.line((0, y, 1280, y), fill=(5, 6, 10, 70))
    d.rectangle((6, 6, 1273, 713), outline=gen.FRAME, width=4)
    d.rectangle((12, 12, 1267, 707), outline=gen.DARK, width=2)

    paste_text(canvas, "BEAT THE HOUSE", 8, gen.CYAN, 0, 44, center_x=640)
    tag_w, tag_h = pixel_text("UPDATE LOG #3.3", 5, gen.WHITE).size
    tag_x, tag_y = 640 - tag_w // 2, 158
    d.rectangle((tag_x - 18, tag_y - 10, tag_x + tag_w + 18, tag_y + tag_h + 10), fill=gen.PINK, outline=gen.BLACK, width=3)
    paste_text(canvas, "UPDATE LOG #3.3", 5, gen.WHITE, tag_x, tag_y, shadow=False)

    card_w, card_h, gap = 596, 118, 16
    grid_x, grid_y = (1280 - card_w * 2 - gap) // 2, 268
    icon_size = 84
    for index, (label, source) in enumerate(FEATURES):
        col, row = index % 2, index // 2
        x = grid_x + col * (card_w + gap)
        y = grid_y + row * (card_h + gap)
        d.rectangle((x, y, x + card_w, y + card_h), fill=(11, 11, 24, 216), outline=gen.FRAME, width=3)
        d.rectangle((x + 3, y + 3, x + card_w - 3, y + card_h - 3), outline=gen.DARK, width=1)
        icon = load_feature_icon(source, icon_size)
        canvas.alpha_composite(icon, (x + 18, y + (card_h - icon_size) // 2))
        paste_text(canvas, label, 3, gen.SOFT, x + 122, y + card_h // 2 - 16)

    paste_text(canvas, "PLAY FREE IN THE BROWSER - ITCH.IO", 3, gen.AMBER, 0, 672, center_x=640)

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out_path = OUT_DIR / "log_3_3_promo.png"
    canvas.convert("RGB").save(out_path, optimize=True)
    print(f"wrote {out_path}")


if __name__ == "__main__":
    build()
