from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
ITEM_DIR = ROOT / "assets" / "art" / "items"
GAME_DIR = ROOT / "assets" / "art" / "games"
MAP_ICON_DIR = ROOT / "assets" / "art" / "map_icons"
MAP_BACKGROUND_DIR = ROOT / "assets" / "art" / "map_backgrounds"
SIZE = 32


def rgba(hex_value, alpha=255):
    hex_value = hex_value.lstrip("#")
    return tuple(int(hex_value[i : i + 2], 16) for i in (0, 2, 4)) + (alpha,)


BLACK = rgba("#05060a")
DARK = rgba("#0b0b18")
FIELD = rgba("#101427")
SHADOW = rgba("#171022")
FRAME = rgba("#0096a6")
CYAN = rgba("#00f5ff")
TEAL = rgba("#00ffd5")
PINK = rgba("#ff2d78")
PINK_2 = rgba("#ff6eb4")
YELLOW = rgba("#ffe45c")
AMBER = rgba("#ffb32d")
PURPLE = rgba("#7b3cff")
PURPLE_2 = rgba("#c44dff")
ORANGE = rgba("#ff6a27")
SOFT = rgba("#d8e8ea")
WHITE = rgba("#ffffff")
BLUE = rgba("#1d2140")
METAL = rgba("#78919d")
PAPER = rgba("#efe2c4")
BROWN = rgba("#5a2a18")


def new_icon():
    image = Image.new("RGBA", (SIZE, SIZE), BLACK)
    d = ImageDraw.Draw(image)
    d.rectangle((1, 1, 30, 30), fill=FRAME)
    d.rectangle((3, 3, 28, 28), fill=FIELD)
    d.rectangle((4, 4, 27, 27), outline=DARK)
    for y in (8, 15, 22):
        d.line((4, y, 27, y), fill=rgba("#0b0b18", 120))
    d.point((29, 29), fill=BLACK)
    return image, d


def save(image, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, optimize=True)


def rect(d, xy, fill, outline=BLACK):
    x0, y0, x1, y1 = xy
    d.rectangle((x0 - 1, y0 - 1, x1 + 1, y1 + 1), fill=outline)
    d.rectangle(xy, fill=fill)


def line(d, xy, fill, width=1, outline=BLACK):
    x0, y0, x1, y1 = xy
    if width > 1:
        d.line((x0, y0, x1, y1), fill=outline, width=width + 2)
    d.line((x0, y0, x1, y1), fill=fill, width=width)


def poly(d, points, fill, outline=BLACK):
    for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        d.polygon([(x + dx, y + dy) for x, y in points], fill=outline)
    d.polygon(points, fill=fill)


def ellipse(d, xy, fill, outline=BLACK):
    x0, y0, x1, y1 = xy
    d.ellipse((x0 - 1, y0 - 1, x1 + 1, y1 + 1), fill=outline)
    d.ellipse(xy, fill=fill)


def glint(d, x, y, color=YELLOW):
    d.line((x - 2, y, x + 2, y), fill=color)
    d.line((x, y - 2, x, y + 2), fill=color)
    d.point((x, y), fill=WHITE)


def pip(d, x, y, color=PINK):
    d.rectangle((x, y, x + 1, y + 1), fill=color)


def card(d, x, y, w=8, h=12, face=SOFT, mark=PINK):
    rect(d, (x, y, x + w, y + h), face)
    d.rectangle((x + 2, y + 2, x + w - 2, y + 3), fill=WHITE)
    pip(d, x + 2, y + 5, mark)
    pip(d, x + w - 3, y + h - 3, mark)


def dice(d, x, y, color=SOFT, mark=BLACK):
    rect(d, (x, y, x + 7, y + 7), color)
    for px, py in ((2, 2), (5, 2), (3, 3), (2, 5), (5, 5)):
        d.point((x + px, y + py), fill=mark)


def chip(d, x, y, fill=PINK):
    ellipse(d, (x, y, x + 8, y + 8), fill)
    d.rectangle((x + 3, y + 1, x + 5, y + 7), fill=CYAN)


def coin(d, x, y, fill=AMBER, accent=CYAN):
    ellipse(d, (x, y, x + 16, y + 16), fill)
    d.ellipse((x + 4, y + 4, x + 12, y + 12), outline=BLACK)
    d.rectangle((x + 7, y + 2, x + 9, y + 4), fill=accent)
    d.rectangle((x + 7, y + 12, x + 9, y + 14), fill=accent)
    d.rectangle((x + 2, y + 7, x + 4, y + 9), fill=accent)
    d.rectangle((x + 12, y + 7, x + 14, y + 9), fill=accent)


def music_note(d, x, y, color=CYAN):
    d.rectangle((x + 3, y, x + 4, y + 8), fill=color)
    d.rectangle((x + 4, y, x + 8, y + 1), fill=color)
    d.rectangle((x + 8, y + 1, x + 9, y + 7), fill=color)
    ellipse(d, (x, y + 7, x + 5, y + 12), color)
    ellipse(d, (x + 5, y + 6, x + 10, y + 11), color)


def tiny_smoke(d, points):
    for x, y, h in points:
        d.line((x, y + h, x - 1, y + h - 3, x, y), fill=METAL)


def draw_card_counters_notes():
    image, d = new_icon()
    rect(d, (6, 6, 19, 24), PAPER)
    for x in (9, 12, 15):
        line(d, (x, 11, x, 17), BLACK)
    line(d, (8, 19, 17, 14), BLACK)
    card(d, 18, 14, 7, 10)
    d.rectangle((8, 22, 15, 23), fill=CYAN)
    return image


def draw_cheap_sunglasses():
    image, d = new_icon()
    rect(d, (6, 12, 13, 18), rgba("#07141c"))
    rect(d, (19, 12, 26, 18), rgba("#07141c"))
    d.rectangle((13, 13, 18, 15), fill=WHITE)
    line(d, (4, 16, 6, 13), PINK)
    line(d, (26, 13, 28, 16), PINK)
    line(d, (20, 13, 24, 17), rgba("#274652"), 1)
    d.rectangle((8, 13, 9, 14), fill=rgba("#274652"))
    return image


def draw_creased_luck_card():
    image, d = new_icon()
    poly(d, [(8, 7), (21, 5), (25, 23), (10, 26)], SOFT)
    line(d, (15, 6, 18, 24), METAL)
    d.line((17, 9, 14, 16, 18, 23), fill=WHITE)
    pip(d, 11, 12)
    pip(d, 21, 19)
    glint(d, 25, 6)
    return image


def draw_flask_of_courage():
    image, d = new_icon()
    rect(d, (11, 9, 23, 25), METAL)
    d.rectangle((14, 6, 20, 8), fill=METAL)
    d.rectangle((15, 4, 18, 6), fill=AMBER)
    d.rectangle((13, 15, 21, 21), fill=rgba("#7a3b20"))
    d.rectangle((14, 13, 20, 14), fill=CYAN)
    poly(d, [(24, 13), (28, 15), (24, 17)], PINK)
    return image


def draw_foil_sleeve():
    image, d = new_icon()
    poly(d, [(8, 6), (23, 4), (26, 24), (10, 27)], METAL)
    d.polygon([(12, 8), (22, 6), (24, 12), (14, 15)], fill=SOFT)
    line(d, (9, 22, 25, 8), CYAN)
    line(d, (11, 25, 26, 14), PINK)
    poly(d, [(5, 17), (9, 14), (8, 20)], YELLOW)
    return image


def draw_gambler_gloves():
    image, d = new_icon()
    poly(d, [(7, 21), (9, 9), (13, 7), (16, 23), (10, 25)], SHADOW)
    poly(d, [(16, 23), (20, 7), (24, 9), (25, 21), (22, 25)], SHADOW)
    for x in (10, 12, 21, 23):
        d.line((x, 10, x - 1, 17), fill=CYAN)
    d.rectangle((9, 24, 14, 26), fill=PINK)
    d.rectangle((18, 24, 23, 26), fill=PINK)
    return image


