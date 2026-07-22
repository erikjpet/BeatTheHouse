"""Build the end-of-run feature spotlight card from a live Godot capture."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SOCIAL_DIR = ROOT / "branding" / "social"
SCREENSHOT = ROOT / "branding" / "screenshots" / "19_end_of_run_report.png"
BACKDROP = ROOT / "assets" / "art" / "map_backgrounds" / "cyberpunk_city_overhead.png"
FONT_DIR = Path("C:/Windows/Fonts")

BLACK = (5, 6, 10, 255)
PANEL = (11, 11, 24, 255)
PINK = (255, 45, 120, 255)
CYAN = (0, 245, 255, 255)
TEAL = (0, 255, 213, 255)
YELLOW = (255, 228, 92, 255)
AMBER = (255, 179, 45, 255)
PURPLE = (196, 77, 255, 255)
WHITE = (255, 255, 255, 255)
SOFT = (216, 232, 234, 255)


def font(name: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONT_DIR / name), size)


F_KICKER = font("ariblk.ttf", 28)
F_TITLE = font("ariblk.ttf", 52)
F_SUBTITLE = font("arialbd.ttf", 24)
F_CAPTURE = font("ariblk.ttf", 18)
F_STRIP_TITLE = font("ariblk.ttf", 29)
F_STRIP_BODY = font("arialbd.ttf", 19)
F_FOOTER = font("arialbd.ttf", 19)


def rounded(draw, box, radius, outline, width=4, fill=None):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def center_x(text: str, face) -> int:
    return int((1080 - face.getlength(text)) / 2)


def cover(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    ratio = max(size[0] / image.width, size[1] / image.height)
    resized = image.resize(
        (int(image.width * ratio) + 1, int(image.height * ratio) + 1),
        Image.Resampling.NEAREST,
    )
    left = (resized.width - size[0]) // 2
    top = (resized.height - size[1]) // 2
    return resized.crop((left, top, left + size[0], top + size[1]))


def build() -> None:
    # Use the game's neon city map as the full-card backdrop instead of a flat
    # black field. A navy/cyan grade keeps copy legible while retaining the
    # pixel-art roads, buildings, and venue lights.
    backdrop = cover(Image.open(BACKDROP).convert("RGBA"), (1080, 1080))
    backdrop = ImageEnhance.Color(backdrop).enhance(1.35)
    backdrop = ImageEnhance.Brightness(backdrop).enhance(0.68)
    grade = Image.new("RGBA", backdrop.size, (6, 12, 35, 105))
    canvas = Image.alpha_composite(backdrop, grade)
    draw = ImageDraw.Draw(canvas)

    # Established double-neon frame and header treatment.
    rounded(draw, (10, 10, 1069, 1069), 42, PINK, 5)
    rounded(draw, (22, 22, 1057, 1057), 34, CYAN, 3)

    # Navy glass panels echo the live game UI without returning to a flat
    # black-background theme.
    rounded(draw, (40, 34, 1040, 220), 22, PINK, 3, fill=(9, 12, 38, 222))
    draw.text((56, 42), "DEVELOPMENT UPDATE", font=F_KICKER, fill=AMBER)
    draw.text((56, 76), "BEAT THE HOUSE", font=F_KICKER, fill=WHITE)
    draw.line((56, 117, 554, 117), fill=PINK, width=4)
    draw.line((554, 117, 624, 95), fill=PINK, width=4)

    title = "END-OF-RUN REPORT"
    draw.text((center_x(title, F_TITLE), 126), title, font=F_TITLE, fill=PINK)
    subtitle = "FEATURE SPOTLIGHT  /  YOUR WHOLE RUN, AT A GLANCE"
    draw.text((center_x(subtitle, F_SUBTITLE), 188), subtitle, font=F_SUBTITLE, fill=WHITE)

    # The primary visual is a real 1280x720 viewport capture, pixel-scaled.
    screenshot = Image.open(SCREENSHOT).convert("RGBA")
    screenshot = screenshot.resize((1000, 563), Image.Resampling.NEAREST)
    canvas.paste(screenshot, (40, 234))
    draw.rounded_rectangle((38, 232, 1041, 799), radius=12, outline=CYAN, width=4)

    capture_label = "LIVE IN-GAME CAPTURE  /  FULL EXTENSIVE RUN"
    label_w = int(F_CAPTURE.getlength(capture_label)) + 34
    rounded(draw, (56, 780, 56 + label_w, 818), 18, CYAN, 3, fill=PANEL)
    draw.text((73, 789), capture_label, font=F_CAPTURE, fill=WHITE)

    # One concise feature strip stays readable after Instagram downsizing.
    strip = (40, 838, 1040, 990)
    rounded(draw, strip, 20, AMBER, 4, fill=(9, 12, 38, 232))
    strip_title = "THE WHOLE RUN. ONE LAST LOOK."
    draw.text((center_x(strip_title, F_STRIP_TITLE), 856), strip_title, font=F_STRIP_TITLE, fill=WHITE)
    draw.line((114, 898, 966, 898), fill=CYAN, width=3)
    row_one = "REPLAY YOUR ROUTE   /   TRACE EVERY HEAT SPIKE   /   BREAK DOWN EVERY DOLLAR"
    row_two = "REVIEW ITEM FATES   /   SETTLE THE LEDGER   /   CHOOSE WHAT COMES HOME"
    draw.text((center_x(row_one, F_STRIP_BODY), 916), row_one, font=F_STRIP_BODY, fill=TEAL)
    draw.text((center_x(row_two, F_STRIP_BODY), 950), row_two, font=F_STRIP_BODY, fill=YELLOW)

    footer = "RESULT  /  REPLAY  /  REWARDS  /  ONE CLEAN SCREEN"
    footer_w = int(F_FOOTER.getlength(footer)) + 56
    footer_x = (1080 - footer_w) // 2
    rounded(draw, (footer_x, 1011, footer_x + footer_w, 1049), 19, TEAL, 3, fill=(9, 12, 38, 238))
    draw.text((footer_x + 28, 1019), footer, font=F_FOOTER, fill=YELLOW)

    SOCIAL_DIR.mkdir(parents=True, exist_ok=True)
    base = SOCIAL_DIR / "beat_the_house_end_run_feature_spotlight"
    flat = canvas.convert("RGB")
    flat.save(f"{base}.png", optimize=True)
    print(f"wrote {base}.png (1080x1080)")


if __name__ == "__main__":
    build()
