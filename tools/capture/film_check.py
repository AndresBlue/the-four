"""What a film of the capture bench measures of itself: how loud, and how it flashes.

    python tools/capture/film_check.py <film.avi> [--caught=5.54 [--scream=0.39]] [--sheet=out.png --times=a,b,c]

The films are the ones ./tools/godot.ps1 bench-films writes into evidence/
(AVI: one JPEG a frame and the sound as it was mixed). Needs Pillow, numpy and
scipy.

Loudness is the programme loudness of ITU-R BS.1770 (K-weighted, gated), of
the whole film and, given the second of the film the capture starts at (what
its .log says after "caught after=", plus the 1.27 s the bench waits before
it sets the creature off: 2.67 s in the wardrobe's), of what comes before
it, of the capture, of the half second of the scream (0.05 s into it; caught
from behind, --scream=0.39) and of the camera lying still.

Flashes are counted after WCAG 2.3.1 ("three flashes or below threshold"): a
flash is a pair of opposing changes of a tenth or more in relative luminance,
the darker of the two under 0.8; it matters when what flashes together fills
more than a quarter of a field of ten degrees, taken here as 341 x 256 pixels
of a 1024 x 768 picture. The picture is cut into cells of a sixteenth of its
width; a cell flashes when its mean luminance does, and a field is three by
three of them. This is a sieve, not a certified analysis: it says where to
look, and it errs towards counting.
"""
import io, struct, sys
import numpy as np
from PIL import Image
from scipy.signal import lfilter


def chunks(data, start, end):
    at = start
    while at + 8 <= end:
        tag = data[at:at + 4]
        size = struct.unpack('<I', data[at + 4:at + 8])[0]
        yield tag, at + 8, size
        at += 8 + size + (size & 1)


def read(path):
    data = open(path, 'rb').read()
    assert data[:4] == b'RIFF' and data[8:12] == b'AVI ', 'not an AVI'
    frames, sound = [], []
    rate = [0, 0, 0]

    def walk(start, end):
        for tag, at, size in chunks(data, start, end):
            if tag == b'LIST':
                walk(at + 4, at + size)
            elif tag == b'strf' and size >= 16 and rate[0] == 0 and data[at:at + 2] in (b'\x01\x00', b'\x03\x00'):
                _, channels, hz, _, _, bits = struct.unpack('<HHIIHH', data[at:at + 16])
                rate[0], rate[1], rate[2] = hz, channels, bits
            elif tag[2:] in (b'dc', b'db'):
                frames.append((at, size))
            elif tag[2:] == b'wb':
                sound.append(data[at:at + size])
    walk(12, len(data))
    return data, frames, b''.join(sound), rate


# --- Loudness ------------------------------------------------------------------------

def programme(signal, hz):
    if hz != 48000 or len(signal) < int(0.4 * hz): return float('-inf'), float('-inf')
    out = lfilter([1.53512485958697, -2.69169618940638, 1.19839281085285], [1.0, -1.69065929318241, 0.73248077421585], signal, axis=0)
    out = lfilter([1.0, -2.0, 1.0], [1.0, -1.99004745483398, 0.99007225036621], out, axis=0)
    size, step = int(0.4 * hz), int(0.1 * hz)
    powers = np.array([float(np.sum(np.mean(out[start:start + size] ** 2, axis=0))) for start in range(0, len(out) - size + 1, step)])
    loud = -0.691 + 10.0 * np.log10(np.maximum(powers, 1e-12))
    kept = powers[loud > -70.0]
    if len(kept) == 0: return float('-inf'), float(np.max(loud))
    gate = -0.691 + 10.0 * np.log10(np.mean(kept)) - 10.0
    kept = powers[(loud > -70.0) & (loud > gate)]
    return float(-0.691 + 10.0 * np.log10(np.mean(kept))), float(np.max(loud))


def loudness(raw, rate, caught, scream=0.05):
    hz, channels, bits = rate
    if not raw or not hz: return
    signal = (np.frombuffer(raw, dtype={16: '<i2', 32: '<i4'}[bits]).astype(np.float64) / float(2 ** (bits - 1))).reshape(-1, channels)
    parts = [('the whole film', signal)]
    if caught >= 0.0:
        parts += [
            ('before the capture', signal[int(0.6 * hz):int(caught * hz)]),
            ('the capture, 4.7 s', signal[int(caught * hz):int((caught + 4.7) * hz)]),
            ('the scream, half a second', signal[int((caught + scream) * hz):int((caught + scream + 0.55) * hz)]),
            ('lying still, to the blow', signal[int((caught + 2.2) * hz):int((caught + 3.08) * hz)]),
        ]
    for name, piece in parts:
        level, most = programme(piece, hz)
        peak = 20.0 * np.log10(max(1e-9, float(np.max(np.abs(piece))))) if len(piece) else float('-inf')
        print('LOUD  %-26s %6.1f LUFS   loudest 400 ms %6.1f   peak %5.1f dBFS' % (name, level, most, peak))


# --- Flashes -------------------------------------------------------------------------

CELLS = (16, 9)