def draw_holdout_rig():
    image, d = new_icon()
    rect(d, (6, 13, 23, 23), BLUE)
    d.rectangle((7, 14, 22, 16), fill=METAL)
    card(d, 15, 6, 8, 12)
    line(d, (8, 20, 22, 20), CYAN, 2)
    rect(d, (4, 17, 9, 22), SHADOW)
    return image


def draw_hot_streak_token():
    image, d = new_icon()
    ellipse(d, (7, 11, 24, 27), AMBER)
    ellipse(d, (11, 15, 20, 24), PINK)
    poly(d, [(16, 5), (22, 15), (18, 19), (13, 16), (14, 10)], ORANGE)
    poly(d, [(17, 9), (20, 15), (17, 17), (15, 14)], YELLOW, ORANGE)
    d.rectangle((9, 13, 11, 15), fill=YELLOW)
    return image


def draw_inside_man():
    image, d = new_icon()
    ellipse(d, (11, 6, 20, 15), SHADOW)
    poly(d, [(8, 27), (11, 17), (20, 17), (24, 27)], BLUE)
    d.polygon([(13, 18), (16, 23), (19, 18)], fill=SOFT)
    d.rectangle((23, 9, 26, 11), fill=CYAN)
    line(d, (21, 12, 26, 16), CYAN)
    d.rectangle((8, 22, 12, 24), fill=PINK)
    return image


def draw_instant_coffee():
    image, d = new_icon()
    rect(d, (8, 12, 23, 25), PAPER)
    d.rectangle((10, 15, 21, 20), fill=PINK)
    d.rectangle((11, 17, 20, 18), fill=ORANGE)
    tiny_smoke(d, [(11, 6, 5), (16, 5, 6), (21, 7, 4)])
    poly(d, [(7, 6), (13, 5), (10, 11)], YELLOW)
    return image


def draw_loaded_dice():
    image, d = new_icon()
    dice(d, 7, 10)
    dice(d, 17, 15)
    d.rectangle((14, 17, 16, 19), fill=PINK)
    d.rectangle((24, 23, 26, 25), fill=PINK)
    ellipse(d, (5, 22, 10, 27), METAL)
    glint(d, 24, 9)
    return image


def draw_lucky_charm():
    image, d = new_icon()
    ellipse(d, (9, 6, 16, 13), TEAL)
    ellipse(d, (16, 6, 23, 13), TEAL)
    ellipse(d, (9, 13, 16, 20), TEAL)
    ellipse(d, (16, 13, 23, 20), TEAL)
    d.rectangle((15, 12, 17, 14), fill=rgba("#04705f"))
    line(d, (16, 20, 19, 26), rgba("#04705f"), 2)
    glint(d, 24, 7)
    return image


def draw_lucky_cigarette():
    image, d = new_icon()
    line(d, (6, 22, 24, 15), SOFT, 3)
    d.line((20, 16, 24, 15), fill=AMBER, width=3)
    d.rectangle((24, 14, 27, 15), fill=ORANGE)
    tiny_smoke(d, [(12, 8, 5), (17, 6, 5)])
    glint(d, 7, 17)
    return image


def draw_lucky_keychain():
    image, d = new_icon()
    ellipse(d, (5, 8, 13, 16), CYAN)
    d.ellipse((8, 11, 10, 13), fill=FIELD)
    line(d, (13, 15, 24, 24), AMBER, 2)
    d.rectangle((22, 23, 27, 25), fill=AMBER)
    poly(d, [(17, 8), (23, 8), (25, 13), (20, 18), (15, 13)], TEAL)
    glint(d, 20, 13)
    return image


def draw_marked_cards():
    image, d = new_icon()
    card(d, 8, 9, 10, 15)
    card(d, 14, 6, 10, 15, WHITE)
    d.rectangle((19, 10, 22, 12), fill=CYAN)
    line(d, (17, 16, 24, 9), PURPLE)
    glint(d, 25, 7)
    return image


def draw_police_scanner():
    image, d = new_icon()
    rect(d, (10, 10, 23, 26), BLUE)
    d.rectangle((13, 13, 20, 15), fill=CYAN)
    for y in (18, 21, 24):
        d.rectangle((13, y, 20, y), fill=METAL)
    line(d, (16, 10, 13, 4), METAL, 2)
    d.rectangle((6, 7, 10, 9), fill=PINK)
    d.rectangle((22, 7, 26, 9), fill=PURPLE)
    return image


def draw_rabbits_foot():
    image, d = new_icon()
    poly(d, [(13, 8), (20, 8), (22, 20), (19, 26), (12, 24), (10, 15)], SOFT)
    d.rectangle((12, 21, 16, 26), fill=WHITE)
    d.rectangle((17, 21, 21, 26), fill=WHITE)
    ellipse(d, (6, 6, 13, 13), CYAN)
    line(d, (12, 11, 17, 13), CYAN, 2)
    glint(d, 24, 8)
    return image


def draw_roadside_map():
    image, d = new_icon()
    poly(d, [(6, 8), (13, 6), (20, 8), (26, 6), (26, 24), (19, 26), (12, 24), (6, 26)], PAPER)
    d.line((13, 6, 13, 24), fill=rgba("#ad9f76"))
    d.line((20, 8, 19, 26), fill=rgba("#ad9f76"))
    line(d, (8, 23, 14, 18), PINK, 2)
    line(d, (14, 18, 18, 20), PINK, 2)
    line(d, (18, 20, 24, 11), PINK, 2)
    d.rectangle((9, 11, 12, 13), fill=CYAN)
    glint(d, 25, 8)
    return image


def draw_ledger_pencil():
    image, d = new_icon()
    rect(d, (7, 6, 21, 25), PAPER)
    d.rectangle((9, 9, 19, 10), fill=CYAN)
    for y in (14, 17, 20):
        d.rectangle((10, y, 18, y), fill=BLACK)
    line(d, (20, 24, 27, 11), AMBER, 2)
    d.polygon([(25, 8), (28, 10), (26, 13)], fill=PINK)
    glint(d, 24, 6)
    return image


def draw_bag():
    image, d = new_icon()
    poly(d, [(9, 13), (23, 13), (25, 25), (7, 25)], BROWN)
    d.arc((11, 7, 21, 18), 190, 350, fill=METAL, width=2)
    d.rectangle((10, 15, 22, 17), fill=AMBER)
    d.rectangle((13, 19, 19, 23), fill=rgba("#2b1511"))
    d.rectangle((21, 12, 24, 15), fill=PINK)
    glint(d, 7, 10, CYAN)
    return image


def draw_backpack():
    image, d = new_icon()
    rect(d, (9, 8, 23, 26), BLUE)
    d.arc((11, 5, 21, 15), 185, 355, fill=METAL, width=2)
    d.rectangle((11, 13, 21, 17), fill=CYAN)
    d.rectangle((12, 20, 20, 24), fill=rgba("#111b38"))
    d.rectangle((7, 13, 10, 22), fill=PINK)
    d.rectangle((22, 13, 25, 22), fill=PINK)
    glint(d, 24, 8, YELLOW)
    return image


def draw_suitcase():
    image, d = new_icon()
    rect(d, (7, 11, 25, 25), BROWN)
    d.arc((12, 7, 20, 16), 180, 360, fill=METAL, width=2)
    d.rectangle((9, 14, 23, 16), fill=AMBER)
    d.rectangle((10, 19, 12, 23), fill=METAL)
    d.rectangle((20, 19, 22, 23), fill=METAL)
    d.rectangle((23, 10, 26, 13), fill=CYAN)
    glint(d, 7, 8, PINK)
    return image


def draw_trunk():
    image, d = new_icon()
    rect(d, (6, 12, 26, 25), rgba("#3a1d16"))
    d.arc((7, 5, 25, 21), 180, 360, fill=BROWN, width=5)
    d.rectangle((8, 14, 24, 16), fill=AMBER)
    d.rectangle((14, 17, 18, 22), fill=METAL)
    d.rectangle((7, 23, 25, 25), fill=rgba("#1b0d0b"))
    d.rectangle((22, 9, 25, 12), fill=PINK)
    glint(d, 6, 9, CYAN)
    return image


