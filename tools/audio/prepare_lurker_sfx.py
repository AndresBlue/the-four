"""The Lurker's warning and her shriek (spec_f2_mind 9.3), from animal
recordings in source_assets/oficinas/audio_criatura/ (outside git) into
assets/audio/sfx/lurker/. Nothing is synthesised and nothing is human: a
horse's breath, bones and knuckles cracking, a barn owl. The originals are
never touched.

  cue_0..2.wav  one wet exhalation, then two jaw clicks   (BigSoundBank CC0; Pixabay)
  scare_0..1.wav  her shriek                              (BigSoundBank CC0)

Each horse breath is a single exhalation of about 0.7 s, so each is taken
whole from its first sound: copies 0 and 2 share the first one, with other
clicks and another gap. The warning's window counts from when its sound
starts, so each cue must start at once: the script fails unless the first sample over -30 dBFS comes
within 20 ms. It prints the time from that onset to the first click.

Deterministic: re-running reproduces the same files.

    python tools/audio/prepare_lurker_sfx.py
"""
from pathlib import Path
import subprocess
import sys
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/trailer3d/audio"))
from dsp import ffmpeg  # noqa: E402

SOURCE = ROOT / "source_assets/oficinas/audio_criatura"
OUT = ROOT / "assets/audio/sfx/lurker"
RATE = 44100
BREATHS = ["breath_horse_bsb/bsb_0285_breath_of_a_horse_1.mp3", "breath_horse_bsb/bsb_1543_breath_horse_4.mp3"]
CLICKS = ["bone_celery_bsb/bsb_0596_bones_cracking_1.mp3", "bone_knuckles_crack/freesound_community-knuckles-cracking-98331.mp3"]
SHRIEKS = ["shriek_barn_owl_bsb/bsb_1400_barn_owl_1.mp3", "shriek_barn_owl_bsb/bsb_1403_barn_owl_2.mp3"]
## The breath's window, the first click's time, the second's gap per copy.
BREATH = 0.7
FIRST_CLICK = 0.72
SECOND_GAP = [0.18, 0.22, 0.26]
CLICK_BEFORE = 0.010
CLICK_AFTER = 0.070
CLICK_APART = 0.15
SHRIEK = 1.4
PEAK = 0.9
ONSET_DB = -30.0
ONSET_MOST = 0.020


def load(path):
    raw = subprocess.run([ffmpeg(), "-v", "error", "-i", str(path), "-f", "f32le", "-ac", "1", "-ar", str(RATE), "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).astype(np.float64)


def fade(x, fin, fout):
    x = x.copy()
    a = min(len(x), int(fin * RATE))
    b = min(len(x), int(fout * RATE))
    if a > 0:
        x[:a] *= np.linspace(0, 1, a)
    if b > 0:
        x[len(x) - b:] *= np.linspace(1, 0, b) ** 2
    return x


def rms(x):
    return float(np.sqrt(np.mean(x * x))) if len(x) else 0.0


def loudest_windows(sources, seconds, count, skip=0.1):
    """The `count` non-overlapping windows of highest RMS across the sources,
    each file's first `skip` s left out, in descending RMS: [(source, start)]."""
    size = int(seconds * RATE)
    hop = int(0.01 * RATE)
    found = []
    for k, x in enumerate(sources):
        for start in range(int(skip * RATE), len(x) - size, hop):
            found.append((rms(x[start:start + size]), k, start))
    found.sort(key=lambda f: (-f[0], f[1], f[2]))
    chosen = []
    for level, k, start in found:
        if all(k != c[1] or abs(start - c[2]) >= size for c in chosen):
            chosen.append((level, k, start))
        if len(chosen) == count:
            break
    return [(c[1], c[2]) for c in chosen]


def highpass(x, hz):
    """First-order high-pass, run forwards (deterministic, no extra library)."""
    rc = 1.0 / (2.0 * np.pi * hz)
    a = rc / (rc + 1.0 / RATE)
    y = np.zeros_like(x)
    for i in range(1, len(x)):
        y[i] = a * (y[i - 1] + x[i] - x[i - 1])
    return y


def click_cuts(sources):
    """Every source's clicks: high-passed at 2 kHz, enveloped over 2 ms, the
    strongest peaks at least CLICK_APART apart, cut around each peak."""
    cuts = []
    for x in sources:
        hp = highpass(x, 2000.0)
        env = np.convolve(np.abs(hp), np.ones(int(0.002 * RATE)) / int(0.002 * RATE), mode="same")
        order = np.argsort(-env)
        taken = []
        for i in order:
            if env[i] <= 0.0 or len(taken) >= 8:
                break
            if all(abs(int(i) - t) >= int(CLICK_APART * RATE) for t in taken):
                if i - int(CLICK_BEFORE * RATE) >= 0 and i + int(CLICK_AFTER * RATE) <= len(hp):
                    taken.append(int(i))
        for i in taken:
            cuts.append((float(env[i]), hp[i - int(CLICK_BEFORE * RATE):i + int(CLICK_AFTER * RATE)]))
    cuts.sort(key=lambda c: -c[0])
    return [fade(c[1], 0.002, 0.03) for c in cuts]


def from_first_sound(x, seconds):
    """From 2 ms before its first sound over -40 dB of its peak, at most `seconds`."""
    level = np.abs(x)
    loud = np.where(level > level.max() * 10 ** (-40 / 20))[0]
    start = max(0, loud[0] - int(0.002 * RATE))
    return x[start:start + int(seconds * RATE)]


def onset(x):
    level = np.abs(x)
    over = np.where(level > 10 ** (ONSET_DB / 20))[0]
    return over[0] / RATE if len(over) else float("inf")


def write(name, x):
    OUT.mkdir(parents=True, exist_ok=True)
    x = x / (np.max(np.abs(x)) or 1.0) * PEAK
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(np.round(np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())
    return x


def main():
    breaths = [from_first_sound(load(SOURCE / b), BREATH) for b in BREATHS]
    clicks = click_cuts([load(SOURCE / c) for c in CLICKS])
    if len(clicks) < 6:
        sys.exit("only %d clicks found" % len(clicks))
    bad = False
    for v in range(3):
        breath = fade(breaths[v % len(breaths)], 0.003, 0.12)
        second = FIRST_CLICK + SECOND_GAP[v]
        cue = np.zeros(int((second + CLICK_AFTER + CLICK_BEFORE + 0.1) * RATE))
        cue[:len(breath)] += breath / (np.max(np.abs(breath)) or 1.0)
        for at, click in [(FIRST_CLICK, clicks[2 * v]), (second, clicks[2 * v + 1])]:
            i = int((at - CLICK_BEFORE) * RATE)
            cue[i:i + len(click)] += click / (np.max(np.abs(click)) or 1.0) * 0.8
        cue = write("cue_%d.wav" % v, cue)
        first = onset(cue)
        print("cue_%d.wav     %.2f s, onset %.1f ms, first click %.3f s after it" % (v, len(cue) / RATE, first * 1000.0, FIRST_CLICK - first))
        if first > ONSET_MOST:
            bad = True
    for v, s in enumerate(SHRIEKS):
        x = load(SOURCE / s)
        (_, start), = loudest_windows([x], SHRIEK, 1, 0.0)
        cut = fade(x[start:start + int(SHRIEK * RATE)], 0.005, 0.3)
        cut = write("scare_%d.wav" % v, cut)
        print("scare_%d.wav   %.2f s" % (v, len(cut) / RATE))
    if bad:
        sys.exit("a cue starts later than %d ms" % int(ONSET_MOST * 1000))


if __name__ == "__main__":
    main()
