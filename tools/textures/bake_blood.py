"""The shapes blood leaves on a surface, baked into one atlas.

    python tools/textures/bake_blood.py

Writes assets/decals/blood_atlas.png: four by four cells of 256 pixels, each
one stain as game/presentation/shaders/blood.gdshader reads it --

    R, G   the slope of its surface (a normal's x and y, 0.5 flat)
    B      how thick it lies there (0 a film, 1 a bead)
    A      how much of the surface it covers

Cells 0-7 are drops that fell straight: a body, the spines it throws out all
round and the satellites beyond them. Cells 8-13 are drops that came in at an
angle: the same body, and everything it throws thrown one way (towards +v,
where the quad that carries it is stretched). Cells 14-15 are runs: what a
thick stain on a wall lets go down it, a thread with a bead at its end.

Drawn, not photographed, and the same every time (the seed is fixed): no
recording of blood is in the project, and none is needed to know what a drop
does when it lands. Needs numpy and Pillow.
"""
import os
import numpy as np
from PIL import Image

CELL = 256
GRID = 4
OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'decals', 'blood_atlas.png')


def blob(field, x, y, radius, weight=1.0):
    """A drop of the liquid added to the field: a soft bump, `radius` wide."""
    yy, xx = np.mgrid[0:CELL, 0:CELL]
    d2 = ((xx - x) ** 2 + (yy - y) ** 2) / float(radius * radius)
    field += weight * np.exp(-d2 * 1.6)


def noise(rng, size, octaves=4):
    """Smooth noise in 0..1, to break an edge."""
    total = np.zeros((size, size))
    for octave in range(octaves):
        cells = 4 * 2 ** octave
        coarse = rng.random((cells + 1, cells + 1))
        image = Image.fromarray((coarse * 255).astype(np.uint8)).resize((size, size), Image.BICUBIC)
        total += np.asarray(image, dtype=np.float64) / 255.0 / 2 ** octave
    return total / total.max()


def finish(field, rng):
    """From how much liquid lies at each point to what the shader reads."""
    field = field * (0.8 + 0.4 * noise(rng, CELL))
    # It holds together: what is above the line is stain, with a rounded edge.
    level = 0.42
    cover = np.clip((field - level) / 0.1, 0.0, 1.0)
    cover = cover * cover * (3.0 - 2.0 * cover)
    # Thick in the middle of a body, a film towards its edge -- and a bead
    # along the edge itself, where a drop piles up as it stops.
    inside = np.clip((field - level) / 1.4, 0.0, 1.0)
    rim = np.exp(-((field - level - 0.16) / 0.11) ** 2) * 0.45
    thick = np.clip(inside ** 0.7 * 0.85 + rim, 0.0, 1.0) * cover
    gy, gx = np.gradient(thick)
    slope = 5.0
    red = np.clip(0.5 - gx * slope, 0.0, 1.0)
    green = np.clip(0.5 - gy * slope, 0.0, 1.0)
    return np.dstack([red, green, thick, cover])


def straight(rng):
    field = np.zeros((CELL, CELL))
    middle = CELL / 2
    body = rng.uniform(26, 38)
    for _ in range(5):
        blob(field, middle + rng.normal(0, 6), middle + rng.normal(0, 6), body * rng.uniform(0.7, 1.0), 1.0)
    # Spines: thrown out all round as it flattens, each a few beads long.
    for _ in range(rng.integers(7, 14)):
        angle = rng.uniform(0, 2 * np.pi)
        reach = body * rng.uniform(1.2, 2.3)
        for step in np.linspace(0.75, 1.0, 5):
            blob(field, middle + np.cos(angle) * reach * step, middle + np.sin(angle) * reach * step, rng.uniform(3.0, 6.5) * (1.4 - step * 0.6), 0.75)
    # Satellites: the small ones that left it altogether.
    for _ in range(rng.integers(6, 16)):
        angle = rng.uniform(0, 2 * np.pi)
        reach = body * rng.uniform(2.0, 3.1)
        blob(field, middle + np.cos(angle) * reach, middle + np.sin(angle) * reach, rng.uniform(2.2, 5.0), 0.9)
    return finish(field, rng)


def slanted(rng):
    field = np.zeros((CELL, CELL))
    middle = CELL / 2
    body = rng.uniform(20, 28)
    start = CELL * 0.3
    # The body, drawn out the way it was going.
    for step in np.linspace(0.0, 1.0, 9):
        blob(field, middle + rng.normal(0, 2.5), start + step * body * 1.9, body * (1.0 - step * 0.55), 0.8)
    # The tail: what went on when the body stopped.
    for _ in range(rng.integers(2, 5)):
        across = rng.normal(0, body * 0.35)
        far = rng.uniform(body * 2.2, body * 4.2)
        for step in np.linspace(0.45, 1.0, 9):
            blob(field, middle + across * step, start + body + far * step, rng.uniform(2.6, 5.5) * (1.3 - step * 0.5), 0.75)
        blob(field, middle + across, start + body + far * 1.08, rng.uniform(3.5, 6.5), 1.0)
    # And the satellites, the same way.
    for _ in range(rng.integers(5, 12)):
        blob(field, middle + rng.normal(0, body * 0.9), start + body + rng.uniform(body * 1.5, CELL * 0.6), rng.uniform(2.0, 4.5), 0.9)
    return finish(field, rng)


def run(rng):
    field = np.zeros((CELL, CELL))
    middle = CELL / 2
    wander = 0.0
    # A thread down the cell (v runs downwards), a little off its line.
    for step in np.linspace(0.04, 0.9, 60):
        wander += rng.normal(0, 0.5)
        blob(field, middle + wander, CELL * step, rng.uniform(5.0, 7.5) * (1.0 - step * 0.3), 0.7)
    # The bead it ends in.
    blob(field, middle + wander, CELL * 0.92, 12.0, 1.3)
    return finish(field, rng)


def main():
    rng = np.random.default_rng(1988)
    atlas = np.zeros((CELL * GRID, CELL * GRID, 4))
    for index in range(GRID * GRID):
        cell = straight(rng) if index < 8 else slanted(rng) if index < 14 else run(rng)
        row, column = divmod(index, GRID)
        atlas[row * CELL:(row + 1) * CELL, column * CELL:(column + 1) * CELL] = cell
    path = os.path.normpath(OUT)
    Image.fromarray((atlas * 255.0 + 0.5).astype(np.uint8), 'RGBA').save(path)
    print('BLOOD_ATLAS', path, atlas.shape)


main()