def draw_cashout_envelope():
    image, d = new_icon()
    poly(d, [(5, 11), (26, 9), (27, 24), (7, 26)], PAPER)
    d.line((7, 12, 17, 19, 26, 10), fill=METAL)
    d.line((8, 25, 17, 18, 27, 23), fill=METAL)
    d.rectangle((11, 14, 21, 15), fill=CYAN)
    d.rectangle((12, 18, 19, 19), fill=PINK)
    glint(d, 25, 8)
    return image


def draw_thermos_black_coffee():
    image, d = new_icon()
    rect(d, (10, 7, 22, 26), SHADOW)
    d.rectangle((12, 5, 20, 8), fill=METAL)
    d.rectangle((12, 11, 20, 17), fill=CYAN)
    d.rectangle((13, 18, 19, 23), fill=rgba("#3b1d12"))
    tiny_smoke(d, [(13, 2, 4), (18, 1, 5)])
    line(d, (23, 12, 27, 17), PINK, 2)
    return image


def draw_odds_notebook():
    image, d = new_icon()
    rect(d, (7, 5, 23, 26), BLUE)
    d.rectangle((9, 8, 21, 10), fill=PINK)
    for y in (14, 17, 20):
        d.rectangle((11, y, 19, y), fill=SOFT)
    d.rectangle((5, 8, 7, 23), fill=METAL)
    chip(d, 18, 20, AMBER)
    glint(d, 25, 7)
    return image


def draw_shoe_cut_marker():
    image, d = new_icon()
    poly(d, [(6, 12), (19, 7), (25, 20), (12, 26)], SOFT)
    d.rectangle((10, 13, 21, 15), fill=CYAN)
    line(d, (8, 23, 23, 9), PINK, 2)
    d.rectangle((20, 5, 25, 9), fill=AMBER)
    d.rectangle((22, 7, 27, 11), fill=AMBER)
    glint(d, 26, 6)
    return image


def draw_payment_calendar():
    image, d = new_icon()
    rect(d, (7, 7, 25, 26), PAPER)
    d.rectangle((7, 7, 25, 12), fill=PINK)
    for x in (11, 16, 21):
        d.rectangle((x, 5, x + 1, 9), fill=METAL)
    for x, y, color in ((10, 15, CYAN), (15, 18, AMBER), (20, 21, PINK_2)):
        d.rectangle((x, y, x + 3, y + 2), fill=color)
    line(d, (9, 24, 23, 14), BLACK)
    return image


def draw_pawn_receipt_sleeve():
    image, d = new_icon()
    poly(d, [(8, 8), (23, 6), (26, 24), (10, 27)], METAL)
    poly(d, [(10, 10), (21, 9), (23, 22), (12, 24)], PAPER)
    d.rectangle((13, 12, 21, 13), fill=PINK)
    d.rectangle((13, 16, 19, 17), fill=BLACK)
    d.rectangle((14, 20, 21, 21), fill=CYAN)
    glint(d, 24, 7)
    return image


def draw_scratch_pad():
    image, d = new_icon()
    rect(d, (8, 6, 24, 25), PAPER)
    for x in (10, 14, 18, 22):
        d.rectangle((x, 5, x + 1, 8), fill=METAL)
    d.rectangle((11, 12, 20, 13), fill=CYAN)
    d.rectangle((11, 16, 19, 16), fill=BLACK)
    d.rectangle((11, 20, 17, 20), fill=PINK)
    line(d, (21, 22, 27, 17), AMBER, 2)
    return image


def draw_tip_sheet():
    image, d = new_icon()
    poly(d, [(8, 6), (24, 5), (26, 24), (9, 26)], PAPER)
    d.rectangle((10, 9, 22, 10), fill=PINK)
    d.rectangle((10, 14, 22, 14), fill=BLACK)
    d.rectangle((10, 18, 20, 18), fill=BLACK)
    ellipse(d, (15, 20, 22, 26), CYAN)
    line(d, (20, 25, 24, 28), CYAN, 2)
    glint(d, 25, 8)
    return image


def draw_xray_glasses():
    image, d = new_icon()
    rect(d, (5, 11, 14, 19), rgba("#170a24"))
    rect(d, (18, 11, 27, 19), rgba("#170a24"))
    d.rectangle((14, 14, 18, 15), fill=METAL)
    d.ellipse((6, 12, 13, 18), outline=PINK)
    d.ellipse((19, 12, 26, 18), outline=PINK)
    d.rectangle((9, 14, 10, 15), fill=PURPLE_2)
    d.rectangle((22, 14, 23, 15), fill=PURPLE_2)
    line(d, (8, 8, 9, 10), YELLOW)
    line(d, (11, 7, 11, 10), YELLOW)
    line(d, (21, 7, 21, 10), YELLOW)
    line(d, (24, 8, 23, 10), YELLOW)
    line(d, (3, 16, 5, 13), PINK)
    line(d, (27, 13, 29, 16), PINK)
    return image


def draw_side_bet_chart():
    image, d = new_icon()
    poly(d, [(7, 6), (24, 6), (26, 25), (8, 26)], PAPER)
    d.rectangle((9, 8, 22, 10), fill=CYAN)
    for y in (13, 16, 19, 22):
        d.rectangle((10, y, 22, y), fill=BLACK)
    for x in (14, 18):
        d.rectangle((x, 12, x, 23), fill=rgba("#ad9f76"))
    chip(d, 5, 20, PINK)
    d.rectangle((20, 12, 22, 14), fill=YELLOW)
    d.rectangle((11, 12, 13, 14), fill=PINK)
    glint(d, 25, 7)
    return image


def draw_basic_strategy_card():
    image, d = new_icon()
    poly(d, [(6, 8), (17, 5), (17, 24), (6, 26)], PAPER)
    poly(d, [(17, 5), (26, 9), (25, 26), (17, 24)], rgba("#f7edcf"))
    d.line((17, 6, 17, 24), fill=rgba("#ad9f76"))
    for y in (11, 15, 19):
        d.rectangle((8, y, 15, y), fill=BLACK)
        d.rectangle((19, y, 24, y), fill=BLACK)
    d.rectangle((9, 8, 14, 9), fill=PINK)
    d.rectangle((19, 8, 23, 9), fill=CYAN)
    card(d, 20, 17, 6, 8, WHITE, PINK)
    return image


def draw_lucky_ladies_compact():
    image, d = new_icon()
    ellipse(d, (6, 14, 21, 27), PINK)
    ellipse(d, (11, 5, 26, 18), PINK_2)
    d.ellipse((14, 8, 23, 16), fill=rgba("#93f7ff"))
    d.rectangle((12, 21, 15, 23), fill=YELLOW)
    d.rectangle((14, 19, 18, 21), fill=YELLOW)
    d.rectangle((17, 21, 20, 23), fill=YELLOW)
    d.rectangle((12, 24, 20, 25), fill=AMBER)
    glint(d, 22, 9, WHITE)
    return image


def draw_coolers_cufflinks():
    image, d = new_icon()
    ellipse(d, (6, 10, 16, 20), METAL)
    ellipse(d, (16, 10, 26, 20), METAL)
    d.rectangle((10, 14, 22, 16), fill=BLACK)
    d.rectangle((9, 13, 13, 17), fill=CYAN)
    d.rectangle((19, 13, 23, 17), fill=CYAN)
    d.rectangle((11, 12, 12, 13), fill=WHITE)
    d.rectangle((21, 12, 22, 13), fill=WHITE)
    d.rectangle((13, 22, 19, 24), fill=PINK)
    glint(d, 24, 8)
    return image


def draw_broken_cufflinks():
    image, d = new_icon()
    ellipse(d, (5, 11, 15, 21), METAL)
    ellipse(d, (18, 9, 27, 18), METAL)
    line(d, (13, 16, 19, 13), METAL, 2)
    d.rectangle((8, 14, 12, 18), fill=CYAN)
    d.rectangle((21, 12, 24, 15), fill=CYAN)
    line(d, (10, 13, 13, 19), PINK)
    line(d, (20, 10, 25, 17), PINK)
    d.rectangle((16, 22, 23, 24), fill=rgba("#53616b"))
    return image


