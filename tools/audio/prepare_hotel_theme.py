"""The hotel's theme, made to loop and made uncanny (the author, 16 November 2026).

    C:/Users/Poblete/AppData/Local/Programs/Python/Python313/python.exe -I tools/audio/prepare_hotel_theme.py <original.wav> <out.wav>

The original (the author's, four pieces, the loudest from 10:00; kept as
source_assets/music/hotel_theme_original.mp3 and in git at f32608e7) ends
loud and cut short, and its start is soft, so it looped with a jolt. Here:

- Forwards to just before its cut, then the last piece backwards, from that
  point back to 10:00, panning slowly from ear to ear, darkening and falling
  to the start's level; and where the loop turns over, its last seconds and
  its first overlap (LOOP_OVERLAP), soft into soft with no silence between.
- Over all of it, kept low: wow and flutter (a tape's slow and fast wobble of
  pitch), two microtonally detuned copies (+18 and -23 cents), a tritone up
  and a minor second down swelling in and out, a frequency shift of a few
  hertz (inharmonic beating), and a few spectral freezes (a moment held
  still for seconds).

Reads and writes 48 kHz stereo WAV; tools/audio/encode_mp3.ps1 makes the MP3.
"""
import sys
import numpy as np
from scipy.io import wavfile
from scipy import signal

RATE = 48000
MIRROR_BEFORE_CUT = 2.0   # seconds before the original's cut where it turns back
BACK_TO = 600.0           # 10:00, the last piece's start
TAIL_GAIN = 0.11          # the backwards part falls to this (about -19 dB)
LOOP_OVERLAP = 8.0        # seconds the end and the start are heard together
CHUNK = 1 << 22


def db(v):
    return 10.0 ** (v / 20.0)


def read(path):
    rate, x = wavfile.read(path)
    assert rate == RATE, rate
    x = x.astype(np.float32) / 32768.0
    if x.ndim == 1: x = np.stack([x, x], axis=1)
    return x


def cut_point(x):
    """The last moment it still sounds before the original's cut."""
    mono = np.abs(x).mean(axis=1)
    frame = RATE // 10
    loud = [i for i in range(0, len(mono) - frame, frame) if mono[i:i + frame].mean() > db(-45)]
    return loud[-1] + frame


def compose(x):
    end = cut_point(x) - int(MIRROR_BEFORE_CUT * RATE)
    # Without the near silence it opens on: the loop would fall into it.
    first = int(np.argmax(np.abs(x).max(axis=1) > db(-60)))
    forward = x[first:end]
    back = x[int(BACK_TO * RATE):end][::-1].copy()
    n = len(back)
    t = np.linspace(0.0, 1.0, n, dtype=np.float32)
    # Falling to the start's level, smoothly.
    gain = (1.0 - (1.0 - TAIL_GAIN) * (0.5 - 0.5 * np.cos(np.pi * t))).astype(np.float32)
    # Darkening: a low-pass closing from 16 kHz to 1.4 kHz, in blocks.
    out = np.empty_like(back)
    blocks = 64
    edges = np.linspace(0, n, blocks + 1).astype(int)
    zi = None
    for k in range(blocks):
        cutoff = 16000.0 * (1400.0 / 16000.0) ** (k / (blocks - 1))
        b, a = signal.butter(2, cutoff / (RATE / 2))
        seg = back[edges[k]:edges[k + 1]]
        if zi is None: zi = np.stack([signal.lfilter_zi(b, a) * seg[0, c] for c in range(2)], axis=1)
        y, zf = signal.lfilter(b, a, seg, axis=0, zi=zi)
        out[edges[k]:edges[k + 1]] = y
        zi = zf
    back = out
    # From ear to ear, slowly (a 26 s sweep), deeper as it goes.
    sweep = np.sin(2 * np.pi * np.arange(n, dtype=np.float32) / (26.0 * RATE)) * (0.35 + 0.5 * t)
    left = np.sqrt(np.clip(0.5 - 0.5 * sweep, 0, 1)) * np.sqrt(2.0)
    right = np.sqrt(np.clip(0.5 + 0.5 * sweep, 0, 1)) * np.sqrt(2.0)
    back[:, 0] *= gain * left
    back[:, 1] *= gain * right
    # The turn: a short crossfade where forwards meets backwards.
    fade = int(0.25 * RATE)
    ramp = np.linspace(0, 1, fade, dtype=np.float32)[:, None]
    joined = np.concatenate([forward[:-fade], forward[-fade:] * (1 - ramp) + back[:fade] * ramp, back[fade:]])
    return joined


def overlap_loop(x):
    """The file starts LOOP_OVERLAP seconds in, and its last seconds carry its
    first ones fading in under the end fading out (equal power): played on a
    loop, the end becomes the start with nothing between."""
    n = int(LOOP_OVERLAP * RATE)
    t = np.linspace(0, np.pi / 2, n, dtype=np.float32)[:, None]
    out = x[n:].copy()
    out[-n:] = x[-n:] * np.cos(t) + x[:n] * np.sin(t)
    return out


def delayed(x, delay):
    """x read `delay` samples late (fractional, per sample), chunk by chunk."""
    n = len(x)
    y = np.empty_like(x)
    for start in range(0, n, CHUNK):
        idx = np.arange(start, min(n, start + CHUNK), dtype=np.float64) - delay[start:start + CHUNK]
        idx = np.clip(idx, 0, n - 1.001)
        i0 = idx.astype(np.int64)
        frac = (idx - i0).astype(np.float32)[:, None]
        y[start:start + CHUNK] = x[i0] * (1 - frac) + x[i0 + 1] * frac
    return y


