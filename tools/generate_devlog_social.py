"""Generate devlog social cards in the established v0.2/v0.3 template style.

Outputs branding/social/beat_the_house_<tag>_instagram.png (1080x1080) plus
720x720 mobile png/jpg variants, matching the committed devlog #2/#3 cards.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SOCIAL_DIR = ROOT / "branding" / "social"
FONT_DIR = Path("C:/Windows/Fonts")

BLACK = (5, 6, 10, 255)
PANEL = (11, 11, 24, 235)
PANEL_SOFT = (13, 13, 30, 255)
PINK = (255, 45, 120, 255)
CYAN = (0, 245, 255, 255)
TEAL = (0, 255, 213, 255)
YELLOW = (255, 228, 92, 255)
AMBER = (255, 179, 45, 255)
ORANGE = (255, 106, 39, 255)
PURPLE = (196, 77, 255, 255)
WHITE = (255, 255, 255, 255)
SOFT = (216, 232, 234, 255)

DEVLOG = {
    "tag": "v0_4_0",
    "header_kicker": "DEVLOG #4",
    "hero": "v0.4 IS OUT",
    "subtitle": "Act 1 completion: home, bags, talk, travel, stability",
    "chips": [
        ("HOME", PINK),
        ("BAGS", YELLOW),
        ("DIALOGUE", CYAN),
        ("TRAVEL", ORANGE),
    ],
    "panel_large": {
        "image": ROOT / "branding/screenshots/11_meta_home_back_alley.png",
        "caption": "WALKABLE HOME BASE",
        "border": CYAN,
    },
    "panel_right_top": {
        "image": ROOT / "branding/screenshots/12_dialogue_talk_dock.png",
        "caption": "DIALOGUE & TALK",
        "border": AMBER,
    },
    "panel_right_bottom": {
        "image": ROOT / "assets/art/map_backgrounds/cyberpunk_city_overhead.png",
        "caption": "PRICED WORLD TRAVEL",
        "border": YELLOW,
    },
    "strip_label": "COLLECTIONS",
    "strip_icons": [
        ROOT / "assets/art/items/bag.png",
        ROOT / "assets/art/items/backpack.png",
        ROOT / "assets/art/items/suitcase.png",
        ROOT / "assets/art/items/trunk.png",
        ROOT / "assets/art/items/roadside_map.png",
        ROOT / "assets/art/items/lucky_keychain.png",
        ROOT / "assets/art/items/rabbits_foot.png",
        ROOT / "assets/art/items/hot_streak_token.png",
        ROOT / "assets/art/items/lucky_charm.png",
        ROOT / "assets/art/items/cashout_envelope.png",
    ],
    "notes": [
        ("HOUSING", PINK, "progression"),
        ("BAGS", YELLOW, "drops"),
        ("TALK", CYAN, "dialogue"),
        ("HOURS", AMBER, "venues"),
        ("TRAVEL", ORANGE, "pricing"),
        ("STABILITY", TEAL, "gates"),
    ],
    "backdrop": ROOT / "branding/screenshots/12_dialogue_talk_dock.png",
    "footer": "ACT 1 COMPLETION RELEASE AVAILABLE NOW",
}


def font(name, size):
    return ImageFont.truetype(str(FONT_DIR / name), size)


F_KICKER = font("ariblk.ttf", 36)
F_TITLE = font("ariblk.ttf", 42)
F_HERO = font("ariblk.ttf", 116)
F_SUB = font("arialbd.ttf", 33)
F_CHIP = font("arialbd.ttf", 29)
F_CAPTION = font("ariblk.ttf", 27)
F_NOTES_H = font("ariblk.ttf", 42)
F_NOTE = font("ariblk.ttf", 25)
F_NOTE_DESC = font("arialbd.ttf", 22)
F_FOOTER = font("ariblk.ttf", 33)
F_PILL = font("ariblk.ttf", 30)
F_STRIP = font("ariblk.ttf", 26)


def rounded(d, box, radius, outline, width=4, fill=None):
    d.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def text_w(f, s):
    return int(f.getlength(s))


def paste_cover(canvas, image, box):
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    ratio = max(w / image.width, h / image.height)
    resized = image.resize((int(image.width * ratio) + 1, int(image.height * ratio) + 1), Image.NEAREST)
    left = (resized.width - w) // 2
    top = (resized.height - h) // 2
    region = resized.crop((left, top, left + w, top + h))
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, w - 1, h - 1), radius=18, fill=255)
    canvas.paste(region, (x0, y0), mask)


def caption_bar(canvas, d, box, caption):
    x0, _, x1, y1 = box
    bar_h = 46
    mask_box = (x0, y1 - bar_h, x1, y1)
    overlay = Image.new("RGBA", (mask_box[2] - mask_box[0], bar_h), (5, 6, 10, 215))
    canvas.alpha_composite(overlay, (mask_box[0], mask_box[1]))
    d.text((x0 + 16, y1 - bar_h + 9), caption, font=F_CAPTION, fill=WHITE)


def build():
    c = DEVLOG
    canvas = Image.new("RGBA", (1080, 1080), BLACK)

    backdrop = Image.open(c["backdrop"]).convert("RGBA")
    ratio = 1080 / backdrop.width
    backdrop = backdrop.resize((1080, int(backdrop.height * ratio)), Image.NEAREST)
    faded = Image.blend(Image.new("RGBA", backdrop.size, BLACK), backdrop, 0.30)
    canvas.alpha_composite(faded, (0, 0))
    d = ImageDraw.Draw(canvas)
    d.rectangle((0, 620, 1080, 1080), fill=BLACK)

    rounded(d, (10, 10, 1069, 1069), 42, PINK, 5)
    rounded(d, (22, 22, 1057, 1057), 34, CYAN, 3)

    # Header
    d.text((64, 48), c["header_kicker"], font=F_KICKER, fill=AMBER)
    d.text((64, 90), "BEAT THE HOUSE", font=F_TITLE, fill=WHITE)
    rule_y = 146
    d.line((64, rule_y, 560, rule_y), fill=PINK, width=4)
    d.line((560, rule_y, 640, rule_y - 24), fill=PINK, width=4)
    pill_w = text_w(F_PILL, "OUT NOW") + 56
    rounded(d, (1016 - pill_w, 56, 1016, 110), 27, PINK, 4, fill=PANEL)
    d.text((1016 - pill_w + 28, 66), "OUT NOW", font=F_PILL, fill=AMBER)

    # Hero
    hero_w = text_w(F_HERO, c["hero"])
    d.text(((1080 - hero_w) // 2, 158), c["hero"], font=F_HERO, fill=PINK)
    sub_w = text_w(F_SUB, c["subtitle"])
    d.text(((1080 - sub_w) // 2, 288), c["subtitle"], font=F_SUB, fill=WHITE)

    # Chips
    chip_y, chip_h = 348, 52
    widths = [text_w(F_CHIP, label) + 56 for label, _ in c["chips"]]
    total = sum(widths) + 24 * (len(widths) - 1)
    x = (1080 - total) // 2
    for (label, color), w in zip(c["chips"], widths):
        rounded(d, (x, chip_y, x + w, chip_y + chip_h), 26, color, 4, fill=PANEL)
        d.text((x + 28, chip_y + 12), label, font=F_CHIP, fill=WHITE)
        x += w + 24

    # Panels
    large_box = (64, 432, 660, 718)
    rounded(d, large_box, 22, c["panel_large"]["border"], 4, fill=PANEL_SOFT)
    inner = (large_box[0] + 7, large_box[1] + 7, large_box[2] - 7, large_box[3] - 7)
    paste_cover(canvas, Image.open(c["panel_large"]["image"]).convert("RGBA"), inner)
    caption_bar(canvas, d, inner, c["panel_large"]["caption"])

    rt = (688, 432, 1016, 566)
    rounded(d, rt, 22, c["panel_right_top"]["border"], 4, fill=PANEL_SOFT)
    if "image" in c["panel_right_top"]:
        inner_rt = (rt[0] + 7, rt[1] + 7, rt[2] - 7, rt[3] - 7)
        paste_cover(canvas, Image.open(c["panel_right_top"]["image"]).convert("RGBA"), inner_rt)
        caption_bar(canvas, d, inner_rt, c["panel_right_top"]["caption"])
    else:
        icons = c["panel_right_top"]["icons"]
        size = 78
        total_icons = len(icons) * size + (len(icons) - 1) * 28
        ix = rt[0] + (rt[2] - rt[0] - total_icons) // 2
        for icon_path in icons:
            icon = Image.open(icon_path).convert("RGBA").resize((size, size), Image.NEAREST)
            canvas.alpha_composite(icon, (ix, rt[1] + 16))
            ix += size + 28
        d.text((rt[0] + 16, rt[3] - 40), c["panel_right_top"]["caption"], font=F_CAPTION, fill=WHITE)

    rb = (688, 590, 1016, 718)
    rounded(d, rb, 22, c["panel_right_bottom"]["border"], 4, fill=PANEL_SOFT)
    inner_rb = (rb[0] + 7, rb[1] + 7, rb[2] - 7, rb[3] - 7)
    paste_cover(canvas, Image.open(c["panel_right_bottom"]["image"]).convert("RGBA"), inner_rb)
    caption_bar(canvas, d, inner_rb, c["panel_right_bottom"]["caption"])

    # Icon strip
    strip = (64, 742, 1016, 826)
    rounded(d, strip, 22, CYAN, 4, fill=PANEL)
    lines = c["strip_label"].split("\n")
    for li, line_text in enumerate(lines):
        d.text((strip[0] + 24, strip[1] + 18 + li * 28), line_text, font=F_STRIP, fill=CYAN)
    tile, pad = 56, 14
    tx = strip[0] + 230
    for icon_path in c["strip_icons"]:
        icon = Image.open(icon_path).convert("RGBA").resize((tile, tile), Image.NEAREST)
        rounded(d, (tx - 4, strip[1] + 12, tx + tile + 4, strip[1] + 12 + tile + 8), 10, (0, 150, 166, 255), 2, fill=PANEL_SOFT)
        canvas.alpha_composite(icon, (tx, strip[1] + 16))
        tx += tile + pad + 8

    # Release notes
    notes = (64, 838, 1016, 974)
    rounded(d, notes, 22, PINK, 4, fill=PANEL)
    d.text((notes[0] + 28, notes[1] - 8), " RELEASE NOTES ", font=F_NOTES_H, fill=WHITE)
    col_x = (notes[0] + 32, notes[0] + 500)
    row_y = notes[1] + 40
    for index, (name, color, desc) in enumerate(c["notes"]):
        cx = col_x[index // 3]
        cy = row_y + (index % 3) * 30
        d.rectangle((cx, cy + 6, cx + 16, cy + 22), outline=color, width=3)
        d.text((cx + 30, cy), name, font=F_NOTE, fill=color)
        d.text((cx + 30 + text_w(F_NOTE, name) + 14, cy + 3), desc, font=F_NOTE_DESC, fill=SOFT)

    # Footer
    footer_w = text_w(F_FOOTER, c["footer"]) + 80
    fx = (1080 - footer_w) // 2
    rounded(d, (fx, 998, fx + footer_w, 1050), 24, AMBER, 4, fill=PANEL)
    d.text((fx + 40, 1008), c["footer"], font=F_FOOTER, fill=AMBER)

    SOCIAL_DIR.mkdir(parents=True, exist_ok=True)
    base = SOCIAL_DIR / f"beat_the_house_{c['tag']}_instagram"
    flat = canvas.convert("RGB")
    flat.save(f"{base}.png", optimize=True)
    mobile = flat.resize((720, 720), Image.LANCZOS)
    mobile.save(f"{base}_mobile.png", optimize=True)
    mobile.save(f"{base}_mobile.jpg", quality=92, optimize=True)
    print(f"wrote {base}.png + mobile png/jpg")


if __name__ == "__main__":
    build()