def draw_high_roller_watch():
    image, d = new_icon()
    poly(d, [(13, 4), (20, 4), (19, 9), (14, 9)], BROWN)
    poly(d, [(13, 23), (20, 23), (19, 28), (14, 28)], BROWN)
    ellipse(d, (8, 8, 25, 25), AMBER)
    d.ellipse((12, 12, 21, 21), fill=rgba("#07222f"))
    d.rectangle((15, 15, 16, 19), fill=CYAN)
    d.rectangle((16, 18, 20, 19), fill=CYAN)
    d.rectangle((11, 9, 14, 10), fill=YELLOW)
    d.rectangle((20, 23, 24, 25), fill=PINK)
    glint(d, 23, 9)
    return image


def draw_coin_return_shim():
    image, d = new_icon()
    poly(d, [(8, 17), (24, 10), (26, 15), (10, 22)], METAL)
    d.rectangle((13, 17, 23, 18), fill=CYAN)
    coin(d, 5, 8, AMBER, PINK)
    line(d, (23, 23, 15, 23), CYAN, 2)
    d.line((15, 23, 18, 20), fill=CYAN)
    d.line((15, 23, 18, 26), fill=CYAN)
    glint(d, 25, 9)
    return image


def draw_lucky_reel_grease():
    image, d = new_icon()
    poly(d, [(7, 18), (20, 7), (25, 12), (12, 25)], TEAL)
    d.rectangle((18, 7, 23, 11), fill=METAL)
    d.rectangle((10, 18, 16, 21), fill=YELLOW)
    d.rectangle((12, 15, 18, 16), fill=BLACK)
    ellipse(d, (20, 19, 25, 26), AMBER)
    d.rectangle((22, 21, 23, 24), fill=PINK)
    poly(d, [(6, 7), (9, 12), (5, 12)], CYAN)
    return image


def draw_timing_bracelet():
    image, d = new_icon()
    ellipse(d, (7, 7, 25, 25), METAL)
    d.ellipse((11, 11, 21, 21), fill=FIELD)
    rect(d, (11, 13, 21, 18), BLUE)
    d.rectangle((13, 15, 18, 16), fill=CYAN)
    d.rectangle((19, 15, 20, 16), fill=PINK)
    d.rectangle((15, 5, 18, 8), fill=AMBER)
    d.rectangle((15, 24, 18, 27), fill=AMBER)
    glint(d, 24, 8)
    return image


def draw_gold_tooth_token():
    image, d = new_icon()
    poly(d, [(10, 8), (22, 8), (24, 14), (22, 17), (22, 23), (19, 19), (16, 23), (13, 19), (10, 23), (10, 17), (8, 14)], AMBER)
    d.rectangle((12, 10, 20, 12), fill=YELLOW)
    glint(d, 19, 14, WHITE)
    pip(d, 25, 6, CYAN)
    pip(d, 6, 20, CYAN)
    return image


def draw_payout_pamphlet():
    image, d = new_icon()
    poly(d, [(7, 7), (15, 5), (15, 25), (7, 27)], PAPER)
    poly(d, [(15, 5), (25, 8), (25, 26), (15, 25)], rgba("#f7edcf"))
    d.line((15, 6, 15, 25), fill=rgba("#ad9f76"))
    for y, color in ((10, PINK), (14, CYAN), (18, YELLOW), (22, BLACK)):
        d.rectangle((9, y, 13, y), fill=color)
        d.rectangle((18, y, 23, y), fill=color)
    coin(d, 20, 18, AMBER, PINK)
    return image


def draw_cold_quarters():
    image, d = new_icon()
    for x, y in ((8, 19), (10, 16), (12, 13), (14, 10), (16, 7), (18, 18)):
        ellipse(d, (x, y, x + 9, y + 6), METAL)
        d.rectangle((x + 3, y + 2, x + 6, y + 3), fill=CYAN)
    d.rectangle((7, 24, 25, 26), fill=rgba("#79dfff"))
    line(d, (7, 8, 12, 13), CYAN)
    line(d, (12, 8, 7, 13), CYAN)
    d.rectangle((9, 10, 10, 11), fill=WHITE)
    glint(d, 25, 8, WHITE)
    return image


def draw_neon_players_charm():
    image, d = new_icon()
    ellipse(d, (8, 8, 24, 25), PURPLE)
    d.rectangle((12, 13, 16, 22), fill=CYAN)
    d.rectangle((16, 13, 20, 14), fill=CYAN)
    d.rectangle((19, 15, 20, 18), fill=CYAN)
    d.rectangle((16, 18, 19, 19), fill=CYAN)
    d.rectangle((12, 11, 20, 11), fill=PINK)
    d.rectangle((15, 4, 17, 8), fill=AMBER)
    line(d, (11, 26, 23, 6), PINK)
    glint(d, 24, 8, YELLOW)
    return image


def draw_split_reel_note():
    image, d = new_icon()
    poly(d, [(7, 6), (24, 7), (25, 25), (8, 26)], PAPER)
    d.rectangle((10, 9, 21, 11), fill=PINK)
    rect(d, (11, 14, 21, 22), rgba("#18202e"))
    d.rectangle((15, 14, 16, 22), fill=CYAN)
    d.rectangle((12, 16, 14, 18), fill=YELLOW)
    d.rectangle((18, 17, 20, 19), fill=PINK)
    line(d, (6, 20, 11, 20), CYAN, 2)
    d.line((10, 18, 12, 20, 10, 22), fill=CYAN)
    glint(d, 24, 8)
    return image


def draw_feature_magnet():
    image, d = new_icon()
    poly(d, [(7, 9), (13, 9), (13, 20), (16, 23), (19, 20), (19, 9), (25, 9), (25, 21), (19, 27), (13, 27), (7, 21)], PINK)
    d.rectangle((9, 11, 12, 15), fill=CYAN)
    d.rectangle((20, 11, 23, 15), fill=CYAN)
    d.rectangle((14, 23, 18, 25), fill=BLACK)
    poly(d, [(16, 4), (18, 9), (24, 9), (19, 12), (21, 18), (16, 14), (11, 18), (13, 12), (8, 9), (14, 9)], YELLOW)
    return image


def draw_cumquat_sandwich_item():
    image, d = new_icon()
    poly(d, [(5, 14), (11, 8), (22, 7), (27, 13), (26, 25), (8, 27)], rgba("#d79b52"))
    poly(d, [(8, 15), (12, 11), (21, 10), (24, 14), (23, 22), (10, 24)], rgba("#f6e5cd"))
    d.rectangle((10, 16, 23, 20), fill=rgba("#fff4de"))
    for x, y in ((12, 14), (18, 13), (21, 18), (14, 20)):
        ellipse(d, (x, y, x + 6, y + 5), ORANGE)
        d.rectangle((x + 2, y + 1, x + 4, y + 3), fill=YELLOW)
    line(d, (6, 25, 25, 24), AMBER, 1)
    line(d, (7, 14, 12, 10), AMBER, 1)
    glint(d, 24, 8, WHITE)
    return image


def draw_drain_cleaner():
    image, d = new_icon()
    rect(d, (8, 7, 23, 12), METAL)
    rect(d, (9, 17, 24, 23), METAL)
    line(d, (10, 12, 10, 19), CYAN, 2)
    line(d, (22, 12, 22, 19), CYAN, 2)
    d.rectangle((12, 18, 21, 20), fill=rgba("#022f36"))
    d.rectangle((13, 21, 20, 22), fill=TEAL)
    glint(d, 24, 7, WHITE)
    return image


def draw_jackpot_magnet():
    image, d = new_icon()
    d.arc((5, 6, 27, 27), 205, 335, fill=PINK, width=5)
    rect(d, (4, 17, 10, 24), CYAN)
    rect(d, (22, 17, 28, 24), CYAN)
    chip(d, 12, 13, YELLOW)
    d.rectangle((13, 10, 20, 11), fill=AMBER)
    d.rectangle((15, 16, 17, 21), fill=PINK_2)
    glint(d, 24, 9)
    return image


