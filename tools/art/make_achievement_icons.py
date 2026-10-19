"""The icons of the achievements (game/ui/achievements_board.gd), one per
milestone of a floor (game/floors/hotel_floor.gd, MILESTONES): a dark badge
with a thin amber edge and a line drawing in the camcorder's amber, drawn here
from plain shapes (no image of anybody's), at four times the size and brought
down so its edges are smooth.

    python tools/art/make_achievement_icons.py [--steam <folder>]

Writes assets/ui/achievements/<floor>_<id>.png (256 px). With --steam it also
writes, into <folder>, what Steamworks asks for each achievement: the icon
achieved and its grey "locked" one, as <API_NAME>.jpg and <API_NAME>_locked.jpg
(the API name is F<floor>_<ID>, steam_link.gd).

Deterministic: re-running reproduces the same files.
"""
from pathlib import Path
import math
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/ui/achievements"
SIZE = 256
BIG = SIZE * 4
AMBER = (245, 199, 102, 255)
DARK = (14, 13, 12, 255)
EDGE = (245, 199, 102, 150)
FONT = "C:/Windows/Fonts/consolab.ttf"
W = 34  # line width on the big canvas


def badge():
    image = Image.new("RGBA", (BIG, BIG), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((24, 24, BIG - 24, BIG - 24), radius=110, fill=DARK, outline=EDGE, width=14)
    return image, draw


def figure(draw, cx, cy, s, fill=True):
    """A person: a head and a body, standing at (cx, cy) its middle, s tall."""
    head = s * 0.17
    draw.ellipse((cx - head, cy - s * 0.5, cx + head, cy - s * 0.5 + head * 2), fill=AMBER)
    top = cy - s * 0.5 + head * 2 + s * 0.05
    draw.rounded_rectangle((cx - s * 0.24, top, cx + s * 0.24, cy + s * 0.5), radius=s * 0.16, fill=AMBER if fill else None, outline=AMBER, width=W)


def text(draw, cx, cy, words, size):
    font = ImageFont.truetype(FONT, size)
    box = draw.textbbox((0, 0), words, font=font)
    draw.text((cx - (box[0] + box[2]) / 2, cy - (box[1] + box[3]) / 2), words, font=font, fill=AMBER)


def cassette(draw):
    draw.rounded_rectangle((210, 330, 814, 700), radius=40, outline=AMBER, width=W)
    draw.rectangle((330, 400, 694, 540), outline=AMBER, width=24)
    for x in (400, 624):
        draw.ellipse((x - 46, 424, x + 46, 516), outline=AMBER, width=22)
    draw.polygon([(330, 700), (370, 610), (654, 610), (694, 700)], outline=AMBER, width=24)


def stopwatch(draw, words):
    draw.ellipse((262, 300, 762, 800), outline=AMBER, width=W)
    draw.rectangle((462, 214, 562, 262), fill=AMBER)
    draw.rectangle((497, 250, 527, 300), fill=AMBER)
    draw.line((700, 330, 744, 286), fill=AMBER, width=W)
    text(draw, 512, 560, words, 230)


def television(draw):
    draw.rounded_rectangle((230, 330, 794, 730), radius=50, outline=AMBER, width=W)
    draw.rounded_rectangle((290, 390, 660, 670), radius=40, outline=AMBER, width=24)
    for y in (450, 540, 630):
        draw.ellipse((705, y - 24, 753, y + 24), fill=AMBER)
    draw.line((420, 330, 330, 210), fill=AMBER, width=26)
    draw.line((604, 330, 694, 210), fill=AMBER, width=26)
    draw.line((330, 730, 300, 800), fill=AMBER, width=W)
    draw.line((694, 730, 724, 800), fill=AMBER, width=W)


def keypad(draw):
    draw.rounded_rectangle((300, 200, 724, 824), radius=40, outline=AMBER, width=W)
    draw.rectangle((350, 250, 674, 360), outline=AMBER, width=22)
    for row in range(4):
        for col in range(3):
            x = 380 + col * 132
            y = 420 + row * 100
            draw.rounded_rectangle((x - 40, y - 34, x + 40, y + 34), radius=10, fill=AMBER)


def wardrobe(draw):
    draw.rectangle((300, 210, 724, 820), outline=AMBER, width=W)
    draw.line((512, 210, 512, 820), fill=AMBER, width=26)
    for x in (470, 554):
        draw.ellipse((x - 18, 490, x + 18, 526), fill=AMBER)
    draw.line((230, 820, 794, 210), fill=DARK, width=W * 3)
    draw.line((230, 820, 794, 210), fill=AMBER, width=W)


def eye(draw, crossed=True):
    # The lids: two curves meeting at the corners, and the iris between.
    upper, lower = [], []
    for i in range(41):
        t = -1.0 + i / 20.0
        x = 512 + t * 310
        upper.append((x, 520 - 190 * (1 - t * t)))
        lower.append((x, 520 + 150 * (1 - t * t)))
    draw.line(upper, fill=AMBER, width=W, joint="curve")
    draw.line(lower, fill=AMBER, width=W, joint="curve")
    draw.ellipse((420, 418, 604, 602), fill=AMBER)
    if crossed:
        draw.line((250, 790, 774, 240), fill=DARK, width=W * 3)
        draw.line((250, 790, 774, 240), fill=AMBER, width=W)


def star(draw):
    points = []
    for i in range(10):
        r = 330 if i % 2 == 0 else 140
        a = -math.pi / 2 + i * math.pi / 5
        points.append((512 + r * math.cos(a), 540 + r * math.sin(a)))
    draw.polygon(points, fill=AMBER)


def grade(draw, letter):
    draw.ellipse((222, 222, 802, 802), outline=AMBER, width=W)
    text(draw, 512, 520, letter, 420)


def again(draw):
    draw.arc((232, 232, 792, 792), 30, 320, fill=AMBER, width=W)
    # The arrowhead at the arc's start, pointing on round it.
    a = math.radians(30)
    tip = (512 + 280 * math.cos(a), 512 + 280 * math.sin(a))
    draw.polygon([(tip[0] + 70, tip[1] - 40), (tip[0] - 60, tip[1] - 30), (tip[0] + 20, tip[1] + 90)], fill=AMBER)
    text(draw, 512, 520, "2", 300)


def exit_sign(draw):
    draw.rectangle((520, 220, 760, 820), outline=AMBER, width=W)
    draw.ellipse((560, 500, 596, 536), fill=AMBER)
    figure(draw, 360, 520, 380)
    draw.line((230, 380, 150, 380), fill=AMBER, width=22)
    draw.line((230, 470, 120, 470), fill=AMBER, width=22)
    draw.line((230, 560, 160, 560), fill=AMBER, width=22)


def shield(draw):
    draw.polygon([(512, 200), (790, 300), (760, 560), (512, 830), (264, 560), (234, 300)], outline=AMBER, width=W)
    draw.line((380, 520, 480, 620), fill=AMBER, width=W + 8)
    draw.line((470, 630, 660, 400), fill=AMBER, width=W + 8)


def claws(draw):
    # Three slashes side by side, each bowed a little, thick in the middle.
    for k in range(3):
        points = []
        for i in range(25):
            t = i / 24.0
            points.append((512 + (k - 1) * 170 + (t - 0.5) * 300 + 70 * math.sin(math.pi * t), 220 + t * 590))
        draw.line(points, fill=AMBER, width=W + 14, joint="curve")


def people(draw, count, mark=False):
    s = 420 if count <= 2 else 360 if count == 3 else 300
    gap = s * 0.62
    first = 512 - gap * (count - 1) / 2
    for i in range(count):
        figure(draw, first + i * gap, 560, s)
    if mark:
        draw.line((440, 250, 500, 310), fill=AMBER, width=W)
        draw.line((490, 318, 600, 196), fill=AMBER, width=W)


DRAWINGS = {
    "out": cassette,
    "solo": lambda d: figure(d, 512, 530, 520),
    "clean": lambda d: people(d, 3, True),
    "brave": wardrobe,
    "half": lambda d: stopwatch(d, "30"),
    "quick": lambda d: stopwatch(d, "20"),
    "three": lambda d: people(d, 3),
    "four": lambda d: people(d, 4),
    "again": again,
    "sets": television,
    "code": keypad,
    "slip": exit_sign,
    "ghost": eye,
    "mvp": star,
    "first": lambda d: grade(d, "A"),
    "master": lambda d: grade(d, "S"),
    "hunted": shield,
    "hunter": claws,
}
## The milestones of each floor, as hotel_floor.gd has them.
FLOORS = {1: list(DRAWINGS.keys())}


def main():
    steam = None
    if "--steam" in sys.argv:
        steam = Path(sys.argv[sys.argv.index("--steam") + 1])
        steam.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    for floor, ids in FLOORS.items():
        for milestone in ids:
            image, draw = badge()
            DRAWINGS[milestone](draw)
            icon = image.resize((SIZE, SIZE), Image.LANCZOS)
            icon.save(OUT / f"{floor}_{milestone}.png")
            if steam is not None:
                name = f"F{floor}_{milestone.upper()}"
                flat = Image.new("RGB", icon.size, (0, 0, 0))
                flat.paste(icon, mask=icon.split()[3])
                flat.save(steam / f"{name}.jpg", quality=92)
                grey = flat.convert("L").point(lambda v: int(v * 0.45)).convert("RGB")
                grey.save(steam / f"{name}_locked.jpg", quality=92)
            print("icon", f"{floor}_{milestone}.png")


if __name__ == "__main__":
    main()
