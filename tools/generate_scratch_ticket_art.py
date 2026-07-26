#!/usr/bin/env python3
"""Generate production scratch-ticket art from the actual gameplay layouts.

This is intentionally deterministic. The scratch ticket renderer composes three
layers in-game:

1. background art: printed ticket face, all prices, top prizes, labels, rules,
   legends, serial/barcode dressing, and empty scratch wells;
2. result symbols: generated per purchased ticket by scripts/games/scratch_tickets.gd;
3. foil: generated per ticket by scripts/games/scratch_tickets.gd from these
   same regions plus scratch_foil_tile_v1.png.

The layout constants below mirror ScratchTickets._ticket_art_regions. If those
GDScript regions change, update this file in the same commit so the artwork and
mechanics continue to agree 1:1.
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
    height = 36 if compact else 48
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
            regions.append(("SPOT %d" % (i + 1), (0.12 + i * 0.28, 0.42, 0.20, 0.30)))
    elif ticket_id == "lucky_7s":
        for i in range(2):
            regions.append(("WIN %d" % (i + 1), (0.07, 0.35 + i * 0.15, 0.13, 0.11)))
        for i in range(6):
            regions.append(("YOUR %d" % (i + 1), (0.39 + (i % 3) * 0.18, 0.34 + (i // 3) * 0.17, 0.14, 0.12)))
        regions.append(("BONUS", (0.29, 0.78, 0.17, 0.15)))
    elif ticket_id == "tic_tac_gold":
        for i in range(9):
            regions.append(("GRID %d" % (i + 1), (0.18 + (i % 3) * 0.18, 0.37 + (i // 3) * 0.16, 0.14, 0.13)))
        regions.append(("BONUS", (0.73, 0.43, 0.18, 0.22)))
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
            regions.append(("YOUR CARD %d" % (i + 1), (0.18 + i * 0.13, 0.43, 0.10, 0.075)))
        for i in range(5):
            regions.append(("DEALER CARD %d" % (i + 1), (0.18 + i * 0.13, 0.55, 0.10, 0.075)))
        regions.append(("WILD", (0.16, 0.79, 0.68, 0.08)))
    elif ticket_id == "golden_vault":
        regions.append(("MULTIPLIER", (0.24, 0.47, 0.52, 0.07)))
        for i in range(5):
            regions.append(("RUNG %d" % (i + 1), (0.13, 0.63 + i * 0.046, 0.74, 0.038)))
        regions.append(("GOLD BAR", (0.14, 0.88, 0.32, 0.052)))
        regions.append(("FINAL VAULT", (0.50, 0.88, 0.34, 0.052)))
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
    draw_prize_ribbon(d, w, 86, f"WIN UP TO {money(ticket.top_prize)}", (255, 218, 80, 255), (26, 142, 83, 255), (52, 25, 35, 255), left=166, right_margin=34)
    panel = (36, 116, w - 36, 188)
    rounded(d, panel, 16, (255, 240, 177, 255), (53, 29, 33, 255), 3)
    center_text(d, (panel[0], 104, panel[2] - panel[0], 18), "MATCH ANY TWO SYMBOLS", 14, (53, 29, 33, 255), stroke_fill=(255, 255, 255, 200), stroke_width=1)
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
    rounded(d, rect_abs((0.045, 0.325, 0.18, 0.33), (w, h), 0), 10, (236, 45, 89, 255), (255, 239, 66, 255), 3)
    center_text(d, (18, 114, 65, 18), "WINNING", 8, (255, 255, 255, 255), stroke_fill=(0, 0, 0, 255), stroke_width=1)
    rounded(d, rect_abs((0.35, 0.29, 0.57, 0.37), (w, h), 0), 13, (8, 56, 38, 245), (255, 239, 66, 255), 3)
    center_text(d, (136, 107, 187, 18), "YOUR NUMBERS", 10, (255, 255, 255, 255), stroke_fill=(0, 0, 0, 255), stroke_width=1)
    rounded(d, rect_abs((0.25, 0.745, 0.45, 0.19), (w, h), 0), 8, (11, 74, 115, 245), (255, 239, 66, 255), 3)
    center_text(d, (92, 265, 68, 20), "BONUS", 14, (255, 239, 66, 255), stroke_fill=(0, 0, 0, 255), stroke_width=1)
    label(d, (164, 286), "REVEAL A 7\nWIN $50", 10, (255, 255, 255, 255), bold=True, stroke=(0, 0, 0, 255))
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
    draw_title(d, w, "TIC TAC", 33, (255, 235, 139, 255), size=43)
    draw_title(d, w, "GOLD", 82, (255, 207, 53, 255), size=64)
    draw_prize_ribbon(d, w, 137, f"TOP PRIZE {money(ticket.top_prize)}", (255, 222, 72, 255), (14, 115, 64, 255), (13, 28, 21, 255), left=178, right_margin=22)
    rounded(d, rect_abs((0.12, 0.32, 0.52, 0.55), (w, h), -6), 11, (9, 21, 28, 240), (255, 222, 72, 255), 3)
    center_text(d, (39, 117, 192, 17), "3 IN A ROW WINS PRINTED PRIZE", 9, (255, 255, 255, 255), stroke_fill=(0, 0, 0, 255), stroke_width=1)
    for txt, r in ticket_regions(ticket.ticket_id):
        if txt.startswith("GRID"):
            well(d, rect_abs(r, (w, h), 1), shape="rect", fill=(255, 239, 184, 255), outline=(12, 22, 29, 255), trim=(255, 222, 72, 255))
    rounded(d, rect_abs((0.70, 0.37, 0.24, 0.32), (w, h), -4), 18, (20, 55, 41, 245), (255, 222, 72, 255), 3)
    center_text(d, (251, 137, 73, 23), "BONUS", 13, (255, 222, 72, 255), stroke_fill=(0, 0, 0, 255), stroke_width=1)
    well(d, rect_abs((0.73, 0.43, 0.18, 0.22), (w, h), 2), shape="rect", fill=(255, 239, 184, 255), outline=(12, 22, 29, 255), trim=(255, 222, 72, 255))
    draw_rules(d, w, h, ["Full WIN line pays.", "Multiple lines add.", "BONUS is instant."], (9, 30, 20, 255), (255, 243, 185, 230), y=288, compact=True)
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
    rounded(d, rect_abs((0.10, 0.39, 0.80, 0.28), (w, h), -5), 10, (18, 83, 55, 245), (229, 188, 73, 255), 3)
    center_text(d, (28, 139, w - 56, 16), "YOUR HAND", 10, (255, 238, 165, 255), stroke_fill=(0, 0, 0, 255), stroke_width=1)
    rounded(d, rect_abs((0.10, 0.52, 0.80, 0.16), (w, h), -5), 10, (41, 25, 31, 245), (229, 188, 73, 255), 3)
    center_text(d, (28, 183, w - 56, 16), "DEALER'S HAND", 10, (255, 238, 165, 255), stroke_fill=(0, 0, 0, 255), stroke_width=1)
    for txt, r in ticket_regions(ticket.ticket_id):
        shape = "card" if "CARD" in txt else "rect"
        well(d, rect_abs(r, (w, h), 1), shape=shape, fill=(255, 246, 216, 255), outline=(32, 22, 27, 255), trim=(229, 188, 73, 255))
    rounded(d, rect_abs((0.12, 0.755, 0.76, 0.18), (w, h), -4), 8, (27, 15, 30, 245), (229, 188, 73, 255), 3)
    center_text(d, (31, 278, w - 62, 16), "WILD / POCKET ACES", 10, (255, 238, 165, 255), stroke_fill=(0, 0, 0, 255), stroke_width=1)
    draw_rules(d, w, h, ["Reveal both 5-card hands.", "Beat dealer to win.", "Wild improves your hand."], (26, 15, 30, 255), (255, 239, 188, 230), y=318, compact=True)
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
    draw_prize_ribbon(d, w, 135, f"TOP PRIZE {money(ticket.top_prize)}", (255, 220, 92, 255), (132, 89, 27, 255), (18, 17, 25, 255), left=42, right_margin=24)
    d.rectangle((44, 184, w - 44, 202), fill=(95, 61, 19, 255), outline=(255, 220, 92, 255), width=2)
    center_text(d, (44, 181, w - 88, 20), "YOUR MULTIPLIER", 9, (255, 241, 163, 255), stroke_fill=(0, 0, 0, 255), stroke_width=1)
    well(d, rect_abs((0.24, 0.47, 0.52, 0.07), (w, h), 1), shape="rect", fill=(38, 25, 23, 255), outline=(14, 13, 18, 255), trim=(255, 220, 92, 255))
    rounded(d, rect_abs((0.10, 0.60, 0.80, 0.27), (w, h), -5), 10, (36, 26, 21, 245), (255, 220, 92, 255), 3)
    center_text(d, (34, 219, w - 68, 17), "CASH LADDER", 10, (255, 241, 163, 255), stroke_fill=(0, 0, 0, 255), stroke_width=1)
    for txt, r in ticket_regions(ticket.ticket_id):
        if txt.startswith("RUNG"):
            well(d, rect_abs(r, (w, h), 1), shape="rect", fill=(46, 31, 23, 255), outline=(12, 11, 16, 255), trim=(255, 220, 92, 255))
    center_text(d, rect_xywh((0.14, 0.856, 0.32, 0.018), (w, h)), "GOLD BAR", 8, (255, 241, 163, 255), stroke_fill=(0, 0, 0, 255), stroke_width=1)
    center_text(d, rect_xywh((0.50, 0.856, 0.34, 0.018), (w, h)), "FINAL VAULT", 8, (255, 241, 163, 255), stroke_fill=(0, 0, 0, 255), stroke_width=1)
    well(d, rect_abs((0.14, 0.88, 0.32, 0.052), (w, h), 1), shape="rect", fill=(48, 31, 24, 255), outline=(12, 11, 16, 255), trim=(255, 220, 92, 255))
    well(d, rect_abs((0.50, 0.88, 0.34, 0.052), (w, h), 1), shape="rect", fill=(48, 31, 24, 255), outline=(12, 11, 16, 255), trim=(255, 220, 92, 255))
    draw_rules(d, w, h, ["Matched rungs pay multiplier.", "GOLD BAR wins ladder.", "Final vault holds top prize."], (255, 238, 168, 255), (18, 17, 25, 210), y=312, compact=True)
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
    SYMBOLS_DIR.mkdir(parents=True, exist_ok=True)

    def coin(d, fill, outline, inner=(255, 255, 255, 80)):
        d.ellipse((10, 10, 118, 118), fill=(0, 0, 0, 70))
        d.ellipse((8, 6, 116, 114), fill=fill, outline=outline, width=5)
        d.ellipse((23, 21, 101, 99), outline=inner, width=4)

    save_symbol("number_coin", lambda d: coin(d, (255, 217, 81, 255), (72, 47, 16, 255)))
    save_symbol("winning_star", lambda d: (coin(d, (238, 48, 88, 255), (255, 233, 64, 255)), d.polygon(star_points(62, 58, 40, 18), fill=(255, 239, 88, 210), outline=(70, 30, 20, 255))))
    save_symbol("lucky_seven", lambda d: (coin(d, (20, 73, 39, 255), (255, 231, 68, 255)), center_text(d, (23, 16, 80, 84), "7", 76, (240, 48, 80, 185), condensed=True, stroke_fill=(255, 232, 80, 180), stroke_width=2)))
    save_symbol("clover", lambda d: (coin(d, (31, 126, 61, 255), (255, 233, 80, 255)), [d.ellipse(b, fill=(22, 194, 83, 255), outline=(10, 80, 33, 255), width=2) for b in [(31, 27, 65, 61), (63, 27, 97, 61), (31, 59, 65, 93), (63, 59, 97, 93)]], d.rectangle((61, 73, 68, 104), fill=(10, 80, 33, 255))))
    save_symbol("bell", lambda d: (coin(d, (255, 211, 84, 255), (94, 56, 20, 255)), d.pieslice((34, 28, 94, 106), 190, 350, fill=(255, 237, 111, 255), outline=(101, 59, 19, 255), width=4), d.rectangle((30, 85, 98, 98), fill=(236, 170, 42, 255), outline=(101, 59, 19, 255), width=3), d.ellipse((56, 94, 72, 110), fill=(101, 59, 19, 255))))
    save_symbol("star", lambda d: (coin(d, (34, 86, 161, 255), (255, 233, 80, 255)), d.polygon(star_points(64, 60, 42, 18), fill=(255, 245, 96, 255), outline=(79, 55, 10, 255))))
    save_symbol("twofer", lambda d: (coin(d, (239, 52, 79, 255), (255, 226, 75, 255)), center_text(d, (20, 42, 88, 34), "2FER", 28, (255, 255, 255, 255), condensed=True, stroke_fill=(63, 20, 28, 255), stroke_width=2)))
    save_symbol("gold_coin", lambda d: (coin(d, (255, 211, 71, 255), (95, 63, 17, 255)), d.polygon(star_points(64, 61, 34, 15), fill=(255, 244, 146, 215))))
    save_symbol("miss_cross", lambda d: (coin(d, (41, 47, 57, 255), (119, 125, 138, 255)), d.line((38, 38, 90, 90), fill=(255, 255, 255, 190), width=10), d.line((90, 38, 38, 90), fill=(255, 255, 255, 190), width=10)))
    save_symbol("dust", lambda d: (coin(d, (132, 116, 87, 255), (80, 70, 50, 255)), [d.ellipse((20+i*17, 33+(i%3)*16, 29+i*17, 42+(i%3)*16), fill=(214, 196, 148, 210)) for i in range(5)]))
    save_symbol("gold_bar", lambda d: (d.rectangle((24, 55, 104, 92), fill=(0, 0, 0, 80)), d.polygon([(20, 46), (98, 46), (110, 85), (32, 85)], fill=(255, 212, 72, 255), outline=(105, 68, 17, 255)), d.polygon([(35, 29), (82, 29), (96, 48), (22, 48)], fill=(255, 236, 126, 255), outline=(105, 68, 17, 255))))
    save_symbol("brass_bar", lambda d: (d.rectangle((24, 55, 104, 92), fill=(0, 0, 0, 80)), d.polygon([(20, 46), (98, 46), (110, 85), (32, 85)], fill=(164, 111, 52, 255), outline=(75, 50, 30, 255)), d.polygon([(35, 29), (82, 29), (96, 48), (22, 48)], fill=(193, 139, 77, 255), outline=(75, 50, 30, 255))))
    save_symbol("letter_tile", lambda d: rounded(d, (16, 16, 112, 112), 10, (219, 250, 255, 255), (23, 63, 86, 255), 5))
    save_symbol("crossword_cell", lambda d: rounded(d, (13, 13, 115, 115), 6, (245, 238, 198, 255), (37, 61, 65, 255), 4))
    save_symbol("bingo_ball", lambda d: (d.ellipse((8, 8, 118, 118), fill=(0, 0, 0, 70)), d.ellipse((8, 5, 116, 113), fill=(255, 245, 217, 255), outline=(20, 98, 56, 255), width=5), d.arc((22, 19, 101, 101), 215, 330, fill=(255, 180, 63, 255), width=7)))
    save_symbol("bingo_cell", lambda d: rounded(d, (12, 12, 116, 116), 8, (255, 255, 241, 255), (18, 76, 43, 255), 4))
    save_symbol("cash_stack", lambda d: ([rounded(d, (22, 38+i*11, 106, 68+i*11), 5, (44, 156, 78, 255), (11, 73, 34, 255), 3) for i in range(3)], center_text(d, (28, 48, 72, 34), "$", 42, (255, 239, 126, 255), stroke_fill=(10, 69, 31, 255), stroke_width=1)))
    save_symbol("multiplier_coin", lambda d: (coin(d, (255, 213, 80, 255), (71, 43, 17, 255)), d.ellipse((34, 33, 94, 93), fill=(84, 46, 19, 110))))
    save_symbol("vault_sealed", lambda d: (rounded(d, (17, 20, 111, 108), 12, (35, 38, 45, 255), (150, 118, 56, 255), 5), d.ellipse((39, 39, 89, 89), outline=(217, 175, 72, 255), width=7), d.ellipse((56, 56, 72, 72), fill=(217, 175, 72, 255))))
    save_symbol("vault_open", lambda d: (rounded(d, (12, 24, 86, 108), 11, (35, 38, 45, 255), (150, 118, 56, 255), 5), rounded(d, (66, 19, 116, 103), 11, (88, 72, 36, 255), (255, 214, 85, 255), 4), d.polygon(star_points(58, 63, 26, 11), fill=(255, 235, 92, 210))))
    save_symbol("wild_card", lambda d: (rounded(d, (22, 12, 106, 116), 8, (34, 23, 39, 255), (234, 194, 75, 255), 5), center_text(d, (28, 37, 72, 42), "WILD", 26, (255, 245, 177, 255), condensed=True, stroke_fill=(0, 0, 0, 255), stroke_width=1)))
    save_symbol("card_red", lambda d: (rounded(d, (19, 10, 109, 118), 8, (130, 24, 41, 255), (255, 236, 192, 255), 5), label(d, (44, 43), "♥", 44, (255, 225, 225, 180), bold=True)))
    save_symbol("card_black", lambda d: (rounded(d, (19, 10, 109, 118), 8, (20, 21, 27, 255), (255, 236, 192, 255), 5), label(d, (44, 43), "♠", 44, (255, 255, 255, 150), bold=True)))


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