def draw_splitter_token():
    image, d = new_icon()
    coin(d, 8, 8, AMBER, PINK)
    line(d, (16, 12, 9, 22), CYAN, 2)
    line(d, (16, 12, 23, 22), CYAN, 2)
    poly(d, [(8, 22), (12, 20), (12, 25)], CYAN)
    poly(d, [(24, 22), (20, 20), (20, 25)], CYAN)
    d.rectangle((15, 7, 17, 22), fill=BLACK)
    return image


def draw_return_spring():
    image, d = new_icon()
    for y in (10, 13, 16, 19, 22):
        d.arc((9, y - 3, 23, y + 4), 0, 180, fill=CYAN, width=2)
    line(d, (16, 24, 16, 8), PINK, 2)
    poly(d, [(16, 5), (11, 11), (21, 11)], PINK)
    rect(d, (8, 24, 24, 26), METAL)
    return image


def draw_tilt_dampener():
    image, d = new_icon()
    rect(d, (7, 16, 25, 24), BLUE)
    d.arc((8, 7, 24, 23), 200, 340, fill=CYAN, width=2)
    line(d, (16, 20, 22, 12), YELLOW, 2)
    ellipse(d, (14, 18, 18, 22), PINK)
    d.rectangle((9, 24, 23, 25), fill=METAL)
    d.rectangle((10, 10, 12, 12), fill=TEAL)
    d.rectangle((20, 10, 22, 12), fill=TEAL)
    return image


def draw_bumper_battery():
    image, d = new_icon()
    rect(d, (8, 11, 23, 24), BLUE)
    d.rectangle((12, 8, 19, 10), fill=METAL)
    d.rectangle((11, 14, 20, 16), fill=TEAL)
    ellipse(d, (18, 5, 27, 14), PINK)
    d.rectangle((21, 8, 24, 11), fill=YELLOW)
    line(d, (12, 20, 19, 20), YELLOW, 2)
    line(d, (16, 17, 16, 23), YELLOW, 2)
    return image


def draw_jazz_sax_lucky_coin():
    image, d = new_icon()
    coin(d, 7, 8, AMBER, PURPLE)
    line(d, (13, 12, 18, 18), CYAN, 2)
    d.arc((13, 13, 22, 24), 70, 285, fill=CYAN, width=2)
    d.rectangle((16, 10, 20, 11), fill=CYAN)
    d.rectangle((20, 20, 24, 22), fill=PINK)
    d.rectangle((17, 15, 18, 16), fill=YELLOW)
    music_note(d, 4, 4, PINK)
    return image


def draw_jazz_cello_lucky_coin():
    image, d = new_icon()
    coin(d, 7, 8, rgba("#d88935"), CYAN)
    ellipse(d, (13, 13, 20, 22), BROWN)
    ellipse(d, (14, 9, 19, 16), BROWN)
    d.rectangle((16, 6, 17, 22), fill=CYAN)
    d.rectangle((12, 22, 21, 23), fill=BLACK)
    line(d, (12, 14, 21, 14), YELLOW)
    d.rectangle((21, 5, 23, 7), fill=PINK)
    music_note(d, 4, 18, CYAN)
    return image


def draw_jazz_drummer_lucky_coin():
    image, d = new_icon()
    coin(d, 7, 8, AMBER, PINK)
    ellipse(d, (11, 16, 22, 23), METAL)
    d.rectangle((13, 16, 20, 18), fill=SOFT)
    line(d, (9, 10, 20, 18), YELLOW)
    line(d, (23, 10, 15, 18), YELLOW)
    d.rectangle((5, 15, 7, 17), fill=rgba("#53616b"))
    d.rectangle((24, 21, 26, 23), fill=rgba("#53616b"))
    glint(d, 24, 8)
    return image


def draw_jazz_drummer_glasses():
    image, d = new_icon()
    ellipse(d, (5, 11, 15, 21), rgba("#07141c"))
    ellipse(d, (17, 11, 27, 21), rgba("#07141c"))
    d.ellipse((8, 14, 13, 19), fill=rgba("#3d1738"))
    d.ellipse((20, 14, 25, 19), fill=rgba("#3d1738"))
    d.rectangle((15, 16, 17, 17), fill=AMBER)
    line(d, (3, 16, 6, 15), AMBER)
    line(d, (27, 15, 29, 17), AMBER)
    d.rectangle((10, 8, 12, 9), fill=CYAN)
    d.rectangle((21, 8, 23, 9), fill=PINK)
    music_note(d, 19, 20, YELLOW)
    glint(d, 25, 8, WHITE)
    return image


def draw_tab_detector():
    image, d = new_icon()
    rect(d, (9, 9, 23, 24), BLUE)
    d.rectangle((12, 12, 20, 15), fill=rgba("#06131c"))
    d.rectangle((13, 13, 19, 14), fill=CYAN)
    d.rectangle((12, 18, 15, 21), fill=PINK)
    d.rectangle((18, 18, 21, 21), fill=YELLOW)
    line(d, (16, 9, 12, 4), METAL, 2)
    d.rectangle((11, 5, 13, 6), fill=CYAN)
    line(d, (23, 16, 28, 12), AMBER, 2)
    d.rectangle((26, 10, 28, 12), fill=YELLOW)
    glint(d, 24, 8)
    return image


def draw_tarot_card():
    image, d = new_icon()
    poly(d, [(9, 5), (23, 6), (24, 26), (10, 25)], PAPER)
    d.polygon([(11, 8), (22, 9), (22, 23), (12, 23)], fill=rgba("#241027"))
    d.ellipse((13, 10, 20, 17), fill=CYAN)
    d.ellipse((15, 9, 22, 16), fill=rgba("#241027"))
    poly(d, [(16, 17), (18, 20), (16, 23), (14, 20)], YELLOW)
    pip(d, 13, 11, YELLOW)
    pip(d, 19, 20, PINK)
    glint(d, 24, 7)
    return image


def draw_weighted_keyring():
    image, d = new_icon()
    ellipse(d, (10, 5, 20, 15), METAL)
    d.ellipse((12, 7, 18, 13), fill=FIELD)
    line(d, (12, 14, 12, 22), AMBER, 2)
    d.rectangle((10, 22, 14, 24), fill=AMBER)
    d.rectangle((13, 18, 15, 19), fill=AMBER)
    line(d, (17, 14, 17, 19), SOFT, 2)
    d.rectangle((15, 19, 19, 21), fill=SOFT)
    poly(d, [(21, 14), (27, 14), (28, 19), (24, 25), (20, 19)], BLUE)
    d.rectangle((23, 16, 25, 18), fill=CYAN)
    glint(d, 24, 6)
    return image


def draw_slot():
    image, d = new_icon()
    rect(d, (9, 5, 23, 26), BLUE)
    d.rectangle((11, 7, 21, 10), fill=PINK)
    rect(d, (11, 13, 21, 20), rgba("#18202e"))
    for x, color in ((12, YELLOW), (15, PINK), (18, CYAN)):
        d.rectangle((x, 15, x + 1, 18), fill=color)
    d.rectangle((12, 23, 20, 25), fill=AMBER)
    line(d, (24, 11, 27, 7), AMBER, 2)
    glint(d, 27, 6)
    return image


def draw_blackjack():
    image, d = new_icon()
    d.polygon([(5, 22), (27, 22), (23, 27), (9, 27)], fill=rgba("#0f5b45"))
    card(d, 8, 8, 9, 13, SOFT, BLACK)
    card(d, 15, 6, 9, 13, WHITE, PINK)
    chip(d, 20, 20, AMBER)
    return image


def draw_cards():
    image, d = new_icon()
    for x, y, mark in ((7, 11, PINK), (12, 8, CYAN), (17, 10, BLACK)):
        card(d, x, y, 8, 12, WHITE, mark)
    d.arc((8, 20, 24, 30), 200, 330, fill=YELLOW, width=1)
    return image


