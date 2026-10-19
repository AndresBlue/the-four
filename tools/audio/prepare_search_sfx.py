"""Working copies of what going through a piece of furniture sounds like, cut
from the author's recordings in sfx/drawer/ into assets/audio/sfx/search/.
The originals are never touched. All four are CC0 (Freesound pages opened on
19 October 2026):

  sfx/drawer/wooden-drawer.wav  "Teak Nightstand Open and Close", Filmscore,
                                Freesound 828784: a teak bedside drawer
                                opened and shut. For the drawers of a small,
                                old wooden piece (the painted cabinet).
                                -> wooden_drawer.wav, the opening
  sfx/drawer/big-drawer.wav     "Drawer Opening & Closing", quantumriver,
                                Freesound 552153. For big drawers (the
                                gothic commode's). -> big_drawer.wav, the
                                opening
  sfx/drawer/soft-drawer.wav    "cajon.wav", ANFEGORES108, Freesound 626414:
                                a nightstand drawer opened again and again,
                                five takes with digital silence between. For
                                a modern piece (the office's drawer cabinet).
                                -> soft_drawer_1..5.wav, the five takes
  sfx/drawer/box.wav            "open-cardboard-box-compartment.wav",
                                newagesoup, Freesound 364740: the flaps of an
                                empty cardboard box folded open. -> box.wav

Only the openings: a piece gone through is left as it was found. The two
recordings that also shut the drawer are cut where the opening ends (OPENING,
seconds, read off their envelopes: the pull, the slide and the knock of the
drawer reaching its stop, rung out). Rumble filtered, faded at both ends, and
each set brought to PEAK as a whole. Mono, 44.1 kHz, 16 bit.

Deterministic: re-running reproduces the same files.

    python tools/audio/prepare_search_sfx.py
"""
from pathlib import Path
import subprocess
import sys
import wave

import numpy as np
from scipy import signal

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/trailer3d/audio"))
from dsp import ffmpeg  # noqa: E402

RATE = 44100
PEAK = 10 ** (-6.0 / 20)
SOURCE = ROOT / "sfx/drawer"
OUT = ROOT / "assets/audio/sfx/search"
OPENING = {"wooden-drawer.wav": (0.72, 1.95), "big-drawer.wav": (0.30, 1.50)}


def load(path):
    raw = subprocess.run([ffmpeg(), "-v", "error", "-i", str(path), "-f", "f32le", "-ac", "1", "-ar", str(RATE), "-"], capture_output=True, check=True).stdout
    x = np.frombuffer(raw, np.float32).astype(np.float64)
    return signal.sosfiltfilt(signal.butter(4, 60.0, "highpass", fs=RATE, output="sos"), x - x.mean())


def fade(x, fin, fout):
    x = x.copy()
    a = max(1, int(fin * RATE))
    b = max(1, int(fout * RATE))
    x[:a] *= np.linspace(0.0, 1.0, a)
    x[-b:] *= np.cos(np.linspace(0.0, np.pi / 2, b)) ** 2
    return x


def write(path, x):
    path.parent.mkdir(parents=True, exist_ok=True)
    data = np.clip(np.round(x * 32767.0), -32768, 32767).astype("<i2")
    with wave.open(str(path), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(data.tobytes())
    print("%-20s %.2f s" % (path.name, len(x) / RATE))


def takes(raw_path):
    """The stretches between the digital silences the author left (exact
    zeros, read from the file itself, before any filtering)."""
    raw = subprocess.run([ffmpeg(), "-v", "error", "-i", str(raw_path), "-f", "s16le", "-ac", "1", "-ar", str(RATE), "-"], capture_output=True, check=True).stdout
    quiet = np.frombuffer(raw, "<i2") == 0
    hop = int(0.01 * RATE)
    silent = [bool(quiet[i:i + hop].all()) for i in range(0, len(quiet) - hop, hop)]
    found = []
    start = None
    for i, mute in enumerate(silent + [True]):
        if not mute and start is None: start = i
        elif mute and start is not None:
            if (i - start) * hop > int(0.3 * RATE): found.append((start * hop, i * hop))
            start = None
    return found


def main():
    for source, (a, b) in OPENING.items():
        x = load(SOURCE / source)
        piece = x[int(a * RATE):int(b * RATE)]
        write(OUT / source.replace("-", "_"), fade(piece * PEAK / np.abs(piece).max(), 0.01, 0.12))
    soft = load(SOURCE / "soft-drawer.wav")
    found = takes(SOURCE / "soft-drawer.wav")
    if len(found) != 5: raise SystemExit("soft-drawer: %d takes found, 5 expected" % len(found))
    cut = [soft[a:b] for a, b in found]
    gain = PEAK / max(np.abs(c).max() for c in cut)
    for index, piece in enumerate(cut):
        write(OUT / ("soft_drawer_%d.wav" % (index + 1)), fade(piece * gain, 0.01, 0.12))
    box = load(SOURCE / "box.wav")[int(0.12 * RATE):]
    write(OUT / "box.wav", fade(box * PEAK / np.abs(box).max(), 0.01, 0.12))


if __name__ == "__main__":
    main()
