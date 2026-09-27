"""Working copies of the lift's four recordings, from the originals in
sfx/elevator/ into assets/audio/sfx/lift/. The originals are never touched.

  doors_close.wav  the car's doors running shut      (CC0)
  descent.wav      the car going down                 (CC0)
  doors_open.wav   the doors opening where it arrives (CC0)
  bell.wav         the bell as it arrives             ("toaster oven or lift/elevator bell",
                                                       azumarill, Freesound, CC BY 3.0)

Each is decoded by ffmpeg (audio/dsp.py finds one), made mono, cut from its
first sound to where it has died away, faded at both ends and brought to a
common peak, so lifts.gd can time the ride on their real lengths: it reads
them (lifts.gd RIDE_*), and a change here is a change there.

Deterministic: re-running reproduces the same files.

    python tools/audio/prepare_lift_sfx.py
"""
from pathlib import Path
import subprocess
import sys
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/trailer3d/audio"))
from dsp import ffmpeg  # noqa: E402

SOURCE = ROOT / "sfx/elevator"
OUT = ROOT / "assets/audio/sfx/lift"
RATE = 44100
## (original, copy, peak, seconds kept from the first sound; 0 keeps it all).
CLIPS = [
    ("door closing.ogg", "doors_close.wav", 0.8, 0.0),
    ("elevator-going-down.ogg", "descent.wav", 0.7, 0.0),
    ("door-opening.ogg", "doors_open.wav", 0.8, 0.0),
    ("liftelevator-bell.wav", "bell.wav", 0.7, 2.6),
]


def load(path):
    raw = subprocess.run([ffmpeg(), "-v", "error", "-i", str(path), "-f", "f32le", "-ac", "1", "-ar", str(RATE), "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).astype(np.float64)


def trim(x, keep):
    """From just before its first sound to where it has fallen 50 dB, or `keep` s."""
    level = np.abs(x)
    loud = np.where(level > level.max() * 10 ** (-40 / 20))[0]
    start = max(0, loud[0] - int(0.01 * RATE))
    quiet = np.where(level > level.max() * 10 ** (-50 / 20))[0]
    end = min(len(x), quiet[-1] + int(0.05 * RATE))
    if keep > 0:
        end = min(end, start + int(keep * RATE))
    return x[start:end]


def fade(x, fin=0.004, fout=0.25):
    x = x.copy()
    a = min(len(x), int(fin * RATE))
    b = min(len(x), int(fout * RATE))
    x[:a] *= np.linspace(0, 1, a)
    x[len(x) - b:] *= np.linspace(1, 0, b) ** 2
    return x


def write(name, x, peak):
    OUT.mkdir(parents=True, exist_ok=True)
    x = x / (np.max(np.abs(x)) or 1.0) * peak
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(np.round(np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())
    print("%-16s %.2f s" % (name, len(x) / RATE))


def main():
    for original, copy, peak, keep in CLIPS:
        write(copy, fade(trim(load(SOURCE / original), keep)), peak)


if __name__ == "__main__":
    main()