def draw_bar_dice():
    image, d = new_icon()
    poly(d, [(9, 7), (22, 7), (24, 18), (19, 24), (12, 24), (7, 18)], BROWN)
    d.rectangle((10, 8, 21, 10), fill=METAL)
    dice(d, 7, 20)
    dice(d, 18, 19)
    d.line((5, 27, 27, 27), fill=AMBER, width=2)
    return image


def draw_dice():
    image, d = new_icon()
    dice(d, 7, 10)
    dice(d, 18, 15)
    d.rectangle((6, 25, 26, 26), fill=CYAN)
    glint(d, 25, 8)
    return image


def draw_poker():
    image, d = new_icon()
    d.ellipse((5, 16, 27, 28), fill=rgba("#0f5b45"), outline=BLACK)
    for x, mark in ((8, PINK), (13, BLACK), (18, PINK)):
        card(d, x, 7, 7, 11, WHITE, mark)
    chip(d, 21, 20, PINK)
    return image


def draw_pull_tabs():
    image, d = new_icon()
    rect(d, (8, 6, 24, 27), PINK)
    d.rectangle((10, 9, 22, 11), fill=AMBER)
    for x in (10, 15, 20):
        rect(d, (x, 15, x + 3, 22), AMBER)
        d.line((x + 1, 15, x + 4, 10), fill=METAL)
    d.rectangle((23, 6, 26, 8), fill=AMBER)
    return image


def draw_video_poker():
    image, d = new_icon()
    rect(d, (6, 6, 26, 25), BLUE)
    d.rectangle((9, 9, 23, 16), fill=CYAN)
    for x in (10, 13, 16, 19, 22):
        d.rectangle((x, 11, x + 1, 14), fill=SOFT)
    d.rectangle((9, 20, 23, 22), fill=AMBER)
    d.rectangle((14, 25, 18, 27), fill=METAL)
    return image


def draw_plunger_tuner():
    image, d = new_icon()
    rect(d, (21, 6, 24, 25), METAL)
    d.rectangle((22, 8, 23, 23), fill=SOFT)
    rect(d, (20, 4, 25, 7), PINK)
    for y in (10, 14, 18, 22):
        line(d, (19, y, 26, y), CYAN, 1)
    rect(d, (7, 6, 12, 25), BLUE)
    d.rectangle((8, 7, 11, 10), fill=PINK)
    d.rectangle((8, 11, 11, 20), fill=TEAL)
    d.rectangle((8, 21, 11, 24), fill=PINK)
    line(d, (13, 15, 17, 15), YELLOW, 2)
    poly(d, [(17, 13), (20, 15), (17, 18)], YELLOW)
    glint(d, 25, 5, WHITE)
    return image


def draw_rubber_pegs():
    image, d = new_icon()
    ellipse(d, (13, 6, 19, 12), PINK)
    d.ellipse((15, 8, 17, 10), fill=PINK_2)
    ellipse(d, (7, 16, 13, 22), TEAL)
    d.ellipse((9, 18, 11, 20), fill=CYAN)
    ellipse(d, (19, 16, 25, 22), TEAL)
    d.ellipse((21, 18, 23, 20), fill=CYAN)
    d.arc((6, 4, 20, 16), 210, 330, fill=YELLOW, width=2)
    d.arc((14, 12, 26, 24), 200, 320, fill=YELLOW, width=2)
    ellipse(d, (23, 8, 27, 12), METAL)
    glint(d, 24, 8, WHITE)
    return image


def draw_extra_ball_token():
    image, d = new_icon()
    coin(d, 6, 9, AMBER, PINK)
    ellipse(d, (17, 13, 26, 22), METAL)
    d.ellipse((19, 15, 22, 18), fill=SOFT)
    glint(d, 20, 15, WHITE)
    rect(d, (20, 5, 22, 11), CYAN)
    rect(d, (18, 7, 24, 9), CYAN)
    return image


def draw_lock_jammer():
    image, d = new_icon()
    d.arc((10, 5, 22, 17), 180, 360, fill=METAL, width=3)
    rect(d, (8, 12, 24, 24), BLUE)
    d.rectangle((14, 16, 17, 21), fill=YELLOW)
    line(d, (4, 22, 15, 13), PINK, 2)
    poly(d, [(4, 22), (8, 20), (7, 24)], PINK_2)
    line(d, (20, 8, 24, 5), ORANGE, 1)
    glint(d, 24, 6, PINK_2)
    return image


def draw_magnet_cup():
    image, d = new_icon()
    poly(d, [(9, 9), (23, 9), (20, 18), (12, 18)], AMBER)
    d.rectangle((14, 18, 17, 21), fill=AMBER)
    rect(d, (11, 22, 21, 24), YELLOW)
    d.rectangle((12, 11, 15, 13), fill=YELLOW)
    d.arc((3, 6, 15, 20), 110, 250, fill=CYAN, width=2)
    d.arc((17, 6, 29, 20), 290, 70, fill=CYAN, width=2)
    ellipse(d, (23, 4, 27, 8), METAL)
    glint(d, 24, 4, WHITE)
    return image


def draw_chip_slide_wax():
    image, d = new_icon()
    ellipse(d, (5, 18, 14, 26), AMBER)
    d.ellipse((7, 20, 12, 23), fill=YELLOW)
    chip(d, 17, 8, PINK)
    line(d, (6, 10, 14, 10), CYAN, 1)
    line(d, (4, 13, 13, 13), CYAN, 1)
    line(d, (8, 7, 15, 7), CYAN, 1)
    glint(d, 25, 20, WHITE)
    return image


def draw_holdout_wax():
    image, d = new_icon()
    card(d, 13, 5, 9, 13, SOFT, PINK)
    d.rectangle((18, 15, 21, 18), fill=AMBER)
    ellipse(d, (6, 17, 16, 26), AMBER)
    d.ellipse((8, 19, 13, 23), fill=rgba("#b57614"))
    glint(d, 25, 21, WHITE)
    return image


def draw_edge_sort_loupe():
    image, d = new_icon()
    card(d, 6, 6, 10, 14, BLUE, CYAN)
    d.rectangle((8, 11, 14, 12), fill=CYAN)
    d.rectangle((8, 14, 11, 15), fill=CYAN)
    ellipse(d, (13, 12, 25, 24), METAL)
    d.ellipse((15, 14, 23, 22), fill=rgba("#0e2f3c"))
    d.rectangle((17, 17, 21, 18), fill=PINK)
    line(d, (24, 23, 28, 27), METAL, 2)
    glint(d, 17, 15, WHITE)
    return image


def draw_dice_calipers():
    image, d = new_icon()
    rect(d, (22, 5, 25, 26), METAL)
    rect(d, (10, 5, 25, 8), METAL)
    rect(d, (10, 20, 25, 23), METAL)
    dice(d, 11, 10, SOFT, BLACK)
    d.rectangle((23, 10, 24, 18), fill=CYAN)
    pip(d, 23, 12, PINK)
    glint(d, 7, 7)
    return image


def draw_corner_store_map():
    image, d = new_icon()
    rect(d, (7, 10, 25, 24), BLUE)
    d.rectangle((9, 13, 23, 15), fill=CYAN)
    d.rectangle((11, 17, 17, 24), fill=PINK)
    d.rectangle((19, 17, 23, 21), fill=YELLOW)
    line(d, (6, 10, 16, 5), AMBER, 2)
    line(d, (16, 5, 26, 10), AMBER, 2)
    glint(d, 24, 7)
    return image


def draw_back_alley_map():
    image, d = new_icon()
    rect(d, (8, 8, 13, 26), BLUE)
    rect(d, (20, 6, 25, 26), SHADOW)
    d.rectangle((14, 22, 21, 24), fill=rgba("#102b30"))
    line(d, (6, 25, 26, 18), CYAN, 1)
    line(d, (17, 7, 17, 20), PINK, 2)
    d.rectangle((15, 18, 20, 20), fill=YELLOW)
    tiny_smoke(d, [(11, 9, 4), (23, 8, 5)])
    return image


