"""Generate transparent, game-native text overlays for the gameplay trailer."""

from __future__ import annotations

import argparse
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "branding" / "trailer" / "cards"
FONT_DIR = Path("C:/Windows/Fonts")

BLACK = (4, 5, 11, 255)
PANEL = (8, 10, 22, 255)
CYAN = (0, 245, 255, 255)
PINK = (255, 45, 120, 255)
YELLOW = (255, 224, 80, 255)
ORANGE = (255, 106, 39, 255)
PURPLE = (174, 74, 255, 255)
WHITE = (240, 248, 248, 255)
SOFT = (165, 190, 198, 255)

CARDS = {
    "logo": {
        "kicker": "CASINO ROGUELIKE",
        "title": "BEAT THE HOUSE",
        "subtitle": "ONE BAD NIGHT. ONE LAST RUN.",
        "accent": PINK,
    },
    "eight_games": {
        "kicker": "PUSH YOUR LUCK",
        "title": "EIGHT GAMES. ONE RUN.",
        "subtitle": "EVERY TABLE HAS AN EDGE.",
        "accent": YELLOW,
    },
    "dodge_heat": {
        "kicker": "WIN BIG. STAY INVISIBLE.",
        "title": "DODGE THE HEAT",
        "subtitle": "THE FLOOR IS WATCHING",
        "accent": ORANGE,
    },
    "cheat_dare": {
        "kicker": "THE ODDS WERE NEVER FAIR",
        "title": "CHEAT IF YOU DARE",
        "subtitle": "SKILL MOVES LEAVE EVIDENCE",
        "accent": PURPLE,
    },
    "beat_house": {
        "kicker": "CLIMB FROM ROADSIDE LIGHTS",
        "title": "BEAT THE HOUSE",
        "subtitle": "FACE ROURKE IN THE BACK ROOM",
        "accent": PINK,
    },
    "cta": {
        "kicker": "BEAT THE HOUSE",
        "title": "PLAY FREE IN YOUR BROWSER",
        "subtitle": "BEATTHEHOUSE.ITCH.IO/BEATTHEHOUSE",
        "accent": CYAN,
    },
}


def _font(size: int, condensed: bool = False) -> ImageFont.FreeTypeFont:
    candidates = (
        ["bahnschrift.ttf", "BebasNeue-Regular.ttf", "arialbd.ttf"]
        if condensed
        else ["consolab.ttf", "bahnschrift.ttf", "arialbd.ttf"]
    )
    for candidate in candidates:
        path = FONT_DIR / candidate
        if path.exists():
            return ImageFont.truetype(str(path), size=size)
    return ImageFont.load_default(size=size)


