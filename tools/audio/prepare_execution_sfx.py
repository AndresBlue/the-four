"""Working copies of the three recordings the execution uses, from the
originals in sfx/ into assets/audio/events/. The originals are never touched.

  execution_scream.wav  the grab      (Freesound 865842, EnclosureX_Studios, CC BY 4.0)
  execution_hit.wav     the blow      (Freesound 829590, Artninja, CC BY 4.0)
  execution_body.wav    the body down (the same recording, its second take)
  execution_static.ogg  the dead tape (Freesound 624412, nlux, CC0)

The impact recording holds three takes. The first is the blow, cut so that the
impact itself lands HIT_AT seconds in: that is the delay the arm has to travel
from a dot to covering the lens, so picture and sound land together. The
second, heavier and with a longer tail, is the body hitting the floor.

Deterministic: re-running reproduces the same files.

    python tools/audio/prepare_execution_sfx.py
"""
from pathlib import Path
import shutil
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "sfx"
OUT = ROOT / "assets/audio/events"
RATE = 44100
## Where the impact sits inside the finished clip: the whoosh comes first.
HIT_AT = 0.18
HIT_TAIL = 0.62


def read(path):
    with wave.open(str(path)) as w:
        channels, width, rate = w.getnchannels(), w.getsampwidth(), w.getframerate()
        raw = w.readframes(w.getnframes())
    if width == 2:
        data = np.frombuffer(raw, "<i2").astype(np.float64) / 32768.0
    elif width == 4:
        data = np.frombuffer(raw, "<i4").astype(np.float64) / 2147483648.0
    else:
        raise SystemExit("unsupported sample width: %d" % width)
    return data.reshape(-1, channels), rate


def resample(samples, rate):
    if rate == RATE:
        return samples
    count = int(round(len(samples) * RATE / rate))
    source = np.linspace(0.0, len(samples) - 1, count)
    return np.interp(source, np.arange(len(samples)), samples)


def write(name, samples, peak=0.95):
    OUT.mkdir(parents=True, exist_ok=True)
    samples = np.asarray(samples, dtype=np.float64)
    if samples.ndim == 1:
        samples = samples[:, None]
    samples = samples / (np.max(np.abs(samples)) or 1.0) * peak
    interleaved = samples.reshape(-1)
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(samples.shape[1])
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(np.clip(interleaved * 32767, -32768, 32767).astype("<i2").tobytes())
    print("wrote", name, f"{len(samples) / RATE:.2f} s", f"{samples.shape[1]} ch")


def scream():
    data, rate = read(SOURCE / "screamer/sound.wav")
    mono = resample(data.mean(axis=1), rate)
    write("execution_scream.wav", mono, peak=0.99)


def take(mono, rate, window, lead, tail):
    """The loudest moment inside `window` seconds, with `lead` before it."""
    span = mono[int(window[0] * rate):int(window[1] * rate)]
    landing = int(window[0] * rate) + int(np.argmax(np.abs(span)))
    start = max(0, landing - int(lead * rate))
    end = min(len(mono), landing + int(tail * rate))
    clip = resample(mono[start:end], rate)
    edge = int(0.003 * RATE)
    clip[:edge] *= np.linspace(0.0, 1.0, edge)
    clip[-edge:] *= np.linspace(1.0, 0.0, edge)
    return clip, (landing - start) / rate


def hit():
    data, rate = read(SOURCE / "hit/829590__artninja__custom_heavy_whoosh_punch_kick_thud_impact_sound_10022025.wav")
    mono = data.mean(axis=1)
    blow, at = take(mono, rate, (0.0, 1.2), HIT_AT, HIT_TAIL)
    print("impact at", round(at, 3), "s into the clip")
    write("execution_hit.wav", blow, peak=0.97)
    body, _ = take(mono, rate, (1.3, 2.6), 0.04, 0.95)
    write("execution_body.wav", body, peak=0.9)


def static():
    OUT.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(SOURCE / "static/noise.ogg", OUT / "execution_static.ogg")
    print("copied execution_static.ogg")


if __name__ == "__main__":
    scream()
    hit()
    static()
