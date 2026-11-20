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
result. With --preview, every frame is also written as the shader shows it
on a screen of 1440 lines, to set beside them.

What is made, in the order it happens to a tape:
  - the tape (tape()): a ground that is all but smooth along a line, and on
    it dashes, dark ones under it and light ones over it. How much of both
    there is, and how deep they go, follows how lively the tape is there,
    which goes by bands of lines from one side of the picture to the other.
    A line of the tape is one, two or three of the video's;
  - the coding (coded()), which is a real one: a lossy WebP is a key frame of
    VP8, and Pillow has it;
  - what a decoder's guesses leave where nothing corrected them (broken()):
    blocks fetched from a line or two off, a few drawn slantwise out of the
    line above, short upright strokes at the edges of blocks;
  - dashes of one line, bright and black, in the liveliest parts (fine());
    then how soft the video is, and a sharpening across the lines;
  - the third frame is of a moment with no bits to spare (starved()): mostly
    not the tape but what was predicted, a level to a block, and of the
    tape only its strongest dashes, a few lines right across, and a block or
    two whole.
Each frame is then given the levels the references measure at the video's
own size (their share of the picture under each level), in the same order.

How it got here, since most of it was not chosen by eye. An imitation of a
coder written in numpy came first, and a reader set to tell its frames from
the references', unlabelled, did every time; with a real coder he began to
miss. The numbers of the tape were then fitted: a random walk kept what
brought some fifty measures of a frame nearer the references' (how alike
neighbours are along a line and down the lines, the ground, the dashes of
each kind, how it goes by zones, how many edges stand upright or slant).
That held until it did not: fitted further the frames measured nearer and
looked further (the walk had driven the coder's quality to nothing), so the
numbers are those of the round the reader did worst at, and after it only
what he named was changed. Two things he settled that are not here any
more. Frames of snow through a real H.264 (Blender has one) he took for the
real thing and the references for the imitation: the two are not alike. And
points one pixel sharp, sprinkled over a coded frame, are the first thing
he sees.

The frames tile: the picture can be read from anywhere in it. Nothing is
random between runs, though another version of Pillow's WebP may not give
the same file to the byte. Needs numpy, scipy and Pillow.
"""
import io, os, sys
import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter, gaussian_filter1d, maximum_filter1d

W, H = 864, 480
OUT = "assets/textures/tape/tape_snow.png"
# The coder's quality (WebP's, of 100) for a frame with bits enough, and for
# the starved one.
QUALITY = 4
STARVED = 1
# The tape (fitted to references 05 and 06, see above): how many of the
# video's lines one of its own is (the shares of one, two and three), how
# much the ground follows how lively the tape is, how long a dash is, and
# from what draw on a stretch is dark, or light. (Fitted, a dash was 11.8
# long, two lines in three were of two, and the lengths differed by 1.43:
# long flat strokes in even rows, a reader said, where the references'
# are shorter, broken and of uneven thickness.)
TALL = [0.28, 0.44, 0.28]
GROUND = 0.30
DASH = 8.5
DARK = 0.19
LIGHT = 0.90
# How much of a dash's shape is its line's stretches, against a field of
# blobs so many of the tape's lines tall and so many pixels wide.
STRETCH = 2.4
BLOB = (0.3, 2.7)
# How much the dashes keep together, in patches a few lines tall.
CLUMP = 0.12
# How much of the tape's liveliness goes by bands of lines and how much by
# patches. (Fitted, the bands were 0.79, and a reader saw them: a window of
# the references is of one brightness, near enough.)
BAND = 0.50
PATCH = 0.08
# How much of that goes line by line, the whole of a line and long stretches
# of it; and how much more of the dashes, dark and light, there is where the
# tape is livelier.
ROUGH = 0.18
LONGWISE = 0.56
LIVELY_DARK = 0.69
LIVELY_LIGHT = 0.83
# How far under the ground a dark dash goes and how far over it a light one,
# and how much the lengths of the dashes of a line differ.
DEEP_DARK = 0.18
DEEP_LIGHT = 0.10
SPREAD = 1.10
# How much the ground has of soft blots under the dashes, how uneven a dash
# is inside, and from what draw on a stretch beside a light dash it is black.
UNDER = 0.06
SHADE = 0.26
OUTLINE = 0.53
# What is not along the lines, and a reader looks for it first. The share of
# the blocks of eight fetched from a line or two off (their edges are the
# references' upright edges every eight pixels), of the blocks of four and
# of eight drawn slantwise (with more of them the frames had wedges the
# references have not), how many of the pixels on a block's edge start an
# upright sliver, and how much of the picture is a bright dash of one line.
KNOCK = 0.10
SLANT = 0.050
SLANT8 = 0.020
TICKS = 0.040
FINE = 0.0030
# The starved frame (fitted to reference 07): how far the tape is smeared
# down and along its lines before it is coded and how strong a dash is that
# is kept; how much of the frame is a level to a block and not the tape, in
# what share of the picture a dash may be kept, what share of the blocks
# are kept whole, how many lines run right across, and how much it has of
# the others' upright strokes; how far apart those levels are, how
# much of them goes by blocks of eight and by blocks of thirty-two, and how
# soft the seam between two blocks is.
SMEAR = (1.4, 3.4)
KEPT = 0.070
GRID = 0.85
SPARED = -0.60
WHOLE = 0.012
ACROSS = 5
SPARSE = 0.12
LEVELS = 0.060
BLOCKS = 0.60
RUNS = 1.2
WIDE = 0.8
SEAM = 0.35
# How much harder the edges across the lines are made.
HALO = 0.61
# How soft the video is down its lines and along them: a tape's lines are
# its own, and what is on one runs into itself.
SOFT = (0.88, 0.43)

# The share of the picture under each level, at the video's own size: of
# references 05 and 06 without their bright lines, and of 07.
SHARE = np.array([0, 0.5, 1, 2, 5, 10, 20, 30, 40, 50, 60, 70, 80, 90, 95, 98, 99, 99.5, 99.9, 100]) / 100.0
SHARP = np.array([0.000, 0.008, 0.020, 0.035, 0.063, 0.086, 0.118, 0.145, 0.169, 0.196, 0.224, 0.259, 0.306, 0.373, 0.427, 0.490, 0.529, 0.561, 0.639, 0.800])
SMEARED = np.array([0.000, 0.035, 0.059, 0.082, 0.110, 0.137, 0.165, 0.188, 0.208, 0.227, 0.247, 0.271, 0.298, 0.333, 0.369, 0.412, 0.447, 0.482, 0.565, 0.784])


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


def shapes(rng, rows, spread, twice):
    """Where the dashes of one kind are, before the cut: the stretches of
    each line, and with them a field that knows nothing of lines, so that a
    dash runs on into the line under it a little to one side. In the
    references a dash is seldom one line's: it is a piece two or three lines
    tall with steps in its outline (as stretches alone they were hairs)."""
    return unit(STRETCH * paired(rng, stretches(rng, DASH, rows, spread), twice) + unit(gaussian_filter(rng.standard_normal((rows, W)), BLOB, mode="wrap")))


def tape(rng):
    """One frame off the tape, before anybody coded it."""
    # Its lines are fewer than the video's: each is one, two or three of them.
    # As many as fill the picture (an even number: they go in pairs), and the
    # line of the video each starts at.
    tall = rng.choice([1, 2, 3], H, p=TALL)
    rows = int(np.searchsorted(np.cumsum(tall), H)) + 1
    rows += rows % 2
    tall = tall[:rows]
    first = np.cumsum(tall) - tall
    # How lively the tape is from one part of the picture to another (in the
    # video's own lines: the picture is the same again above its top as at
    # its foot). Measured, the references are of one piece in this: where
    # the ground is lighter there are more dashes, of the dark as of the
    # light, and they go deeper; where it is dark it is quiet. And it goes by
    # bands: a run of lines is lively or quiet from one side of the picture
    # to the other (windows of it a whole picture's width apart are still
    # half alike), a dozen lines or fifty tall, with patches a few lines tall
    # and a dozen pixels wide over that. (As round clouds it was camouflage.)
    band = unit(0.6 * unit(gaussian_filter1d(rng.standard_normal((H, 1)), 15.0, axis=0, mode="wrap")) + 1.1 * unit(gaussian_filter1d(rng.standard_normal((H, 1)), 45.0, axis=0, mode="wrap")))
    lively = BAND * band + PATCH * unit(gaussian_filter(rng.standard_normal((H, W)), (4.7, 11.5), mode="wrap"))
    lively = lively[first % H] + ROUGH * rng.standard_normal((rows, 1)) + LONGWISE * gaussian_filter1d(stretches(rng, 50.0, rows), 4.0, axis=1, mode="wrap")
    # The ground: all but smooth along a line, a little of the stretches in it.
    ground = 0.21 * np.exp(GROUND * lively + 0.11 * (stretches(rng, 18.0, rows) + 0.35 * stretches(rng, 4.5, rows)))
    # Under the dashes the ground is in soft blots a few lines tall and a
    # dozen pixels wide, which have nothing to do with the dashes: what is
    # left of the frames before, out of focus.
    ground = ground * np.exp(UNDER * unit(gaussian_filter(rng.standard_normal((rows, W)), (1.6, 5.0), mode="wrap")))
    # The dashes, each a stretch of its line: dark ones under the ground and
    # light ones over it, the brightest the shortest, and a few that run a
    # long way.
    d = shapes(rng, rows, SPREAD, 0.6) + LIVELY_DARK * lively + CLUMP * unit(gaussian_filter(rng.standard_normal((rows, W)), (2.5, 10.0), mode="wrap"))
    y = np.where(d > DARK, ground - DEEP_DARK * (ground / 0.22) ** 0.45 * np.clip(1.0 + 0.35 * stretches(rng, 4.0, rows), 0.4, 2.0), ground)
    l = shapes(rng, rows, SPREAD, 0.65) + LIVELY_LIGHT * lively + CLUMP * unit(gaussian_filter(rng.standard_normal((rows, W)), (2.5, 10.0), mode="wrap"))
    y = np.where(l > LIGHT, ground + DEEP_LIGHT * (ground / 0.22) ** 0.3 * np.exp(0.2 * stretches(rng, 2.5, rows)), y)
    # A dash is not of one level from end to end.
    y = ground + (y - ground) * np.clip(1.0 + SHADE * unit(gaussian_filter(rng.standard_normal((rows, W)), (0.6, 2.0), mode="wrap")), 0.2, 2.5)
    y = gaussian_filter1d(np.clip(y, 0.0, 1.0), 0.4, axis=1, mode="wrap")
    line = np.repeat(np.arange(rows), tall)[:H]
    y = y[line]
    # Over and under a light dash, for stretches of it, a line of black one
    # of the video's lines thick: the outline the references' bars have, and
    # the black they have right beside their light.
    lit = (l > LIGHT)[line]
    edge = (np.roll(lit, 1, axis=0) | np.roll(lit, -1, axis=0)) & ~lit & (stretches(rng, 6.0, H) > OUTLINE)
    return gaussian_filter1d(np.where(edge, y * 0.15, y), 0.2, axis=0, mode="wrap")


def knocked(rng, y, share, size=8):
    """That share of the blocks are not the tape there but the tape a line or
    two off: a coder that predicts a block from the frame before fetches it
    from where it guesses it has moved to, and with snow it guesses wrong.
    The dashes break at the block's edge, in steps, T's and crosses."""
    out = y.copy()
    for r, c in zip(*np.nonzero(rng.random((H // size, W // size)) < share)):
        rows = (np.arange(r * size, (r + 1) * size) + rng.choice([-2, -1, 1, 2])) % H
        cols = (np.arange(c * size, (c + 1) * size) + rng.integers(-3, 4)) % W
        out[r * size:(r + 1) * size, c * size:(c + 1) * size] = y[np.ix_(rows, cols)]
    return out


def slanted(rng, y, share, size):
    """That share of the blocks of that size are drawn out of the line above
    the block, slantwise one way or the other, as a coder predicts a block
    inside a frame: where that line has an edge the block has a wedge, its
    side a pixel further along on every line. (Of the references' steps
    across, near a fifth go on like that for three lines; of a tape of dashes
    coded without it, a thirteenth, and a reader told the two apart by it.)"""
    out = y.copy()
    across = np.arange(size)
    for r, c in zip(*np.nonzero(rng.random((H // size, W // size)) < share)):
        above, way = y[r * size - 1], rng.choice([-1, 1])
        # (Not always to the foot of the block: two lines of it, or more.)
        for i in range(rng.integers(2, size + 1)): out[r * size + i, c * size:c * size + size] = above[(c * size + across + (i + 1) * way) % W]
    return out


def ticked(rng, y, share):
    """Slivers one pixel wide where two blocks of four meet, drawn straight
    down (or up) out of the pixel next to them for three lines to five, as a
    coder predicts a block from the line over it. Out of a dash they are the
    references' T's and crosses, through one they break it, and over flat
    ground they are nothing at all. (As strokes of a shade of their own they
    were specks on the ground, and a reader saw those first.)"""
    start = (rng.random((H, W)) < share) & (np.arange(W)[None, :] % 4 == 0)
    reach = np.where(start, rng.integers(3, 6, (H, W)), 0) * np.where(rng.random((H, W)) < 0.5, -1, 1)
    out = y.copy()
    for k in range(1, 6):
        for way in (1, -1): out = np.where(np.roll(reach * way >= k, k * way, axis=0), np.roll(y, k * way, axis=0), out)
    return out


def broken(rng, y, few=1.0):
    """A frame as the decoder's guesses leave it where nothing corrected
    them: after the coding, then, not before (before it, the coding took
    most of them out again). `few` is how much of the strokes it has."""
    return ticked(rng, slanted(rng, slanted(rng, knocked(rng, y, KNOCK), SLANT, 4), SLANT8, 8), TICKS * few)


def starved(rng):
    """A frame off the tape as a coder with no bits to spare has it before it
    starts. Most of it is not this tape at all but what was predicted: a
    level to each block of sixteen, of eight and of thirty-two and to runs
    of three blocks side by side, with a seam to the next. Under that, a
    share of the tape smeared; and of the tape itself only what had bits
    left for it: its strongest and longest dashes, in clusters, a block or
    two whole here and there, and a few lines right across the picture.
    (With blocks of one size and dashes alone it was a plain checkerboard
    with a few dashes on it, and a reader knew it from reference 07 by that.)"""
    now = tape(rng)
    levels = RUNS * rng.standard_normal((H // 16, W // 48)).repeat(16, axis=0).repeat(48, axis=1)
    for size, much in ((16, 1.0), (8, BLOCKS), (32, WIDE)): levels = levels + much * rng.standard_normal((H // size, W // size)).repeat(size, axis=0).repeat(size, axis=1)
    guess = now.mean() + LEVELS * unit(gaussian_filter(levels, SEAM, mode="wrap"))
    dashes = now - gaussian_filter(now, (2.0, 6.0), mode="wrap")
    long = gaussian_filter1d(dashes, 5.0, axis=1, mode="wrap")
    spared = unit(gaussian_filter(rng.standard_normal((H, W)), (10.0, 24.0), mode="wrap")) > SPARED
    # (Whole blocks go two or three in a row.)
    pick = gaussian_filter1d(rng.random((H // 16, W // 16)), 0.7, axis=1, mode="wrap")
    whole = (pick > np.quantile(pick, 1.0 - WHOLE)).repeat(16, axis=0).repeat(16, axis=1)
    y = GRID * guess + (1.0 - GRID) * gaussian_filter(now, SMEAR, mode="wrap") + np.where(whole | (spared & ((long < -KEPT) | (long > 1.5 * KEPT))), dashes, 0.0)
    # (A line right across: one line of the video, dark, for two thirds of the picture's width or all of it.)
    for row in rng.choice(H, ACROSS, replace=False):
        start, length = rng.integers(W), int(W * rng.uniform(0.35, 1.0))
        y[row, (start + np.arange(length)) % W] *= 0.35
    return y


def coded(frame, quality):
    """Through a real coder and back. A lossy WebP is one key frame of VP8:
    blocks of four pixels, each predicted from its neighbours (straight, or
    slantwise: the wedges the references have beside their dashes), what is
    left cut to steps, and a loop filter over the blocks' edges. Coded with a
    margin of itself round it, so that the picture still tiles."""
    wide = np.pad(np.clip(frame, 0.0, 1.0), 16, mode="wrap")
    file = io.BytesIO()
    Image.fromarray((wide * 255.0 + 0.5).astype(np.uint8), "L").convert("RGB").save(file, "WEBP", quality=quality, method=6)
    return np.asarray(Image.open(io.BytesIO(file.getvalue())).convert("L")).astype(np.float64)[16:-16, 16:-16] / 255.0


def fine(rng, y, share):
    """Where the picture is lively (which is where it is light): dashes one
    line tall and a few pixels long, a good deal brighter than what is round
    them over that share of it, and black ones over a third as much. In the
    references what stands a tenth clear of all its neighbours is this, and
    nearly all of it is in their liveliest third. They go in after the
    coding, which took them out, and before the video's softness, which they
    have like the rest: sharp to the pixel over a soft frame they were the
    first thing a reader saw."""
    lively = 1.2 * unit(gaussian_filter(y, (6.0, 20.0), mode="wrap"))
    bright, black = stretches(rng, 3.5, H) + lively, stretches(rng, 3.5, H) + lively
    y = np.where(bright > np.quantile(bright, 1.0 - share), np.minimum(y + 0.5, 1.0), y)
    return np.where(black > np.quantile(black, 1.0 - share * 0.3), y * 0.1, y)


def haloed(y, much):
    """Edges across the lines made harder than they are, as a deck's own
    sharpening and a coder's ringing leave them: a dark line over and under a
    light bar, a light one beside a dark."""
    return y + much * (y - gaussian_filter1d(y, 1.1, axis=0, mode="wrap"))


def shown(frame):
    """A frame three times over, as the shader shows it on a screen of 1440
    lines: not a straight line from one of its pixels to the next (a line of
    black one pixel tall came out a grey smear with one black line of the
    screen in it, and the references' is black for all three) but each pixel
    flat over its middle half. Of three screen pixels the middle one is the
    video's own and the outer two have a little of the neighbour in them."""
    lent = 0.0741
    for axis in (0, 1):
        big = np.repeat(frame, 3, axis=axis)
        before, after = np.repeat(np.roll(frame, 1, axis=axis), 3, axis=axis), np.repeat(np.roll(frame, -1, axis=axis), 3, axis=axis)
        at = (np.arange(big.shape[axis]) % 3).reshape([-1, 1] if axis == 0 else [1, -1])
        frame = np.where(at == 0, big + (before - big) * lent, np.where(at == 2, big + (after - big) * lent, big))
    return frame


def frames():
    """Three frames of the video: two with bits enough, and one starved."""
    rng = np.random.default_rng(1992)
    kept = []
    for quality, levels in ((QUALITY, SHARP), (QUALITY, SHARP), (STARVED, SMEARED)):
        few = SPARSE if quality == STARVED else 1.0
        seen = broken(rng, coded(starved(rng) if quality == STARVED else tape(rng), quality), few)
        # (What a player's scaling does to it, and then the levels.)
        # (The starved frame has none of the fine dashes: what is lively in it is a block or two, and they sat there in a heap.)
        if quality != STARVED: seen = fine(rng, seen, FINE)
        kept.append(toned(haloed(gaussian_filter(seen, SOFT, mode="wrap"), HALO), levels))
    return kept


if __name__ == "__main__":
    made = frames()
    # One frame lighter than the next would be a flash every time it came up
    # (tools/capture/film_check.py): they are to differ in what is in them only.
    assert max(frame.mean() for frame in made) - min(frame.mean() for frame in made) < 0.02
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    Image.fromarray((np.stack(made, axis=2) * 255.0 + 0.5).astype(np.uint8), "RGB").save(OUT, optimize=True)
    print(OUT, os.path.getsize(OUT), "bytes; means", " ".join("%.3f" % frame.mean() for frame in made))
    for arg in sys.argv[1:]:
        if not arg.startswith("--preview="): continue
        for k, frame in enumerate(made):
            Image.fromarray((shown(frame) * 255.0 + 0.5).astype(np.uint8), "L").save(os.path.join(arg[10:], "tape_snow_%d.png" % k))