def _fit_font(
    draw: ImageDraw.ImageDraw,
    text: str,
    max_width: int,
    initial_size: int,
    minimum_size: int,
) -> ImageFont.FreeTypeFont:
    size = initial_size
    while size > minimum_size:
        font = _font(size, condensed=True)
        bounds = draw.textbbox((0, 0), text, font=font, stroke_width=max(1, size // 55))
        if bounds[2] - bounds[0] <= max_width:
            return font
        size -= 2
    return _font(minimum_size, condensed=True)


def _centered_text(
    base: Image.Image,
    text: str,
    y: int,
    font: ImageFont.FreeTypeFont,
    color: tuple[int, int, int, int],
    glow: tuple[int, int, int, int],
    stroke: int,
) -> None:
    draw = ImageDraw.Draw(base)
    bounds = draw.textbbox((0, 0), text, font=font, stroke_width=stroke)
    x = (base.width - (bounds[2] - bounds[0])) // 2

    glow_layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow_layer)
    glow_draw.text(
        (x, y),
        text,
        font=font,
        fill=glow,
        stroke_width=stroke + 3,
        stroke_fill=glow,
    )
    blurred = glow_layer.filter(ImageFilter.GaussianBlur(max(5, font.size // 14)))
    base.alpha_composite(blurred)

    crisp = ImageDraw.Draw(base)
    crisp.text(
        (x + 5, y + 6),
        text,
        font=font,
        fill=(0, 0, 0, 190),
        stroke_width=stroke,
        stroke_fill=(0, 0, 0, 230),
    )
    crisp.text(
        (x, y),
        text,
        font=font,
        fill=color,
        stroke_width=stroke,
        stroke_fill=(3, 5, 13, 255),
    )


def _draw_backdrop(image: Image.Image, accent: tuple[int, int, int, int], seed: int) -> None:
    draw = ImageDraw.Draw(image, "RGBA")
    width, height = image.size
    rng = random.Random(seed)

    draw.rectangle((0, 0, width, height), fill=BLACK)
    draw.rectangle(
        (width * 0.055, height * 0.09, width * 0.945, height * 0.91),
        fill=PANEL,
        outline=(accent[0], accent[1], accent[2], 210),
        width=max(3, width // 420),
    )
    draw.rectangle(
        (width * 0.075, height * 0.125, width * 0.925, height * 0.875),
        outline=(CYAN[0], CYAN[1], CYAN[2], 75),
        width=max(2, width // 650),
    )

    horizon = int(height * 0.68)
    for lane in range(-4, 5):
        start_x = width // 2 + lane * width // 16
        end_x = width // 2 + lane * width // 3
        lane_color = [PINK, CYAN, YELLOW, PURPLE][(lane + 4) % 4]
        draw.line(
            (start_x, horizon, end_x, height),
            fill=(lane_color[0], lane_color[1], lane_color[2], 42),
            width=max(2, width // 600),
        )
    for row in range(7):
        y = horizon + int((row / 6) ** 1.7 * (height - horizon))
        draw.line((0, y, width, y), fill=(CYAN[0], CYAN[1], CYAN[2], 28), width=2)

    for _ in range(max(24, width // 36)):
        x = rng.randrange(int(width * 0.07), int(width * 0.93))
        y = rng.randrange(int(height * 0.13), int(height * 0.84))
        color = rng.choice((PINK, CYAN, YELLOW, PURPLE))
        size = rng.choice((2, 3, 4, 7))
        draw.rectangle((x, y, x + size, y + size), fill=(color[0], color[1], color[2], 85))

    chip_radius = max(34, width // 24)
    chip_y = int(height * 0.50)
    for chip_x, chip_color in (
        (int(width * 0.12), PINK),
        (int(width * 0.88), CYAN),
    ):
        draw.ellipse(
            (chip_x - chip_radius, chip_y - chip_radius, chip_x + chip_radius, chip_y + chip_radius),
            fill=(chip_color[0], chip_color[1], chip_color[2], 20),
            outline=(chip_color[0], chip_color[1], chip_color[2], 130),
            width=max(3, width // 420),
        )
        inner = int(chip_radius * 0.64)
        draw.ellipse(
            (chip_x - inner, chip_y - inner, chip_x + inner, chip_y + inner),
            outline=(chip_color[0], chip_color[1], chip_color[2], 90),
            width=max(2, width // 700),
        )

    for y in range(0, height, max(4, height // 270)):
        draw.line((0, y, width, y), fill=(0, 0, 0, 32), width=1)


def _render_card(
    card_id: str,
    card: dict[str, object],
    width: int,
    height: int,
) -> Image.Image:
    image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    accent = card["accent"]
    assert isinstance(accent, tuple)
    draw = ImageDraw.Draw(image)

    vertical = height > width
    is_cta = card_id == "cta"
    is_logo = card_id == "logo"
    if is_cta:
        panel_box = (
            int(width * 0.06),
            int(height * (0.62 if not vertical else 0.68)),
            int(width * 0.94),
            int(height * (0.94 if not vertical else 0.91)),
        )
    elif is_logo:
        panel_box = (
            int(width * (0.16 if not vertical else 0.06)),
            int(height * 0.055),
            int(width * (0.84 if not vertical else 0.94)),
            int(height * (0.32 if not vertical else 0.23)),
        )
    else:
        panel_box = (
            int(width * (0.20 if not vertical else 0.05)),
            int(height * (0.68 if not vertical else 0.72)),
            int(width * (0.80 if not vertical else 0.95)),
            int(height * (0.94 if not vertical else 0.91)),
        )
    radius = max(12, width // 90)
    draw.rounded_rectangle(
        panel_box,
        radius=radius,
        fill=(4, 5, 11, 205),
        outline=(accent[0], accent[1], accent[2], 235),
        width=max(3, width // 420),
    )
    inner = (
        panel_box[0] + max(8, width // 150),
        panel_box[1] + max(8, width // 150),
        panel_box[2] - max(8, width // 150),
        panel_box[3] - max(8, width // 150),
    )
    draw.rounded_rectangle(
        inner,
        radius=max(8, radius - 4),
        outline=(CYAN[0], CYAN[1], CYAN[2], 95),
        width=max(2, width // 700),
    )

    max_text_width = int((panel_box[2] - panel_box[0]) * 0.88)
    title_size = int(height * (0.075 if not vertical else 0.043))
    title_min = int(height * (0.045 if not vertical else 0.028))
    title_font = _fit_font(draw, str(card["title"]), max_text_width, title_size, title_min)
    kicker_font = _fit_font(
        draw,
        str(card["kicker"]),
        max_text_width,
        int(height * (0.021 if not vertical else 0.014)),
        int(height * 0.014),
    )
    subtitle_font = _fit_font(
        draw,
        str(card["subtitle"]),
        max_text_width,
        int(height * (0.025 if not vertical else 0.016)),
        int(height * 0.015),
    )

    panel_height = panel_box[3] - panel_box[1]
    kicker_y = panel_box[1] + int(panel_height * 0.12)
    title_y = panel_box[1] + int(panel_height * 0.34)
    subtitle_y = panel_box[1] + int(panel_height * 0.70)
    _centered_text(image, str(card["kicker"]), kicker_y, kicker_font, SOFT, accent, 1)
    _centered_text(
        image,
        str(card["title"]),
        title_y,
        title_font,
        WHITE,
        accent,
        max(2, title_font.size // 50),
    )
    _centered_text(image, str(card["subtitle"]), subtitle_y, subtitle_font, accent, accent, 1)

    return image


def generate(output: Path) -> None:
    output.mkdir(parents=True, exist_ok=True)
    for card_id, card in CARDS.items():
        _render_card(card_id, card, 1920, 1080).save(
            output / f"{card_id}_1080p.png",
            optimize=True,
        )
        _render_card(card_id, card, 1080, 1920).save(
            output / f"{card_id}_vertical.png",
            optimize=True,
        )
        print(f"TRAILER_CARD {card_id}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    generate(args.output.resolve())


if __name__ == "__main__":
    main()
