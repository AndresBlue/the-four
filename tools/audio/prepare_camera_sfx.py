"""Working copies of the survivor's kit: the torch's switch and the camcorder's
zoom motor, cut from the author's two recordings in sfx/ into
assets/audio/sfx/flashlight/ and assets/audio/sfx/camera/. The originals are
never touched.

  sfx/flashlight/on-off-x3.ogg   "Flashlight Clicking On and Off",
                                 deleted_user_7146007, Freesound 383659, CC0:
                                 the switch on, then off, three times over.
                                 -> on_1..3.wav, off_1..3.wav
  sfx/cam/zoom-in-and-out.mp3    "camera lens zooming", CorneRoose,
                                 Freesound 654182, CC0: the motor zooming in,
                                 a pause, and zooming out.
                                 -> zoom_in.wav, zoom_out.wav

The clicks are found by their transients: each is a press and a release a
tenth of a second apart, taken together as one click, from just before the
first to where the second has rung out. The motor's two runs are the two long
stretches loud above the rest, each from its start (the motor kicking in) to
where it stops. Each set is brought to one peak as a whole, so the clicks keep
the little differences in loudness they were recorded with. Mono, 44.1 kHz,
16 bit, faded at both ends.

Deterministic: re-running reproduces the same files.

    python tools/audio/prepare_camera_sfx.py
"""
from pathlib import Path
import subprocess
import sys
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/trailer3d/audio"))
from dsp import ffmpeg  # noqa: E402

RATE = 44100
PEAK = 10 ** (-3.0 / 20)
TORCH = ROOT / "sfx/flashlight/on-off-x3.ogg"
ZOOM = ROOT / "sfx/cam/zoom-in-and-out.mp3"
TORCH_OUT = ROOT / "assets/audio/sfx/flashlight"
ZOOM_OUT = ROOT / "assets/audio/sfx/camera"


def load(path):
    raw = subprocess.run([ffmpeg(), "-v", "error", "-i", str(path), "-f", "f32le", "-ac", "1", "-ar", str(RATE), "-"], capture_output=True, check=True).stdout
    x = np.frombuffer(raw, np.float32).astype(np.float64)
    return x - x.mean()


def envelope(x, hop_s):
    hop = int(hop_s * RATE)
    frames = len(x) // hop
    return np.array([np.sqrt(np.mean(x[i * hop:(i + 1) * hop] ** 2)) for i in range(frames)]), hop


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


def clicks(x):
    """The six clicks: [start, end] in samples, in the order they were made."""
    env, hop = envelope(x, 0.002)
    loud = env > env.max() * 10 ** (-20 / 20)
    hits = []
    for i in range(1, len(loud)):
        if loud[i] and not loud[i - 1]: hits.append(i * hop)
    # A press and its release, a tenth of a second apart, are one click.
    groups = []
    for hit in hits:
        if groups and hit - groups[-1][-1] < int(0.2 * RATE): groups[-1].append(hit)
        else: groups.append([hit])
    return [(max(0, g[0] - int(0.012 * RATE)), min(len(x), g[-1] + int(0.14 * RATE))) for g in groups]


def runs(x):
    """The motor's runs: the stretches over a second long loud above the pauses."""
    env, hop = envelope(x, 0.01)
    # Over the quiet between them (the motor takes up most of the recording:
    # its median is the motor itself).
    loud = env > np.percentile(env, 15) * 10 ** (8 / 20)
    found = []
    start = None
    for i, on in enumerate(list(loud) + [False]):
        if on and start is None: start = i
        elif not on and start is not None:
            if (i - start) * hop > RATE: found.append((max(0, start * hop - int(0.03 * RATE)), min(len(x), i * hop + int(0.06 * RATE))))
            start = None
    return found


def main():
    x = load(TORCH)
    found = clicks(x)
    if len(found) != 6: raise SystemExit("on-off-x3: %d clicks found, 6 expected" % len(found))
    cut = [x[a:b] for a, b in found]
    gain = PEAK / max(np.abs(c).max() for c in cut)
    for index, piece in enumerate(cut):
        name = ("on_%d.wav" if index % 2 == 0 else "off_%d.wav") % (index // 2 + 1)
        write(TORCH_OUT / name, fade(piece * gain, 0.002, 0.05))
        print("%-10s %.3f-%.3f s, %3.0f ms" % (name, found[index][0] / RATE, found[index][1] / RATE, len(piece) / RATE * 1000))
    z = load(ZOOM)
    motor = runs(z)
    if len(motor) != 2: raise SystemExit("zoom-in-and-out: %d runs found, 2 expected" % len(motor))
    cut = [z[a:b] for a, b in motor]
    gain = PEAK / max(np.abs(c).max() for c in cut)
    for name, (a, b), piece in zip(["zoom_in.wav", "zoom_out.wav"], motor, cut):
        write(ZOOM_OUT / name, fade(piece * gain, 0.005, 0.06))
        print("%-12s %.3f-%.3f s, %.2f s" % (name, a / RATE, b / RATE, len(piece) / RATE))


if __name__ == "__main__":
    main()