def luminance(picture):
    small = np.asarray(picture.convert('RGB').resize((CELLS[0] * 8, CELLS[1] * 8), Image.BOX), dtype=np.float64) / 255.0
    linear = np.where(small <= 0.04045, small / 12.92, ((small + 0.055) / 1.055) ** 2.4)
    light = 0.2126 * linear[..., 0] + 0.7152 * linear[..., 1] + 0.0722 * linear[..., 2]
    return light.reshape(CELLS[1], 8, CELLS[0], 8).mean(axis=(1, 3))


def flashes(data, frames, fps=60):
    light = np.array([luminance(Image.open(io.BytesIO(data[at:at + size]))) for at, size in frames])
    count = len(light)
    # For each cell, the frames at which its luminance has turned by a tenth
    # or more from its last extreme, the darker of the two under 0.8: +1 up,
    # -1 down.
    turns = np.zeros(light.shape, dtype=np.int8)
    for row in range(CELLS[1]):
        for column in range(CELLS[0]):
            series = light[:, row, column]
            low = high = series[0]
            way = 0
            for index in range(1, count):
                value = series[index]
                if way >= 0:
                    high = max(high, value)
                    if high - value >= 0.1 and value < 0.8:
                        turns[index, row, column] = -1
                        way, low = -1, value
                        continue
                if way <= 0:
                    low = min(low, value)
                    if value - low >= 0.1 and low < 0.8:
                        turns[index, row, column] = 1
                        way, high = 1, value
    # A general flash is counted where it is seen: in a cell, when each of
    # its two changes is shared -- the same way, within a frame -- by a
    # quarter or more of some field of three by three cells that holds it
    # (three cells of the nine). What moves across the picture, a bar going
    # up it, flashes each place it passes once, not once for every row.
    ups = (turns == 1)
    downs = (turns == -1)

    def shared(mask):
        # For every frame and cell: how many cells of the fullest field of
        # three by three round it changed that way within a frame of it.
        near = mask.copy()
        near[1:] |= mask[:-1]
        near[:-1] |= mask[1:]
        total = np.zeros(mask.shape, dtype=np.int16)
        padded = np.pad(near.astype(np.int16), ((0, 0), (2, 2), (2, 2)))
        best = np.zeros(mask.shape, dtype=np.int16)
        for top in range(3):
            for left in range(3):
                # The field whose top-left corner is (row - top, column - left).
                window = np.zeros(mask.shape, dtype=np.int16)
                for row in range(3):
                    for column in range(3):
                        window += padded[:, 2 - top + row:2 - top + row + CELLS[1], 2 - left + column:2 - left + column + CELLS[0]]
                best = np.maximum(best, window)
        return best

    wide_up = ups & (shared(ups) >= 3)
    wide_down = downs & (shared(downs) >= 3)
    worst = (0, 0.0, (0, 0))
    single = 0
    for row in range(CELLS[1]):
        for column in range(CELLS[0]):
            # Every change of this cell, and the wide ones among them.
            for wide in (False, True):
                marks = [(int(index), 1) for index in np.nonzero(wide_up[:, row, column] if wide else ups[:, row, column])[0]]
                marks += [(int(index), -1) for index in np.nonzero(wide_down[:, row, column] if wide else downs[:, row, column])[0]]
                marks.sort()
                pairs = []
                last = None
                for index, way in marks:
                    if last is not None and way != last:
                        pairs.append(index)
                        last = None
                    else: last = way
                for start in range(len(pairs)):
                    inside = sum(1 for frame in pairs[start:] if frame < pairs[start] + fps)
                    if wide and inside > worst[0]: worst = (inside, pairs[start] / float(fps), (column, row))
                    if not wide: single = max(single, inside)
    print('FLASH frames %d (%.1f s)   most general flashes in any second: %d (from %.2f s, cell %d,%d)   most in one cell, any size: %d' % (count, count / float(fps), worst[0], worst[1], worst[2][0], worst[2][1], single))
    print('FLASH verdict: %s' % ('within three a second' if worst[0] <= 3 else 'OVER three a second: look at it'))


def sheet(data, frames, times, out, fps=60):
    columns = 4
    rows = (len(times) + columns - 1) // columns
    page = Image.new('RGB', (640 * columns, 360 * rows))
    for index, second in enumerate(times):
        at, size = frames[min(len(frames) - 1, int(round(second * fps)))]
        picture = Image.open(io.BytesIO(data[at:at + size])).convert('RGB').resize((640, 360), Image.LANCZOS)
        page.paste(picture, ((index % columns) * 640, (index // columns) * 360))
    page.save(out)
    print('SHEET', out)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return
    options = dict(piece[2:].split('=', 1) for piece in sys.argv[2:] if piece.startswith('--') and '=' in piece)
    data, frames, raw, rate = read(sys.argv[1])
    print('FILM  %s: %d frames, sound %d Hz x %d' % (sys.argv[1], len(frames), rate[0], rate[1]))
    loudness(raw, rate, float(options.get('caught', -1.0)), float(options.get('scream', 0.05)))
    flashes(data, frames)
    if 'sheet' in options: sheet(data, frames, [float(piece) for piece in options.get('times', '0,1,2,3').split(',')], options['sheet'])


main()
