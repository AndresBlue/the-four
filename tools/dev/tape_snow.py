"""The snow of a tape with nothing on it, as a video of it keeps it: three
frames, one in each channel of assets/textures/tape/tape_snow.png, which the
tape's shaders read (game/presentation/shaders/tape_snow.gdshaderinc).

    python tools/dev/tape_snow.py [--preview=<folder>]

The author's references (evidence/referencias/vhs/05 to 07) are not snow off
a tube: they are frames of a video of it, 480 lines, and most of what one
sees in them is what the video's coding left. Drawn by a formula in the
shader, sixteen times over, the levels and the lengths came out as measured
and the picture still read as pixel art with digital noise: what was missing
is the coding itself, so it is done here, once, and the game shows the
result. With --preview, every frame is also written three times over (as a
player shows a video of 480 lines on a screen of 1440) to set beside them.

What is made, in the order it happens to a tape:
  - the tape: every line its own, cut into stretches of grey of a level
    each; over them dashes of black and of light, the brightest the
    shortest, a few that run a long way, and specks; all of it denser where
    the tape is lighter, in clouds and by the line. A line is one, two or
    three of the video's;
  - the coding: a run of frames, each predicted from the last one (a little
    blurred, as a block fetched from half a pixel off is) and corrected in
    blocks of four pixels, every term of the correction cut to a multiple of
    a step, with a dead zone: what is small is lost and what is strong
    stays, flat across its block. Some macroblocks get a finer step than
    others, and a few blocks are drawn slantwise out of the line above them
    (the wedges and notches the references have beside their dashes). Then
    the loop filter, which smooths a block's edge where both sides are flat;
  - the last frame is of a moment with no bits to spare: corrected first in
    blocks of sixteen, coarsely, so that it is mostly what was predicted,
    smooth, and a shade off from block to block.
Each frame is then given the levels the references measure at the video's
own size (their share of the picture under each level), in the same order.

The frames tile: the picture can be read from anywhere in it. Nothing is
random between runs. Needs numpy, scipy and Pillow.
"""
import os, sys
import numpy as np
from PIL import Image
from scipy.fft import dctn, idctn
from scipy.ndimage import gaussian_filter, gaussian_filter1d, uniform_filter1d

W, H = 864, 480
OUT = "assets/textures/tape/tape_snow.png"
SLANT = 0.08

# The share of the picture under each level, at the video's own size: of
# references 05 and 06 without their bright lines, and of 07.
SHARE = np.array([0, 0.5, 1, 2, 5, 10, 20, 30, 40, 50, 60, 70, 80, 90, 95, 98, 99, 99.5, 99.9, 100]) / 100.0
SHARP = np.array([0.000, 0.010, 0.021, 0.035, 0.063, 0.088, 0.122, 0.147, 0.172, 0.200, 0.229, 0.269, 0.318, 0.392, 0.455, 0.515, 0.550, 0.590, 0.700, 0.920])
SMEARED = np.array([0.000, 0.039, 0.055, 0.073, 0.094, 0.116, 0.143, 0.169, 0.192, 0.216, 0.239, 0.259, 0.287, 0.329, 0.365, 0.412, 0.451, 0.490, 0.584, 0.784])


def unit(n): return (n - n.mean()) / (n.std() + 1e-9)


def toned(z, levels):
    """Whatever z is, with those levels in the same order."""
    rank = np.empty(z.size)
    rank[np.argsort(z, axis=None)] = (np.arange(z.size) + 0.5) / z.size
    return np.interp(rank, SHARE, levels).reshape(z.shape)


def stretches(rng, median, rows, spread=0.75):
    """Every line cut into stretches of its own, each of one level (a normal
    draw): rows x W. A line runs round: where it ends it begins, somewhere
    else on every line."""
    out = np.empty((rows, W))
    for row in range(rows):
        # (A line's stretches are all longer, or all shorter, than the next line's.)
        lengths = np.maximum(np.round(rng.lognormal(np.log(median) + 0.35 * rng.standard_normal(), spread, int(W / median * 5) + 8)), 1).astype(int)
        out[row] = np.roll(np.repeat(rng.standard_normal(lengths.size), lengths)[:W], rng.integers(W))
    return out