def wow_flutter(x):
    n = len(x)
    t = np.arange(n, dtype=np.float64) / RATE
    rng = np.random.default_rng(1987)
    drift = np.interp(t, np.arange(0, t[-1] + 8, 4.0), rng.normal(0, 1, int(t[-1] / 4) + 3))
    delay = 200 + 140 * np.sin(2 * np.pi * 0.33 * t) * (0.7 + 0.3 * drift.clip(-1, 1)) + 6 * np.sin(2 * np.pi * 6.1 * t)
    return delayed(x, delay)


def pitch_shift(x, cents, window=0.09):
    """A rotating two-tap delay: the pitch moves `cents`, the time does not."""
    ratio = 2.0 ** (cents / 1200.0)
    w = window * RATE
    n = len(x)
    y = np.zeros_like(x)
    for start in range(0, n, CHUNK):
        k = np.arange(start, min(n, start + CHUNK), dtype=np.float64)
        part = np.zeros((len(k), 2), dtype=np.float32)
        for offset in (0.0, 0.5):
            phase = np.mod(k * (1.0 - ratio) / w + offset, 1.0)
            d = phase * w
            g = np.sin(np.pi * phase).astype(np.float32)[:, None]
            idx = np.clip(k - d, 0, n - 1.001)
            i0 = idx.astype(np.int64)
            frac = (idx - i0).astype(np.float32)[:, None]
            part += g * (x[i0] * (1 - frac) + x[i0 + 1] * frac)
        y[start:start + len(k)] = part
    return y


def frequency_shift(x, hz):
    taps = 511
    h = signal.firwin(taps, [40, RATE / 2 - 40], pass_zero=False, fs=RATE)
    # A Hilbert transformer: the band-pass turned a quarter of a cycle.
    hilbert = signal.remez(taps, [60, RATE / 2 - 60], [1], type="hilbert", fs=RATE)
    lag = (taps - 1) // 2
    n = len(x)
    t = np.arange(n, dtype=np.float64) / RATE
    c = np.cos(2 * np.pi * hz * t).astype(np.float32)
    s = np.sin(2 * np.pi * hz * t).astype(np.float32)
    out = np.empty_like(x)
    for ch in range(2):
        real = signal.oaconvolve(x[:, ch], h)[lag:lag + n].astype(np.float32)
        imag = signal.oaconvolve(x[:, ch], hilbert)[lag:lag + n].astype(np.float32)
        out[:, ch] = real * c - imag * s
    return out


def freeze(x, at, seconds=8.0, nfft=4096, hop=1024):
    """The spectrum around `at` held still for `seconds`, with moving phases."""
    rng = np.random.default_rng(int(at))
    start = int(at * RATE)
    window = np.hanning(nfft).astype(np.float32)
    frames = int(seconds * RATE / hop)
    out = np.zeros((frames * hop + nfft, 2), dtype=np.float32)
    for ch in range(2):
        grab = x[start:start + nfft * 6, ch]
        mags = np.mean([np.abs(np.fft.rfft(grab[i:i + nfft] * window)) for i in range(0, len(grab) - nfft, hop)], axis=0)
        for f in range(frames):
            phases = rng.uniform(0, 2 * np.pi, len(mags))
            frame = np.fft.irfft(mags * np.exp(1j * phases), nfft).astype(np.float32) * window
            out[f * hop:f * hop + nfft, ch] += frame
    local = np.sqrt(np.mean(x[start:start + RATE] ** 2)) + 1e-9
    out *= local / (np.sqrt(np.mean(out ** 2)) + 1e-9)
    env = np.ones(len(out), dtype=np.float32)
    ramp = int(2.5 * RATE)
    env[:ramp] = np.linspace(0, 1, ramp) ** 2
    env[-ramp:] = np.linspace(1, 0, ramp) ** 2
    return start, out * env[:, None]


def swell(n, period, phase):
    t = np.arange(n, dtype=np.float32) / RATE
    return (0.5 - 0.5 * np.cos(2 * np.pi * t / period + phase)) ** 3


def main():
    source, target = sys.argv[1], sys.argv[2]
    x = compose(read(source))
    n = len(x)
    print("composed", round(n / RATE, 1), "s")
    base = wow_flutter(x)
    print("wow and flutter")
    mix = base.copy()
    mix += db(-9) * pitch_shift(base, 18)
    mix += db(-10) * pitch_shift(base, -23)
    print("detuned")
    mix += db(-19) * swell(n, 47.0, 0.0)[:, None] * pitch_shift(base, 600)
    mix += db(-20) * swell(n, 61.0, 2.0)[:, None] * pitch_shift(base, -100)
    print("dissonant")
    mix += db(-15) * frequency_shift(base, 4.0)
    print("frequency shifted")
    for at in (150.0, 330.0, 545.0, 700.0, 880.0):
        if at * RATE >= n - 10 * RATE: continue
        start, held = freeze(base, at)
        end = min(n, start + len(held))
        mix[start:end] += db(-8) * held[:end - start]
    print("frozen")
    mix = overlap_loop(mix)
    # As loud as the original at its peak, never clipped.
    mix *= 0.95 / max(1e-9, float(np.abs(mix).max()))
    wavfile.write(target, RATE, (mix * 32767).astype(np.int16))
    print("written", target)


if __name__ == "__main__":
    main()
