"""Builds the screamer that fires the instant the creature gets hold of you,
in assets/audio/events/execution_scream.wav (16-bit mono WAV).

It is meant to be ugly, not musical: no attack to speak of (two milliseconds
from nothing to full), an inharmonic stack of partials sliding down, a torn
noise layer over it and hard saturation, so it reads as a throat and not as a
synthesizer. Then it collapses into a breath, which is what leaves room for
the kill that follows.

Deterministic (fixed seed): re-running reproduces the same file.

    python tools/audio/generate_screamer.py
"""
from pathlib import Path
import sys

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate_intro_sfx as base  # noqa: E402  (shared writer and filters)

base.OUT = Path(__file__).resolve().parents[2] / "assets/audio/events"
rng = np.random.default_rng(6613)


def scream():
    t = base.seconds(1.6)
    # The cry falls from a shriek to a growl: the fall is what makes it read as
    # something alive closing in, rather than an alarm.
    slide = 980.0 * np.exp(-t * 1.9) + 120.0
    phase = 2 * np.pi * np.cumsum(slide) / base.RATE
    # Inharmonic partials: a throat that is not a single tone.
    voice = np.zeros(len(t))
    for ratio, amp in [(1.0, 1.0), (1.47, 0.62), (2.09, 0.45), (3.13, 0.3), (4.71, 0.18)]:
        voice += amp * np.sin(phase * ratio + rng.random() * 6.28)
    # A second, slower cry underneath, detuned, so it never sounds like one voice.
    voice += 0.5 * np.sin(phase * 0.503 + 1.1)
    # Torn edges: band noise that follows the same envelope as the voice.
    rasp = base.band(rng.standard_normal(len(t)), 700, 9000) * (0.55 + 0.45 * np.sin(phase * 0.5))
    body = voice * 0.75 + rasp * 0.45
    # Two milliseconds of attack, then a long uneven decay with a tremor.
    onset = np.clip(t / 0.002, 0.0, 1.0)
    tail = np.exp(-np.maximum(t - 0.05, 0.0) * 2.2)
    tremor = 1.0 + 0.22 * np.sin(2 * np.pi * 17.0 * t) * np.clip((t - 0.2) * 3.0, 0.0, 1.0)
    body = body * onset * tail * tremor
    # Hard saturation: the recording itself gives way, like a mic too close.
    body = np.tanh(body * 3.4)
    # The chest under it, and the breath it collapses into.
    thump = base.partial(t, 46, 9, 0.0, 1.1) + base.partial(t, 73, 14, 0.01, 0.6)
    breath = base.band(rng.standard_normal(len(t)), 200, 2600) * base.decay(t, 3.4, 0.62) * 0.35
    return body + thump * 0.5 + breath


if __name__ == "__main__":
    base.write("execution_scream.wav", scream(), peak=0.97)
