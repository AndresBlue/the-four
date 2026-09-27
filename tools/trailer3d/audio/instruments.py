"""The trailer's instruments and sound effects, synthesized (dsp.py).
Each function returns a mono or stereo float signal at dsp.SR that starts at
its onset. `rng` is a numpy Generator, so every sound is reproducible."""
import numpy as np

from dsp import (SR, adsr, bp, convolve, db, eq, exp_decay, fade, hp, impulse, lp, n_of, noise,
                 normalize, phase, saturate, saw, sine, stereo, sweep_filter, t_of)


def note_hz(name):
    """'A4', 'C#5', 'Bb3' -> Hz (A4 = 440)."""
    names = {'C': -9, 'D': -7, 'E': -5, 'F': -4, 'G': -2, 'A': 0, 'B': 2}
    step = names[name[0]]
    rest = name[1:]
    if rest.startswith('#'): step += 1; rest = rest[1:]
    elif rest.startswith('b'): step -= 1; rest = rest[1:]
    octave = int(rest)
    return 440.0 * 2 ** ((step + (octave - 4) * 12) / 12)


# --- Tuned percussion -------------------------------------------------------------

def struck(freq, dur, partials, rng, click=0.3, detune_cents=3.0):
    """A struck metal voice: (ratio, amp, seconds to -60 dB) partials, two
    copies a few cents apart, and the click of the strike."""
    n = n_of(dur)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for sign in (-1, 1):
        f0 = freq * 2 ** (sign * detune_cents / 2400)
        for ratio, amp, decay in partials:
            out += amp * np.sin(2 * np.pi * f0 * ratio * t + rng.uniform(0, 6.28)) * 10 ** (-3 * t / decay)
    out *= 0.5
    if click:
        k = n_of(0.004)
        burst = hp(rng.standard_normal(k), 2500) * np.linspace(1, 0, k) ** 2 * click
        out[:k] += burst
    # A few milliseconds of attack, so nothing clicks at the start.
    a = n_of(0.0015)
    out[:a] *= np.linspace(0, 1, a)
    return out


def music_box(freq, rng, dur=2.6):
    """A comb tooth plucked: the fundamental, its bright bending modes (6.27x
    and 17.55x of a cantilever) that die at once, and a little body."""
    return struck(freq, dur, [(1.0, 1.0, 2.8), (2.0, 0.05, 1.1), (6.27, 0.16, 0.22), (17.55, 0.05, 0.07)], rng, click=0.12, detune_cents=4.0)


def chime(freq, rng, dur=3.2):
    """A vibraphone-like bar, for the public-address chime."""
    return struck(freq, dur, [(1.0, 1.0, 2.6), (3.98, 0.28, 0.7), (9.2, 0.06, 0.2)], rng, click=0.05, detune_cents=2.0)


def lift_ding(rng, freq=1318.5, dur=3.0):
    """A lift's arrival bell: one bright stroke with a bell's uneven partials."""
    return struck(freq, dur, [(1.0, 1.0, 2.4), (2.02, 0.32, 1.3), (2.74, 0.22, 0.9), (4.07, 0.1, 0.45), (0.5, 0.12, 1.6)], rng, click=0.2, detune_cents=5.0)


def pa_chime(rng):
    """Three descending tones before an announcement."""
    out = np.zeros(n_of(3.4))
    for k, name in enumerate(['G5', 'E5', 'C5']):
        tone = chime(note_hz(name), rng, 2.6) * (1.0 - 0.1 * k)
        at = n_of(0.34 * k)
        out[at:at + len(tone)] += tone[:len(out) - at]
    return out * 0.5


# --- Low end and impacts ------------------------------------------------------------

def sub_drop(rng, dur=2.5, start=95.0, end=34.0, fall=0.35, decay=1.8):
    n = n_of(dur)
    t = np.arange(n) / SR
    f = end + (start - end) * np.exp(-t / fall)
    x = np.sin(phase(f, n)) * 10 ** (-3 * t / decay)
    a = n_of(0.003)
    x[:a] *= np.linspace(0, 1, a)
    return x


