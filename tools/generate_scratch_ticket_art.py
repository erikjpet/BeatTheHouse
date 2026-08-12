#!/usr/bin/env python3
"""Legacy generator for the unused *_background_v2.png scratch-ticket set.

This is intentionally deterministic. The scratch ticket renderer composes three
layers in-game:

1. background art: printed ticket face, all prices, top prizes, labels, rules,
   legends, serial/barcode dressing, and empty scratch wells;
2. result symbols: generated per purchased ticket by scripts/games/scratch_tickets.gd;
3. foil: generated per ticket by scripts/games/scratch_tickets.gd from these
   same regions plus scratch_foil_tile_v1.png.

The shipped *_background_pro.png art and its measured runtime geometry are not
produced here; use scratch_ticket_alignment_audit.py for that source of truth.
"""

from __future__ import annotations

import json
import math
import random
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Iterable

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
DATA_PATH = ROOT / "data" / "games" / "scratch_tickets.json"
LAYERS_DIR = ROOT / "assets" / "art" / "scratch_tickets" / "layers"
SYMBOLS_DIR = ROOT / "assets" / "art" / "scratch_tickets" / "reveal_symbols"
PREVIEW_DIR = ROOT / ".tmp" / "scratch_layout_review" / "generated_layers"

SIZES: dict[str, tuple[int, int]] = {
    "small_rectangle": (500, 224),
    "medium_square": (354, 356),
    "large_rectangle": (548, 356),
    "tall": (292, 366),
}

CROSSWORD_COLUMNS = 11
CROSSWORD_ROWS = 10
CROSSWORD_GRID = (0.06, 0.35, 0.50, 0.50)
CROSSWORD_BANK = (0.62, 0.38, 0.31, 0.44)
CROSSWORD_ENTRIES = [
    {"word": "CASH", "dir": "across", "x": 1, "y": 1},
    {"word": "HOUSE", "dir": "down", "x": 4, "y": 1},
    {"word": "SLOT", "dir": "across", "x": 4, "y": 4},
    {"word": "GOLD", "dir": "down", "x": 6, "y": 3},
    {"word": "LUCK", "dir": "across", "x": 2, "y": 7},
    {"word": "RISK", "dir": "across", "x": 1, "y": 9},
    {"word": "VAULT", "dir": "down", "x": 9, "y": 2},
]


@dataclass(frozen=True)
class TicketArt:
    ticket_id: str
    path_name: str
    title: str
    size_id: str
    price: int
    top_prize: int
    palette: dict[str, str]
    rules: list[str]
    legend: dict[str, int]


def hex_color(value: str, alpha: int = 255) -> tuple[int, int, int, int]:
    value = value.strip().lstrip("#")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), alpha)


def mix(a: tuple[int, int, int, int], b: tuple[int, int, int, int], t: float) -> tuple[int, int, int, int]:
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(4))  # type: ignore[return-value]


def rgba(rgb: tuple[int, int, int] | tuple[int, int, int, int], alpha: int = 255) -> tuple[int, int, int, int]:
    if len(rgb) == 4:
        return rgb  # type: ignore[return-value]
    return (rgb[0], rgb[1], rgb[2], alpha)


def font(size: int, bold: bool = False, condensed: bool = False) -> ImageFont.FreeTypeFont:
    candidates = []
    if condensed:
        candidates.extend([
            Path("C:/Windows/Fonts/impact.ttf"),
            Path("C:/Windows/Fonts/arialbd.ttf"),
        ])
    if bold:
        candidates.extend([
            Path("C:/Windows/Fonts/arialbd.ttf"),
            Path("C:/Windows/Fonts/seguibl.ttf"),
        ])
    candidates.extend([
        Path("C:/Windows/Fonts/arial.ttf"),
        Path("C:/Windows/Fonts/segoeui.ttf"),
    ])
    for candidate in candidates:
        if candidate.exists():
            return ImageFont.truetype(str(candidate), size)
    return ImageFont.load_default()


def text_bbox(draw: ImageDraw.ImageDraw, text: str, fnt: ImageFont.ImageFont) -> tuple[int, int, int, int]:
    return draw.textbbox((0, 0), text, font=fnt, stroke_width=0)


def center_text(
    draw: ImageDraw.ImageDraw,
    rect: tuple[float, float, float, float],
    text: str,
    size: int,
    fill: tuple[int, int, int, int],
    *,
    bold: bool = True,
    condensed: bool = False,
    stroke_fill: tuple[int, int, int, int] | None = None,
    stroke_width: int = 0,
    max_shrink: int = 5,
) -> None:
    if not text:
        return
    x, y, w, h = rect
    chosen = font(size, bold=bold, condensed=condensed)
    for trial in range(size, max_shrink - 1, -1):
        chosen = font(trial, bold=bold, condensed=condensed)
        bx = text_bbox(draw, text, chosen)
        if bx[2] - bx[0] <= w - 4 and bx[3] - bx[1] <= h - 2:
            break
    bx = text_bbox(draw, text, chosen)
    tx = x + (w - (bx[2] - bx[0])) / 2 - bx[0]
    ty = y + (h - (bx[3] - bx[1])) / 2 - bx[1]
    draw.text((tx, ty), text, font=chosen, fill=fill, stroke_fill=stroke_fill, stroke_width=stroke_width)


def label(draw: ImageDraw.ImageDraw, xy: tuple[float, float], text: str, size: int, fill, *, bold: bool = True, stroke=None) -> None:
    draw.text(xy, text, font=font(size, bold=bold), fill=fill, stroke_width=1 if stroke else 0, stroke_fill=stroke or fill)


def rect_abs(rect: tuple[float, float, float, float], size: tuple[int, int], pad: int = 0) -> tuple[int, int, int, int]:
    x, y, w, h = rect
    W, H = size
    return (round(x * W) + pad, round(y * H) + pad, round((x + w) * W) - pad, round((y + h) * H) - pad)


def rect_xywh(rect: tuple[float, float, float, float], size: tuple[int, int], pad: int = 0) -> tuple[int, int, int, int]:
    x1, y1, x2, y2 = rect_abs(rect, size, pad)
    return (x1, y1, x2 - x1, y2 - y1)


def normalize_rect_abs(box: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
    x1, y1, x2, y2 = box
    return (min(x1, x2), min(y1, y2), max(x1, x2), max(y1, y2))


def rounded(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], radius: int, fill, outline=None, width: int = 1) -> None:
    box = normalize_rect_abs(box)
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def star_points(cx: float, cy: float, outer: float, inner: float, points: int = 5, rotation: float = -math.pi / 2) -> list[tuple[float, float]]:
    out: list[tuple[float, float]] = []
    for i in range(points * 2):
        r = outer if i % 2 == 0 else inner
        angle = rotation + math.pi * i / points
        out.append((cx + math.cos(angle) * r, cy + math.sin(angle) * r))
    return out


