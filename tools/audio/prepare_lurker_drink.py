"""The Lurker's shriek as she drinks a room's light (lurker_versus.md 8), made
from two recordings already in assets/: her own shriek (scare_1.wav, a barn
owl, BigSoundBank CC0) slowed to 0.72 of its speed, lower and longer, so it
is hers and not her fright; and the breaker's clunk (office/breaker.wav)
under its first instant, the light going. Nothing synthesised, nothing human.

  assets/audio/sfx/lurker/drink_0.wav

Deterministic: re-running reproduces the same file.

    python tools/audio/prepare_lurker_drink.py
"""
from pathlib import Path
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
SFX = ROOT / "assets/audio/sfx"
RATE = 44100
SPEED = 0.72
CLUNK_DB = -8.0
PEAK = 0.7


def load(path):
    with wave.open(str(path)) as w:
        assert w.getframerate() == RATE and w.getsampwidth() == 2
        x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float64) / 32768.0
        if w.getnchannels() == 2:
            x = x.reshape(-1, 2).mean(axis=1)
    return x


def slowed(x, speed):
    at = np.arange(0.0, len(x) - 1, speed)
    return np.interp(at, np.arange(len(x)), x)


def main():
    shriek = slowed(load(SFX / "lurker/scare_1.wav"), SPEED)
    clunk = load(SFX / "office/breaker.wav")[: int(0.6 * RATE)] * 10 ** (CLUNK_DB / 20.0)
    out = shriek.copy()
    out[: len(clunk)] += clunk[: len(out)]
    fade = int(0.08 * RATE)
    out[-fade:] *= np.linspace(1.0, 0.0, fade)
    out *= PEAK / max(1e-9, np.abs(out).max())
    with wave.open(str(SFX / "lurker/drink_0.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((np.clip(out, -1.0, 1.0) * 32767.0).astype(np.int16).tobytes())
    print("drink_0.wav   %.2f s" % (len(out) / RATE))


if __name__ == "__main__":
    main()
