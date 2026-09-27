"""Sound building blocks for the trailer (mix.py): loading,
filters, envelopes, synthesis, reverb, dynamics and loudness. Everything is
numpy/scipy and deterministic; nothing is downloaded.

Signals are float64 at SR, mono arrays (n,) or stereo arrays (n, 2)."""
import os
import subprocess

import numpy as np
import scipy.signal as sig
from scipy.ndimage import minimum_filter1d, uniform_filter1d

SR = 48000
FFMPEG_CANDIDATES = [
    os.environ.get('FFMPEG', ''),
    r'C:\Users\Poblete\AppData\Local\Programs\Stremio\ffmpeg.exe',
    r'C:\Program Files\MediaHuman\YouTube to MP3 Converter\ffmpeg\ffmpeg.exe',
    'ffmpeg',
]


def ffmpeg():
    for path in FFMPEG_CANDIDATES:
        if path and (os.path.exists(path) or path == 'ffmpeg'): return path
    raise RuntimeError('ffmpeg not found (set FFMPEG)')


def load(path, mono=True):
    """Any audio file, decoded by ffmpeg to float at SR."""
    cmd = [ffmpeg(), '-v', 'error', '-i', path, '-f', 'f32le', '-acodec', 'pcm_f32le', '-ac', '1' if mono else '2', '-ar', str(SR), '-']
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    x = np.frombuffer(raw, np.float32).astype(np.float64)
    return x if mono else x.reshape(-1, 2)


