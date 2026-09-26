"""The engraving of the refuge's exit sign (docs/REALISM.md, phase 4).

Draws SALIDA and an arrow pointing down as the mask an edge-lit acrylic panel
is read through (game/presentation/shaders/exit_panel.gdshader), in letters
drawn here as outlines: no font file is embedded, so nothing of anybody
else's is shipped.

Also the corridors' signs (exit_route_signs.gd): a figure running out of a
door and an arrow, way_right, way_left, way_ahead and way_back.png.

Writes assets/props/exit_sign/engraving.png, 1024 x 512, imported lossless:
  R  the engraved face, where the sheet scatters the light it guides
  G  the rim of the cut, which catches more of it and reads as a bright edge
  B  0

    python tools/textures/make_exit_sign.py
"""
import os
from math import cos, radians, sin
from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(HERE, "assets", "props", "exit_sign")
SIZE = (1024, 512)
# Drawn this many times larger and reduced, for clean diagonals.
OVER = 4
SUPER = (SIZE[0] * OVER, SIZE[1] * OVER)
# The lettering, in texture pixels: cap height, stroke, and the baseline.
CAP = 196
STROKE = 29
BASE = 352
TOP = BASE - CAP
GAP = 20
ARROW_GAP = 48


def rect(pen, x0, y0, x1, y1, fill=255):
    pen.rectangle([x0 * OVER, y0 * OVER, x1 * OVER, y1 * OVER], fill=fill)


def poly(pen, points, fill=255):
    pen.polygon([(x * OVER, y * OVER) for x, y in points], fill=fill)


def bow(cx, cy, rx, ry, first, last, steps=200):
    """Points along an ellipse, from one angle to another (degrees, 0 to the
    right and turning the way the picture reads: down is positive)."""
    out = []
    for i in range(steps + 1):
        angle = radians(first + (last - first) * i / steps)
        out.append((cx + rx * cos(angle), cy + ry * sin(angle)))
    return out


def joining(a, b, steps=24):
    return [(a[0] + (b[0] - a[0]) * i / steps, a[1] + (b[1] - a[1]) * i / steps) for i in range(steps + 1)]


def stroke_path(pen, path, width=STROKE):
    """The path stamped with a round pen: the union of the discs has a clean
    outline, which a wide line of straight segments does not."""
    radius = width * 0.5 * OVER
    for px, py in path:
        pen.ellipse([px * OVER - radius, py * OVER - radius, px * OVER + radius, py * OVER + radius], fill=255)


def cut(pen, point, away):
    """Squares off a terminal: the round end of the pen, and no more than
    that, taken off past the point in the direction the stroke was going."""
    half = STROKE * 0.75
    depth = STROKE * 1.5
    normal = (-away[1], away[0])
    poly(pen, [
        (point[0] + normal[0] * half, point[1] + normal[1] * half),
        (point[0] - normal[0] * half, point[1] - normal[1] * half),
        (point[0] - normal[0] * half + away[0] * depth, point[1] - normal[1] * half + away[1] * depth),
        (point[0] + normal[0] * half + away[0] * depth, point[1] + normal[1] * half + away[1] * depth),
    ], fill=0)


def letter_S(mask, x, w):
    """One stroke along the letter's own line: round the top bowl, across the
    spine and round the lower one, the wider of the two. Both terminals are
    cut off square, the way a grotesque's are."""
    layer = Image.new("L", SUPER, 0)
    pen = ImageDraw.Draw(layer)
    top_h = CAP * 0.54
    low_h = CAP * 0.58
    cx = x + w * 0.5
    rx = (w - STROKE) * 0.5
    top = bow(cx, TOP + top_h * 0.5, rx, (top_h - STROKE) * 0.5, -6, -254)
    low = bow(cx, BASE - low_h * 0.5, rx, (low_h - STROKE) * 0.5, -58, 190)
    stroke_path(pen, top + joining(top[-1], low[0]) + low)
    cut(pen, top[0], (0.1, 1.0))
    cut(pen, low[-1], (0.17, -1.0))
    mask.paste(ImageChops.lighter(mask, layer))


