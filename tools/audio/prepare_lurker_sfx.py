"""The Lurker's warning and her shriek (spec_f2_mind 9.3), from animal
recordings in source_assets/oficinas/audio_criatura/ (outside git) into
assets/audio/sfx/lurker/. Nothing is synthesised and nothing is human: a
horse's breath, bones and knuckles cracking, a barn owl. The originals are
never touched.

  cue_0..2.wav  one wet exhalation, then two jaw clicks   (BigSoundBank CC0; Pixabay)
  cue_short_0..2.wav  the same, shorter, for windows under 1.2 s (Pesadilla's)
  scare_0..1.wav  her shriek                              (BigSoundBank CC0)

And her sounds on the floor (spec_f3_integration 3.1), all Pixabay but the
bite's bones (BigSoundBank CC0):

  tile_1..6, tile_creak_1..3, tile_grind, dust_1..2   the false ceiling
  metal_1..4, scrape_1, knock_1..8                    sheet metal, the ducts
  hard_1..8, drag_1..2, wood_1..8, wood_scratch_1..2  walls and floors
  presence.wav                                        a cow's breath, looped
  bite_1..2                                           bones and a knuckle

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
## The short warning, for a window under 1.2 s (Pesadilla's 0.9): the breath
## cut to this, its clicks right after, and the silence after them.
SHORT_BREATH = 0.5
SHORT_FIRST = 0.5
SHORT_GAP = [0.12, 0.14, 0.16]
SHORT_TAIL = 0.05
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


def run_ffmpeg(x, filters):
    """x through an ffmpeg audio filter chain, mono at RATE."""
    raw = subprocess.run([ffmpeg(), "-v", "error", "-f", "f32le", "-ar", str(RATE), "-ac", "1", "-i", "-", "-af", filters, "-f", "f32le", "-ac", "1", "-ar", str(RATE), "-"], input=x.astype(np.float32).tobytes(), capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).astype(np.float64)


def pitch(x, ratio):
    """Slower and lower by `ratio` (under 1), as a tape played slow."""
    return run_ffmpeg(x, "asetrate=%d,aresample=%d" % (int(round(RATE * ratio)), RATE))


def lowpass(x, hz):
    return run_ffmpeg(x, "lowpass=f=%d:p=2" % int(hz))


def onsets(x, count, gap, pre, post):
    """The `count` loudest peaks of the 5 ms envelope over -24 dB of its
    maximum, at least `gap` s apart, in time order, each cut from `pre` s
    before it to `post` s after."""
    size = int(0.005 * RATE)
    env = np.convolve(np.abs(x), np.ones(size) / size, mode="same")
    floor = env.max() * 10 ** (-24 / 20)
    peaks = [i for i in range(1, len(env) - 1) if env[i] >= floor and env[i] >= env[i - 1] and env[i] > env[i + 1]]
    peaks.sort(key=lambda i: (-env[i], i))
    taken = []
    for i in peaks:
        if all(abs(i - t) >= int(gap * RATE) for t in taken) and i - int(pre * RATE) >= 0 and i + int(post * RATE) <= len(x):
            taken.append(i)
        if len(taken) == count:
            break
    if len(taken) < count:
        sys.exit("only %d onsets of %d" % (len(taken), count))
    return [x[i - int(pre * RATE):i + int(post * RATE)] for i in sorted(taken)]


def mix(a, b, at, gain_db):
    """b laid over a from `at` s on, `gain_db` down."""
    i = int(at * RATE)
    out = np.zeros(max(len(a), i + len(b)))
    out[:len(a)] += a
    out[i:i + len(b)] += b * 10 ** (gain_db / 20)
    return out


def loop(x, seconds):
    """The end crossfaded into the start over `seconds`, so it repeats
    without a seam: the last `seconds` fade out over the first ones."""
    n = int(seconds * RATE)
    head = x[:n]
    body = x[n:].copy()
    ramp = np.linspace(0, 1, n)
    body[len(body) - n:] = body[len(body) - n:] * (1 - ramp) + head * ramp
    return body


def out(name, x, peak=0.7):
    """A floor sound: 4 ms in, 30 ms out, to `peak`."""
    x = fade(x, 0.004, 0.03)
    x = x / (np.max(np.abs(x)) or 1.0) * peak
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(np.round(np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())
    print("%-18s %.2f s" % (name, len(x) / RATE))


def sounds():
    OUT.mkdir(parents=True, exist_ok=True)
    src = lambda slug, name: load(SOURCE / slug / name)
    for k, cut in enumerate(onsets(src("ceiling_claws_cardboard_scratch", "freesound_community-scratching-on-box-40160.mp3"), 6, 0.15, 0.02, 0.22)):
        out("tile_%d.wav" % (k + 1), cut)
    rattle = src("tile_grid_metal_rattle", "freesound_community-air-conditioner-vent-metal-ring-clank-26871.mp3")
    for k, cut in enumerate(onsets(rattle, 3, 1.0, 0.03, 0.5)):
        out("tile_creak_%d.wav" % (k + 1), pitch(cut, 0.9))
    grind = src("tile_styrofoam_grind", "freesound_community-grinding-styrofoam-46849.mp3")
    (_, start), = loudest_windows([grind], 1.2, 1, 0.0)
    out("tile_grind.wav", grind[start:start + int(1.2 * RATE)])
    out("dust_1.wav", src("debris_sandfall", "freesound_community-sandfall5-83468.mp3"), 0.5)
    out("dust_2.wav", src("debris_gravel_dirt_small", "freesound_community-gravel-stone-dirt-debris-falling-small-1-3-36216.mp3")[:int(2.5 * RATE)], 0.5)
    nail = src("metal_fingernail_elevator_ceiling", "freesound_community-20131209_fingernail-on-elevator-ceiling_olympusls10_xy-87239.mp3")
    for k, cut in enumerate(onsets(nail[:int(1.8 * RATE)], 4, 0.12, 0.01, 0.18)):
        out("metal_%d.wav" % (k + 1), cut)
    out("scrape_1.wav", nail[len(nail) - int(0.9 * RATE):])
    for k, cut in enumerate(onsets(src("duct_impacts_metal_box", "freesound_community-duct-impacts-76170.mp3"), 6, 0.4, 0.02, 0.35)):
        out("knock_%d.wav" % (k + 1), pitch(cut, 0.85))
    out("knock_7.wav", pitch(src("duct_heater_vent_hits", "freesound_community-heater-vent-hit-lower-part-83044.mp3"), 0.8))
    out("knock_8.wav", pitch(src("duct_heater_vent_hits", "freesound_community-heater-vent-hit-higher-part-103305.mp3"), 0.8))
    for k, cut in enumerate(onsets(src("wall_claws_smooth_rock", "freesound_community-claws-on-smooth-rock-65642.mp3"), 8, 0.15, 0.01, 0.16)):
        out("hard_%d.wav" % (k + 1), cut)
    plaster = src("plaster_tool_scrape", "freesound_community-plaster-screaming-55526.mp3")
    for k, (_, start) in enumerate(sorted(loudest_windows([plaster], 0.7, 2, 0.0), key=lambda w: w[1])):
        out("drag_%d.wav" % (k + 1), pitch(lowpass(plaster[start:start + int(0.7 * RATE)], 5000), 0.9))
    for k, cut in enumerate(onsets(src("wood_claws_skittering_dog", "freesound_community-skittering-dog-33523.mp3"), 8, 0.15, 0.01, 0.16)):
        out("wood_%d.wav" % (k + 1), cut)
    nails = src("wood_fingernail_scratch", "freesound_community-scratching-with-fingernails-79478.mp3")
    for k, (_, start) in enumerate(sorted(loudest_windows([nails], 0.8, 2, 0.0), key=lambda w: w[1])):
        out("wood_scratch_%d.wav" % (k + 1), nails[start:start + int(0.8 * RATE)])
    cow = src("breath_cow_bodot", "freesound_community-breath-of-cow-78843.mp3")
    breath = lowpass(pitch(cow[int(10 * RATE):int(30.5 * RATE)], 0.85), 3500)
    breath = loop(breath[:int((20.0 + 0.5) * RATE)], 0.5)
    breath = breath / (np.max(np.abs(breath)) or 1.0) * 0.6
    with wave.open(str(OUT / "presence.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(np.round(np.clip(breath, -1, 1) * 32767).astype("<i2").tobytes())
    print("%-18s %.2f s (loop)" % ("presence.wav", len(breath) / RATE))
    # The fifth click of the knuckles, cut as the warning's clicks are.
    knuckles = click_cuts([src("bone_knuckles_crack", "freesound_community-knuckles-cracking-98331.mp3")])
    knuckle = knuckles[min(4, len(knuckles) - 1)]
    for k, name in enumerate(["bsb_1408_bones_cracking_2.mp3", "bsb_1409_bones_cracking_3.mp3"]):
        bones = pitch(src("bone_celery_bsb", name), 0.8)
        out("bite_%d.wav" % (k + 1), mix(bones, knuckle / (np.max(np.abs(knuckle)) or 1.0) * np.max(np.abs(bones)), 0.05, -6.0))


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
    for v in range(3):
        breath = fade(breaths[v % len(breaths)][:int(SHORT_BREATH * RATE)], 0.003, 0.1)
        second = SHORT_FIRST + SHORT_GAP[v]
        cue = np.zeros(int((second + CLICK_AFTER + CLICK_BEFORE + SHORT_TAIL) * RATE))
        cue[:len(breath)] += breath / (np.max(np.abs(breath)) or 1.0)
        for at, click in [(SHORT_FIRST, clicks[2 * v]), (second, clicks[2 * v + 1])]:
            i = int((at - CLICK_BEFORE) * RATE)
            cue[i:i + len(click)] += click / (np.max(np.abs(click)) or 1.0) * 0.8
        cue = write("cue_short_%d.wav" % v, cue)
        first = onset(cue)
        print("cue_short_%d.wav %.2f s, onset %.1f ms" % (v, len(cue) / RATE, first * 1000.0))
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
    sounds()


if __name__ == "__main__":
    main()