def draw_motel_map():
    image, d = new_icon()
    rect(d, (6, 13, 25, 24), BLUE)
    d.rectangle((9, 16, 13, 20), fill=CYAN)
    d.rectangle((16, 16, 20, 20), fill=CYAN)
    d.rectangle((21, 17, 24, 24), fill=PINK)
    rect(d, (10, 7, 22, 12), PINK)
    d.rectangle((12, 9, 20, 10), fill=YELLOW)
    line(d, (16, 12, 16, 16), METAL, 1)
    return image


def draw_motel_room_map():
    image, d = new_icon()
    rect(d, (6, 11, 26, 24), BLUE)
    rect(d, (8, 15, 18, 22), rgba("#39201e"))
    d.rectangle((10, 16, 17, 17), fill=PINK)
    d.rectangle((20, 13, 24, 24), fill=AMBER)
    d.rectangle((21, 16, 23, 19), fill=FIELD)
    d.rectangle((12, 8, 23, 11), fill=CYAN)
    d.rectangle((13, 9, 22, 9), fill=YELLOW)
    return image


def draw_apartment_map():
    image, d = new_icon()
    rect(d, (8, 7, 24, 26), BLUE)
    line(d, (7, 7, 16, 3), PINK, 2)
    line(d, (16, 3, 25, 7), PINK, 2)
    for x in (11, 18):
        d.rectangle((x, 10, x + 4, 14), fill=CYAN)
        d.rectangle((x, 17, x + 4, 21), fill=AMBER)
    d.rectangle((14, 22, 18, 26), fill=rgba("#211017"))
    glint(d, 25, 5, YELLOW)
    return image


def draw_house_map():
    image, d = new_icon()
    rect(d, (7, 13, 25, 25), rgba("#233044"))
    poly(d, [(5, 13), (16, 5), (27, 13)], BROWN)
    d.rectangle((10, 16, 14, 20), fill=CYAN)
    d.rectangle((19, 16, 23, 20), fill=PINK)
    d.rectangle((14, 21, 18, 25), fill=AMBER)
    d.rectangle((22, 8, 25, 12), fill=METAL)
    tiny_smoke(d, [(24, 4, 4)])
    return image


def draw_bar_map():
    image, d = new_icon()
    rect(d, (7, 9, 25, 24), BROWN)
    d.rectangle((9, 11, 23, 13), fill=AMBER)
    d.rectangle((9, 17, 23, 22), fill=rgba("#211017"))
    for x, color in ((11, CYAN), (15, PINK), (19, YELLOW)):
        d.rectangle((x, 14, x + 2, 19), fill=color)
    line(d, (5, 25, 27, 25), CYAN, 1)
    return image


def draw_gas_station_casino_map():
    image, d = new_icon()
    rect(d, (7, 11, 24, 24), BLUE)
    rect(d, (5, 7, 18, 11), AMBER)
    d.rectangle((8, 14, 14, 20), fill=CYAN)
    d.rectangle((17, 15, 22, 22), fill=PINK)
    line(d, (24, 10, 27, 10), METAL, 2)
    line(d, (27, 10, 27, 23), METAL, 2)
    d.rectangle((25, 15, 29, 18), fill=YELLOW)
    return image


def draw_small_underground_casino_map():
    image, d = new_icon()
    rect(d, (8, 11, 24, 25), SHADOW)
    d.rectangle((10, 13, 22, 15), fill=TEAL)
    d.rectangle((11, 20, 21, 23), fill=rgba("#0f5b45"))
    line(d, (8, 10, 24, 10), PINK, 2)
    d.rectangle((12, 6, 20, 9), fill=METAL)
    chip(d, 19, 17, AMBER)
    return image


def draw_jazz_club_map():
    image, d = new_icon()
    rect(d, (7, 10, 25, 24), rgba("#281629"))
    d.rectangle((9, 12, 23, 14), fill=AMBER)
    music_note(d, 11, 8, CYAN)
    music_note(d, 18, 12, PINK)
    d.rectangle((10, 22, 22, 24), fill=BROWN)
    glint(d, 24, 8, YELLOW)
    return image


def draw_kitty_cat_lounge_map():
    image, d = new_icon()
    rect(d, (7, 10, 25, 25), rgba("#23142f"))
    d.rectangle((9, 13, 23, 15), fill=PINK)
    d.rectangle((11, 18, 21, 22), fill=rgba("#0f5b45"))
    chip(d, 18, 17, AMBER)
    line(d, (8, 9, 13, 5), CYAN, 1)
    line(d, (24, 9, 19, 5), CYAN, 1)
    d.rectangle((13, 7, 19, 9), fill=YELLOW)
    return image


def draw_delta_queen_map():
    image, d = new_icon()
    poly(d, [(5, 19), (25, 19), (21, 25), (9, 25)], BROWN)
    rect(d, (8, 12, 23, 19), BLUE)
    d.rectangle((10, 14, 21, 15), fill=CYAN)
    d.rectangle((11, 17, 14, 19), fill=PINK)
    d.rectangle((17, 17, 20, 19), fill=YELLOW)
    line(d, (7, 26, 26, 26), CYAN, 1)
    tiny_smoke(d, [(21, 6, 5), (24, 8, 4)])
    return image


def draw_beach_map():
    image, d = new_icon()
    d.rectangle((5, 18, 27, 26), fill=rgba("#d79b52"))
    d.rectangle((5, 7, 27, 18), fill=rgba("#063a58"))
    for y in (10, 14, 18):
        line(d, (5, y, 27, y - 2), CYAN, 1)
    poly(d, [(12, 16), (18, 8), (24, 16)], PINK)
    line(d, (18, 8, 18, 24), AMBER, 1)
    d.rectangle((8, 22, 15, 24), fill=TEAL)
    chip(d, 22, 20, ORANGE)
    glint(d, 25, 8, WHITE)
    return image


def draw_grand_casino_map():
    image, d = new_icon()
    rect(d, (6, 12, 26, 25), BLUE)
    d.rectangle((8, 15, 24, 17), fill=AMBER)
    for x in (9, 14, 19):
        d.rectangle((x, 18, x + 2, 25), fill=METAL)
    poly(d, [(5, 12), (16, 5), (27, 12)], PINK)
    d.rectangle((13, 8, 19, 11), fill=YELLOW)
    glint(d, 25, 7, WHITE)
    return image


