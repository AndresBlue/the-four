"""The "do not disturb" card that hangs on a door's knob (the author's word,
22 October 2026): the hotel's own, in the colours of its form.

    python tools/textures/bake_do_not_disturb.py

Writes assets/textures/no-molestar.png, 360 x 900: a card of the form's
cream, a hole and a slit at the top to go round the knob (alpha), the logo
taken off the form (assets/nota-hotel.png), "NO MOLESTAR" on a band of the
form's maroon, and "POR FAVOR" under it; and no-molestar-reverso.png, its
back, the same card with only the rule round it (where the pencil goes). Read held up (game/ui/hint_view.gd)
and seen on the door (game/world/interactables/hotel_hint.gd), the same
picture. The printing is set in Georgia from the system (on the author's
machine); without it, in Pillow's own face. Needs numpy and Pillow.
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.join(os.path.dirname(__file__), '..', '..')
FORM = os.path.join(ROOT, 'assets', 'nota-hotel.png')
OUT = os.path.join(ROOT, 'assets', 'textures', 'no-molestar.png')
BACK = os.path.join(ROOT, 'assets', 'textures', 'no-molestar-reverso.png')
SIZE = (360, 900)
CREAM = (234, 226, 208, 255)
MAROON = (92, 36, 40, 255)
INK = (34, 30, 28, 255)
SERIF = [r'C:\Windows\Fonts\georgia.ttf', r'C:\Windows\Fonts\times.ttf', '/System/Library/Fonts/Supplemental/Georgia.ttf']


def face(size):
    for path in SERIF:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def centred(draw, y, text, font, fill):
    width = draw.textlength(text, font=font)
    draw.text(((SIZE[0] - width) / 2, y), text, font=font, fill=fill)


def cut(card):
    """The hole for the knob and the slit up to the top edge, cut out."""
    whole = Image.new('L', SIZE, 255)
    knife = ImageDraw.Draw(whole)
    knife.ellipse([180 - 46, 92 - 46, 180 + 46, 92 + 46], fill=0)
    knife.rectangle([180 - 7, 0, 180 + 7, 92], fill=0)
    card.putalpha(Image.fromarray(np.minimum(np.asarray(card.split()[3]), np.asarray(whole))))
    return card


def blank():
    card = Image.new('RGBA', SIZE, CREAM)
    # A thin rule round the edge, as printed cards have.
    ImageDraw.Draw(card).rectangle([14, 14, SIZE[0] - 15, SIZE[1] - 15], outline=MAROON, width=3)
    return card


def main():
    back = cut(blank())
    back.save(BACK)
    print('wrote', os.path.normpath(BACK))
    card = blank()
    draw = ImageDraw.Draw(card)
    # The logo off the form, its dark strokes only.
    logo = Image.open(FORM).convert('RGBA').crop((48, 40, 205, 235))
    grey = logo.convert('L')
    mask = grey.point(lambda v: 255 if v < 90 else 0)
    stamp = Image.new('RGBA', logo.size, INK)
    stamp.putalpha(mask)
    stamp = stamp.resize((124, 154), Image.LANCZOS)
    card.alpha_composite(stamp, ((SIZE[0] - 124) // 2, 200))
    centred(draw, 372, 'HOTEL  THE  FOUR', face(26), INK)
    draw.rectangle([14, 470, SIZE[0] - 15, 640], fill=MAROON)
    centred(draw, 486, 'NO', face(70), CREAM)
    centred(draw, 572, 'MOLESTAR', face(44), CREAM)
    centred(draw, 680, 'POR FAVOR', face(30), INK)
    cut(card).save(OUT)
    print('wrote', os.path.normpath(OUT))


if __name__ == '__main__':
    main()
