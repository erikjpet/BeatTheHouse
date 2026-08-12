"""Generate the v0.5 devlog social card in the established devlog #2-#4 style.

Outputs branding/social/0.5.0_beat_the_house_instagram.png (1080x1080) plus
720x720 mobile png/jpg variants, matching the committed devlog #2/#3/#4 cards.
Showcase panels use real 0.5 captures already committed under docs/screenshots/
and review_artifacts/.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SOCIAL_DIR = ROOT / "branding" / "social"
SHOTS_05 = ROOT / "docs" / "screenshots" / "0.5"
SCRATCH = ROOT / "docs" / "screenshots" / "scratch_ticket_three_state_review"
VPOKER = ROOT / "review_artifacts" / "video_poker_cabinets"
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
    "tag": "0.5.0",
    "header_kicker": "DEVLOG #5",
    "hero": "v0.5 IS OUT",
    "subtitle": "Grand Casino, UI Rebuild, New Games",
    "chips": [
        ("GRAND CASINO", PINK),
        ("NEW GAMES", TEAL),
        ("UI REBUILD", AMBER),
        ("BOSS FIGHT", ORANGE),
    ],
    # Crops are fractional (x0, y0, x1, y1) of the source image.
    "panel_tutorial": {
        "image": SHOTS_05 / "0.5.0_tutorial_panel.png",
        # Keep Pal, the guided prompt, and the highlighted in-world item in a
        # single social-readable strip instead of returning to casino-floor art.
        "crop": (0.050, 0.660, 0.950, 0.985),
        "caption": "NEW: GUIDED FIRST NIGHT",
        "border": PINK,
    },
    "panel_cage": {
        "image": SHOTS_05 / "06_cage.png",
        "crop": (0.070, 0.230, 0.860, 0.940),
        "caption": "NEW: THE CAGE",
        "border": CYAN,
    },
    "panel_scratch": {
        "image": SCRATCH / "all_scratch_tickets_three_states.png",
        "crop": (0.105, 0.126, 0.352, 0.248),
        "caption": "SCRATCH TICKETS",
        "border": YELLOW,
        "fit": "contain",
    },
    "panel_vpoker": {
        "image": VPOKER / "all_three_video_poker_cabinets.png",
        "crop": (0.235, 0.500, 0.720, 0.875),
        "caption": "VIDEO POKER",
        "border": TEAL,
    },
    "panel_talk": {
        "image": SHOTS_05 / "03_conversation_popup.png",
        "crop": (0.120, 0.210, 0.880, 0.990),
        "caption": "CHARACTER CONVERSATIONS",
        "border": ORANGE,
        "caption_top": True,
    },
    "notes": [
        (PINK, "Grand Casino and Rourke overhaul"),
        (YELLOW, "Added Scratch Tickets"),
        (TEAL, "UI and main menu redesign"),
        (AMBER, "New guided tutorial"),
        (CYAN, "Map and travel overhaul"),
        (ORANGE, "Video Poker and cheat updates"),
        (PURPLE, "Improved all casino games"),
        (CYAN, "New items and better Heat feedback"),
        (TEAL, "Expanded cross-run progression"),
        (PINK, "Audio, performance, balance and fixes"),
    ],
    "backdrop": SHOTS_05 / "05_game_surface.png",
    "footer": "THE GRAND CASINO IS OPEN - PLAY FREE",
}


def font(name, size):
    return ImageFont.truetype(str(FONT_DIR / name), size)


F_KICKER = font("ariblk.ttf", 34)
F_TITLE = font("ariblk.ttf", 40)
F_HERO = font("ariblk.ttf", 100)
F_SUB = font("arialbd.ttf", 30)
F_CHIP = font("arialbd.ttf", 24)
F_CAPTION = font("ariblk.ttf", 25)
F_CAPTION_SM = font("ariblk.ttf", 18)
F_CAPTION_XS = font("ariblk.ttf", 16)
F_NOTES_H = font("ariblk.ttf", 38)
F_NOTE_LINE = font("arialbd.ttf", 20)
F_FOOTER = font("ariblk.ttf", 28)
F_PILL = font("ariblk.ttf", 30)


def rounded(d, box, radius, outline, width=4, fill=None):
    d.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def text_w(f, s):
    return int(f.getlength(s))


def frac_crop(image, box):
    w, h = image.size
    return image.crop((int(box[0] * w), int(box[1] * h), int(box[2] * w), int(box[3] * h)))


def paste_cover(canvas, image, box):
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    ratio = max(w / image.width, h / image.height)
    resized = image.resize((int(image.width * ratio) + 1, int(image.height * ratio) + 1), Image.NEAREST)
    left = (resized.width - w) // 2
    top = (resized.height - h) // 2
    region = resized.crop((left, top, left + w, top + h))
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, w - 1, h - 1), radius=16, fill=255)
    canvas.paste(region, (x0, y0), mask)


def paste_contain(canvas, image, box):
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    ratio = min(w / image.width, h / image.height)
    rw, rh = max(1, int(image.width * ratio)), max(1, int(image.height * ratio))
    resized = image.resize((rw, rh), Image.NEAREST)
    canvas.paste(resized, (x0 + (w - rw) // 2, y0 + (h - rh) // 2))


def caption_bar(canvas, d, box, caption, bar_h=42, f=None, top=False):
    x0, y0, x1, y1 = box
    f = f or F_CAPTION
    bar_y = y0 if top else y1 - bar_h
    overlay = Image.new("RGBA", (x1 - x0, bar_h), (5, 6, 10, 215))
    canvas.alpha_composite(overlay, (x0, bar_y))
    d.text((x0 + 14, bar_y + (bar_h - f.size) // 2 - 2), caption, font=f, fill=WHITE)


def image_panel(canvas, d, box, cfg, bar_h=42, f=None):
    rounded(d, box, 20, cfg["border"], 4, fill=PANEL_SOFT)
    inner = (box[0] + 6, box[1] + 6, box[2] - 6, box[3] - 6)
    source = Image.open(cfg["image"]).convert("RGBA")
    if "crop" in cfg:
        source = frac_crop(source, cfg["crop"])
    if cfg.get("fit") == "contain":
        paste_contain(canvas, source, inner)
    else:
        paste_cover(canvas, source, inner)
    caption_bar(canvas, d, inner, cfg["caption"], bar_h, f, bool(cfg.get("caption_top", False)))


def build():
    c = DEVLOG
    canvas = Image.new("RGBA", (1080, 1080), BLACK)

    backdrop = Image.open(c["backdrop"]).convert("RGBA")
    backdrop = frac_crop(backdrop, (0.0, 0.20, 1.0, 1.0))
    ratio = 1080 / backdrop.width
    backdrop = backdrop.resize((1080, int(backdrop.height * ratio)), Image.NEAREST)
    faded = Image.blend(Image.new("RGBA", backdrop.size, BLACK), backdrop, 0.24)
    canvas.alpha_composite(faded, (0, 0))
    d = ImageDraw.Draw(canvas)
    d.rectangle((0, 560, 1080, 1080), fill=BLACK)

    rounded(d, (10, 10, 1069, 1069), 42, PINK, 5)
    rounded(d, (22, 22, 1057, 1057), 34, CYAN, 3)

    # Header
    d.text((64, 44), c["header_kicker"], font=F_KICKER, fill=AMBER)
    d.text((64, 84), "BEAT THE HOUSE", font=F_TITLE, fill=WHITE)
    rule_y = 138
    d.line((64, rule_y, 540, rule_y), fill=PINK, width=4)
    d.line((540, rule_y, 616, rule_y - 22), fill=PINK, width=4)
    pill_w = text_w(F_PILL, "OUT NOW") + 56
    rounded(d, (1016 - pill_w, 52, 1016, 104), 26, PINK, 4, fill=PANEL)
    d.text((1016 - pill_w + 28, 60), "OUT NOW", font=F_PILL, fill=AMBER)

    # Hero
    hero_w = text_w(F_HERO, c["hero"])
    d.text(((1080 - hero_w) // 2, 148), c["hero"], font=F_HERO, fill=PINK)
    sub_w = text_w(F_SUB, c["subtitle"])
    d.text(((1080 - sub_w) // 2, 262), c["subtitle"], font=F_SUB, fill=WHITE)

    # Chips
    chip_y, chip_h = 310, 48
    widths = [text_w(F_CHIP, label) + 46 for label, _ in c["chips"]]
    total = sum(widths) + 18 * (len(widths) - 1)
    x = (1080 - total) // 2
    for (label, color), w in zip(c["chips"], widths):
        rounded(d, (x, chip_y, x + w, chip_y + chip_h), 24, color, 4, fill=PANEL)
        d.text((x + 23, chip_y + 12), label, font=F_CHIP, fill=WHITE)
        x += w + 18

    # Showcase panels: conversation left; cage + new games right.
    image_panel(canvas, d, (64, 372, 536, 640), c["panel_talk"], 40)
    image_panel(canvas, d, (560, 372, 1016, 516), c["panel_cage"], 30, F_CAPTION_SM)
    image_panel(canvas, d, (560, 532, 782, 640), c["panel_scratch"], 26, F_CAPTION_XS)
    image_panel(canvas, d, (794, 532, 1016, 640), c["panel_vpoker"], 26, F_CAPTION_XS)

    # Wide tutorial panel replaces the former Grand Casino floor showcase.
    image_panel(canvas, d, (64, 660, 1016, 832), c["panel_tutorial"], 40)

    # Release notes: ten entries, two columns of five.
    notes = (64, 844, 1016, 1000)
    rounded(d, notes, 20, PINK, 4, fill=PANEL)
    heading = " WHAT'S NEW "
    heading_w = text_w(F_NOTES_H, heading)
    d.rectangle((notes[0] + 24, notes[1] - 14, notes[0] + 24 + heading_w, notes[1] + 30), fill=BLACK)
    d.text((notes[0] + 28, notes[1] - 12), heading, font=F_NOTES_H, fill=WHITE)
    col_x = (notes[0] + 36, notes[0] + 496)
    row_y = notes[1] + 34
    for index, (color, line) in enumerate(c["notes"]):
        cx = col_x[index // 5]
        cy = row_y + (index % 5) * 23
        d.rectangle((cx, cy + 4, cx + 14, cy + 18), outline=color, width=3)
        d.text((cx + 28, cy), line, font=F_NOTE_LINE, fill=SOFT)

    # Footer
    footer_w = text_w(F_FOOTER, c["footer"]) + 72
    fx = (1080 - footer_w) // 2
    rounded(d, (fx, 1008, fx + footer_w, 1052), 22, AMBER, 4, fill=PANEL)
    d.text((fx + 36, 1017), c["footer"], font=F_FOOTER, fill=AMBER)

    SOCIAL_DIR.mkdir(parents=True, exist_ok=True)
    base = SOCIAL_DIR / f"{c['tag']}_beat_the_house_instagram"
    flat = canvas.convert("RGB")
    flat.save(f"{base}.png", optimize=True)
    mobile = flat.resize((720, 720), Image.LANCZOS)
    mobile.save(f"{base}_mobile.png", optimize=True)
    mobile.save(f"{base}_mobile.jpg", quality=92, optimize=True)
    print(f"wrote {base}.png + mobile png/jpg")


if __name__ == "__main__":
    build()