def letter_A(mask, x, w):
    pen = ImageDraw.Draw(mask)
    apex = x + w * 0.5
    poly(pen, [(x, BASE), (apex - STROKE * 0.5, TOP), (apex + STROKE * 0.5, TOP), (x + w, BASE)])
    inner = STROKE * 1.3
    poly(pen, [(x + inner, BASE), (apex, TOP + STROKE * 1.6), (x + w - inner, BASE)], fill=0)
    bar = BASE - STROKE * 2.0
    rect(pen, x + STROKE * 0.7, bar, x + w - STROKE * 0.7, bar + STROKE)


def letter_L(mask, x, w):
    pen = ImageDraw.Draw(mask)
    rect(pen, x, TOP, x + STROKE, BASE)
    rect(pen, x, BASE - STROKE, x + w, BASE)


def letter_I(mask, x, w):
    rect(ImageDraw.Draw(mask), x, TOP, x + STROKE, BASE)


def letter_D(mask, x, w):
    pen = ImageDraw.Draw(mask)
    radius = CAP * 0.46
    pen.rounded_rectangle([x * OVER, TOP * OVER, (x + w) * OVER, BASE * OVER],
                          radius=radius * OVER, fill=255, corners=(False, True, True, False))
    pen.rounded_rectangle([(x + STROKE) * OVER, (TOP + STROKE) * OVER,
                           (x + w - STROKE) * OVER, (BASE - STROKE) * OVER],
                          radius=(radius - STROKE) * OVER, fill=0, corners=(False, True, True, False))
    rect(pen, x, TOP, x + STROKE, BASE)


def arrow(mask, x, w):
    """A block arrow pointing down: the way out is here, under the sign."""
    pen = ImageDraw.Draw(mask)
    head = w * 0.52
    shaft = STROKE * 1.35
    middle = x + w * 0.5
    rect(pen, middle - shaft * 0.5, TOP, middle + shaft * 0.5, BASE - head)
    poly(pen, [(x, BASE - head), (x + w, BASE - head), (middle, BASE)])


LETTERS = [(letter_S, 112), (letter_A, 124), (letter_L, 98), (letter_I, STROKE), (letter_D, 114), (letter_A, 124)]


def draw_engraving():
    mask = Image.new("L", SUPER, 0)
    lettering = sum(w for _, w in LETTERS) + GAP * (len(LETTERS) - 1)
    head = CAP * 0.64
    x = (SIZE[0] - (lettering + ARROW_GAP + head)) * 0.5
    for glyph, w in LETTERS:
        glyph(mask, x, w)
        x += w + GAP
    arrow(mask, x - GAP + ARROW_GAP, head)
    return mask.resize(SIZE, Image.LANCZOS)


# --- The corridors' signs: the way out --------------------------------------
# A figure running out through a door, and an arrow saying which way: right,
# left (the same, mirrored), ahead (up) and back (a turn). The figure runs
# the way the arrow points; ahead and back keep it running right.
FIG = 300  # the figure's box, in texture pixels
LIMB = 30


def figure(mask, x0, y0):
    """The running figure of the standard sign, in its own box: head, body
    leaning into the run, the front arm reaching, the back arm pulling, one
    leg stepping out and the other kicking back. Stamped with a round pen."""
    layer = Image.new("L", SUPER, 0)
    pen = ImageDraw.Draw(layer)
    at = lambda u, v: (x0 + u * FIG, y0 + v * FIG)
    head = at(0.60, 0.13)
    r = 0.085 * FIG
    pen.ellipse([(head[0] - r) * OVER, (head[1] - r) * OVER, (head[0] + r) * OVER, (head[1] + r) * OVER], fill=255)

    def limb(points, width=LIMB):
        path = []
        for a, b in zip(points, points[1:]):
            path += joining(at(*a), at(*b), 40)
        stroke_path(pen, path, width)

    limb([(0.54, 0.29), (0.44, 0.58)], LIMB * 1.45)            # body
    limb([(0.55, 0.32), (0.70, 0.36), (0.80, 0.48)])           # front arm
    limb([(0.52, 0.33), (0.36, 0.40), (0.24, 0.35)])           # back arm
    limb([(0.45, 0.58), (0.62, 0.70), (0.60, 0.90), (0.72, 0.90)])  # front leg
    limb([(0.43, 0.60), (0.32, 0.76), (0.12, 0.78)])           # back leg
    mask.paste(ImageChops.lighter(mask, layer))