def hit(rng, dur=4.0, metal=0.35, crack=0.5, sub=1.0, space=0.35):
    """A trailer impact: a falling sub, a body punch, a crack and struck metal,
    in a big room. Stereo."""
    n = n_of(dur)
    t = np.arange(n) / SR
    body = sub_drop(rng, dur, 110.0, 36.0, 0.25, 2.2) * sub
    k = n_of(0.12)
    punch = lp(rng.standard_normal(k), 220, 4) * np.exp(-np.arange(k) / n_of(0.03)) * 2.5
    body[:k] += punch
    c = n_of(0.05)
    body[:c] += hp(rng.standard_normal(c), 2500) * np.exp(-np.arange(c) / n_of(0.008)) * crack
    if metal:
        ring = np.zeros(n)
        for f in [187, 311, 463, 587, 829, 1123, 1579, 2203]:
            ring += rng.uniform(0.3, 1.0) * np.sin(2 * np.pi * f * rng.uniform(0.98, 1.02) * t) * 10 ** (-3 * t / rng.uniform(0.5, 2.4))
        body += bp(ring, 150, 3000) * metal * 0.25
    body = saturate(body, 1.6)
    ir = impulse(4.5, 3.2, rng, damping=3500, width=1.0)
    return convolve(body, ir, wet=space, dry=1.0)