def draw_cyberpunk_city_overhead():
    width, height = 768, 512
    image = Image.new("RGBA", (width, height), rgba("#05060a"))
    d = ImageDraw.Draw(image)
    d.rectangle((0, 0, width, height), fill=rgba("#05060a"))

    # Water and rail corridors give the generated node anchors readable city landmarks.
    d.polygon([(548, 0), (768, 0), (768, 118), (612, 92), (566, 42)], fill=rgba("#071c2f"))
    d.polygon([(596, 512), (768, 512), (768, 332), (650, 350), (610, 422)], fill=rgba("#071929"))
    d.rectangle((0, 372, width, 392), fill=rgba("#101018"))
    d.rectangle((0, 376, width, 378), fill=rgba("#00f5ff", 92))
    d.rectangle((0, 386, width, 388), fill=rgba("#ff2d78", 78))

    for y in range(32, height - 34, 62):
        for x in range(28, width - 42, 76):
            if 552 < x < 742 and (y < 120 or y > 332):
                continue
            shade = "#101427" if (x // 76 + y // 62) % 2 == 0 else "#0b1021"
            d.rectangle((x, y, x + 48, y + 36), fill=rgba(shade), outline=rgba("#151b31"))
            if (x + y) % 3 == 0:
                d.rectangle((x + 5, y + 5, x + 18, y + 8), fill=rgba("#00f5ff", 95))
            if (x + y) % 4 == 0:
                d.rectangle((x + 27, y + 22, x + 43, y + 25), fill=rgba("#ff2d78", 90))
            if (x + y) % 5 == 0:
                d.rectangle((x + 20, y + 12, x + 31, y + 15), fill=rgba("#ffe45c", 90))

    def glow_line(points, color, widths):
        for line_width, alpha in widths:
            layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
            ld = ImageDraw.Draw(layer)
            ld.line(points, fill=color[:3] + (alpha,), width=line_width)
            image.alpha_composite(layer)

    road_specs = [
        ([(92, 0), (100, height)], CYAN),
        ([(196, 0), (178, 210), (204, height)], PINK),
        ([(316, 0), (330, 190), (304, height)], AMBER),
        ([(454, 0), (430, 228), (468, height)], TEAL),
        ([(620, 122), (586, 248), (636, 512)], PURPLE_2),
        ([(0, 126), (768, 96)], CYAN),
        ([(0, 244), (768, 232)], PINK),
        ([(0, 338), (768, 306)], TEAL),
        ([(62, 512), (206, 368), (340, 292), (540, 188), (768, 164)], AMBER),
        ([(0, 446), (164, 330), (324, 248), (488, 164), (668, 38)], PURPLE),
    ]
    for points, color in road_specs:
        glow_line(points, color, [(13, 34), (7, 58), (3, 180)])

    district_marks = [
        (86, 220, 150, 270, CYAN),
        (210, 104, 288, 154, PINK),
        (332, 190, 410, 242, YELLOW),
        (456, 298, 540, 350, TEAL),
        (606, 210, 700, 268, PURPLE_2),
        (650, 72, 728, 118, AMBER),
    ]
    for x0, y0, x1, y1, color in district_marks:
        d.rectangle((x0, y0, x1, y1), outline=color[:3] + (170,), width=2)
        d.rectangle((x0 + 5, y0 + 5, x1 - 5, y1 - 5), outline=color[:3] + (64,), width=1)

    for i in range(120):
        x = (i * 83 + 29) % width
        y = (i * 47 + 17) % height
        color = [CYAN, PINK, YELLOW, TEAL, PURPLE_2][i % 5]
        d.rectangle((x, y, x + 1, y + 1), fill=color)
    d.rectangle((8, 8, width - 9, height - 9), outline=rgba("#00f5ff", 80))
    d.rectangle((14, 14, width - 15, height - 15), outline=rgba("#ff2d78", 54))
    return image


ITEM_ICONS = {
    "backpack": draw_backpack,
    "bag": draw_bag,
    "basic_strategy_card": draw_basic_strategy_card,
    "broken_cufflinks": draw_broken_cufflinks,
    "card_counters_notes": draw_card_counters_notes,
    "cashout_envelope": draw_cashout_envelope,
    "cheap_sunglasses": draw_cheap_sunglasses,
    "coin_return_shim": draw_coin_return_shim,
    "cold_quarters": draw_cold_quarters,
    "coolers_cufflinks": draw_coolers_cufflinks,
    "creased_luck_card": draw_creased_luck_card,
    "cumquat_sandwich": draw_cumquat_sandwich_item,
    "drain_cleaner": draw_drain_cleaner,
    "feature_magnet": draw_feature_magnet,
    "flask_of_courage": draw_flask_of_courage,
    "foil_sleeve": draw_foil_sleeve,
    "gambler_gloves": draw_gambler_gloves,
    "gold_tooth_token": draw_gold_tooth_token,
    "high_roller_watch": draw_high_roller_watch,
    "holdout_rig": draw_holdout_rig,
    "hot_streak_token": draw_hot_streak_token,
    "inside_man": draw_inside_man,
    "instant_coffee": draw_instant_coffee,
    "jackpot_magnet": draw_jackpot_magnet,
    "jazz_cello_lucky_coin": draw_jazz_cello_lucky_coin,
    "jazz_drummer_glasses": draw_jazz_drummer_glasses,
    "jazz_drummer_lucky_coin": draw_jazz_drummer_lucky_coin,
    "jazz_sax_lucky_coin": draw_jazz_sax_lucky_coin,
    "ledger_pencil": draw_ledger_pencil,
    "loaded_dice": draw_loaded_dice,
    "lucky_charm": draw_lucky_charm,
    "lucky_cigarette": draw_lucky_cigarette,
    "lucky_keychain": draw_lucky_keychain,
    "lucky_ladies_compact": draw_lucky_ladies_compact,
    "lucky_reel_grease": draw_lucky_reel_grease,
    "marked_cards": draw_marked_cards,
    "odds_notebook": draw_odds_notebook,
    "bumper_battery": draw_bumper_battery,
    "plunger_tuner": draw_plunger_tuner,
    "rubber_pegs": draw_rubber_pegs,
    "extra_ball_token": draw_extra_ball_token,
    "lock_jammer": draw_lock_jammer,
    "magnet_cup": draw_magnet_cup,
    "chip_slide_wax": draw_chip_slide_wax,
    "holdout_wax": draw_holdout_wax,
    "edge_sort_loupe": draw_edge_sort_loupe,
    "dice_calipers": draw_dice_calipers,
    "neon_players_charm": draw_neon_players_charm,
    "payout_pamphlet": draw_payout_pamphlet,
    "pawn_receipt_sleeve": draw_pawn_receipt_sleeve,
    "payment_calendar": draw_payment_calendar,
    "police_scanner": draw_police_scanner,
    "rabbits_foot": draw_rabbits_foot,
    "roadside_map": draw_roadside_map,
    "scratch_pad": draw_scratch_pad,
    "shoe_cut_marker": draw_shoe_cut_marker,
    "side_bet_chart": draw_side_bet_chart,
    "split_reel_note": draw_split_reel_note,
    "splitter_token": draw_splitter_token,
    "suitcase": draw_suitcase,
    "tab_detector": draw_tab_detector,
    "tarot_card": draw_tarot_card,
    "timing_bracelet": draw_timing_bracelet,
    "tilt_dampener": draw_tilt_dampener,
    "tip_sheet": draw_tip_sheet,
    "thermos_black_coffee": draw_thermos_black_coffee,
    "trunk": draw_trunk,
    "return_spring": draw_return_spring,
    "weighted_keyring": draw_weighted_keyring,
    "xray_glasses": draw_xray_glasses,
}

GAME_ICONS = {
    "bar_dice": draw_bar_dice,
    "blackjack": draw_blackjack,
    "cards": draw_cards,
    "dice": draw_dice,
    "poker": draw_poker,
    "pull_tabs": draw_pull_tabs,
    "slot": draw_slot,
    "video_poker": draw_video_poker,
}

MAP_ICONS = {
    "apartment": draw_apartment_map,
    "back_alley": draw_back_alley_map,
    "bar": draw_bar_map,
    "beach": draw_beach_map,
    "corner_store": draw_corner_store_map,
    "delta_queen": draw_delta_queen_map,
    "gas_station_casino": draw_gas_station_casino_map,
    "grand_casino": draw_grand_casino_map,
    "house": draw_house_map,
    "jazz_club": draw_jazz_club_map,
    "kitty_cat_lounge": draw_kitty_cat_lounge_map,
    "motel": draw_motel_map,
    "motel_room": draw_motel_room_map,
    "small_underground_casino": draw_small_underground_casino_map,
}


MAP_BACKGROUNDS = {
    "cyberpunk_city_overhead": draw_cyberpunk_city_overhead,
}


def main():
    for name, draw_func in ITEM_ICONS.items():
        save(draw_func(), ITEM_DIR / f"{name}.png")
    for name, draw_func in GAME_ICONS.items():
        save(draw_func(), GAME_DIR / f"{name}.png")
    for name, draw_func in MAP_ICONS.items():
        save(draw_func(), MAP_ICON_DIR / f"{name}.png")
    for name, draw_func in MAP_BACKGROUNDS.items():
        save(draw_func(), MAP_BACKGROUND_DIR / f"{name}.png")
    print(
        f"Wrote {len(ITEM_ICONS)} item icons, {len(GAME_ICONS)} game icons, "
        f"{len(MAP_ICONS)} map icons, and {len(MAP_BACKGROUNDS)} map backgrounds."
    )


if __name__ == "__main__":
    main()
