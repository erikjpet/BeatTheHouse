from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
ITEM_DIR = ROOT / "assets" / "art" / "items"
GAME_DIR = ROOT / "assets" / "art" / "games"
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
    rect(d, (7, 12, 13, 17), rgba("#07141c"))
    rect(d, (18, 12, 24, 17), rgba("#07141c"))
    d.rectangle((8, 13, 12, 15), fill=CYAN)
    d.rectangle((19, 13, 23, 15), fill=CYAN)
    d.rectangle((13, 14, 18, 15), fill=PINK)
    line(d, (5, 15, 7, 14), PINK)
    line(d, (24, 14, 27, 16), PINK)
    glint(d, 24, 8)
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
    ellipse(d, (7, 8, 24, 25), AMBER)
    d.rectangle((12, 12, 18, 18), fill=TEAL)
    d.rectangle((10, 14, 20, 16), fill=TEAL)
    d.rectangle((14, 10, 16, 20), fill=TEAL)
    d.rectangle((15, 15, 17, 17), fill=FIELD)
    glint(d, 23, 8)
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
    rect(d, (6, 11, 14, 18), rgba("#07141c"))
    rect(d, (18, 11, 26, 18), rgba("#07141c"))
    d.rectangle((8, 13, 12, 16), fill=CYAN)
    d.rectangle((20, 13, 24, 16), fill=CYAN)
    d.rectangle((14, 14, 18, 15), fill=YELLOW)
    line(d, (4, 15, 6, 14), PINK)
    line(d, (26, 14, 29, 16), PINK)
    d.rectangle((9, 8, 11, 9), fill=YELLOW)
    d.rectangle((21, 8, 23, 9), fill=YELLOW)
    line(d, (10, 19, 8, 24), CYAN)
    line(d, (22, 19, 24, 24), CYAN)
    glint(d, 27, 8)
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
    coin(d, 7, 8, AMBER, PINK)
    poly(d, [(13, 13), (19, 12), (21, 17), (18, 23), (14, 23), (11, 17)], WHITE)
    d.rectangle((15, 14, 16, 21), fill=YELLOW)
    d.rectangle((18, 14, 19, 21), fill=YELLOW)
    d.arc((5, 6, 15, 17), 180, 315, fill=CYAN, width=2)
    d.arc((17, 6, 28, 17), 225, 360, fill=CYAN, width=2)
    glint(d, 23, 9)
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
    poly(d, [(8, 5), (23, 7), (25, 26), (9, 25)], PAPER)
    d.polygon([(10, 8), (22, 9), (23, 23), (11, 23)], fill=rgba("#241027"))
    ellipse(d, (13, 11, 20, 18), CYAN)
    d.ellipse((15, 13, 18, 16), fill=BLACK)
    poly(d, [(12, 21), (14, 17), (16, 20), (18, 16), (20, 21)], YELLOW)
    line(d, (9, 6, 24, 25), PINK)
    d.rectangle((6, 21, 10, 24), fill=AMBER)
    glint(d, 24, 7)
    return image


def draw_weighted_keyring():
    image, d = new_icon()
    ellipse(d, (7, 5, 21, 19), METAL)
    d.ellipse((11, 9, 17, 15), fill=FIELD)
    line(d, (16, 17, 25, 25), AMBER, 2)
    d.rectangle((22, 24, 28, 26), fill=AMBER)
    ellipse(d, (5, 17, 14, 26), rgba("#53616b"))
    d.rectangle((8, 20, 11, 23), fill=BLUE)
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


def draw_slots():
    image, d = new_icon()
    rect(d, (6, 7, 26, 25), BLUE)
    d.rectangle((8, 9, 24, 11), fill=PINK)
    for x, color in ((9, YELLOW), (15, PINK), (21, CYAN)):
        rect(d, (x, 14, x + 3, 20), SOFT)
        d.rectangle((x + 1, 16, x + 2, 18), fill=color)
    d.rectangle((10, 23, 22, 24), fill=AMBER)
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


def draw_last_chance():
    image, d = new_icon()
    poly(d, [(8, 8), (20, 7), (25, 19), (17, 26), (7, 23)], PAPER)
    d.rectangle((10, 11, 20, 12), fill=PINK)
    d.rectangle((11, 16, 18, 16), fill=BLACK)
    line(d, (14, 19, 22, 25), PINK, 2)
    ellipse(d, (21, 5, 27, 11), AMBER)
    return image


def draw_monte():
    image, d = new_icon()
    d.rectangle((6, 25, 26, 26), fill=BROWN)
    for x in (7, 13, 19):
        rect(d, (x, 11, x + 7, 22), BLUE)
        d.rectangle((x + 2, 14, x + 5, 15), fill=PINK)
    d.rectangle((15, 18, 17, 20), fill=YELLOW)
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


def draw_scratch():
    image, d = new_icon()
    rect(d, (7, 9, 24, 25), AMBER)
    d.rectangle((9, 11, 22, 13), fill=PINK)
    d.rectangle((10, 17, 21, 21), fill=CYAN)
    line(d, (11, 22, 21, 17), FRAME)
    ellipse(d, (21, 5, 27, 11), YELLOW)
    return image