def write(path, x, bits=24):
    """A WAV at SR, 24-bit by default (stereo if x is (n, 2))."""
    x = np.asarray(x, dtype=np.float64)
    if x.ndim == 1: x = x[:, None]
    channels = x.shape[1]
    clipped = np.clip(x, -1.0, 1.0 - 2.0 ** -23)
    import wave
    with wave.open(path, 'wb') as w:
        w.setnchannels(channels)
        w.setsampwidth(bits // 8)
        w.setframerate(SR)
        if bits == 24:
            ints = np.round(clipped * (2 ** 23)).astype(np.int32).reshape(-1)
            data = np.empty((ints.size, 3), dtype=np.uint8)
            data[:, 0] = ints & 0xFF
            data[:, 1] = (ints >> 8) & 0xFF
            data[:, 2] = (ints >> 16) & 0xFF
            w.writeframes(data.tobytes())
        else:
            w.writeframes(np.round(clipped * 32767).astype('<i2').reshape(-1).tobytes())


def secs(n): return n / SR
def n_of(seconds): return int(round(seconds * SR))
def t_of(seconds): return np.arange(n_of(seconds)) / SR
def db(x): return 10 ** (x / 20.0)


def stereo(x, pan=0.0, width=0.0):
    """Mono to stereo with an equal-power pan (-1 left .. 1 right)."""
    if x.ndim == 2: return x
    angle = (pan + 1) * np.pi / 4
    return np.stack([x * np.cos(angle) * np.sqrt(2), x * np.sin(angle) * np.sqrt(2)], axis=1)


def mono(x):
    return x.mean(axis=1) if x.ndim == 2 else x


def fit(x, n):
    """Pad with silence or cut to n samples."""
    if len(x) >= n: return x[:n]
    pad = np.zeros((n - len(x),) + x.shape[1:])
    return np.concatenate([x, pad])


def normalize(x, peak=1.0):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


# --- Filters ---------------------------------------------------------------------

def _sos(kind, f, order=2):
    f = np.clip(np.asarray(f, dtype=float), 5.0, SR * 0.49)
    return sig.butter(order, f, btype=kind, fs=SR, output='sos')


def lp(x, f, order=2): return sig.sosfilt(_sos('lowpass', f, order), x, axis=0)
def hp(x, f, order=2): return sig.sosfilt(_sos('highpass', f, order), x, axis=0)
def bp(x, lo, hi, order=2): return sig.sosfilt(_sos('bandpass', [lo, hi], order), x, axis=0)


def biquad(kind, f, q=0.707, gain=0.0):
    """RBJ cookbook biquad as (b, a)."""
    A = 10 ** (gain / 40)
    w = 2 * np.pi * f / SR
    cw, sw = np.cos(w), np.sin(w)
    alpha = sw / (2 * q)
    if kind == 'peak':
        b = [1 + alpha * A, -2 * cw, 1 - alpha * A]
        a = [1 + alpha / A, -2 * cw, 1 - alpha / A]
    elif kind == 'lowshelf':
        sq = 2 * np.sqrt(A) * alpha
        b = [A * ((A + 1) - (A - 1) * cw + sq), 2 * A * ((A - 1) - (A + 1) * cw), A * ((A + 1) - (A - 1) * cw - sq)]
        a = [(A + 1) + (A - 1) * cw + sq, -2 * ((A - 1) + (A + 1) * cw), (A + 1) + (A - 1) * cw - sq]
    elif kind == 'highshelf':
        sq = 2 * np.sqrt(A) * alpha
        b = [A * ((A + 1) + (A - 1) * cw + sq), -2 * A * ((A - 1) + (A + 1) * cw), A * ((A + 1) + (A - 1) * cw - sq)]
        a = [(A + 1) - (A - 1) * cw + sq, 2 * ((A - 1) - (A + 1) * cw), (A + 1) - (A - 1) * cw - sq]
    elif kind == 'bandpass':
        b = [alpha, 0, -alpha]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    else:
        raise ValueError(kind)
    return np.array(b) / a[0], np.array(a) / a[0]


def eq(x, kind, f, q=0.707, gain=0.0):
    b, a = biquad(kind, f, q, gain)
    return sig.lfilter(b, a, x, axis=0)


def sweep_filter(x, cutoffs, kind='lowpass', q=0.9, block=64):
    """A resonant filter whose cutoff follows `cutoffs` (Hz, one per sample,
    or a callable of time), recomputed every `block` samples, state kept."""
    n = len(x)
    if callable(cutoffs): cutoffs = cutoffs(np.arange(n) / SR)
    cutoffs = np.broadcast_to(np.asarray(cutoffs, dtype=float), (n,))
    out = np.zeros_like(x)
    zi = None
    for start in range(0, n, block):
        end = min(n, start + block)
        f = float(np.clip(cutoffs[start], 20.0, SR * 0.45))
        w = 2 * np.pi * f / SR
        alpha = np.sin(w) / (2 * q)
        cw = np.cos(w)
        if kind == 'lowpass':
            b = np.array([(1 - cw) / 2, 1 - cw, (1 - cw) / 2])
        elif kind == 'highpass':
            b = np.array([(1 + cw) / 2, -(1 + cw), (1 + cw) / 2])
        else:
            b = np.array([alpha, 0.0, -alpha])
        a = np.array([1 + alpha, -2 * cw, 1 - alpha])
        b, a = b / a[0], a / a[0]
        if zi is None:
            shape = (2,) + x.shape[1:]
            zi = np.zeros(shape)
        chunk, zi = sig.lfilter(b, a, x[start:end], axis=0, zi=zi)
        out[start:end] = chunk
    return out


# --- Envelopes -----------------------------------------------------------------------

def adsr(n, a=0.01, d=0.1, s=0.7, r=0.3, hold=None):
    """Attack, decay, sustain level, release (seconds); the note lasts n samples
    of which the release is the end."""
    env = np.zeros(n)
    ta, td, tr = n_of(a), n_of(d), n_of(r)
    th = n - tr if hold is None else n_of(hold)
    th = max(th, ta + td)
    i = 0
    if ta: env[:min(ta, n)] = np.linspace(0, 1, ta)[:min(ta, n)]
    i = ta
    if i < n and td:
        seg = np.linspace(1, s, td)[:max(0, min(td, n - i))]
        env[i:i + len(seg)] = seg
    i = ta + td
    if i < th and i < n: env[i:min(th, n)] = s
    if th < n: env[th:] = s * np.linspace(1, 0, n - th) ** 2
    return env


def exp_decay(n, seconds_to_60db):
    t = np.arange(n) / SR
    return 10 ** (-3 * t / seconds_to_60db)


def fade(x, fin=0.0, fout=0.0):
    x = x.copy()
    a, b = n_of(fin), n_of(fout)
    if a: x[:a] *= (np.linspace(0, 1, a) ** 2)[:, None] if x.ndim == 2 else np.linspace(0, 1, a) ** 2
    if b: x[-b:] *= (np.linspace(1, 0, b) ** 2)[:, None] if x.ndim == 2 else np.linspace(1, 0, b) ** 2
    return x


# --- Oscillators -------------------------------------------------------------------------

def phase(freq, n):
    """Running phase (radians) of a frequency that may vary per sample."""
    f = np.broadcast_to(np.asarray(freq, dtype=float), (n,))
    return 2 * np.pi * np.cumsum(f) / SR


def sine(freq, n, ph=0.0): return np.sin(phase(freq, n) + ph)


def saw(freq, n, rng=None, harmonics=None):
    """Band-limited sawtooth by summed harmonics (for low, rich tones)."""
    f = np.broadcast_to(np.asarray(freq, dtype=float), (n,))
    ph = phase(f, n) + (rng.uniform(0, 2 * np.pi) if rng is not None else 0.0)
    top = float(np.max(f))
    count = harmonics or int(min(60, (SR * 0.45) // max(top, 1.0)))
    out = np.zeros(n)
    for k in range(1, count + 1):
        out += np.sin(k * ph) / k
    return out * (2 / np.pi)


def noise(n, rng, color='white'):
    x = rng.standard_normal(n)
    if color == 'pink':
        # Paul Kellet's refined filter, as a filter on white noise.
        b = [0.049922035, -0.095993537, 0.050612699, -0.004408786]
        a = [1, -2.494956002, 2.017265875, -0.522189400]
        x = sig.lfilter(b, a, x)
    elif color == 'brown':
        x = sig.lfilter([1.0], [1.0, -0.995], x) * 0.1
    return x / (np.std(x) or 1.0)


# --- Space -----------------------------------------------------------------------------

def impulse(seconds, rt60, rng, damping=4500.0, predelay=0.012, early=6, width=1.0, bright=1.0):
    """A synthetic stereo room: early reflections, then a noise tail that
    decays to -60 dB in rt60 and darkens as it goes (highs die faster)."""
    n = n_of(seconds)
    t = np.arange(n) / SR
    ir = np.zeros((n, 2))
    pd = n_of(predelay)
    for ch in range(2):
        tail = rng.standard_normal(n)
        low = lp(tail, 700) * 10 ** (-3 * t / (rt60 * 1.15))
        mid = bp(tail, 700, 3000) * 10 ** (-3 * t / rt60)
        high = hp(tail, 3000) * 10 ** (-3 * t / (rt60 * 0.45)) * bright
        tail = lp(low + mid + high, damping)
        onset = np.clip(t / 0.03, 0, 1)
        ir[:, ch] = np.concatenate([np.zeros(pd), (tail * onset)[:n - pd]])
        for k in range(early):
            at = pd + n_of(rng.uniform(0.004, 0.07))
            if at < n: ir[at, ch] += rng.uniform(0.3, 0.8) * (-1) ** k
    # Decorrelate the sides by width.
    mid_ = ir.mean(axis=1, keepdims=True)
    ir = mid_ + (ir - mid_) * width
    return ir / np.sqrt(np.sum(ir ** 2) / 2)


def convolve(x, ir, wet=0.3, dry=1.0):
    """x (mono or stereo) through a stereo impulse; returns stereo."""
    xs = stereo(x) if x.ndim == 1 else x
    src = mono(xs)
    out = np.stack([sig.fftconvolve(src, ir[:, 0]), sig.fftconvolve(src, ir[:, 1])], axis=1)[:len(xs)]
    return xs * dry + out * wet


def delay(x, seconds, feedback=0.3, mix=0.3, damp=3000.0):
    d = n_of(seconds)
    out = np.array(x, dtype=float, copy=True)
    echo = np.array(x, dtype=float, copy=True)
    for k in range(1, 8):
        echo = lp(echo, damp) * feedback if k > 1 else lp(echo, damp)
        shifted = np.zeros_like(x)
        if d * k < len(x): shifted[d * k:] = echo[:len(x) - d * k]
        out = out + shifted * mix * (feedback ** (k - 1))
    return out


def wobble(x, depth_cents=12.0, rate=0.55, flutter_cents=4.0, flutter_rate=6.8, rng=None):
    """Tape wow and flutter: the signal read at a slowly wandering speed."""
    n = len(x)
    t = np.arange(n) / SR
    wander = np.sin(2 * np.pi * rate * t) + 0.5 * np.sin(2 * np.pi * rate * 1.73 * t + 1.1)
    wander += 0.4 * np.sin(2 * np.pi * flutter_rate * t) * (flutter_cents / max(depth_cents, 0.01))
    ratio = 2 ** (wander * depth_cents / 1200 / 1.5)
    pos = np.cumsum(ratio)
    pos -= pos[0]
    pos = np.clip(pos, 0, n - 1)
    if x.ndim == 1: return np.interp(pos, np.arange(n), x)
    return np.stack([np.interp(pos, np.arange(n), x[:, c]) for c in range(x.shape[1])], axis=1)


def resample_speed(x, speed):
    """Played faster (>1) or slower (<1): pitch and length both change."""
    n = len(x)
    m = max(1, int(n / speed))
    pos = np.linspace(0, n - 1, m)
    if x.ndim == 1: return np.interp(pos, np.arange(n), x)
    return np.stack([np.interp(pos, np.arange(n), x[:, c]) for c in range(x.shape[1])], axis=1)


def tape_stop(x, seconds):
    """The last `seconds` of x slowing to a halt, as a tape machine stopping."""
    n = len(x)
    k = n_of(seconds)
    head = x[:n - k]
    t = np.linspace(0, 1, k)
    speed = (1 - t) ** 1.6
    pos = (n - k) + np.cumsum(speed)
    pos = np.clip(pos, 0, n - 1)
    if x.ndim == 1: tail = np.interp(pos, np.arange(n), x)
    else: tail = np.stack([np.interp(pos, np.arange(n), x[:, c]) for c in range(x.shape[1])], axis=1)
    env = (1 - t) ** 0.7
    tail = tail * (env[:, None] if x.ndim == 2 else env)
    return np.concatenate([head, tail])


def saturate(x, drive=2.0):
    return np.tanh(x * drive) / np.tanh(drive)


# --- Dynamics ------------------------------------------------------------------------------

def envelope_follow(x, attack=0.005, release=0.12):
    """Peak envelope with separate attack and release (sample loop in blocks)."""
    level = np.abs(mono(x) if x.ndim == 2 else x)
    # Downsample the detector: 1 ms blocks are plenty for a mix.
    block = n_of(0.001)
    m = len(level) // block + 1
    peaks = np.array([level[i * block:(i + 1) * block].max() if i * block < len(level) else 0.0 for i in range(m)])
    ga = np.exp(-0.001 / attack)
    gr = np.exp(-0.001 / release)
    env = np.zeros(m)
    acc = 0.0
    for i, p in enumerate(peaks):
        acc = ga * acc + (1 - ga) * p if p > acc else gr * acc + (1 - gr) * p
        env[i] = acc
    return np.repeat(env, block)[:len(level)]


def compress(x, threshold=-18.0, ratio=3.0, attack=0.01, release=0.15, makeup=0.0, knee=6.0):
    env = envelope_follow(x, attack, release)
    level = 20 * np.log10(np.maximum(env, 1e-9))
    over = level - threshold
    gain_db = np.where(over <= -knee / 2, 0.0,
                       np.where(over >= knee / 2, -over * (1 - 1 / ratio),
                                -((over + knee / 2) ** 2) / (2 * knee) * (1 - 1 / ratio)))
    gain = db(gain_db + makeup)
    return x * (gain[:, None] if x.ndim == 2 else gain)


def duck(x, key, amount_db=-8.0, attack=0.04, release=0.45, threshold=0.02):
    """x ducked while `key` sounds (sidechain)."""
    env = envelope_follow(key, attack, release)
    k = np.clip(env / threshold, 0, 1)
    gain = db(amount_db * k)
    return x * (gain[:, None] if x.ndim == 2 else gain)


def limit(x, ceiling_db=-1.0, lookahead=0.004, release=0.08, oversample=4):
    """Look-ahead peak limiter, run at `oversample` times the rate so the
    peaks between samples are held to the ceiling too (true peak)."""
    ceiling = db(ceiling_db)
    up = sig.resample_poly(x, oversample, 1, axis=0)
    rate = SR * oversample
    peak = np.abs(up).max(axis=1) if up.ndim == 2 else np.abs(up)
    need = np.minimum(1.0, ceiling / np.maximum(peak, 1e-9))
    la = max(1, int(lookahead * rate))
    floor = minimum_filter1d(need, size=2 * la + 1, mode='nearest')
    g = uniform_filter1d(floor, size=la, mode='nearest')
    rel = np.exp(-1.0 / max(1, int(release * rate)))
    g = sig.lfilter([1 - rel], [1, -rel], g - 1.0) + 1.0
    g = np.minimum(g, floor)
    up = up * (g[:, None] if up.ndim == 2 else g)
    out = sig.resample_poly(up, 1, oversample, axis=0)[:len(x)]
    # The filter of the way back down can ring a hair over: a last trim.
    over = true_peak(out) - ceiling_db
    if over > 0: out = out * db(-over - 0.02)
    return out

def true_peak(x):
    up = sig.resample_poly(x, 4, 1, axis=0)
    return 20 * np.log10(np.max(np.abs(up)) + 1e-12)


def lufs(x):
    """Integrated loudness, ITU-R BS.1770-4 (K-weighted, gated)."""
    xs = stereo(x) if x.ndim == 1 else x
    b1, a1 = [1.53512485958697, -2.69169618940638, 1.19839281085285], [1.0, -1.69065929318241, 0.73248077421585]
    b2, a2 = [1.0, -2.0, 1.0], [1.0, -1.99004745483398, 0.99007225036621]
    k = sig.lfilter(b2, a2, sig.lfilter(b1, a1, xs, axis=0), axis=0)
    block, step = n_of(0.4), n_of(0.1)
    powers = []
    for start in range(0, len(k) - block + 1, step):
        powers.append(np.mean(k[start:start + block] ** 2, axis=0).sum())
    powers = np.array(powers)
    loud = -0.691 + 10 * np.log10(np.maximum(powers, 1e-12))
    gated = powers[loud > -70]
    if gated.size == 0: return -70.0
    rel = -0.691 + 10 * np.log10(gated.mean()) - 10
    final = powers[(loud > -70) & (loud > rel)]
    return -0.691 + 10 * np.log10(final.mean())


def rms_db(x):
    return 20 * np.log10(np.sqrt(np.mean(np.square(x))) + 1e-12)