def draw_halftone(draw: ImageDraw.ImageDraw, w: int, h: int, color, spacing: int, radius: int, *, offset: int = 0) -> None:
    for y in range(offset, h, spacing):
        for x in range((y // spacing % 2) * spacing // 2, w, spacing):
            draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=color)


def draw_burst(draw: ImageDraw.ImageDraw, w: int, h: int, center: tuple[float, float], color, count: int = 34) -> None:
    cx, cy = center
    for i in range(count):
        angle = i * math.tau / count
        r1 = min(w, h) * 0.08
        r2 = max(w, h) * 0.85
        p1 = (cx + math.cos(angle - 0.035) * r1, cy + math.sin(angle - 0.035) * r1)
        p2 = (cx + math.cos(angle + 0.035) * r1, cy + math.sin(angle + 0.035) * r1)
        p3 = (cx + math.cos(angle) * r2, cy + math.sin(angle) * r2)
        draw.polygon([p1, p2, p3], fill=color)


def draw_ticket_edge(draw: ImageDraw.ImageDraw, w: int, h: int, trim, dark) -> None:
    draw.rectangle((3, 3, w - 4, h - 4), outline=dark, width=2)
    draw.rectangle((8, 8, w - 9, h - 9), outline=trim, width=2)
    for x in range(16, w - 16, 18):
        draw.rectangle((x, 0, x + 6, 4), fill=trim)
        draw.rectangle((x, h - 4, x + 6, h), fill=trim)


def draw_price_badge(draw: ImageDraw.ImageDraw, price: int, trim, accent, dark) -> None:
    box = (10, 9, 54, 38)
    rounded(draw, box, 6, dark, trim, 2)
    center_text(draw, (box[0], box[1], box[2] - box[0], box[3] - box[1]), f"${price}", 18, (255, 255, 255, 255), stroke_fill=(0, 0, 0, 255), stroke_width=1)
    draw.rectangle((9, 39, 54, 43), fill=accent)


def draw_prize_ribbon(draw: ImageDraw.ImageDraw, w: int, y: int, text: str, trim, accent, dark, *, left: int = 70, right_margin: int = 28) -> None:
    x1 = left
    x2 = w - right_margin
    poly = [(x1, y + 6), (x1 + 14, y), (x2 - 14, y), (x2, y + 6), (x2 - 14, y + 30), (x1 + 14, y + 30)]
    draw.polygon([(x + 4, yy + 4) for x, yy in poly], fill=(0, 0, 0, 90))
    draw.polygon(poly, fill=trim, outline=dark)
    draw.rectangle((x1 + 18, y + 4, x2 - 18, y + 26), fill=accent, outline=dark, width=1)
    center_text(draw, (x1 + 20, y + 3, x2 - x1 - 40, 25), text, 17 if w > 400 else 14, (255, 255, 255, 255), condensed=True, stroke_fill=dark, stroke_width=1)


def draw_footer(draw: ImageDraw.ImageDraw, w: int, h: int, ink, trim, serial: str) -> None:
    draw.rectangle((14, h - 24, 64, h - 9), fill=(250, 250, 245, 255), outline=ink)
    center_text(draw, (14, h - 24, 50, 15), "VOID", 8, ink, bold=True)
    bar = (w // 2 - 64, h - 22, w // 2 + 64, h - 7)
    draw.rectangle(bar, fill=(255, 255, 255, 235), outline=(30, 30, 30, 255))
    rng = random.Random(serial)
    x = bar[0] + 6
    while x < bar[2] - 6:
        bw = rng.choice([1, 2, 3])
        draw.rectangle((x, bar[1] + 3, x + bw, bar[3] - 3), fill=(20, 20, 20, 180))
        x += rng.choice([3, 4, 5])
    center_text(draw, (bar[0], bar[3] - 2, bar[2] - bar[0], 11), serial, 7, ink, bold=False)
    label(draw, (w - 48, h - 23), serial[-3:], 8, ink, bold=True)
    draw.rectangle((4, h - 5, w - 5, h - 3), fill=trim)


def money(amount: int) -> str:
    return f"${amount:,}"


def draw_rules(draw: ImageDraw.ImageDraw, w: int, h: int, lines: list[str], ink, fill, *, y: int | None = None, compact: bool = False) -> None:
    height = 30 if compact else 48
    if y is None:
        y = h - height - 28
    box = (16, y, w - 16, y + height)
    rounded(draw, box, 5, fill, ink, 1)
    available = height - 10
    line_h = max(8, available // max(1, min(3, len(lines))))
    for i, rule in enumerate(lines[:3]):
        text = rule.replace("–", "-").replace("—", "-")
        label(draw, (box[0] + 8, box[1] + 6 + i * line_h), text[:88], 8 if not compact else 7, ink, bold=True)


def well(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], *, shape: str = "rect", fill=(255, 245, 190, 255), outline=(20, 20, 20, 255), trim=(255, 210, 70, 255), label_text: str = "") -> None:
    box = normalize_rect_abs(box)
    shadow = (box[0] + 3, box[1] + 3, box[2] + 3, box[3] + 3)
    if shape == "circle":
        draw.ellipse(shadow, fill=(0, 0, 0, 88))
        draw.ellipse(box, fill=fill, outline=outline, width=2)
        draw.ellipse((box[0] + 4, box[1] + 4, box[2] - 4, box[3] - 4), outline=trim, width=2)
    elif shape == "card":
        rounded(draw, shadow, 5, (0, 0, 0, 90))
        rounded(draw, box, 6, fill, outline, 2)
        draw.rectangle((box[0] + 4, box[1] + 4, box[2] - 4, box[3] - 4), outline=trim, width=1)
    else:
        rounded(draw, shadow, 5, (0, 0, 0, 90))
        rounded(draw, box, 6, fill, outline, 2)
        draw.rectangle((box[0] + 4, box[1] + 4, box[2] - 4, box[3] - 4), outline=trim, width=2)
    if label_text:
        center_text(draw, (box[0], box[1] - 13, box[2] - box[0], 12), label_text, 8, outline, bold=True, stroke_fill=(255, 255, 255, 180), stroke_width=1)


def crossword_cell_rect(column: int, row: int) -> tuple[float, float, float, float]:
    x, y, w, h = CROSSWORD_GRID
    return (x + column * w / CROSSWORD_COLUMNS, y + row * h / CROSSWORD_ROWS, w / CROSSWORD_COLUMNS, h / CROSSWORD_ROWS)


def crossword_bank_rect(index: int) -> tuple[float, float, float, float]:
    x, y, w, h = CROSSWORD_BANK
    cols, rows = 6, 3
    gap_x, gap_y = 0.006, 0.012
    cw = (w - gap_x * (cols - 1)) / cols
    ch = (h - gap_y * (rows - 1)) / rows
    col, row = index % cols, index // cols
    return (x + col * (cw + gap_x), y + row * (ch + gap_y), cw, ch)


def ticket_regions(ticket_id: str) -> list[tuple[str, tuple[float, float, float, float]]]:
    regions: list[tuple[str, tuple[float, float, float, float]]] = []
    if ticket_id == "two_fer":
        for i in range(3):
            regions.append(("SPOT %d" % (i + 1), (0.12 + i * 0.28, 0.50, 0.20, 0.24)))
    elif ticket_id == "lucky_7s":
        for i in range(2):
            regions.append(("WIN %d" % (i + 1), (0.075, 0.43 + i * 0.15, 0.135, 0.105)))
        for i in range(6):
            regions.append(("YOUR %d" % (i + 1), (0.38 + (i % 3) * 0.18, 0.42 + (i // 3) * 0.165, 0.145, 0.115)))
        regions.append(("BONUS", (0.28, 0.80, 0.18, 0.13)))
    elif ticket_id == "tic_tac_gold":
        for i in range(9):
            regions.append(("GRID %d" % (i + 1), (0.18 + (i % 3) * 0.18, 0.405 + (i // 3) * 0.135, 0.14, 0.105)))
        regions.append(("BONUS", (0.73, 0.45, 0.18, 0.18)))
    elif ticket_id == "crossword_corner":
        for i in range(18):
            regions.append(("LETTER %d" % (i + 1), crossword_bank_rect(i)))
        for col, row in sorted(crossword_occupied_cells()):
            regions.append(("GRID %d,%d" % (col + 1, row + 1), crossword_cell_rect(col, row)))
    elif ticket_id == "bonus_bingo":
        for i in range(24):
            regions.append(("CALL %d" % (i + 1), (0.06 + (i % 12) * 0.075, 0.27 + (i // 12) * 0.085, 0.055, 0.060)))
        for card in range(4):
            ox = 0.07 + card * 0.23
            for cell in range(25):
                regions.append(("CARD %d-%d" % (card + 1, cell + 1), (ox + (cell % 5) * 0.038, 0.55 + (cell // 5) * 0.052, 0.036, 0.046)))
    elif ticket_id == "high_roller_holdem":
        for i in range(5):
            regions.append(("YOUR CARD %d" % (i + 1), (0.16 + i * 0.135, 0.40, 0.105, 0.075)))
        for i in range(5):
            regions.append(("DEALER CARD %d" % (i + 1), (0.16 + i * 0.135, 0.55, 0.105, 0.075)))
        regions.append(("WILD", (0.15, 0.74, 0.70, 0.075)))
    elif ticket_id == "golden_vault":
        regions.append(("MULTIPLIER", (0.24, 0.405, 0.52, 0.075)))
        for i in range(5):
            regions.append(("RUNG %d" % (i + 1), (0.13, 0.535 + i * 0.055, 0.74, 0.045)))
        regions.append(("GOLD BAR", (0.13, 0.825, 0.34, 0.060)))
        regions.append(("FINAL VAULT", (0.53, 0.825, 0.34, 0.060)))
    return regions


def crossword_occupied_cells() -> set[tuple[int, int]]:
    cells: set[tuple[int, int]] = set()
    for entry in CROSSWORD_ENTRIES:
        for i in range(len(entry["word"])):
            cells.add((entry["x"] + (i if entry["dir"] == "across" else 0), entry["y"] + (0 if entry["dir"] == "across" else i)))
    return cells


def base(ticket: TicketArt, background: tuple[int, int, int, int], dark_overlay=(0, 0, 0, 0)) -> tuple[Image.Image, ImageDraw.ImageDraw, tuple[int, int]]:
    size = SIZES[ticket.size_id]
    img = Image.new("RGBA", size, background)
    d = ImageDraw.Draw(img, "RGBA")
    if dark_overlay[3] > 0:
        d.rectangle((0, 0, *size), fill=dark_overlay)
    return img, d, size


def draw_title(draw: ImageDraw.ImageDraw, w: int, title: str, y: int, fill, shadow=(0, 0, 0, 255), size: int = 52) -> None:
    center_text(draw, (16, y + 4, w - 32, size + 8), title.upper(), size, shadow, condensed=True, stroke_fill=shadow, stroke_width=2)
    center_text(draw, (14, y, w - 28, size + 8), title.upper(), size, fill, condensed=True, stroke_fill=shadow, stroke_width=2)


def draw_two_fer(ticket: TicketArt) -> Image.Image:
    img, d, (w, h) = base(ticket, (248, 61, 61, 255))
    draw_burst(d, w, h, (70, h // 2), (255, 215, 55, 58), 38)
    draw_halftone(d, w, h, (77, 12, 50, 56), 18, 2)
    draw_ticket_edge(d, w, h, (255, 222, 79, 255), (72, 21, 28, 255))
    draw_price_badge(d, ticket.price, (255, 220, 79, 255), (242, 52, 78, 255), (32, 22, 29, 255))
    draw_title(d, w, "TWO FER", 28, (255, 238, 145, 255), size=56)
    draw_prize_ribbon(d, w, 86, f"WIN UP TO {money(ticket.top_prize)}", (255, 218, 80, 255), (26, 142, 83, 255), (52, 25, 35, 255), left=150, right_margin=34)
    panel = (34, 108, w - 34, 184)
    rounded(d, panel, 16, (255, 240, 177, 255), (53, 29, 33, 255), 3)
    center_text(d, (panel[0], 112, panel[2] - panel[0], 16), "MATCH ANY TWO SYMBOLS", 12, (53, 29, 33, 255), stroke_fill=(255, 255, 255, 200), stroke_width=1)
    for label_text, r in ticket_regions(ticket.ticket_id):
        well(d, rect_abs(r, (w, h), 2), shape="rect", fill=(255, 245, 193, 255), outline=(46, 24, 31, 255), trim=(238, 45, 93, 255), label_text="")
    legends = [("CLOVER", 2), ("BELL", 4), ("STAR", 10), ("2FER", 50)]
    for i, (name, amount) in enumerate(legends):
        center_text(d, (55 + i * 100, h - 59, 88, 15), f"{name} {money(amount)}", 9, (255, 255, 255, 255), stroke_fill=(64, 23, 30, 255), stroke_width=1)
    draw_footer(d, w, h, (55, 28, 35, 255), (255, 218, 75, 255), "280-345625-002")
    return img


def draw_lucky_7s(ticket: TicketArt) -> Image.Image:
    img, d, (w, h) = base(ticket, (0, 140, 194, 255))
    draw_burst(d, w, h, (w * 0.52, h * 0.42), (255, 255, 255, 40), 42)
    draw_halftone(d, w, h, (0, 37, 68, 70), 15, 2)
    for i in range(22):
        x = 18 + (i * 47) % (w - 36)
        y = 46 + (i * 73) % (h - 90)
        d.polygon(star_points(x, y, 8, 3), fill=(255, 244, 94, 150))
    draw_ticket_edge(d, w, h, (255, 236, 67, 255), (10, 34, 70, 255))
    draw_price_badge(d, ticket.price, (255, 236, 67, 255), (242, 47, 93, 255), (14, 24, 55, 255))
    center_text(d, (66, 18, w - 88, 76), "LUCKY", 45, (255, 234, 96, 255), condensed=True, stroke_fill=(15, 26, 54, 255), stroke_width=3)
    center_text(d, (105, 68, w - 136, 80), "7s", 88, (235, 45, 78, 255), condensed=True, stroke_fill=(255, 232, 78, 255), stroke_width=2)
    draw_prize_ribbon(d, w, 116, f"TOP PRIZE {money(ticket.top_prize)}", (255, 233, 75, 255), (239, 45, 91, 255), (16, 26, 54, 255), left=166, right_margin=18)
    rounded(d, rect_abs((0.045, 0.395, 0.19, 0.31), (w, h), 0), 10, (236, 45, 89, 245), (255, 239, 66, 255), 3)
    center_text(d, (14, 139, 74, 18), "WINNING", 8, (255, 255, 255, 255), stroke_fill=(0, 0, 0, 255), stroke_width=1)
    rounded(d, rect_abs((0.34, 0.375, 0.59, 0.35), (w, h), 0), 13, (8, 56, 38, 245), (255, 239, 66, 255), 3)
    center_text(d, (126, 132, 198, 18), "YOUR NUMBERS", 10, (255, 255, 255, 255), stroke_fill=(0, 0, 0, 255), stroke_width=1)
    rounded(d, rect_abs((0.245, 0.765, 0.50, 0.18), (w, h), 0), 8, (11, 74, 115, 245), (255, 239, 66, 255), 3)
    center_text(d, (88, 273, 76, 18), "BONUS", 13, (255, 239, 66, 255), stroke_fill=(0, 0, 0, 255), stroke_width=1)
    label(d, (168, 286), "REVEAL A 7\nWIN $50", 9, (255, 255, 255, 255), bold=True, stroke=(0, 0, 0, 255))
    for txt, r in ticket_regions(ticket.ticket_id):
        section_shape = "circle" if not txt.startswith("BONUS") else "rect"
        well(d, rect_abs(r, (w, h), 2), shape=section_shape, fill=(15, 27, 50, 255), outline=(5, 10, 24, 255), trim=(255, 225, 59, 255))
    draw_footer(d, w, h, (9, 32, 66, 255), (255, 229, 63, 255), "280-345625-005")
    return img


def draw_tic_tac_gold(ticket: TicketArt) -> Image.Image:
    img, d, (w, h) = base(ticket, (3, 72, 38, 255))
    draw_burst(d, w, h, (w * 0.54, h * 0.50), (255, 221, 68, 48), 40)
    draw_halftone(d, w, h, (5, 20, 10, 80), 14, 2)
    for i in range(26):
        x = 24 + (i * 43) % (w - 48)
        y = 38 + (i * 61) % (h - 78)
        d.polygon(star_points(x, y, 7, 3), fill=(255, 219, 58, 165))
    draw_ticket_edge(d, w, h, (255, 219, 65, 255), (8, 30, 20, 255))
    draw_price_badge(d, ticket.price, (255, 219, 65, 255), (18, 133, 70, 255), (8, 22, 18, 255))
    draw_title(d, w, "TIC TAC", 24, (255, 235, 139, 255), size=37)
    draw_title(d, w, "GOLD", 64, (255, 207, 53, 255), size=50)
    draw_prize_ribbon(d, w, 121, f"TOP PRIZE {money(ticket.top_prize)}", (255, 222, 72, 255), (14, 115, 64, 255), (13, 28, 21, 255), left=178, right_margin=22)
    rounded(d, rect_abs((0.12, 0.365, 0.52, 0.42), (w, h), -6), 11, (9, 21, 28, 240), (255, 222, 72, 255), 3)
    center_text(d, (39, 132, 192, 16), "3 IN A ROW WINS PRINTED PRIZE", 8, (255, 255, 255, 255), stroke_fill=(0, 0, 0, 255), stroke_width=1)
    for txt, r in ticket_regions(ticket.ticket_id):
        if txt.startswith("GRID"):
            well(d, rect_abs(r, (w, h), 1), shape="rect", fill=(255, 239, 184, 255), outline=(12, 22, 29, 255), trim=(255, 222, 72, 255))
    rounded(d, rect_abs((0.70, 0.39, 0.24, 0.28), (w, h), -4), 18, (20, 55, 41, 245), (255, 222, 72, 255), 3)
    center_text(d, (251, 144, 73, 20), "BONUS", 12, (255, 222, 72, 255), stroke_fill=(0, 0, 0, 255), stroke_width=1)
    well(d, rect_abs((0.73, 0.45, 0.18, 0.18), (w, h), 2), shape="rect", fill=(255, 239, 184, 255), outline=(12, 22, 29, 255), trim=(255, 222, 72, 255))
    draw_rules(d, w, h, ["Full WIN line pays.", "Multiple lines add.", "BONUS is instant."], (9, 30, 20, 255), (255, 243, 185, 230), y=292, compact=True)
    draw_footer(d, w, h, (9, 30, 20, 255), (255, 222, 72, 255), "280-345625-010")
    return img


def draw_crossword(ticket: TicketArt) -> Image.Image:
    img, d, (w, h) = base(ticket, (230, 58, 84, 255))
    draw_halftone(d, w, h, (90, 0, 29, 70), 16, 3)
    draw_burst(d, w, h, (w * 0.18, h * 0.10), (255, 255, 255, 28), 34)
    draw_ticket_edge(d, w, h, (255, 238, 90, 255), (71, 22, 36, 255))
    draw_price_badge(d, ticket.price, (255, 238, 90, 255), (21, 151, 184, 255), (42, 22, 35, 255))
    draw_title(d, w, "CROSSWORD", 18, (255, 255, 255, 255), size=45)
    draw_title(d, w, "CORNER", 61, (255, 235, 115, 255), size=43)
    draw_prize_ribbon(d, w, 111, f"WIN UP TO {money(ticket.top_prize)}", (255, 234, 91, 255), (25, 152, 186, 255), (58, 25, 38, 255), left=302, right_margin=22)
    center_text(d, (54, 121, 250, 16), "COMPLETE HORIZONTAL OR VERTICAL WORDS", 10, (255, 255, 255, 255), stroke_fill=(60, 20, 37, 255), stroke_width=1)
    grid_box = rect_abs(CROSSWORD_GRID, (w, h), -4)
    rounded(d, grid_box, 4, (11, 32, 49, 255), (255, 238, 90, 255), 3)
    occupied = crossword_occupied_cells()
    for row in range(CROSSWORD_ROWS):
        for col in range(CROSSWORD_COLUMNS):
            box = rect_abs(crossword_cell_rect(col, row), (w, h), 1)
            if (col, row) in occupied:
                d.rectangle(box, fill=(230, 255, 246, 255), outline=(28, 61, 63, 255), width=1)
            else:
                d.rectangle(box, fill=(25, 34, 45, 255), outline=(49, 60, 72, 255), width=1)
    for idx, entry in enumerate(CROSSWORD_ENTRIES, start=1):
        cell = rect_abs(crossword_cell_rect(entry["x"], entry["y"]), (w, h), 1)
        label(d, (cell[0] + 1, cell[1] + 0), str(idx), 6, (41, 63, 70, 255), bold=True)
    bank_box = rect_abs(CROSSWORD_BANK, (w, h), -7)
    rounded(d, bank_box, 5, (8, 38, 65, 255), (255, 238, 90, 255), 3)
    center_text(d, (bank_box[0], bank_box[1] - 19, bank_box[2] - bank_box[0], 18), "YOUR 18 LETTERS", 11, (255, 255, 255, 255), stroke_fill=(42, 22, 35, 255), stroke_width=1)
    for i in range(18):
        d.rectangle(rect_abs(crossword_bank_rect(i), (w, h), 1), fill=(216, 250, 255, 255), outline=(20, 55, 76, 255), width=1)
    legend_y = h - 61
    rounded(d, (28, legend_y, w - 28, legend_y + 30), 4, (255, 246, 204, 255), (58, 25, 38, 255), 2)
    legend_text = "PRIZE LEGEND   " + "   ".join(f"{k} WORDS {money(v)}" for k, v in ticket.legend.items())
    center_text(d, (34, legend_y + 3, w - 68, 24), legend_text, 10, (36, 45, 47, 255), bold=True)
    draw_footer(d, w, h, (45, 25, 36, 255), (255, 238, 90, 255), "280-345625-015")
    return img


def draw_bingo(ticket: TicketArt) -> Image.Image:
    img, d, (w, h) = base(ticket, (29, 126, 71, 255))
    draw_halftone(d, w, h, (5, 38, 22, 82), 19, 3)
    for i in range(24):
        x = 18 + (i * 71) % (w - 36)
        y = 44 + (i * 47) % (h - 90)
        d.ellipse((x - 7, y - 7, x + 7, y + 7), fill=(255, 214, 68, 70), outline=(255, 255, 255, 60))
    draw_ticket_edge(d, w, h, (255, 219, 75, 255), (9, 55, 32, 255))
    draw_price_badge(d, ticket.price, (255, 219, 75, 255), (22, 147, 82, 255), (8, 35, 24, 255))
    draw_title(d, w, "BONUS BINGO", 25, (255, 233, 83, 255), size=46)
    draw_prize_ribbon(d, w, 85, f"TOP PRIZE {money(ticket.top_prize)}", (255, 219, 75, 255), (245, 93, 45, 255), (8, 35, 24, 255), left=328, right_margin=18)
    rounded(d, rect_abs((0.045, 0.245, 0.91, 0.22), (w, h), -4), 9, (239, 255, 231, 245), (255, 219, 75, 255), 3)
    center_text(d, (34, 87, 270, 18), "CALLER NUMBERS", 11, (8, 54, 31, 255), bold=True)
    for txt, r in ticket_regions(ticket.ticket_id):
        if txt.startswith("CALL"):
            well(d, rect_abs(r, (w, h), 1), shape="circle", fill=(255, 248, 215, 255), outline=(8, 54, 31, 255), trim=(255, 219, 75, 255))
    for card in range(4):
        card_box = rect_abs((0.055 + card * 0.23, 0.505, 0.215, 0.34), (w, h), 0)
        rounded(d, card_box, 5, (238, 255, 233, 255), (7, 57, 32, 255), 3)
        center_text(d, (card_box[0], card_box[1] + 2, card_box[2] - card_box[0], 17), f"CARD {card + 1}", 9, (7, 57, 32, 255), bold=True)
        for letter_i, letter_char in enumerate("BINGO"):
            x = card_box[0] + 8 + letter_i * ((card_box[2] - card_box[0] - 16) / 5)
            center_text(d, (x, card_box[1] + 18, (card_box[2] - card_box[0] - 16) / 5, 11), letter_char, 7, (234, 78, 42, 255))
        for cell in range(25):
            r = (0.07 + card * 0.23 + (cell % 5) * 0.038, 0.55 + (cell // 5) * 0.052, 0.036, 0.046)
            d.rectangle(rect_abs(r, (w, h), 1), fill=(255, 255, 242, 255), outline=(18, 62, 40, 255), width=1)
            if cell == 12:
                center_text(d, rect_xywh(r, (w, h), 1), "FREE", 5, (205, 53, 39, 255), bold=True)
    draw_rules(d, w, h, ["Reveal 24 caller numbers.", "Every completed line pays.", "Blackout wins large prize."], (8, 47, 29, 255), (255, 241, 190, 235), y=h - 66, compact=True)
    draw_footer(d, w, h, (8, 47, 29, 255), (255, 219, 75, 255), "280-345625-020")
    return img


def draw_holdem(ticket: TicketArt) -> Image.Image:
    img, d, (w, h) = base(ticket, (50, 16, 65, 255))
    draw_burst(d, w, h, (w * 0.50, h * 0.43), (255, 255, 255, 28), 36)
    draw_halftone(d, w, h, (0, 0, 0, 60), 16, 2)
    for i, suit in enumerate(["♠", "♥", "♣", "♦"] * 6):
        x = 19 + (i * 41) % (w - 38)
        y = 78 + (i * 57) % (h - 122)
        label(d, (x, y), suit, 29, (245, 70, 74, 115) if suit in "♥♦" else (12, 13, 19, 150), bold=True)
    draw_ticket_edge(d, w, h, (229, 188, 73, 255), (23, 15, 30, 255))
    draw_price_badge(d, ticket.price, (229, 188, 73, 255), (154, 38, 70, 255), (23, 15, 30, 255))
    draw_title(d, w, "HIGH ROLLER", 28, (255, 235, 142, 255), size=39)
    draw_title(d, w, "HOLD'EM", 70, (255, 220, 92, 255), size=45)
    draw_prize_ribbon(d, w, 125, f"TOP PRIZE {money(ticket.top_prize)}", (229, 188, 73, 255), (143, 43, 82, 255), (23, 15, 30, 255), left=42, right_margin=24)
    rounded(d, rect_abs((0.09, 0.365, 0.82, 0.15), (w, h), -5), 10, (18, 83, 55, 245), (229, 188, 73, 255), 3)
    center_text(d, (28, 134, w - 56, 16), "YOUR HAND", 10, (255, 238, 165, 255), stroke_fill=(0, 0, 0, 255), stroke_width=1)
    rounded(d, rect_abs((0.09, 0.515, 0.82, 0.15), (w, h), -5), 10, (41, 25, 31, 245), (229, 188, 73, 255), 3)
    center_text(d, (28, 189, w - 56, 16), "DEALER'S HAND", 10, (255, 238, 165, 255), stroke_fill=(0, 0, 0, 255), stroke_width=1)
    for txt, r in ticket_regions(ticket.ticket_id):
        shape = "card" if "CARD" in txt else "rect"
        well(d, rect_abs(r, (w, h), 1), shape=shape, fill=(255, 246, 216, 255), outline=(32, 22, 27, 255), trim=(229, 188, 73, 255))
    rounded(d, rect_abs((0.12, 0.715, 0.76, 0.14), (w, h), -4), 8, (27, 15, 30, 245), (229, 188, 73, 255), 3)
    center_text(d, (31, 263, w - 62, 15), "WILD / POCKET ACES", 9, (255, 238, 165, 255), stroke_fill=(0, 0, 0, 255), stroke_width=1)
    draw_rules(d, w, h, ["Reveal both hands.", "Beat dealer to win.", "Wild improves hand."], (26, 15, 30, 255), (255, 239, 188, 230), y=306, compact=True)
    draw_footer(d, w, h, (26, 15, 30, 255), (229, 188, 73, 255), "280-345625-050")
    return img


def draw_golden_vault(ticket: TicketArt) -> Image.Image:
    img, d, (w, h) = base(ticket, (15, 15, 22, 255))
    for r in range(8):
        d.ellipse((w * 0.5 - 48 - r * 24, 24 - r * 18, w * 0.5 + 48 + r * 24, 120 + r * 34), outline=(213, 165, 64, 44), width=3)
    draw_halftone(d, w, h, (215, 166, 60, 52), 17, 2)
    for i in range(34):
        x = 15 + (i * 37) % (w - 30)
        y = 28 + (i * 53) % (h - 60)
        d.ellipse((x - 3, y - 3, x + 3, y + 3), fill=(255, 209, 83, 150))
    draw_ticket_edge(d, w, h, (255, 220, 92, 255), (18, 17, 25, 255))
    draw_price_badge(d, ticket.price, (255, 220, 92, 255), (107, 73, 25, 255), (18, 17, 25, 255))
    draw_title(d, w, "GOLDEN", 32, (255, 232, 128, 255), size=44)
    draw_title(d, w, "VAULT", 76, (255, 216, 70, 255), size=53)
    draw_prize_ribbon(d, w, 128, f"TOP PRIZE {money(ticket.top_prize)}", (255, 220, 92, 255), (132, 89, 27, 255), (18, 17, 25, 255), left=42, right_margin=24)
    d.rectangle((44, 156, w - 44, 184), fill=(95, 61, 19, 255), outline=(255, 220, 92, 255), width=2)
    center_text(d, (44, 150, w - 88, 18), "YOUR MULTIPLIER", 9, (255, 241, 163, 255), stroke_fill=(0, 0, 0, 255), stroke_width=1)
    well(d, rect_abs((0.24, 0.405, 0.52, 0.075), (w, h), 1), shape="rect", fill=(38, 25, 23, 255), outline=(14, 13, 18, 255), trim=(255, 220, 92, 255))
    rounded(d, rect_abs((0.10, 0.50, 0.80, 0.315), (w, h), -5), 10, (36, 26, 21, 245), (255, 220, 92, 255), 3)
    center_text(d, (34, 185, w - 68, 17), "CASH LADDER", 10, (255, 241, 163, 255), stroke_fill=(0, 0, 0, 255), stroke_width=1)
    for txt, r in ticket_regions(ticket.ticket_id):
        if txt.startswith("RUNG"):
            well(d, rect_abs(r, (w, h), 1), shape="rect", fill=(46, 31, 23, 255), outline=(12, 11, 16, 255), trim=(255, 220, 92, 255))
    center_text(d, rect_xywh((0.13, 0.798, 0.34, 0.020), (w, h)), "GOLD BAR", 8, (255, 241, 163, 255), stroke_fill=(0, 0, 0, 255), stroke_width=1)
    center_text(d, rect_xywh((0.53, 0.798, 0.34, 0.020), (w, h)), "FINAL VAULT", 8, (255, 241, 163, 255), stroke_fill=(0, 0, 0, 255), stroke_width=1)
    well(d, rect_abs((0.13, 0.825, 0.34, 0.060), (w, h), 1), shape="rect", fill=(48, 31, 24, 255), outline=(12, 11, 16, 255), trim=(255, 220, 92, 255))
    well(d, rect_abs((0.53, 0.825, 0.34, 0.060), (w, h), 1), shape="rect", fill=(48, 31, 24, 255), outline=(12, 11, 16, 255), trim=(255, 220, 92, 255))
    rule_band = (14, 328, w - 14, 339)
    rounded(d, rule_band, 3, (18, 17, 25, 215), (255, 220, 92, 255), 1)
    center_text(d, (rule_band[0] + 3, rule_band[1], rule_band[2] - rule_band[0] - 6, rule_band[3] - rule_band[1]), "Rungs pay multiplier • Gold bar wins ladder • Final vault top prize", 6, (255, 238, 168, 255), bold=True)
    draw_footer(d, w, h, (255, 238, 168, 255), (255, 220, 92, 255), "280-345625-100")
    return img


BACKGROUND_RENDERERS: dict[str, Callable[[TicketArt], Image.Image]] = {
    "two_fer": draw_two_fer,
    "lucky_7s": draw_lucky_7s,
    "tic_tac_gold": draw_tic_tac_gold,
    "crossword_corner": draw_crossword,
    "bonus_bingo": draw_bingo,
    "high_roller_holdem": draw_holdem,
    "golden_vault": draw_golden_vault,
}


def symbol_canvas() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img, "RGBA")


def save_symbol(name: str, draw_fn: Callable[[ImageDraw.ImageDraw], None]) -> None:
    img, d = symbol_canvas()
    draw_fn(d)
    img = img.filter(ImageFilter.UnsharpMask(radius=0.4, percent=120, threshold=2))
    img.save(SYMBOLS_DIR / f"{name}.png")


def generate_symbols() -> None:
    """Generate high-legibility reveal icons.

    Runtime overlays the actual numbers, letters, and card ranks, so these
    assets should read as unmistakable icon backplates at tiny in-game sizes:
    big silhouettes, thick outlines, and quiet interiors behind text.
    """
    SYMBOLS_DIR.mkdir(parents=True, exist_ok=True)

    def plaque(d, box, fill, outline, width: int = 6, radius: int = 12):
        rounded(d, (box[0] + 5, box[1] + 6, box[2] + 5, box[3] + 6), radius, (0, 0, 0, 105))
        rounded(d, box, radius, fill, outline, width)

    def coin(d, fill, outline, inner=(255, 255, 255, 115)):
        d.ellipse((9, 10, 119, 120), fill=(0, 0, 0, 90))
        d.ellipse((7, 5, 117, 115), fill=fill, outline=outline, width=7)
        d.ellipse((23, 21, 101, 99), fill=mix(fill, (255, 255, 255, 255), 0.18), outline=inner, width=5)

    def centered_word(d, text, fill, stroke, y=39, size=32):
        center_text(d, (12, y, 104, 44), text, size, fill, condensed=True, stroke_fill=stroke, stroke_width=3)

    save_symbol("number_coin", lambda d: (coin(d, (255, 221, 82, 255), (59, 38, 12, 255)), d.rectangle((40, 58, 88, 69), fill=(97, 65, 17, 180))))
    save_symbol("winning_star", lambda d: (coin(d, (235, 39, 83, 255), (255, 234, 61, 255)), d.polygon(star_points(64, 62, 43, 19), fill=(255, 241, 78, 255), outline=(57, 28, 12, 255))))
    save_symbol("lucky_seven", lambda d: (coin(d, (19, 78, 40, 255), (255, 230, 62, 255)), center_text(d, (22, 12, 84, 88), "7", 82, (246, 33, 67, 255), condensed=True, stroke_fill=(255, 238, 92, 255), stroke_width=4)))
    save_symbol("clover", lambda d: (coin(d, (23, 126, 58, 255), (255, 233, 71, 255)), [d.ellipse(b, fill=(18, 207, 81, 255), outline=(5, 72, 28, 255), width=5) for b in [(26, 24, 66, 64), (62, 24, 102, 64), (26, 59, 66, 99), (62, 59, 102, 99)]], d.rectangle((59, 75, 70, 108), fill=(5, 72, 28, 255))))
    save_symbol("bell", lambda d: (coin(d, (255, 213, 78, 255), (87, 52, 14, 255)), d.pieslice((29, 24, 99, 106), 190, 350, fill=(255, 236, 99, 255), outline=(86, 48, 13, 255), width=6), d.rectangle((25, 83, 103, 100), fill=(230, 157, 33, 255), outline=(86, 48, 13, 255), width=5), d.ellipse((55, 95, 73, 113), fill=(86, 48, 13, 255))))
    save_symbol("star", lambda d: (coin(d, (27, 75, 163, 255), (255, 232, 69, 255)), d.polygon(star_points(64, 62, 45, 20), fill=(255, 245, 90, 255), outline=(58, 43, 7, 255))))
    save_symbol("twofer", lambda d: (coin(d, (239, 46, 79, 255), (255, 226, 68, 255)), centered_word(d, "2FER", (255, 255, 255, 255), (57, 17, 25, 255), 39, 33)))
    save_symbol("gold_coin", lambda d: (coin(d, (255, 211, 65, 255), (94, 59, 13, 255)), d.polygon(star_points(64, 62, 34, 15), fill=(255, 246, 142, 235), outline=(122, 80, 18, 255))))
    save_symbol("miss_cross", lambda d: (coin(d, (38, 45, 55, 255), (139, 147, 162, 255)), d.line((34, 34, 94, 94), fill=(255, 255, 255, 235), width=15), d.line((94, 34, 34, 94), fill=(255, 255, 255, 235), width=15)))
    save_symbol("dust", lambda d: (coin(d, (127, 108, 76, 255), (63, 52, 34, 255)), centered_word(d, "MISS", (249, 226, 151, 255), (50, 41, 28, 255), 42, 27)))
    save_symbol("gold_bar", lambda d: (d.rectangle((17, 69, 111, 102), fill=(0, 0, 0, 95)), d.polygon([(13, 51), (97, 51), (113, 91), (29, 91)], fill=(255, 211, 59, 255), outline=(91, 55, 8, 255)), d.polygon([(32, 28), (83, 28), (99, 51), (15, 51)], fill=(255, 239, 118, 255), outline=(91, 55, 8, 255)), centered_word(d, "GOLD", (74, 45, 8, 255), (255, 246, 153, 255), 51, 24)))
    save_symbol("brass_bar", lambda d: (d.rectangle((17, 69, 111, 102), fill=(0, 0, 0, 95)), d.polygon([(13, 51), (97, 51), (113, 91), (29, 91)], fill=(165, 101, 43, 255), outline=(60, 38, 21, 255)), d.polygon([(32, 28), (83, 28), (99, 51), (15, 51)], fill=(206, 145, 68, 255), outline=(60, 38, 21, 255)), centered_word(d, "BRASS", (255, 230, 158, 255), (55, 36, 20, 255), 52, 22)))
    save_symbol("letter_tile", lambda d: plaque(d, (10, 10, 118, 118), (220, 250, 255, 255), (8, 57, 80, 255), 7, 10))
    save_symbol("crossword_cell", lambda d: plaque(d, (9, 9, 119, 119), (255, 248, 214, 255), (28, 55, 59, 255), 7, 7))
    save_symbol("bingo_ball", lambda d: (d.ellipse((8, 9, 120, 121), fill=(0, 0, 0, 85)), d.ellipse((6, 5, 118, 117), fill=(255, 247, 220, 255), outline=(18, 96, 50, 255), width=7), d.ellipse((31, 30, 93, 92), fill=(255, 255, 250, 255), outline=(255, 179, 47, 255), width=6)))
    save_symbol("bingo_cell", lambda d: plaque(d, (8, 8, 120, 120), (255, 255, 242, 255), (12, 76, 38, 255), 7, 8))
    save_symbol("cash_stack", lambda d: ([rounded(d, (17, 33 + i * 14, 111, 68 + i * 14), 6, (39, 159, 77, 255), (6, 66, 28, 255), 4) for i in range(3)], center_text(d, (21, 46, 86, 44), "$", 48, (255, 242, 118, 255), stroke_fill=(5, 61, 27, 255), stroke_width=3)))
    save_symbol("multiplier_coin", lambda d: (coin(d, (255, 214, 74, 255), (67, 42, 13, 255)), centered_word(d, "X", (67, 42, 13, 255), (255, 246, 151, 255), 36, 48)))
    save_symbol("vault_sealed", lambda d: (plaque(d, (14, 18, 114, 112), (29, 32, 40, 255), (204, 164, 68, 255), 6, 12), d.ellipse((38, 37, 90, 89), outline=(238, 192, 79, 255), width=9), d.line((46, 46, 82, 82), fill=(238, 192, 79, 255), width=6), d.line((82, 46, 46, 82), fill=(238, 192, 79, 255), width=6)))
    save_symbol("vault_open", lambda d: (plaque(d, (10, 24, 84, 114), (31, 34, 42, 255), (202, 162, 65, 255), 5, 10), plaque(d, (64, 17, 119, 106), (100, 77, 32, 255), (255, 217, 82, 255), 5, 10), d.polygon(star_points(58, 66, 29, 13), fill=(255, 239, 88, 235), outline=(105, 70, 14, 255))))
    save_symbol("wild_card", lambda d: (plaque(d, (20, 9, 108, 119), (34, 22, 42, 255), (242, 199, 72, 255), 6, 8), centered_word(d, "WILD", (255, 245, 177, 255), (0, 0, 0, 255), 42, 27)))
    save_symbol("card_red", lambda d: (plaque(d, (18, 8, 110, 120), (255, 247, 228, 255), (145, 24, 41, 255), 6, 8), center_text(d, (26, 33, 76, 58), "H", 54, (199, 30, 47, 255), stroke_fill=(255, 255, 255, 255), stroke_width=3)))
    save_symbol("card_black", lambda d: (plaque(d, (18, 8, 110, 120), (255, 247, 228, 255), (18, 19, 27, 255), 6, 8), center_text(d, (26, 33, 76, 58), "S", 54, (18, 19, 27, 255), stroke_fill=(255, 255, 255, 255), stroke_width=3)))


def generate_foil_tile() -> None:
    rng = random.Random(1801)
    img = Image.new("RGBA", (64, 64), (185, 192, 202, 255))
    d = ImageDraw.Draw(img, "RGBA")
    for y in range(64):
        for x in range(64):
            base_v = 168 + ((x * 3 + y * 5) % 43) + rng.randint(-11, 11)
            img.putpixel((x, y), (max(120, min(235, base_v)), max(120, min(238, base_v + 4)), max(130, min(245, base_v + 13)), 255))
    for i in range(34):
        x = rng.randint(-10, 64)
        y = rng.randint(0, 64)
        d.line((x, y, x + rng.randint(12, 36), y + rng.randint(-4, 4)), fill=(255, 255, 255, 80), width=1)
    for i in range(20):
        x = rng.randint(0, 64)
        y = rng.randint(0, 64)
        d.ellipse((x - 1, y - 1, x + 2, y + 2), fill=(95, 103, 114, 70))
    img.save(LAYERS_DIR / "scratch_foil_tile_v1.png")


def make_ticket(row: dict) -> TicketArt:
    prize_table = row.get("prize_table", [])
    top = max(int(p.get("payout", 0)) for p in prize_table)
    mechanic = row.get("mechanic", {})
    face = row.get("face", {})
    return TicketArt(
        ticket_id=row["id"],
        path_name=f"{row['id']}_background_v2.png",
        title=row["display_name"],
        size_id=row["size_id"],
        price=int(row["price"]),
        top_prize=top,
        palette=face.get("palette", {}),
        rules=list(mechanic.get("rules", [])),
        legend={str(k): int(v) for k, v in mechanic.get("legend", {}).items()},
    )


def save_previews(tickets: list[TicketArt]) -> None:
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    thumbs: list[Image.Image] = []
    for ticket in tickets:
        bg = Image.open(LAYERS_DIR / ticket.path_name).convert("RGBA")
        size = bg.size
        symbols = Image.new("RGBA", size, (0, 0, 0, 0))
        ds = ImageDraw.Draw(symbols, "RGBA")
        for index, (name, region) in enumerate(ticket_regions(ticket.ticket_id)):
            box = rect_abs(region, size, 2)
            if ticket.ticket_id == "crossword_corner" and name.startswith("GRID"):
                rounded(ds, box, 2, (245, 238, 198, 255), (37, 61, 65, 255), 1)
                center_text(ds, (box[0], box[1], box[2] - box[0], box[3] - box[1]), chr(65 + index % 26), 9, (28, 44, 46, 255), bold=True)
            elif ticket.ticket_id == "bonus_bingo" and ("CARD" in name or "CALL" in name):
                center_text(ds, (box[0], box[1], box[2] - box[0], box[3] - box[1]), str((index * 7) % 75 + 1), 8, (16, 58, 34, 255), bold=True)
            else:
                rounded(ds, box, 5, (255, 232, 99, 230), (32, 22, 28, 255), 1)
                center_text(ds, (box[0], box[1], box[2] - box[0], box[3] - box[1]), "SYM", 8, (34, 28, 28, 255), bold=True)
        foil = Image.new("RGBA", size, (0, 0, 0, 0))
        df = ImageDraw.Draw(foil, "RGBA")
        for _, region in ticket_regions(ticket.ticket_id):
            box = rect_abs(region, size, 0)
            rounded(df, box, 5, (176, 188, 201, 230), (255, 255, 255, 145), 1)
            for x in range(box[0] + 4, box[2], 12):
                df.line((x, box[1] + 2, x + 10, box[3] - 2), fill=(255, 255, 255, 80), width=1)
        trip = Image.new("RGBA", (size[0] * 3 + 24, size[1] + 34), (16, 17, 23, 255))
        for col, (label_text, layer) in enumerate([("BACKGROUND", bg), ("+ SYMBOLS", Image.alpha_composite(bg, symbols)), ("+ FOIL", Image.alpha_composite(Image.alpha_composite(bg, symbols), foil))]):
            x = col * (size[0] + 12)
            trip.alpha_composite(layer, (x, 26))
            ImageDraw.Draw(trip).text((x + 4, 6), f"{ticket.ticket_id} {label_text}", font=font(12, True), fill=(235, 235, 235, 255))
        out = PREVIEW_DIR / f"{ticket.ticket_id}_three_layers.png"
        trip.save(out)
        thumbs.append(trip.resize((trip.width // 2, trip.height // 2)))
    sheet_w = max(t.width for t in thumbs)
    sheet_h = sum(t.height + 18 for t in thumbs) + 16
    sheet = Image.new("RGBA", (sheet_w, sheet_h), (14, 15, 21, 255))
    y = 8
    for thumb in thumbs:
        sheet.alpha_composite(thumb, (0, y))
        y += thumb.height + 18
    sheet.save(PREVIEW_DIR / "all_generated_three_layers.png")


def main() -> None:
    LAYERS_DIR.mkdir(parents=True, exist_ok=True)
    tickets = [make_ticket(row) for row in json.loads(DATA_PATH.read_text(encoding="utf-8"))]
    for ticket in tickets:
        renderer = BACKGROUND_RENDERERS[ticket.ticket_id]
        img = renderer(ticket).filter(ImageFilter.UnsharpMask(radius=0.35, percent=110, threshold=2))
        img.save(LAYERS_DIR / ticket.path_name)
    generate_symbols()
    generate_foil_tile()
    save_previews(tickets)
    print(f"Generated {len(tickets)} ticket backgrounds, reveal symbols, foil tile, and previews under {PREVIEW_DIR}")


if __name__ == "__main__":
    main()
