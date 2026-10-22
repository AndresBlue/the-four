"""The hotel's papers as they are seen lying on a table, from across the room:
its form, and the letter and the notebook's page (assets/carta.png,
assets/libreta.png, 22 October 2026), each typed over and brought down to
assets/textures/<paper>-lejos.png the same way.

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
    for paper in RULED:
        bake_ruled(paper)
    bake_piece()


# The ruled papers (game/ui/ruled_paper.gd): the letter folded in four and the
# page of a notebook, typed over with what is read on them.
RULED = {
    'carta': {'lines': [158, 199, 238, 275, 315, 354, 393, 432, 470, 510, 549, 587, 626, 665, 706, 746, 790], 'from': 66, 'to': 966, 'type': 26,
              'text': ['Si alguien encuentra esto: me he pasado la noche dentro de un armario. Lo que anda por los pasillos ve muy lejos, mucho más lejos que tú. No le apuntes con la linterna, la luz lo trae.', '', 'Cuando se para en seco y chilla, ya sabe dónde estás. Ese segundo es lo único que tienes: sal de su vista.']},
    'libreta': {'lines': [182, 239, 295, 350, 406, 462, 518, 574, 631, 686, 742], 'from': 100, 'to': 948, 'type': 28,
                'text': ['02:40 Pasos en la planta de arriba. No son de persona, suenan como puntas contra el suelo.', '02:55 Se oye por las puertas abiertas y por los pasillos. A través de las paredes, nada. Cierro detrás de mí.', '03:10 En la sala de la salida no entra. Me quedo aquí hasta que se haga de día.']},
}


def bake_ruled(paper):
    spec = RULED[paper]
    source = Image.open(os.path.join(ROOT, 'assets', paper + '.png'))
    sheet = source.convert('RGBA') if source.mode == 'RGBA' else cut_out(source)
    ink = Image.new('RGBA', sheet.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(ink)
    font = ImageFont.truetype(next(path for path in COURIER if os.path.exists(path)), spec['type']) if any(os.path.exists(path) for path in COURIER) else None
    per_line = int((spec['to'] - spec['from']) / (spec['type'] * 0.6))
    lines = []
    for paragraph in spec['text']:
        current = ''
        for word in paragraph.split(' '):
            trial = word if not current else current + ' ' + word
            if current and len(trial) > per_line:
                lines.append(current)
                current = word
            else:
                current = trial
        lines.append(current)
    for index, text in enumerate(lines[:len(spec['lines'])]):
        if text:
            type_at(draw, font, (spec['from'], spec['lines'][index] - 7), text)
    out = os.path.join(ROOT, 'assets', 'textures', paper + '-lejos.png')
    Image.alpha_composite(sheet, ink).resize(SIZE, Image.LANCZOS).save(out)
    print('wrote', os.path.normpath(out))


# The pages of the code are the letter torn along its folds into four
# (game/ui/torn_letter.gd): what shows of one shut in a piece of furniture is
# the outside of a quarter, ruled and blank, torn along its two inner edges.
FOLD = (515, 767)
PIECE = (256, 384)


def torn_mask(size, cut_x, cut_y, seed):
    """Alpha of the top-left quarter: straight where the letter's own edges
    are, ragged along the folds it was torn on (right and bottom)."""
    rng = np.random.default_rng(seed)
    w, h = size
    mask = Image.new('L', size, 0)
    draw = ImageDraw.Draw(mask)
    right = [(cut_x + rng.uniform(-7, 7), y) for y in np.linspace(0, cut_y, 26)]
    bottom = [(x, cut_y + rng.uniform(-7, 7)) for x in np.linspace(cut_x, 0, 20)]
    draw.polygon([(0, 0), (cut_x, 0)] + right + bottom + [(0, cut_y)], fill=255)
    return mask


def bake_piece():
    sheet = Image.open(os.path.join(ROOT, 'assets', 'carta.png')).convert('RGBA')
    quarter = sheet.crop((0, 0, FOLD[0] + 10, FOLD[1] + 10))
    cut = torn_mask(quarter.size, FOLD[0] - 4, FOLD[1] - 4, 7)
    alpha = Image.fromarray(np.minimum(np.asarray(quarter.split()[3]), np.asarray(cut)))
    quarter.putalpha(alpha)
    out = os.path.join(ROOT, 'assets', 'textures', 'carta-trozo.png')
    quarter.resize(PIECE, Image.LANCZOS).save(out)
    print('wrote', os.path.normpath(out))


if __name__ == '__main__':
    main()
