"""Builds the synthesized dread layers and mono working copies used by the
spatial audio system. Output goes to assets/audio/dread/ (16-bit WAV).

Everything is deterministic (fixed seeds), so re-running reproduces the same
files. Originals in sfx/ are only read, never modified.

    python tools/audio/generate_dread_layers.py
"""
from pathlib import Path
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/audio/dread"
RATE = 22050


def write(name, samples, rate=RATE):
    OUT.mkdir(parents=True, exist_ok=True)
    samples = np.asarray(samples, dtype=np.float64)
    peak = np.max(np.abs(samples)) or 1.0
    samples = samples / peak * 0.89  # about -1 dBFS; levels are set in the mix
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(np.clip(samples * 32767, -32768, 32767).astype("<i2").tobytes())
    print("wrote", name, f"{len(samples) / rate:.2f} s")


def one_pole_lowpass(x, cutoff, rate=RATE):
    a = np.exp(-2 * np.pi * cutoff / rate)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def bandpass(x, center, q, rate=RATE):
    """RBJ biquad band-pass (constant 0 dB peak gain)."""
    w0 = 2 * np.pi * center / rate
    alpha = np.sin(w0) / (2 * q)
    b0, b1, b2 = alpha, 0.0, -alpha
    a0, a1, a2 = 1 + alpha, -2 * np.cos(w0), 1 - alpha
    b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
    y = np.zeros_like(x)
    x1 = x2 = y1 = y2 = 0.0
    for i, v in enumerate(x):
        out = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, v, y1, out
        y[i] = out
    return y


def seamless(signal, fade_seconds, rate=RATE):
    """Crossfades the tail into the head so the result loops without a click."""
    n = int(fade_seconds * rate)
    body = signal[n:-n] if n else signal
    ramp = np.linspace(0, 1, n, endpoint=False)
    head = signal[:n] * ramp + signal[-n:] * (1 - ramp)
    return np.concatenate([head, body])


def periodic(freq, seconds):
    """Snap a frequency to a whole number of cycles over the loop length."""
    return round(freq * seconds) / seconds


rng = np.random.default_rng(1989)

# 1. Sub drone: beating low partials, slow swells and dark rumble.
seconds = 12.0
t = np.arange(int(seconds * RATE)) / RATE
drone = (
    np.sin(2 * np.pi * periodic(36.9, seconds) * t)
    + 0.8 * np.sin(2 * np.pi * periodic(37.6, seconds) * t)
    + 0.45 * np.sin(2 * np.pi * periodic(55.4, seconds) * t + 1.3)
    + 0.22 * np.sin(2 * np.pi * periodic(110.6, seconds) * t)
)
swell = 0.65 + 0.35 * np.sin(2 * np.pi * (3 / seconds) * t) * np.sin(2 * np.pi * (1 / seconds) * t + 0.5)
rumble = one_pole_lowpass(rng.standard_normal(len(t) + 44100), 60.0)
rumble = seamless(rumble, 2.0)[: len(t)]
drone = np.tanh(1.6 * (drone * swell + rumble * 6.0))
write("dread_drone.wav", drone)

# 2. Breath: filtered noise shaped into irregular inhales, with a hollow formant.
seconds = 9.0
extra = int(0.8 * RATE)
n = int(seconds * RATE) + 2 * extra
t = np.arange(n) / RATE
noise = rng.standard_normal(n)
air = bandpass(noise, 520, 1.6) + 0.7 * bandpass(noise, 1150, 2.5) + 0.25 * bandpass(noise, 2600, 4.0)
envelope = np.clip(np.sin(2 * np.pi * 0.37 * t) * 0.6 + np.sin(2 * np.pi * 0.113 * t + 1.1) * 0.5 + 0.15, 0, None) ** 1.7
breath = seamless(air * envelope, 0.8)
write("dread_breath.wav", breath)

# 3. Chitters: bursts of dry clicks like hard legs tapping on each other.
for variant in range(4):
    local = np.random.default_rng(700 + variant)
    length = local.uniform(0.45, 0.9)
    signal = np.zeros(int(length * RATE))
    position = 0.0
    gap = local.uniform(0.02, 0.05)
    while position < length - 0.05:
        start = int(position * RATE)
        size = int(0.018 * RATE)
        k = np.arange(size) / RATE
        pitch = local.uniform(2400, 4600)
        click = np.sin(2 * np.pi * pitch * k) * np.exp(-k * local.uniform(260, 420))
        click += 0.6 * np.sin(2 * np.pi * local.uniform(150, 230) * k) * np.exp(-k * 90)
        gain = np.sin(np.pi * position / length) * local.uniform(0.5, 1.0)
        end = min(start + size, len(signal))
        signal[start:end] += click[: end - start] * gain
        gap *= local.uniform(0.85, 1.18)
        gap = float(np.clip(gap, 0.015, 0.08))
        position += gap
    write(f"chitter_{variant}.wav", signal)

# 4. Fluorescent hum: mains buzz with a thin whine, loops every 2 s.
seconds = 2.0
t = np.arange(int(seconds * RATE)) / RATE
hum = sum(np.sin(2 * np.pi * 100 * h * t) / h for h in range(1, 7))
hum = np.clip(hum * 1.8, -1, 1) + 0.04 * np.sin(2 * np.pi * periodic(2130, seconds) * t)
write("fluorescent_hum.wav", hum)


def mono_copy(source, name, rate_out):
    """24-bit stereo master -> mono 16-bit working copy at a lower rate."""
    with wave.open(str(ROOT / source), "rb") as w:
        rate, channels, width, frames = w.getframerate(), w.getnchannels(), w.getsampwidth(), w.getnframes()
        raw = w.readframes(frames)
    if width == 3:
        b = np.frombuffer(raw, np.uint8).reshape(-1, 3).astype(np.int32)
        ints = b[:, 0] | (b[:, 1] << 8) | (b[:, 2] << 16)
        data = ((ints ^ 0x800000) - 0x800000).astype(np.float64) / 2 ** 23
    else:
        data = np.frombuffer(raw, "<i2").astype(np.float64) / 32768
    mono = data.reshape(-1, channels).mean(axis=1)
    # Windowed-sinc low-pass before resampling to avoid aliasing.
    ratio = rate_out / rate
    taps = np.arange(-63, 64)
    kernel = np.sinc(taps * ratio * 0.9) * np.hamming(len(taps))
    kernel /= kernel.sum()
    filtered = np.convolve(mono, kernel, mode="same")
    positions = np.arange(0, len(filtered) - 1, 1 / ratio)
    resampled = np.interp(positions, np.arange(len(filtered)), filtered)
    return resampled


riser = mono_copy("sfx/ambience/presence/sub-riser-presence.wav", "riser", RATE)
write("presence_riser.wav", riser)