def braam(rng, dur=5.0, root=36.71, chord=(1.0, 1.5, 2.0, 2.4, 3.0), open_to=2600.0, space=0.4):
    """The big brass-like blast: detuned saws on a minor chord whose filter
    snaps open and slowly closes, driven hard, with a sub under it. Stereo."""
    n = n_of(dur)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for ratio in chord:
        for det in (-0.007, -0.002, 0.004, 0.009):
            f = root * ratio * (1 + det)
            x += saw(f, n, rng, harmonics=int(min(70, 5000 // f))) / len(chord)
    cutoff = 140.0 + (open_to - 140.0) * (np.clip(t / 0.09, 0, 1) * np.exp(-np.maximum(t - 0.09, 0) / 1.4))
    x = sweep_filter(x, cutoff, 'lowpass', q=1.3)
    air = bp(rng.standard_normal(n), 250, 2200) * 0.08
    air = sweep_filter(air, cutoff, 'lowpass', q=0.8)
    x = saturate((x + air) * 1.6, 2.2)
    x += sub_drop(rng, dur, root * 1.3, root, 0.4, dur * 0.9) * 0.7
    env = adsr(n, a=0.03, d=0.4, s=0.75, r=dur * 0.55)
    x *= env
    ir = impulse(5.0, 3.6, rng, damping=3000, width=1.0)
    return convolve(x, ir, wet=space, dry=1.0)


def riser(rng, dur=4.0, lo=250.0, hi=7500.0):
    """Noise sweeping up, a Shepard glide under it and a tremolo that quickens,
    all growing to the end. Stereo."""
    n = n_of(dur)
    t = np.arange(n) / SR
    k = t / dur
    centre = lo * (hi / lo) ** (k ** 1.3)
    x = sweep_filter(noise(n, rng, 'pink'), centre, 'bandpass', q=2.2) * 1.5
    shep = np.zeros(n)
    for octave in range(7):
        f = 55.0 * 2 ** (octave + k)
        weight = np.exp(-0.5 * ((np.log2(f) - np.log2(440.0)) / 1.3) ** 2)
        shep += np.sin(phase(f, n)) * weight
    x += shep * 0.25
    trem = 0.6 + 0.4 * np.sin(phase(4.0 + 16.0 * k ** 2, n))
    x *= trem * k ** 2.2
    left = x
    right = np.roll(x, n_of(0.011))
    return np.stack([left, right], axis=1)


def reverse_swell(rng, dur=1.6):
    """A hit played backwards into the moment: the reverb comes first."""
    x = hit(rng, dur + 1.5, metal=0.5, crack=0.2, sub=0.4, space=0.8)[:n_of(dur)]
    return x[::-1] * np.linspace(0, 1, len(x))[:, None] ** 1.5


def whoosh(rng, dur=0.9, lo=300.0, hi=2600.0, pan_from=-0.6, pan_to=0.6):
    n = n_of(dur)
    t = np.arange(n) / SR
    k = t / dur
    env = np.exp(-0.5 * ((k - 0.55) / 0.18) ** 2)
    centre = lo + (hi - lo) * np.sin(np.pi * np.clip(k, 0, 1)) ** 2
    x = sweep_filter(noise(n, rng, 'pink'), centre, 'bandpass', q=1.4) * env
    pan = pan_from + (pan_to - pan_from) * k
    angle = (pan + 1) * np.pi / 4
    return np.stack([x * np.cos(angle), x * np.sin(angle)], axis=1) * 1.4


# --- Pads and pulses ---------------------------------------------------------------------

def strings(rng, dur, notes=('D3', 'Eb3', 'A3', 'D4'), tremolo=0.0, cutoff=1400.0, attack=1.5):
    """A cluster of bowed-like voices: many detuned saws, dark, slow to swell."""
    n = n_of(dur)
    x = np.zeros(n)
    t = np.arange(n) / SR
    for name in notes:
        f = note_hz(name)
        for det in (-0.004, 0.0, 0.005):
            vib = 1 + 0.0025 * np.sin(2 * np.pi * rng.uniform(4.6, 5.6) * t + rng.uniform(0, 6))
            x += saw(f * (1 + det) * vib, n, rng, harmonics=int(min(40, 4000 // f)))
    x = lp(x, cutoff, 2) / (len(notes) * 3)
    if tremolo: x *= 1 - tremolo * (0.5 + 0.5 * np.sin(2 * np.pi * 8.5 * t))
    x *= adsr(n, a=attack, d=0.5, s=1.0, r=min(2.0, dur * 0.3))
    ir = impulse(4.0, 2.8, rng, damping=4000)
    return convolve(x, ir, wet=0.45, dry=0.8)


def heartbeat(rng, strength=1.0):
    """Lub-dub: two soft low thumps."""
    n = n_of(0.7)
    out = np.zeros(n)
    for at, amp in ((0.0, 1.0), (0.26, 0.7)):
        k = n_of(0.18)
        tt = np.arange(k) / SR
        thump = np.sin(2 * np.pi * (48 + 30 * np.exp(-tt / 0.03)) * tt) * np.exp(-tt / 0.06)
        thump += lp(rng.standard_normal(k), 120) * np.exp(-tt / 0.02) * 0.4
        s = n_of(at)
        out[s:s + k] += thump * amp
    return out * strength


def clock_tick(rng, tock=False):
    k = n_of(0.08)
    tt = np.arange(k) / SR
    f = 1150 if tock else 1450
    x = np.sin(2 * np.pi * f * tt) * np.exp(-tt / 0.012)
    x += bp(rng.standard_normal(k), 2500, 6000) * np.exp(-tt / 0.004) * 0.6
    return x * 0.5


def kick(rng, depth=1.0):
    k = n_of(0.45)
    tt = np.arange(k) / SR
    f = 42 + 70 * np.exp(-tt / 0.035)
    x = np.sin(phase(f, k)) * np.exp(-tt / 0.18)
    x[:n_of(0.004)] += hp(rng.standard_normal(n_of(0.004)), 1500) * 0.3
    return saturate(x * depth, 1.4)


def tom(rng, freq=90.0):
    k = n_of(0.6)
    tt = np.arange(k) / SR
    x = np.sin(phase(freq * (1 + 0.5 * np.exp(-tt / 0.05)), k)) * np.exp(-tt / 0.25)
    x += bp(rng.standard_normal(k), 200, 1200) * np.exp(-tt / 0.04) * 0.3
    return x


def metal_hit(rng, dur=1.4):
    n = n_of(dur)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for f in [523, 787, 1111, 1497, 2011, 2769, 3301]:
        x += rng.uniform(0.3, 1) * np.sin(2 * np.pi * f * rng.uniform(0.97, 1.03) * t) * 10 ** (-3 * t / rng.uniform(0.2, 1.1))
    x[:n_of(0.003)] += rng.standard_normal(n_of(0.003))
    return hp(x, 300) * 0.2


# --- Foley ------------------------------------------------------------------------------------

def footstep(rng, weight=1.0, carpet=True):
    """A shoe on carpet: a dull heel thump and a short scuff."""
    k = n_of(0.22)
    tt = np.arange(k) / SR
    thump = lp(rng.standard_normal(k), 180 if carpet else 400, 2) * np.exp(-tt / 0.03) * 2.2
    thump += np.sin(2 * np.pi * rng.uniform(60, 80) * tt) * np.exp(-tt / 0.025) * 0.5
    scuff = bp(rng.standard_normal(k), 700, 2600) * np.exp(-np.maximum(tt - 0.015, 0) / 0.035) * (tt > 0.015) * 0.18
    return (thump + scuff) * weight


def claw_step(rng, weight=1.0):
    """The creature's pointed foot: a hard tap over a hollow knock."""
    k = n_of(0.25)
    tt = np.arange(k) / SR
    tap = hp(rng.standard_normal(k), 1800) * np.exp(-tt / 0.004) * 0.9
    knock = bp(rng.standard_normal(k), 350, 900) * np.exp(-tt / 0.05) * 1.2
    knock += np.sin(2 * np.pi * rng.uniform(140, 190) * tt) * np.exp(-tt / 0.06) * 0.5
    return (tap + knock) * weight


def creak(rng, dur=0.9, base=22.0, spread=12.0, bright=1.0):
    """Wood under load: stick-slip pulses through the wood's resonances."""
    n = n_of(dur)
    t = np.arange(n) / SR
    rate = base + spread * (0.5 + 0.5 * np.sin(2 * np.pi * rng.uniform(0.6, 1.4) * t + rng.uniform(0, 6)))
    rate *= 1 + 0.3 * np.cumsum(rng.standard_normal(n)) / np.sqrt(n) / 3
    ph = np.cumsum(rate) / SR
    pulses = np.diff(np.floor(ph), prepend=0.0)
    pulses *= rng.uniform(0.5, 1.0, n)
    body = np.zeros(n)
    for f, q in ((520, 9.0), (1210, 12.0), (2480, 14.0 * bright)):
        body += eq(pulses, 'peak', f, q, 18.0) - pulses
    body = bp(body, 300, 5000)
    env = adsr(n, a=0.05, d=0.1, s=1.0, r=dur * 0.4)
    return normalize(body * env, 0.8)


def wood_close(rng, soft=1.0):
    """A wardrobe leaf pulled to: a hollow knock and the latch."""
    k = n_of(0.5)
    tt = np.arange(k) / SR
    knock = bp(rng.standard_normal(k), 140, 700) * np.exp(-tt / 0.07) * 1.4
    knock += np.sin(2 * np.pi * 110 * tt) * np.exp(-tt / 0.05) * 0.6
    latch = np.zeros(k)
    at = n_of(0.03)
    c = n_of(0.01)
    latch[at:at + c] = hp(rng.standard_normal(c), 2500) * np.exp(-np.arange(c) / n_of(0.002)) * 0.7
    return (knock + latch) * soft


def breath(rng, dur=3.0, rate=0.9, strength=1.0, panicked=False):
    """Human breathing through the mouth: shaped, formant-filtered noise."""
    n = n_of(dur)
    t = np.arange(n) / SR
    air = bp(rng.standard_normal(n), 500, 2800) + 0.4 * bp(rng.standard_normal(n), 1200, 1800)
    cycle = np.sin(2 * np.pi * rate * t) * 0.5 + 0.5
    shape = np.where(np.sin(2 * np.pi * rate * t) > 0, cycle ** 1.5, cycle ** 3 * 0.6)
    if panicked: shape *= 0.8 + 0.2 * np.sin(2 * np.pi * 11 * t)
    return air * shape * 0.3 * strength


def paper(rng, dur=0.7):
    n = n_of(dur)
    t = np.arange(n) / SR
    crackle = hp(rng.standard_normal(n), 1500) * (rng.uniform(0, 1, n) > 0.96) * 2.0
    rustle = bp(rng.standard_normal(n), 1200, 6000) * 0.25
    env = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 0.7
    return (crackle + rustle) * env * 0.5


def pencil(rng, dur=1.4):
    """Graphite scratching on paper: bursts of bright noise in strokes."""
    n = n_of(dur)
    t = np.arange(n) / SR
    strokes = 0.5 + 0.5 * np.sin(2 * np.pi * 3.2 * t + np.cumsum(rng.standard_normal(n)) * 0.002)
    grain = bp(rng.standard_normal(n), 2500, 9000) * (0.7 + 0.3 * rng.uniform(0, 1, n))
    return grain * strokes ** 2 * 0.25


# --- Machines and electricity -------------------------------------------------------------------

def vcr_clunk(rng):
    """The deck taking the tape: a mechanism and its thump."""
    n = n_of(1.4)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for at, f, amp in ((0.0, 900, 0.5), (0.05, 400, 0.8), (0.18, 250, 1.0)):
        k = n_of(0.12)
        tt = np.arange(k) / SR
        s = n_of(at)
        x[s:s + k] += bp(rng.standard_normal(k), f * 0.6, f * 1.6) * np.exp(-tt / 0.02) * amp
    return x


def tv_on(rng):
    """A CRT coming on: the thump of the tube and the whine climbing."""
    n = n_of(1.6)
    t = np.arange(n) / SR
    thump = sub_drop(rng, 1.6, 70, 40, 0.1, 0.4) * 0.8
    k = n_of(0.02)
    thump[:k] += hp(rng.standard_normal(k), 1000) * np.exp(-np.arange(k) / n_of(0.004))
    whine = np.sin(phase(15734 * 0.5 * (1 + 0.02 * np.exp(-t / 0.2)), n)) * 0.03 * np.clip(t / 0.3, 0, 1)
    return thump + whine


def power_cut(rng):
    """The power going: a heavy relay thunk and the hum dying under it."""
    n = n_of(2.0)
    t = np.arange(n) / SR
    thunk = sub_drop(rng, 2.0, 80, 30, 0.08, 0.6) * 1.2
    k = n_of(0.03)
    thunk[:k] += bp(rng.standard_normal(k), 300, 3000) * np.exp(-np.arange(k) / n_of(0.006)) * 1.5
    hum = np.zeros(n)
    f = 100 * np.exp(-t / 0.4) + 20
    for h in (1, 2, 3):
        hum += np.sin(phase(f * h, n)) / h
    hum *= np.exp(-t / 0.35) * 0.3
    return thunk + hum


def power_down(rng, dur=1.2):
    n = n_of(dur)
    t = np.arange(n) / SR
    f = 30 + 260 * np.exp(-t / 0.25)
    x = lp(saw(f, n, rng, harmonics=25), 1500) * np.exp(-t / 0.5) * 0.5
    return x


def zoom_motor(rng, dur=0.9):
    n = n_of(dur)
    t = np.arange(n) / SR
    whine = sine(3150 + 80 * np.sin(2 * np.pi * 3 * t), n) * 0.5 + sine(6300, n) * 0.15
    gear = 0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 42 * t))
    env = np.clip(t / 0.05, 0, 1) * np.clip((dur - t) / 0.05, 0, 1)
    return whine * gear * env * 0.12


def glitch(rng, dur=0.45):
    """The tape tearing: stutters of static, a buzz, a pitch collapse."""
    n = n_of(dur)
    t = np.arange(n) / SR
    buzz = np.sign(np.sin(2 * np.pi * 60 * t)) * 0.4 + np.sign(np.sin(2 * np.pi * 1210 * t)) * 0.15
    hiss = rng.standard_normal(n) * 0.8
    gate = (np.floor(t * rng.uniform(28, 40)) % 3 != 1).astype(float)
    crush = np.round((buzz + hiss) * 5) / 5
    x = (crush * gate) * np.exp(-t / (dur * 0.6))
    return hp(x, 200) * 0.6


def sonar_click(rng):
    """The creature's click, as it hears it."""
    k = n_of(0.03)
    tt = np.arange(k) / SR
    x = np.sin(2 * np.pi * 3600 * tt) * np.exp(-tt / 0.003) + hp(rng.standard_normal(k), 3000) * np.exp(-tt / 0.002) * 0.6
    return x


def screech(rng, dur=1.8, low=180.0, high=620.0):
    """A creature's shriek, built: a harsh voiced glide through open vowel
    formants, insect rattle under it, a sub. Mono."""
    n = n_of(dur)
    t = np.arange(n) / SR
    k = t / dur
    contour = low + (high - low) * np.clip(k / 0.25, 0, 1) - (high - low) * 0.35 * np.clip((k - 0.6) / 0.4, 0, 1)
    jitter = 1 + 0.02 * np.sin(2 * np.pi * 23 * t) + 0.015 * rng.standard_normal(n).cumsum() / np.sqrt(n)
    src = saw(contour * jitter, n, rng, harmonics=40)
    voice = np.zeros(n)
    for f, q, g in ((820, 5.0, 1.0), (1240, 6.0, 0.8), (2900, 7.0, 0.5), (3600, 8.0, 0.3)):
        voice += eq(src, 'peak', f, q, 20.0) * g
    rattle = bp(rng.standard_normal(n), 2500, 7000) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 57 * t)))
    x = saturate(voice * 0.25 + rattle * 0.35, 2.5)
    x *= adsr(n, a=0.02, d=0.2, s=0.8, r=dur * 0.45)
    x += sub_drop(rng, dur, 70, 40, 0.3, 1.2) * 0.3
    return hp(x, 60)


# --- The archive's motif and machines (tools/trailer3d) ------------------------------------

## The four's motif, falling: B flat, G, E flat, and the fourth, C, below
## them, that turns the three into something darker. Only the title ever
## plays the fourth.
MOTIF = ('Bb4', 'G4', 'Eb4', 'C4')


def motif_note(k, rng, dur=5.0):
    """Note k (0..3) of the motif: a struck bar, a music box's brightness on
    top and a low body an octave down."""
    f = note_hz(MOTIF[k])
    bar = struck(f, dur, [(1.0, 1.0, 4.5), (2.0, 0.16, 2.0), (3.0, 0.07, 1.2), (4.2, 0.09, 0.6), (6.27, 0.06, 0.25)], rng, click=0.08, detune_cents=6.0)
    body = struck(f / 2, dur, [(1.0, 0.6, 3.5), (2.0, 0.18, 1.5)], rng, click=0.0, detune_cents=3.0)
    return bar + body * 0.5


def tape_hiss(n, rng):
    """A cassette dub's hiss: bright, soft, never quite steady."""
    x = hp(noise(n, rng, 'pink'), 2400)
    x = lp(x, 12000)
    t = np.arange(n) / SR
    return x * (0.85 + 0.15 * np.sin(2 * np.pi * 0.37 * t + rng.uniform(0, 6)))


def key_beep(rng, freq=1900.0, dur=0.035):
    """A keypad's key: a short square-ish tone off a piezo."""
    n = n_of(dur + 0.01)
    t = np.arange(n) / SR
    x = np.tanh(3.0 * np.sin(2 * np.pi * freq * t)) * 0.4
    env = np.clip(t / 0.002, 0, 1) * np.clip((dur - t) / 0.004, 0, 1)
    return x * env


def relay(rng, strength=1.0):
    """A lamp's relay: the click of the contact and the thump behind it."""
    k = n_of(0.25)
    tt = np.arange(k) / SR
    click = hp(rng.standard_normal(k), 2000) * np.exp(-tt / 0.003) * 0.8
    thump = np.sin(2 * np.pi * 95 * tt) * np.exp(-tt / 0.03) * 0.5
    ring = np.sin(2 * np.pi * 2300 * tt) * np.exp(-tt / 0.02) * 0.08
    return (click + thump + ring) * strength


def lamp_hum(rng, dur, freq=100.0):
    """A lamp on the mains: its buzz, the harmonics a little rough."""
    n = n_of(dur)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for h, a in ((1, 1.0), (2, 0.5), (3, 0.35), (5, 0.18), (7, 0.1)):
        x += a * np.sin(2 * np.pi * freq * h * t + rng.uniform(0, 6))
    x += bp(rng.standard_normal(n), 900, 3000) * 0.05
    return x * 0.2


def rewind(rng, dur=0.3):
    """A tape rewinding through the heads: a whine climbing, the picture's
    sound garbled into chirps, the motor under it."""
    n = n_of(dur)
    t = np.arange(n) / SR
    k = t / dur
    whine = np.sin(phase(2200 + 2400 * k, n)) * 0.12
    chirps = bp(rng.standard_normal(n), 1500, 7000) * (0.5 + 0.5 * np.sign(np.sin(phase(30 + 70 * k, n))))
    motor = lp(saw(110 + 70 * k, n, rng, harmonics=20), 900) * 0.25
    env = np.clip(t / 0.015, 0, 1) * np.clip((dur - t) / 0.02, 0, 1)
    return (whine + chirps * 0.3 + motor) * env


def tear(rng, dur=0.6):
    """The picture tearing: a rip of static through a buzz, falling apart."""
    n = n_of(dur)
    t = np.arange(n) / SR
    rip = bp(rng.standard_normal(n), 700, 7000) * (rng.uniform(0, 1, n) > 0.25)
    rip *= 0.6 + 0.4 * np.sign(np.sin(2 * np.pi * rng.uniform(18, 26) * t))
    buzz = np.sign(np.sin(2 * np.pi * 60 * t)) * 0.25 + np.sign(np.sin(phase(900 - 700 * t / dur, n))) * 0.12
    env = np.clip(t / 0.01, 0, 1) * np.exp(-np.maximum(t - dur * 0.5, 0) / (dur * 0.2))
    return hp(rip * 0.5 + buzz, 120) * env


def bolt(rng):
    """A door's electric lock letting go: the solenoid's knock, the latch."""
    k = n_of(0.35)
    tt = np.arange(k) / SR
    knock = np.sin(2 * np.pi * 170 * tt) * np.exp(-tt / 0.04) * 0.7
    knock += bp(rng.standard_normal(k), 300, 1500) * np.exp(-tt / 0.025) * 0.6
    latch = np.zeros(k)
    at = n_of(0.05)
    c = n_of(0.05)
    tc = np.arange(c) / SR
    latch[at:at + c] = (hp(rng.standard_normal(c), 2500) * np.exp(-tc / 0.004) * 0.6 + np.sin(2 * np.pi * 1350 * tc) * np.exp(-tc / 0.02) * 0.2)
    return knock + latch


def lift_doors(rng, dur=0.95):
    """A lift car's doors running shut: the roller and the motor, then the
    leaves meeting."""
    n = n_of(dur + 0.6)
    t = np.arange(n) / SR
    run = (t < dur).astype(float)
    slide = lp(rng.standard_normal(n), 500) * 0.5 + np.sin(2 * np.pi * 88 * t) * 0.1 + bp(rng.standard_normal(n), 800, 1600) * 0.06
    slide *= run * np.clip(t / 0.08, 0, 1) * (1 - 0.5 * np.clip((t - dur * 0.6) / (dur * 0.4), 0, 1))
    x = slide
    s = n_of(dur)
    k = n - s
    tk = np.arange(k) / SR
    clack = hp(rng.standard_normal(k), 1200) * np.exp(-tk / 0.006) * 1.2
    clack += np.sin(2 * np.pi * 240 * tk) * np.exp(-tk / 0.07) * 0.8
    clack += np.sin(2 * np.pi * 610 * tk) * np.exp(-tk / 0.12) * 0.25
    x[s:] += clack
    return x


def lift_motor(rng, dur=1.5):
    """The car setting off: the brake lifting, the motor's hum and the shaft."""
    n = n_of(dur)
    t = np.arange(n) / SR
    hum = np.zeros(n)
    for h, a in ((1, 1.0), (2, 0.45), (3, 0.25), (4, 0.12)):
        hum += a * np.sin(2 * np.pi * 50 * h * t)
    rumble = lp(rng.standard_normal(n), 90) * 1.2
    x = (hum * 0.3 + rumble) * np.clip(t / 0.25, 0, 1)
    k = n_of(0.2)
    tk = np.arange(k) / SR
    x[:k] += (np.sin(2 * np.pi * 70 * tk) * np.exp(-tk / 0.05) + hp(rng.standard_normal(k), 1500) * np.exp(-tk / 0.004) * 0.5) * 0.8
    return x


def data_burst(rng, dur=0.2):
    """Corrupt data read off a tape: crushed, held, chirping."""
    n = n_of(dur)
    t = np.arange(n) / SR
    held = np.repeat(rng.standard_normal(n // 12 + 1), 12)[:n]
    crushed = np.round(held * 2.0) / 2.0
    chirp = np.zeros(n)
    step = n_of(0.018)
    for s in range(0, n, step):
        f = rng.uniform(700, 4200)
        e = min(n, s + step)
        chirp[s:e] = np.sign(np.sin(2 * np.pi * f * t[s:e]))
    env = np.clip(t / 0.004, 0, 1) * np.clip((dur - t) / 0.01, 0, 1)
    return hp(crushed * 0.35 + chirp * 0.2, 200) * env


def cassette_slide(rng, dur=0.45):
    """A cassette pushed into a deck's slot: plastic on the flap and the guides."""
    n = n_of(dur)
    t = np.arange(n) / SR
    rub = bp(rng.standard_normal(n), 900, 5000) * (0.4 + 0.6 * rng.uniform(0, 1, n) ** 3)
    env = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 0.8
    flap = np.zeros(n)
    k = n_of(0.03)
    flap[:k] = bp(rng.standard_normal(k), 400, 2500) * np.exp(-np.arange(k) / n_of(0.006)) * 0.8
    return rub * env * 0.25 + flap


def tick(rng, strength=1.0):
    """A character generator's letter going down: barely a tick."""
    k = n_of(0.012)
    tt = np.arange(k) / SR
    return hp(rng.standard_normal(k), 3500) * np.exp(-tt / 0.0015) * 0.3 * strength