def draw_scratch_tickets():
    image, d = new_icon()
    rect(d, (6, 8, 26, 25), AMBER)
    d.rectangle((8, 10, 24, 12), fill=PINK)
    d.rectangle((9, 17, 14, 21), fill=CYAN)
    d.rectangle((17, 17, 22, 21), fill=PINK_2)
    line(d, (23, 8, 28, 5), METAL, 2)
    glint(d, 27, 5)
    return image


def draw_street_dice():
    image, d = new_icon()
    d.rectangle((5, 23, 27, 26), fill=SHADOW)
    d.line((5, 22, 26, 18), fill=CYAN)
    dice(d, 8, 11)
    dice(d, 18, 15)
    d.rectangle((5, 27, 27, 27), fill=PINK)
    return image


def draw_three_card_monte():
    image, d = new_icon()
    d.rectangle((5, 25, 27, 26), fill=BROWN)
    for x, mark in ((7, BLACK), (13, PINK), (19, BLACK)):
        card(d, x, 10, 7, 11, SOFT, mark)
    d.rectangle((15, 15, 17, 17), fill=PINK)
    glint(d, 17, 8)
    return image


def draw_ticket():
    image, d = new_icon()
    poly(d, [(6, 8), (25, 8), (25, 23), (21, 23), (19, 26), (16, 23), (6, 23)], AMBER)
    d.rectangle((9, 11, 22, 12), fill=PINK)
    d.rectangle((9, 17, 14, 20), fill=CYAN)
    d.rectangle((17, 17, 22, 20), fill=PINK_2)
    d.rectangle((24, 7, 27, 9), fill=CYAN)
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


def draw_vpoker():
    image, d = new_icon()
    rect(d, (7, 7, 25, 25), BLUE)
    d.rectangle((10, 10, 22, 16), fill=PURPLE)
    for x in (11, 14, 17, 20):
        d.rectangle((x, 11, x + 1, 14), fill=SOFT)
    d.rectangle((10, 20, 12, 22), fill=CYAN)
    d.rectangle((15, 20, 17, 22), fill=PINK)
    d.rectangle((20, 20, 22, 22), fill=YELLOW)
    return image


ITEM_ICONS = {
    "basic_strategy_card": draw_basic_strategy_card,
    "broken_cufflinks": draw_broken_cufflinks,
    "card_counters_notes": draw_card_counters_notes,
    "cheap_sunglasses": draw_cheap_sunglasses,
    "coin_return_shim": draw_coin_return_shim,
    "cold_quarters": draw_cold_quarters,
    "coolers_cufflinks": draw_coolers_cufflinks,
    "creased_luck_card": draw_creased_luck_card,
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
    "jazz_cello_lucky_coin": draw_jazz_cello_lucky_coin,
    "jazz_drummer_glasses": draw_jazz_drummer_glasses,
    "jazz_drummer_lucky_coin": draw_jazz_drummer_lucky_coin,
    "jazz_sax_lucky_coin": draw_jazz_sax_lucky_coin,
    "loaded_dice": draw_loaded_dice,
    "lucky_charm": draw_lucky_charm,
    "lucky_cigarette": draw_lucky_cigarette,
    "lucky_keychain": draw_lucky_keychain,
    "lucky_ladies_compact": draw_lucky_ladies_compact,
    "lucky_reel_grease": draw_lucky_reel_grease,
    "marked_cards": draw_marked_cards,
    "neon_players_charm": draw_neon_players_charm,
    "payout_pamphlet": draw_payout_pamphlet,
    "police_scanner": draw_police_scanner,
    "rabbits_foot": draw_rabbits_foot,
    "roadside_map": draw_roadside_map,
    "scratch_pad": draw_scratch_pad,
    "side_bet_chart": draw_side_bet_chart,
    "split_reel_note": draw_split_reel_note,
    "tab_detector": draw_tab_detector,
    "tarot_card": draw_tarot_card,
    "timing_bracelet": draw_timing_bracelet,
    "tip_sheet": draw_tip_sheet,
    "weighted_keyring": draw_weighted_keyring,
    "xray_glasses": draw_xray_glasses,
}

GAME_ICONS = {
    "bar_dice": draw_bar_dice,
    "blackjack": draw_blackjack,
    "cards": draw_cards,
    "dice": draw_dice,
    "last_chance": draw_last_chance,
    "monte": draw_monte,
    "poker": draw_poker,
    "pull_tabs": draw_pull_tabs,
    "scratch": draw_scratch,
    "scratch_tickets": draw_scratch_tickets,
    "slot": draw_slot,
    "slots": draw_slots,
    "street_dice": draw_street_dice,
    "three_card_monte": draw_three_card_monte,
    "ticket": draw_ticket,
    "video_poker": draw_video_poker,
    "vpoker": draw_vpoker,
}


def main():
    for name, draw_func in ITEM_ICONS.items():
        save(draw_func(), ITEM_DIR / f"{name}.png")
    for name, draw_func in GAME_ICONS.items():
        save(draw_func(), GAME_DIR / f"{name}.png")
    print(f"Wrote {len(ITEM_ICONS)} item icons and {len(GAME_ICONS)} game icons.")


if __name__ == "__main__":
    main()
