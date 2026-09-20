"""The game's icon, from the artwork to what Windows and Godot need.

The artwork is a square painting with the badge on a black field. Windows
wants the field gone (or the taskbar shows a black tile), so the outside is
cut away by flooding from the corners over what is nearly black: only what is
connected to the border goes, and the dark doorway inside the badge stays.

    python tools/textures/make_icon.py [source]

Source: source_assets/icon/the_four.png (outside git; the original the user
supplied, whatever its extension said it was). Writes:
  assets/images/the_four.ico  the icon of the exported game, seven sizes
  assets/images/the_four.png  256 px, the project icon Godot shows
"""
import os
import sys
from collections import deque
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SOURCE = os.path.join(HERE, "source_assets", "icon", "the_four.png")
OUT = os.path.join(HERE, "assets", "images")
SIZES = [16, 24, 32, 48, 64, 128, 256]
## A pixel this dark, and joined to the border, is the field round the badge.
FIELD = 24


def cut_field(image):
    """Transparent wherever the black field is, from the border inwards."""
    w, h = image.size
    pixels = image.load()
    outside = bytearray(w * h)
    queue = deque()
    for x in range(w):
        for y in (0, h - 1):
            queue.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            queue.append((x, y))
    while queue:
        x, y = queue.pop()
        if x < 0 or y < 0 or x >= w or y >= h or outside[y * w + x]:
            continue
        r, g, b = pixels[x, y][:3]
        if max(r, g, b) > FIELD:
            continue
        outside[y * w + x] = 1
        queue.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    alpha = Image.frombytes("L", (w, h), bytes(255 - v * 255 for v in outside))
    # A touch of blur, so the cut has an edge and not a staircase.
    image.putalpha(alpha.filter(ImageFilter.GaussianBlur(1.5)).point(lambda v: min(255, int(v * 1.35))))
    return image


def main():
    source = sys.argv[1] if len(sys.argv) > 1 else SOURCE
    art = cut_field(Image.open(source).convert("RGBA"))
    os.makedirs(OUT, exist_ok=True)
    square = art.resize((256, 256), Image.LANCZOS)
    square.save(os.path.join(OUT, "the_four.png"))
    # Every size drawn from the artwork itself, not from the one before it.
    art.save(os.path.join(OUT, "the_four.ico"), sizes=[(s, s) for s in SIZES])
    print("the_four.ico", SIZES, "/ the_four.png 256")


if __name__ == "__main__":
    main()
