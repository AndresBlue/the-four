"""The hotel's form as it is seen lying on a table, from across the room.

    python tools/textures/bake_hotel_note.py

Reads the author's form (assets/nota-hotel.png, 1024 x 1536) and writes
assets/textures/nota-hotel-lejos.png, 384 x 576: the same sheet with less in
it, for the papers of the hotel's own paperwork in the world
(game/world/interactables/hotel_document.gd, hotel_hint.gd). Up close they are
read held up (game/ui/hotel_form.gd); lying there, all that has to come across
is a printed form that somebody filled in: its dark bands and boxes, the logo,
and the ruled lines with typing on them.

  - The dark surround of the picture outside the paper's worn corners is cut
    out (alpha), so the sheet lies on the wood and not on a black square.
  - It is filled in as one of them would be: fields, a box crossed, a few
    paragraphs typed in Courier (the system's Courier New, which is what is
    on the author's machine; without it the typing is drawn as dashes), and a
    signature in pen. The same text on every one: at this size nobody reads it.
  - Brought down to 384 x 576, which takes the small print and the paper's
    grain out with it.

Needs numpy and Pillow.
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.join(os.path.dirname(__file__), '..', '..')
SOURCE = os.path.join(ROOT, 'assets', 'nota-hotel.png')
OUT = os.path.join(ROOT, 'assets', 'textures', 'nota-hotel-lejos.png')
SIZE = (384, 576)
COURIER = [r'C:\Windows\Fonts\cour.ttf', '/Library/Fonts/Courier New.ttf', '/System/Library/Fonts/Supplemental/Courier New.ttf']
RIBBON = (22, 20, 25, 230)
PEN = (26, 31, 72, 220)
# Where things are on the form, in its own pixels (as in hotel_form.gd).
RULED_FIRST, RULED_STEP = 461.0, 31.78
TYPE = 26
FIELDS = [((542, 298), 'RECEPCIÓN'), ((54, 361), 'PLANTA PRIMERA'), ((542, 361), 'AVISO'), ((772, 84), '0417')]
CROSSES = [(826, 418), (588, 1347.5), (818, 1288), (63.5, 1367)]
BODY = [
    'Tres quejas más de la planta primera. Dicen que la tele se',
    'enciende sola pasadas las tres y que en la pantalla sale',
    'alguien mirando desde muy cerca. El 107 pidió cambiar de',
    'habitación. El 112 no contestó al teléfono.',
    '',
    'Ya desenchufé dos aparatos y volvieron a encenderse. No',
    'subas solo. Si oyes golpes en una puerta, no abras para ver',
    'quién es.',
]


def cut_out(image):
    """Alpha: the dark surround, reached from the picture's border."""
    rgb = np.asarray(image.convert('RGB')).astype(np.float32)
    dark = rgb.mean(axis=2) < 70.0
    outside = np.zeros_like(dark)
    outside[0, :] = dark[0, :]
    outside[-1, :] = dark[-1, :]
    outside[:, 0] = dark[:, 0]
    outside[:, -1] = dark[:, -1]
    while True:
        grown = outside.copy()
        grown[1:, :] |= outside[:-1, :]
        grown[:-1, :] |= outside[1:, :]
        grown[:, 1:] |= outside[:, :-1]
        grown[:, :-1] |= outside[:, 1:]
        grown &= dark
        if (grown == outside).all():
            break
        outside = grown
    alpha = np.where(outside, 0, 255).astype(np.uint8)
    out = image.convert('RGBA')
    out.putalpha(Image.fromarray(alpha))
    return out


def typeface():
    for path in COURIER:
        if os.path.exists(path):
            return ImageFont.truetype(path, TYPE)
    return None


def type_at(draw, font, at, text):
    x, y = at
    if font is None:
        # Dashes for words, where there is no Courier to type with.
        for word in text.split(' '):
            if word:
                draw.rectangle([x, y - 12, x + len(word) * 15.6, y - 2], fill=RIBBON)
            x += (len(word) + 1) * 15.6
        return
    draw.text((x, y), text, font=font, fill=RIBBON, anchor='ls', stroke_width=1, stroke_fill=(RIBBON[0], RIBBON[1], RIBBON[2], 120))


def main():
    form = cut_out(Image.open(SOURCE))
    ink = Image.new('RGBA', form.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(ink)
    font = typeface()
    for at, text in FIELDS:
        type_at(draw, font, at, text)
    for line, text in enumerate(BODY):
        if text:
            type_at(draw, font, (72, RULED_FIRST + RULED_STEP * line - 6), text)
    for x, y in CROSSES:
        draw.line([(x - 9, y - 9), (x + 9, y + 9)], fill=RIBBON, width=4)
        draw.line([(x - 9, y + 9), (x + 9, y - 9)], fill=RIBBON, width=4)
    # The signature: loops along the line, and a stroke back under them.
    points = []
    for step in range(141):
        t = step / 140.0
        turn = t * 7.5 * 2 * np.pi
        tall = 1.0 if t < 1 / 7.5 else 0.45
        points.append((128 + t * 246 + np.sin(turn) * 7, 1464 - (0.5 - 0.5 * np.cos(turn)) * 40 * tall - t * 8))
    draw.line(points, fill=PEN, width=3, joint='curve')
    draw.line([(398, 1466), (250, 1471), (128, 1467)], fill=PEN, width=3)
    filled = Image.alpha_composite(form, ink)
    filled.resize(SIZE, Image.LANCZOS).save(OUT)
    print('wrote', os.path.normpath(OUT))


if __name__ == '__main__':
    main()
