"""Builds the synthesized sounds of the pacing director's events and of an
execution in assets/audio/events/ (16-bit mono WAV): something heavy falling
over in a nearby room, knuckles rapping on a door, the blows of a blade going
through a body and the body dropping afterwards.

Deterministic (fixed seeds): re-running reproduces the same files.

    python tools/audio/generate_event_sfx.py
"""
from pathlib import Path
import sys

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate_intro_sfx as base  # noqa: E402  (shared writer and filters)

base.OUT = Path(__file__).resolve().parents[2] / "assets/audio/events"
rng = np.random.default_rng(3141)


def fall(index):
    """A wooden object topples: the tip, the heavy landing, a bounce and a roll."""
    t = base.seconds(2.2)
    lean = base.band(rng.standard_normal(len(t)), 300, 2500) * base.decay(t, 30) * 0.2
    land = 0.12 + index * 0.05
    thud = base.partial(t, 58 + index * 9, 11, land, 1.5) + base.partial(t, 140, 20, land, 0.6)
    crash = base.band(rng.standard_normal(len(t)), 200, 6000) * base.decay(t, 26, land) * 1.2
    bounce = base.partial(t, 95, 30, land + 0.21, 0.5) + base.band(rng.standard_normal(len(t)), 400, 5000) * base.decay(t, 45, land + 0.21) * 0.4
    roll = base.band(rng.standard_normal(len(t)), 150, 1200) * np.where(t > land + 0.3, np.exp(-(t - land - 0.3) * 2.5), 0) * 0.15
    roll *= 0.6 + 0.4 * np.sin(2 * np.pi * 7 * t)
    base.write(f"object_fall_{index + 1}.wav", lean + thud + crash + bounce + roll)


def raps(index):
    """Three slow knocks with the knuckles on a hotel door."""
    t = base.seconds(2.0)
    signal = np.zeros(len(t))
    start = 0.05
    for hit in range(3):
        signal += base.partial(t, 180 + index * 15, 38, start, 1.0) + base.partial(t, 420, 60, start, 0.35)
        signal += base.band(rng.standard_normal(len(t)), 300, 3000) * base.decay(t, 90, start) * 0.5
        start += 0.42 + rng.uniform(-0.04, 0.08)
    base.write(f"door_raps_{index + 1}.wav", signal)


def stab(index):
    """A blade driven into a body: the hit, a wet tear and a short ring."""
    t = base.seconds(1.1)
    hit = base.partial(t, 70 + index * 8, 26, 0.0, 1.0) + base.partial(t, 150 + index * 20, 40, 0.0, 0.5)
    # Wet burst that tears off instead of cracking like wood.
    tear = base.band(rng.standard_normal(len(t)), 240, 2600) * base.decay(t, 22 + index * 4) * 0.75
    tear *= 0.7 + 0.3 * np.sin(2 * np.pi * (26 + index * 7) * t)
    ring = base.partial(t, 1850 + index * 240, 30, 0.01, 0.12)
    drip = base.band(rng.standard_normal(len(t)), 500, 4200) * np.where(t > 0.18, np.exp(-(t - 0.18) * 7.0), 0) * 0.2
    base.write(f"execution_stab_{index + 1}.wav", hit + tear + ring + drip, 0.8)


def body_drop():
    """The body let go: it lands and settles."""
    t = base.seconds(1.6)
    land = base.partial(t, 52, 14, 0.0, 1.0) + base.partial(t, 110, 26, 0.0, 0.45)
    cloth = base.band(rng.standard_normal(len(t)), 300, 3200) * base.decay(t, 16) * 0.5
    settle = base.partial(t, 64, 22, 0.22, 0.35) + base.band(rng.standard_normal(len(t)), 250, 2000) * base.decay(t, 20, 0.22) * 0.25
    base.write("execution_drop.wav", land + cloth + settle, 0.82)


if __name__ == "__main__":
    for i in range(2):
        fall(i)
        raps(i)
    for i in range(3):
        stab(i)
    body_drop()
