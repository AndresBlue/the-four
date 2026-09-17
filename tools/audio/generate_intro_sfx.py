"""Builds the synthesized sounds of the opening scene in assets/audio/intro/
(16-bit mono WAV): the television's static and line whine, knocks on the
screen glass from inside, the screen shattering and the creature battering
the bedroom door, heard from the corridor.

Deterministic (fixed seeds): re-running reproduces the same files.

    python tools/audio/generate_intro_sfx.py
"""
from pathlib import Path
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/audio/intro"
RATE = 44100
rng = np.random.default_rng(1987)


def write(name, samples, peak=0.89):
    OUT.mkdir(parents=True, exist_ok=True)
    samples = np.asarray(samples, dtype=np.float64)
    samples = samples / (np.max(np.abs(samples)) or 1.0) * peak
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(np.clip(samples * 32767, -32768, 32767).astype("<i2").tobytes())
    print("wrote", name, f"{len(samples) / RATE:.2f} s")


def band(x, low, high):
    spectrum = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1.0 / RATE)
    spectrum[(freqs < low) | (freqs > high)] = 0
    return np.fft.irfft(spectrum, len(x))


def seconds(duration):
    return np.arange(int(duration * RATE)) / RATE


def seamless(signal, fade):
    n = int(fade * RATE)
    ramp = np.linspace(0.0, 1.0, n)
    head = signal[:n] * ramp + signal[-n:] * (1 - ramp)
    return np.concatenate([head, signal[n:-n]])


def decay(t, rate, start=0.0):
    return np.where(t >= start, np.exp(-(t - start) * rate), 0.0)


def partial(t, freq, rate, start=0.0, amp=1.0):
    return amp * np.sin(2 * np.pi * freq * np.maximum(t - start, 0)) * decay(t, rate, start)


def static():
    """A dead channel on a big set: harsh full-band hiss that surges and
    crackles, over the field-rate buzz of the picture tube. Looped."""
    t = seconds(4.5)
    noise = band(rng.standard_normal(len(t)), 250, 17000)
    bright = band(rng.standard_normal(len(t)), 3000, 12000) * 0.6
    surge = 0.7 + 0.3 * np.abs(np.sin(2 * np.pi * 0.45 * t) * np.sin(2 * np.pi * 1.9 * t + 0.6))
    crackle = np.zeros(len(t))
    for start in rng.uniform(0, 4.4, 160):
        i = int(start * RATE)
        length = int(rng.uniform(20, 140))
        crackle[i:i + length] += rng.standard_normal(length) * np.exp(-np.arange(length) / (length / 5)) * rng.uniform(1.5, 4.0)
    # Vertical sync buzz: a pulse train at the field rate with its harmonics.
    buzz = np.sign(np.sin(2 * np.pi * 59.94 * t)) * 0.5 + np.sin(2 * np.pi * 119.88 * t) * 0.3
    buzz = band(buzz, 55, 2400) * 0.35
    write("tv_static.wav", seamless((noise + bright) * surge + crackle + buzz, 0.25))


def whine():
    """A CRT at rest: line-output whine and mains hum, very quiet in the mix."""
    t = seconds(3.0)
    signal = 0.4 * np.sin(2 * np.pi * 15734 * t) + np.sin(2 * np.pi * 60 * t) * 0.6 + np.sin(2 * np.pi * 180 * t) * 0.25
    signal += band(rng.standard_normal(len(t)), 100, 400) * 0.05
    write("tv_whine.wav", seamless(signal, 0.2), 0.5)


def knock(index):
    """A fist on the screen glass from inside: thump, glass ring, fresh cracks."""
    t = seconds(1.4)
    body = partial(t, 72, 16) * 1.2 + partial(t, 118, 22) * 0.7
    body += band(rng.standard_normal(len(t)), 60, 400) * decay(t, 40) * 0.8
    ring = sum(partial(t, f, 9 + k * 3, 0.004, 0.18 / (k + 1)) for k, f in enumerate([1180, 2630, 3910, 5270]))
    cracks = np.zeros(len(t))
    for start in np.sort(rng.uniform(0.01, 0.12 + index * 0.08, 6 + index * 8)):
        i = int(start * RATE)
        length = int(rng.uniform(0.002, 0.01) * RATE)
        cracks[i:i + length] += rng.standard_normal(length) * np.exp(-np.arange(length) / (length / 4)) * rng.uniform(0.3, 1.0)
    cracks = band(cracks, 1500, 16000) * (0.5 + index * 0.25)
    write(f"glass_knock_{index + 1}.wav", body + ring + cracks)


def shatter():
    """The screen gives: a crack, the implosion thump and falling shards."""
    t = seconds(3.2)
    hit = band(rng.standard_normal(len(t)), 400, 18000) * decay(t, 18) * 1.4
    thump = partial(t, 55, 7) * 1.6 + partial(t, 90, 12)
    shards = np.zeros(len(t))
    for start in rng.uniform(0.02, 2.2, 140) ** 1.6:
        freq = rng.uniform(2200, 9000)
        shards += partial(t, freq, rng.uniform(25, 70), start, rng.uniform(0.05, 0.3) * np.exp(-start * 1.2))
    debris = band(rng.standard_normal(len(t)), 2000, 14000) * decay(t, 2.5, 0.05) * 0.25
    write("glass_shatter.wav", hit + thump + shards + debris)


def bang(index):
    """The creature battering a shut wooden door, heard from the corridor."""
    t = seconds(1.6)
    thud = partial(t, 64 + index * 6, 9) * 1.4 + partial(t, 132, 15) * 0.6
    wood = band(rng.standard_normal(len(t)), 150, 900) * decay(t, 20) * 1.1
    panel = partial(t, 310 + index * 20, 24, 0.002, 0.35)
    rattle = np.zeros(len(t))
    for start in 0.03 + np.cumsum(rng.uniform(0.02, 0.06, 7)):
        i = int(start * RATE)
        rattle[i:i + 200] += rng.standard_normal(200) * np.exp(-np.arange(200) / 30) * np.exp(-start * 6)
    rattle = band(rattle, 1200, 7000) * 0.5
    write(f"door_bang_{index + 1}.wav", band(thud + wood + panel + rattle, 30, 5000))


def stomp(index):
    """A heavy, deliberate step on carpet over a wooden floor."""
    t = seconds(0.7)
    thud = partial(t, 62 + index * 7, 22) * 1.4 + partial(t, 115, 30) * 0.5
    board = band(rng.standard_normal(len(t)), 120, 900) * decay(t, 45) * 0.7
    scuff = band(rng.standard_normal(len(t)), 1500, 7000) * decay(t, 25, 0.02) * 0.08
    write(f"stomp_{index + 1}.wav", thud + board + scuff)


if __name__ == "__main__":
    static()
    whine()
    for i in range(3):
        knock(i)
    shatter()
    for i in range(3):
        bang(i)
    for i in range(3):
        stomp(i)