def door(mask, x0, y0):
    """The door it comes out of: a frame open on the side it runs to."""
    pen = ImageDraw.Draw(mask)
    t = LIMB * 0.55
    rect(pen, x0, y0 - 6, x0 + t, y0 + FIG * 0.98)
    rect(pen, x0, y0 - 6, x0 + FIG * 0.34, y0 - 6 + t)
    rect(pen, x0, y0 + FIG * 0.98 - t, x0 + FIG * 0.22, y0 + FIG * 0.98)


def side_arrow(mask, x0, y0, w, h):
    """A block arrow pointing right, as the standard's."""
    pen = ImageDraw.Draw(mask)
    head = h * 0.5
    shaft = h * 0.34
    mid = y0 + h * 0.5
    rect(pen, x0, mid - shaft * 0.5, x0 + w - head, mid + shaft * 0.5)
    poly(pen, [(x0 + w - head - 2, y0), (x0 + w, mid), (x0 + w - head - 2, y0 + h)])


def up_arrow(mask, x0, y0, w, h):
    pen = ImageDraw.Draw(mask)
    head = w * 0.5
    shaft = w * 0.34
    mid = x0 + w * 0.5
    rect(pen, mid - shaft * 0.5, y0 + head - 2, mid + shaft * 0.5, y0 + h)
    poly(pen, [(x0, y0 + head), (mid, y0), (x0 + w, y0 + head)])


def turn_arrow(mask, x0, y0, w, h):
    """Back the way you came: a shaft going up, over and down into a head."""
    layer = Image.new("L", SUPER, 0)
    pen = ImageDraw.Draw(layer)
    shaft = w * 0.2
    left = x0 + shaft * 0.5
    right = x0 + w - w * 0.28
    top = y0 + (right - left) * 0.5 + shaft * 0.5
    bend = bow((left + right) * 0.5, top, (right - left) * 0.5, (right - left) * 0.5, 180, 360, 120)
    path = joining((left, y0 + h), bend[0]) + bend + joining(bend[-1], (right, y0 + h * 0.62))
    stroke_path(pen, path, shaft)
    mask.paste(ImageChops.lighter(mask, layer))
    pen = ImageDraw.Draw(mask)
    rect(pen, left - shaft * 0.5, y0 + h - 6, left + shaft * 0.5, y0 + h)
    head = w * 0.3
    poly(pen, [(right - head, y0 + h * 0.62), (right + head, y0 + h * 0.62), (right, y0 + h)])


def draw_way(kind):
    mask = Image.new("L", SUPER, 0)
    y0 = (SIZE[1] - FIG) * 0.5
    fx = 150
    door(mask, fx, y0)
    figure(mask, fx + 40, y0)
    ax = fx + FIG + 110
    if kind == "right":
        side_arrow(mask, ax, y0 + FIG * 0.18, 300, FIG * 0.64)
    elif kind == "ahead":
        up_arrow(mask, ax + 70, y0 + 6, FIG * 0.56, FIG * 0.9)
    elif kind == "back":
        turn_arrow(mask, ax + 40, y0 + 10, FIG * 0.8, FIG * 0.86)
    return mask.resize(SIZE, Image.LANCZOS)


def save(fill, name):
    # The rim of the cut: what the fill loses when it is eaten in by a few
    # pixels, which is where an engraved letter catches the guided light.
    inner = fill.filter(ImageFilter.MinFilter(7))
    edge = ImageChops.subtract(fill, inner).filter(ImageFilter.GaussianBlur(1.2))
    os.makedirs(OUT, exist_ok=True)
    Image.merge("RGB", (fill, edge, Image.new("L", SIZE, 0))).save(os.path.join(OUT, name))
    print(name, SIZE)


def main():
    save(draw_engraving(), "engraving.png")
    right = draw_way("right")
    save(right, "way_right.png")
    save(right.transpose(Image.FLIP_LEFT_RIGHT), "way_left.png")
    save(draw_way("ahead"), "way_ahead.png")
    save(draw_way("back"), "way_back.png")


if __name__ == "__main__":
    main()