def paired(rng, field, share):
    """Every other line is, for that share of its length, the line above over again."""
    twice = stretches(rng, 10.0, field.shape[0] // 2)
    out = field.copy()
    out[1::2] = np.where(twice > np.quantile(twice, 1.0 - share), field[0::2], field[1::2])
    return out


def tape(rng):
    """One frame off the tape, before anybody coded it."""
    # Its lines are fewer than the video's: each is one, two or three of them.
    # As many as fill the picture (an even number: they go in pairs), and the
    # line of the video each starts at.
    tall = rng.choice([1, 2, 3], H, p=[0.22, 0.45, 0.33])
    rows = int(np.searchsorted(np.cumsum(tall), H)) + 1
    rows += rows % 2
    tall = tall[:rows]
    first = np.cumsum(tall) - tall
    # The ground: long stretches of grey, a little of the short ones over them.
    z = 0.35 * (stretches(rng, 18.0, rows) + 0.35 * stretches(rng, 4.5, rows))
    # Some lines carry more of it than others, and whole regions too (these
    # in the video's own lines: the picture is the same again above its top
    # as at its foot).
    z *= np.exp(0.3 * rng.standard_normal((rows, 1)))
    low = 0.2 * unit(gaussian_filter(rng.standard_normal((H, W)), (50.0, 60.0), mode="wrap"))
    low = low + 0.13 * unit(gaussian_filter1d(rng.standard_normal((H, 1)), 85.0, axis=0, mode="wrap"))
    low = low[first % H] + 0.2 * rng.standard_normal((rows, 1))
    z = paired(rng, z + low, 0.2)
    # The dashes, more of the light where the tape is lighter: the black of
    # the snow, and the light ones, the brightest the shortest; and a few
    # that run a long way.
    d = paired(rng, stretches(rng, 5.0, rows, 0.9), 0.2) - 0.9 * low
    z = np.where(d > np.quantile(d, 0.91), -3.0 + 0.3 * d, z)
    l = paired(rng, stretches(rng, 5.5, rows), 0.3) + 0.9 * low
    z = np.where(l > np.quantile(l, 0.885), 3.0 + 0.4 * l + 0.6 * stretches(rng, 2.5, rows), z)
    far = stretches(rng, 45.0, rows) + 0.9 * low
    z = np.where(far > np.quantile(far, 0.98), 3.0 + 0.3 * stretches(rng, 6.0, rows), z)
    # Specks of white, a pixel or two.
    z = np.where(rng.random((rows, W)) < 0.0004, 5.0, z)
    y = gaussian_filter1d(toned(z, SHARP), 0.4, axis=1, mode="wrap")
    y = y[np.repeat(np.arange(rows), tall)[:H]]
    return gaussian_filter1d(y, 0.2, axis=0, mode="wrap")


def cut(x, rng, step, block, across, down=0.15, mean=0.25):
    """x in blocks, each term of each cut to a multiple of its step (coarser up
    the frequencies, and more so across than down: a block keeps its lines and
    loses what changes along them), with a dead zone. The step is another for
    every macroblock."""
    spread = unit(gaussian_filter(rng.standard_normal((H // 16, W // 16)), 1.0, mode="wrap"))
    step = np.repeat(np.repeat(step * np.exp(0.5 * spread), 16 // block, axis=0), 16 // block, axis=1)
    c = dctn(x.reshape(H // block, block, W // block, block).transpose(0, 2, 1, 3), axes=(2, 3), norm="ortho")
    q = step[:, :, None, None] * (1.0 + down * np.arange(block)[:, None] + across * np.arange(block)[None, :]) * block
    # The mean of a block is kept finer than what is in it.
    q[:, :, 0, 0] *= mean
    c = np.sign(c) * np.floor(np.abs(c) / q + 0.3) * q
    return idctn(c, axes=(2, 3), norm="ortho").transpose(0, 2, 1, 3).reshape(H, W)


def deblocked(y, block=4):
    """The decoder's loop filter: across a block's edge, where the step is small and both sides are flat."""
    for axis in (1, 0):
        n = y.shape[axis]
        edge = np.arange(block - 1, n, block)
        p0, q0 = np.take(y, edge, axis=axis), np.take(y, (edge + 1) % n, axis=axis)
        p1, q1 = np.take(y, edge - 1, axis=axis), np.take(y, (edge + 2) % n, axis=axis)
        gate = (np.abs(p0 - q0) < 0.07) & (np.abs(p1 - p0) < 0.03) & (np.abs(q1 - q0) < 0.03)
        # The gate of an edge covers the two pixels each side of it.
        gate = np.roll(np.repeat(gate, block, axis=axis), block // 2, axis=axis)
        soft = uniform_filter1d(uniform_filter1d(y, 3, axis=axis, mode="wrap"), 3, axis=axis, mode="wrap")
        at = np.arange(n) % block
        weight = np.where((at == 0) | (at == block - 1), 1.0, 0.45)
        shape = [1, 1]
        shape[axis] = n
        y = y + (soft - y) * weight.reshape(shape) * gate
    return y


def slanted(rng, y, share):
    """That share of the blocks of four is not sent at all but drawn out of the
    line above the block, slantwise one way or the other, as a coder predicts a
    block inside a frame: where that line has an edge the block has a wedge."""
    out = y.copy()
    across = np.arange(4)
    for r, c in zip(*np.nonzero(rng.random((H // 4, W // 4)) < share)):
        above, way = y[r * 4 - 1], rng.choice([-1, 1])
        for i in range(4): out[r * 4 + i, c * 4:c * 4 + 4] = above[(c * 4 + across + (i + 1) * way) % W]
    return out


def frames():
    """A run of the video; its last three frames, the third of them starved."""
    rng = np.random.default_rng(1992)
    seen = cut(tape(rng) - 0.2, rng, 0.012, 4, 0.8) + 0.2
    kept = []
    for k in range(1, 6):
        # What a block is predicted from: the last picture, a little off and so a little blurred.
        guess = gaussian_filter(seen, 0.8, mode="wrap")
        now = tape(rng)
        if k == 5:
            guess = gaussian_filter(seen, (2.0, 3.5), mode="wrap")
            guess = gaussian_filter(guess + cut(now - guess, rng, 0.045, 16, 1.5, 1.0, 1.0), 0.7, mode="wrap")
            # Of the rest, only the dashes too strong and too long to lose,
            # and of the light ones fewer than of the black.
            rest = now - guess
            long = gaussian_filter1d(rest, 2.0, axis=1, mode="wrap")
            seen = guess + gaussian_filter1d(np.where((long > 0.3) | (long < -0.17), rest, 0.0), 0.5, axis=1, mode="wrap")
        else:
            seen = slanted(rng, guess + cut(now - guess, rng, 0.07, 4, 0.8), SLANT)
        seen = np.clip(deblocked(seen), 0.0, 1.0)
        # (What a player's scaling does to it, and then the levels.)
        if k >= 3: kept.append(toned(gaussian_filter(seen, 0.3, mode="wrap"), SMEARED if k == 5 else SHARP))
    return kept


if __name__ == "__main__":
    made = frames()
    # One frame lighter than the next would be a flash every time it came up
    # (tools/capture/film_check.py): they are to differ in what is in them only.
    assert max(frame.mean() for frame in made) - min(frame.mean() for frame in made) < 0.01
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    Image.fromarray((np.stack(made, axis=2) * 255.0 + 0.5).astype(np.uint8), "RGB").save(OUT, optimize=True)
    print(OUT, os.path.getsize(OUT), "bytes; means", " ".join("%.3f" % frame.mean() for frame in made))
    for arg in sys.argv[1:]:
        if not arg.startswith("--preview="): continue
        for k, frame in enumerate(made):
            Image.fromarray((frame * 255.0 + 0.5).astype(np.uint8), "L").resize((W * 3, H * 3), Image.BILINEAR).save(os.path.join(arg[10:], "tape_snow_%d.png" % k))
