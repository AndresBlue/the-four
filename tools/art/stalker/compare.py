"""Puts a game capture next to the reference picture: the middle of the 16:9
frame cut to the picture's portrait shape.

    python tools/art/stalker/compare.py capture.png reference.png out.png [--zoom 1.0] [--dy 0.0]
"""

import sys

from PIL import Image


def main():
    cap, ref, out = sys.argv[1:4]
    zoom = float(sys.argv[sys.argv.index("--zoom") + 1]) if "--zoom" in sys.argv else 1.0
    dy = float(sys.argv[sys.argv.index("--dy") + 1]) if "--dy" in sys.argv else 0.0
    a = Image.open(cap).convert("RGB")
    r = Image.open(ref).convert("RGB")
    h = int(a.height / zoom)
    w = int(h * r.width / r.height)
    cx = a.width // 2
    cy = int(a.height / 2 + dy * a.height)
    box = (cx - w // 2, max(0, cy - h // 2), cx + w // 2, min(a.height, cy + h // 2))
    crop = a.crop(box).resize((r.width, r.height), Image.LANCZOS)
    both = Image.new("RGB", (r.width * 2 + 12, r.height), (20, 20, 20))
    both.paste(crop, (0, 0))
    both.paste(r, (r.width + 12, 0))
    both.save(out)


if __name__ == "__main__":
    main()
