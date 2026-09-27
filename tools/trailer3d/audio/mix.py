"""The trailer's sound: the archivist's voice, the score and the effects, laid
on the edit (timeline.json) at the marks each shot module exports (the
`export const` lines of web/shots/*.js), mixed and mastered to -14 LUFS, with
room under -1 dBTP for the encoder.

    python tools/trailer3d/audio/mix.py    -> evidence/trailer3d/audio/mix.wav (+ stems)

Everything is synthesized here (dsp.py, instruments.py) or is a sound this
project generated for the game (assets/audio/dread, intro, events), plus the
game's own three execution recordings. The voice is the one voice.mjs made."""
import json
import os
import re
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dsp
import instruments as ins
from dsp import SR, n_of

HERE = os.path.dirname(os.path.abspath(__file__))
TOOL = os.path.dirname(HERE)
ROOT = os.path.dirname(os.path.dirname(TOOL))
OUT = os.path.join(ROOT, 'evidence', 'trailer3d', 'audio')
ASSETS = os.path.join(ROOT, 'assets', 'audio')
with open(os.path.join(TOOL, 'timeline.json'), encoding='utf-8') as f:
    TIMELINE = json.load(f)
VOICE_DIR = os.path.join(ROOT, 'evidence', 'trailer3d', 'voice', TIMELINE['voice']['name'])
LENGTH_S = TIMELINE['shots'][-1]['end']
LENGTH = n_of(LENGTH_S)

# --- The edit ----------------------------------------------------------------------------

SHOTS = {s['id']: s for s in TIMELINE['shots']}
## The archive module films four shots, each with its own set of marks.
ARCHIVE = {'vcr': 'VCR', 'crt': 'CRT', 'database': 'DB', 'endtape': 'END'}
_marks = {}


def marks(shot):
    """The marks a shot's module exports, in seconds from the shot's start."""
    if shot not in _marks:
        module = SHOTS[shot]['module']
        with open(os.path.join(TOOL, 'web', 'shots', module + '.js'), encoding='utf-8') as f:
            src = f.read()
        found = {}
        for name, literal in re.findall(r'^export const (\w+) = (.+?);\s*$', src, re.M):
            found[name] = json.loads(re.sub(r'([{,]\s*)(\w+)\s*:', r'\1"\2":', literal))
        _marks[shot] = found[ARCHIVE[shot]] if shot in ARCHIVE else found
    return _marks[shot]


def start(shot): return SHOTS[shot]['start']
def end(shot): return SHOTS[shot]['end']


def at(shot, name, i=None):
    """A mark as a time on the edit: at('guest1', 'TURN', 1)."""
    v = marks(shot)[name]
    return start(shot) + (v if i is None else v[i])


class Track:
    def __init__(self, name):
        self.name = name
        self.buf = np.zeros((LENGTH, 2))

    def add(self, x, when, gain=0.0, pan=0.0):
        """x (mono or stereo) placed at `when` seconds, `gain` dB."""
        if x is None or when is None: return
        x = dsp.stereo(x, pan) if x.ndim == 1 else x
        s = n_of(when)
        if s < 0:
            x = x[-s:]
            s = 0
        e = min(LENGTH, s + len(x))
        if e <= s: return
        self.buf[s:e] += x[:e - s] * dsp.db(gain)


def asset(*parts):
    return dsp.load(os.path.join(ASSETS, *parts))


def loop_to(x, seconds):
    n = n_of(seconds)
    reps = int(np.ceil(n / len(x)))
    return np.tile(x, (reps,) + (1,) * (x.ndim - 1))[:n]


def span(x, a, b, fin=0.3, fout=0.5):
    """A loop cut to [a, b] seconds, with fades."""
    return dsp.fade(loop_to(x, b - a), fin, fout)


def cut(x, seconds, fout=0.02):
    """The first `seconds` of x, with a short fade out."""
    return dsp.fade(x[:n_of(seconds)], 0.0, fout)


# --- The voice -----------------------------------------------------------------------------

## Each line and where it starts on the edit. Lines that finish a thought over
## a cut run on across it; the rest sit inside their shot.
def voice_cues():
    return [
        ('tape', at('crt', 'TEXT') + 0.03),
        ('guests', start('reception') + 0.6),
        ('different', start('rewind') + 0.1),
        ('always', at('rewind', 'SUPER') - 0.3),
        ('ran', start('guest1') + 0.2),
        ('heard', at('guest1', 'CUT') + 0.15),
        ('door', at('guest2', 'BREAK', 1) + 0.1),
        ('hid', start('guest3') + 0.15),
        ('saw', at('guest3', 'CLOSE', 1) - 0.05),
        ('sighting', at('guest4', 'JERK') + 0.1),
        ('harmless', at('guest4', 'BLINK') + 0.15),
        ('occupant', at('occupant', 'FAIL') - 0.3),
        ('one_of', at('occupant', 'TEAR', 0) + 0.25),
        ('mapped', start('sheet') + 0.15),
        ('forgot', start('sheet') + 2.2),
        ('floors', start('database') + 0.1),
        ('recovered', start('database') + 1.9),
        ('end', start('endtape') + 0.3),
    ]


def trim(x, floor_db=-42.0):
    """The line without the silence the synthesizer leaves around it."""
    env = dsp.envelope_follow(x, 0.002, 0.03)
    loud = np.where(env > np.max(env) * dsp.db(floor_db))[0]
    if len(loud) == 0: return x
    a = max(0, loud[0] - n_of(0.012))
    b = min(len(x), loud[-1] + n_of(0.06))
    return dsp.fade(x[a:b], 0.004, 0.03)


def archivist(x, rng):
    """The archive's narrator: read, not acted, and heard off a cassette dub —
    dry, band-limited, a little wow and flutter, a little saturation."""
    x = dsp.normalize(trim(x), 0.5)
    x = dsp.hp(x, 100, 2)
    x = dsp.lp(x, 8500, 2)
    x = dsp.eq(x, 'lowshelf', 200, 0.7, 1.5)
    x = dsp.eq(x, 'peak', 3100, 0.9, 2.5)
    x = dsp.eq(x, 'peak', 480, 1.2, -2.0)
    x = dsp.compress(x, threshold=-24, ratio=3.0, attack=0.004, release=0.12, makeup=5.0)
    x = dsp.saturate(x * 1.3, 1.4) * 0.8
    x = dsp.wobble(x, depth_cents=5.0, rate=0.7, flutter_cents=2.5, flutter_rate=7.2, rng=rng)
    # Barely a room: the booth it was read in.
    booth = dsp.impulse(0.25, 0.12, rng, damping=6000, predelay=0.004, width=0.4)
    return dsp.convolve(x, booth, wet=0.06, dry=1.0)


def voice_track(rng):
    track = Track('voice')
    for ident, when in voice_cues():
        raw = dsp.load(os.path.join(VOICE_DIR, ident + '.wav'))
        track.add(archivist(raw, rng), when, 0.0)
    return track


# --- The score -------------------------------------------------------------------------------

def motif(k, rng, tape=True):
    """A note of the motif as the tape holds it: a slow waver on it."""
    x = ins.motif_note(k, rng)
    return dsp.wobble(x, depth_cents=9.0, rate=0.45, flutter_cents=3.0, rng=rng) if tape else x


def pulse(rng, a, b, bpm=108.0):
    """The climax's pulse, from the lunge to the blackout: a kick on the beat,
    a low E on the eighths, ticks on the sixteenths; denser and brighter as
    it goes, and nothing after b."""
    out = np.zeros((n_of(b - a) + n_of(1.0), 2))
    beat = 60.0 / bpm
    k = 0
    when = 0.0
    total = b - a
    while when < total - 0.02:
        rise = when / total
        s = n_of(when)
        if k % 4 == 0:
            kk = dsp.stereo(ins.kick(rng, 1.1 + 0.3 * rise))
            out[s:s + len(kk)] += kk[:len(out) - s] * 0.9
        if k % 2 == 0:
            f = ins.note_hz('E1') * (2 if (k // 2) % 4 == 3 else 1)
            n = n_of(beat * 0.45)
            bass = dsp.lp(ins.saw(np.full(n, f), n, rng, harmonics=24), 180 + 900 * rise)
            bass = dsp.fade(bass, 0.004, beat * 0.2) * 0.5
            out[s:s + n] += dsp.stereo(bass)[:len(out) - s]
        tk = ins.clock_tick(rng, tock=k % 2 == 1) * (0.35 + 0.5 * rise)
        out[s:s + len(tk)] += dsp.stereo(tk, 0.3 if k % 2 else -0.3)[:len(out) - s]
        when += beat / 4
        k += 1
    return out


def score(rng):
    music = Track('music')
    drone = asset('dread', 'dread_drone.wav')
    room = dsp.impulse(3.2, 2.2, rng, damping=3500, predelay=0.03)
    # The sectors: the motif's first three notes, one on each hit, each a
    # blow with the note ringing out of it.
    for k, h in enumerate(marks('sectors')['HITS']):
        when = start('sectors') + h
        music.add(dsp.convolve(motif(k, rng), room, wet=0.3, dry=1.0), when, -8.0)
        music.add(ins.hit(rng, 3.0, metal=0.25, crack=0.2, sub=1.0, space=0.45), when, -10.0)
        music.add(ins.sub_drop(rng, 2.2, 80, 32, 0.25, 1.6), when, -12.0)
    # Under the guests, from the first to the occupant's card: the drone,
    # swelling as they are lost one by one.
    a, b = start('guest1'), at('occupant', 'TEAR', 0)
    bed = span(drone, a, b, 1.5, 0.6)
    t = np.arange(len(bed)) / SR
    music.add(dsp.lp(bed * (0.55 + 0.45 * np.clip(t / (b - a), 0, 1)), 900), a, -15.0)
    # Before that, from the reception, something low and far.
    music.add(dsp.lp(span(drone, start('reception'), start('guest1'), 2.0, 1.0), 400), start('reception'), -20.0)
    # Tension under guest three and four.
    music.add(ins.strings(rng, 5.2, ('E2', 'B2', 'F3', 'C4'), tremolo=0.25, cutoff=1000, attack=2.2), start('guest3') + 0.2, -19.0)
    music.add(ins.strings(rng, 5.0, ('E2', 'C3', 'G3', 'Bb3'), tremolo=0.4, cutoff=1400, attack=1.6), start('guest4') + 0.1, -18.0)
    # The versus: low strings rising under the clicks into the shriek.
    music.add(ins.strings(rng, 3.2, ('E2', 'B2', 'F3', 'C4', 'F4'), tremolo=0.6, cutoff=2000, attack=1.4), start('versus'), -16.0)
    # The pulse: from the lunge through the sheet to the power going.
    pa, pb = at('versus', 'LUNGE'), at('blackout', 'POWER')
    music.add(pulse(rng, pa, pb), pa, -6.0)
    rise = ins.riser(rng, pb - pa - 0.4)
    music.add(dsp.fade(rise, 0.5, 0.0), pa + 0.4, -19.0)
    # The last set coming on: the motif's third note, once more.
    music.add(dsp.convolve(motif(2, rng), room, wet=0.3, dry=1.0), at('blackout', 'CLICK'), -10.0)
    # The chase: a blast as it turns; then nothing until the keypad.
    music.add(ins.braam(rng, 1.6, open_to=1800.0), at('chase', 'TURN') - 0.05, -13.0)
    # In the car, watching it: the low strings hold under the doors.
    music.add(ins.strings(rng, 2.6, ('E2', 'B2', 'C3', 'F3'), tremolo=0.2, cutoff=900, attack=0.8), at('keypad', 'TURNED') - 0.4, -18.0)
    # The database and the end of the tape: the drone, far down.
    music.add(dsp.lp(span(drone, start('database'), at('endtape', 'BLACK'), 1.0, 0.03), 380), start('database'), -16.0)
    # The title: three notes as the first three lamps come on; a breath; the
    # fourth, heard for the first time, with the fourth lamp.
    lamps = marks('title')['LAMPS']
    for k, h in enumerate(lamps):
        note = dsp.convolve(motif(k, rng, tape=False), room, wet=0.35, dry=1.0)
        music.add(note, start('title') + h, -8.0 if k < 3 else -6.0)
    music.add(ins.sub_drop(rng, 3.5, 60, 28, 0.4, 2.8), start('title') + lamps[3], -10.0)
    music.add(dsp.fade(ins.strings(rng, 3.2, ('C2', 'G2', 'E3', 'B3'), cutoff=900, attack=0.6), 0.2, 1.0), start('title') + lamps[3], -20.0)
    return music


# --- Effects -------------------------------------------------------------------------------

def effects(rng):
    fx = Track('effects')
    room = dsp.impulse(1.6, 0.8, rng, damping=5000, predelay=0.008)
    hall = dsp.impulse(3.0, 1.9, rng, damping=4000, predelay=0.02)
    wood = dsp.impulse(0.4, 0.2, rng, damping=3000, predelay=0.002)
    static = asset('intro', 'tv_static.wav')
    whine = asset('intro', 'tv_whine.wav')
    hum = asset('dread', 'fluorescent_hum.wav')
    chitter = [asset('dread', 'chitter_%d.wav' % i) for i in range(4)]
    breath = asset('dread', 'dread_breath.wav')
    riser = asset('dread', 'presence_riser.wav')
    knocks = [asset('intro', 'glass_knock_%d.wav' % i) for i in (1, 2, 3)]
    shatter = asset('intro', 'glass_shatter.wav')
    bangs = [asset('intro', 'door_bang_%d.wav' % i) for i in (1, 2, 3)]
    scream = asset('events', 'execution_scream.wav')
    arm_hit = asset('events', 'execution_hit.wav')
    dead = asset('events', 'execution_static.ogg')

    def in_room(x, wet=0.25): return dsp.convolve(x, room, wet=wet)
    def in_hall(x, wet=0.35): return dsp.convolve(x, hall, wet=wet)
    def far(x): return dsp.lp(in_hall(x, 0.7), 1800)

    # The tape under all of it; the room it plays in before the picture.
    hiss = ins.tape_hiss(LENGTH, rng)
    fx.add(dsp.fade(hiss, 0.3, 0.02), 0.0, -40.0)
    tone = dsp.lp(dsp.noise(n_of(start('crt') + 0.2), rng, 'pink'), 320)
    fx.add(dsp.fade(tone, 0.4, 0.2), 0.0, -30.0)
    fx.add(span(hum, 0.0, start('crt') + 0.2, 0.4, 0.2), 0.0, -40.0)

    # The deck: the cassette in, the mechanism, the drum spinning up.
    fx.add(ins.cassette_slide(rng, at('vcr', 'IN', 1) - at('vcr', 'IN', 0)), at('vcr', 'IN', 0), -9.0)
    fx.add(ins.vcr_clunk(rng), at('vcr', 'CLACK'), -1.0)
    # The set: the tube, the snow, the blue with PLAY, the letters.
    on = at('crt', 'ON')
    fx.add(ins.tv_on(rng), on, -8.0)
    snow_to = at('crt', 'HOLD')
    fx.add(dsp.fade(loop_to(static, snow_to - on), 0.02, 0.015), on + 0.03, -12.0)
    fx.add(span(whine, on, end('crt'), 0.1, 0.2), on, -34.0)
    fx.add(ins.relay(rng, 0.6), snow_to, -16.0)
    card = ['RECOVERED TAPE 81', 'THE HOTEL — FLOOR 1', 'GUESTS: 4', 'OCCUPANT: THE LOCUST']
    t0 = at('crt', 'TEXT')
    letters = sum(len(s) for s in card) + len(card)
    for i in range(0, letters, 2):
        fx.add(ins.tick(rng, 0.8), t0 + i / 72.0, -22.0)
    # Into the phosphor: the whine climbing, the snow rushing up.
    dive = at('crt', 'DIVE')
    fx.add(ins.reverse_swell(rng, 0.8), dive - 0.55, -12.0)
    fx.add(dsp.fade(loop_to(static, end('crt') - dive), 0.5, 0.02), dive, -16.0)

    # The reception: the big dark room; the beacon; the guests' feet; the door.
    a, b = start('reception'), end('reception')
    fx.add(dsp.lp(span(dsp.noise(n_of(3.0), rng, 'pink'), a, b, 0.05, 0.1), 250), a, -24.0)
    for k in range(4):
        fx.add(in_room(ins.footstep(rng, 0.35), 0.4), a + 0.35 + k * 0.52 + rng.uniform(-0.05, 0.05), -24.0, pan=rng.uniform(-0.5, 0.5))
    fx.add(far(bangs[0]), at('reception', 'CLACK'), -12.0, pan=0.35)

    # The rewinds: through three different hotels.
    for i, (p, q) in enumerate(marks('rewind')['REWINDS']):
        fx.add(ins.rewind(rng, q - p), start('rewind') + p, -12.0)
        fx.add(ins.glitch(rng, 0.12), start('rewind') + p, -18.0)
    for i, (p, q) in enumerate(marks('rewind')['PASSES']):
        pa, pb = start('rewind') + p, start('rewind') + q
        fx.add(span(hum, pa, pb, 0.03, 0.03), pa, -34.0 + i * 2)
        fx.add(dsp.lp(span(dsp.noise(n_of(2.0), rng, 'pink'), pa, pb, 0.03, 0.03), 300 + 200 * i), pa, -28.0)
    fx.add(ins.tick(rng), at('rewind', 'SUPER'), -20.0)

    # The sectors: what each hit shows sounds with it.
    h = [start('sectors') + x for x in marks('sectors')['HITS']]
    fx.add(ins.lamp_hum(rng, 0.9, 120.0) * dsp.fade(np.ones(n_of(0.9)), 0.005, 0.3), h[0], -26.0)
    fx.add(ins.tv_on(rng), h[1], -12.0)
    fx.add(dsp.fade(static[:n_of(1.0)], 0.01, 0.4), h[1] + 0.05, -16.0)
    fx.add(ins.paper(rng, 0.5), h[2], -16.0)

    # Guest one: running, and the one it heard first.
    g1 = start('guest1')
    stop = at('guest1', 'CUT')
    k = 0
    when = g1 + 0.05
    while when < stop - 0.05:
        fx.add(in_room(ins.footstep(rng, rng.uniform(0.8, 1.0))), when, -9.0, pan=rng.uniform(-0.1, 0.1))
        when += 0.29 + rng.uniform(-0.02, 0.02)
        k += 1
    fx.add(dsp.fade(ins.breath(rng, stop - g1, rate=2.4, strength=1.0, panicked=True), 0.1, 0.05), g1, -15.0)
    # Cut to it, still, back turned: only its lamp.
    fx.add(span(hum, stop, at('guest1', 'SNOW'), 0.02, 0.1), stop, -30.0)
    t1a, t1b = at('guest1', 'TURN', 0), at('guest1', 'TURN', 1)
    fx.add(in_hall(ins.creak(rng, t1b - t1a, 16, 8, 0.7), 0.3), t1a, -24.0)
    fx.add(in_hall(chitter[0], 0.4), t1b - 0.25, -16.0)
    fx.add(ins.reverse_swell(rng, 0.7), at('guest1', 'SCREAM') - 0.7, -14.0)
    fx.add(in_hall(ins.screech(rng, 1.1, 200, 660), 0.45), at('guest1', 'SCREAM'), -7.0)
    fx.add(ins.hit(rng, 2.0, metal=0.4, crack=0.4, sub=1.0, space=0.4), at('guest1', 'SCREAM'), -11.0)
    for k in range(4):
        fx.add(in_hall(ins.claw_step(rng, 1.1), 0.3), at('guest1', 'LAUNCH') + k * 0.12, -9.0)
    fx.add(ins.whoosh(rng, 0.4, 500, 3500, 0.0, 0.0), at('guest1', 'LAUNCH') + 0.1, -10.0)
    snow = at('guest1', 'SNOW')
    fx.add(dsp.fade(loop_to(static, end('guest1') - snow), 0.0, 0.03), snow, -10.0)

    # Guest two: the click and the set; the room where one is already on.
    click = at('guest2', 'CLICK')
    fx.add(ins.relay(rng, 0.9), click - 0.03, -14.0)
    fx.add(ins.tv_on(rng), click, -9.0)
    cut2 = at('guest2', 'CUT')
    fx.add(dsp.fade(loop_to(static, cut2 - click), 0.05, 0.02), click + 0.05, -20.0)
    b1, b2 = at('guest2', 'BREAK', 0), at('guest2', 'BREAK', 1)
    swell = loop_to(static, b1 - cut2)
    swell = swell * np.linspace(0.35, 1.0, len(swell))
    fx.add(dsp.fade(swell, 0.02, 0.01), cut2, -17.0)
    fx.add(ins.glitch(rng, b2 - b1), b1, -8.0)
    fx.add(dsp.fade(loop_to(static, end('guest2') - b2), 0.01, 0.1), b2, -22.0)
    fx.add(in_room(breath[:n_of(end('guest2') - b2)], 0.3), b2, -22.0)
    fx.add(in_room(chitter[1], 0.3), at('guest2', 'TURN', 0) + 0.1, -15.0)
    fx.add(ins.hit(rng, 1.8, metal=0.3, crack=0.2, sub=0.9, space=0.4), at('guest2', 'TURN', 1), -14.0)

    # Guest three: inside the wardrobe. Everything outside is muffled.
    def muffled(x): return dsp.lp(x, 900)
    g3 = start('guest3')
    fx.add(dsp.fade(ins.breath(rng, at('guest3', 'DOOR1') - g3, rate=0.8, strength=0.6), 0.3, 0.1), g3, -21.0)
    beat = 60 / 68
    when = g3 + 0.3
    while when < at('guest3', 'DOOR1') - 0.2:
        fx.add(ins.heartbeat(rng, 1.0), when, -15.0)
        when += beat * (1 - 0.25 * (when - g3) / 5.0)
    e0, e1 = at('guest3', 'ENTER', 0), at('guest3', 'ENTER', 1)
    fx.add(muffled(in_room(ins.creak(rng, 0.7, 26, 10))), e0, -16.0)
    for k in range(3):
        fx.add(muffled(in_room(ins.claw_step(rng, 0.9))), e0 + 0.15 + k * 0.33, -12.0)
    fx.add(muffled(in_room(chitter[2], 0.3)), at('guest3', 'TURN', 0) + 0.1, -12.0)
    c0, c1 = at('guest3', 'CLOSE', 0), at('guest3', 'CLOSE', 1)
    for k in range(3):
        fx.add(muffled(in_room(ins.claw_step(rng, 0.8))), c0 + k * 0.22, -12.0)
    fx.add(dsp.lp(breath[n_of(2.0):n_of(2.0 + at('guest3', 'DOOR1') - c1)], 1400), c1, -14.0)
    for key in ('DOOR1', 'DOOR2'):
        fx.add(in_room(ins.creak(rng, 0.25, 34, 16, 1.2), 0.2), at('guest3', key), -12.0)
        fx.add(dsp.fade(in_room(ins.wood_close(rng, 0.6)), 0.0, 0.1), at('guest3', key), -12.0)
    fx.add(dsp.convolve(ins.wood_close(rng, 1.0), wood, wet=0.3), at('guest3', 'BLACK') + 0.05, -6.0)

    # Guest four: the warm corridor; the zoom; the head that was not there.
    g4 = start('guest4')
    fx.add(span(hum, g4, end('guest4'), 0.2, 0.3), g4, -30.0)
    z0, z1 = at('guest4', 'ZOOM_IN', 0), at('guest4', 'ZOOM_IN', 1)
    fx.add(ins.zoom_motor(rng, z1 - z0), z0, -18.0)
    z0, z1 = at('guest4', 'ZOOM_OUT', 0), at('guest4', 'ZOOM_OUT', 1)
    fx.add(ins.zoom_motor(rng, z1 - z0), z0, -20.0)
    fx.add(ins.relay(rng, 0.5), at('guest4', 'TORCH'), -18.0)
    fx.add(dsp.lp(breath[:n_of(at('guest4', 'JERK') - g4 - 0.5)], 1200), g4 + 0.5, -26.0)
    fx.add(ins.glitch(rng, 0.3), at('guest4', 'JERK') - 0.03, -9.0)
    fx.add(dsp.fade(ins.hit(rng, 1.2, metal=0.5, crack=0.3, sub=0.8, space=0.4), 0.0, 0.5), at('guest4', 'JERK'), -17.0)
    fx.add(ins.reverse_swell(rng, 0.6), at('guest4', 'BLINK') - 0.6, -18.0)
    fx.add(ins.glitch(rng, 0.18), at('guest4', 'BLINK') - 0.02, -10.0)

    # The occupant's card: the letters, the picture failing, the tear.
    oc = start('occupant')
    for i in range(0, 60, 2):
        fx.add(ins.tick(rng, 0.7), oc + 0.1 + i / 72.0, -24.0)
    fx.add(ins.glitch(rng, 0.25), at('occupant', 'FAIL'), -12.0)
    fx.add(ins.tear(rng, at('occupant', 'TEAR', 1) - at('occupant', 'TEAR', 0) + 0.15), at('occupant', 'TEAR', 0), -8.0)

    # Versus: its clicks and what they find; the shriek; the lunge.
    for k, c in enumerate(marks('versus')['CLICKS']):
        when = start('versus') + c
        fx.add(dsp.delay(ins.sonar_click(rng), 0.07, 0.45, 0.45), when, -12.0, pan=rng.uniform(-0.15, 0.15))
        fx.add(in_hall(chitter[k % 4], 0.5), when + 0.02, -20.0)
    shriek = at('versus', 'SHRIEK')
    fx.add(ins.reverse_swell(rng, 0.5), shriek - 0.5, -14.0)
    fx.add(in_hall(ins.screech(rng, 1.8, 190, 640), 0.45), shriek, -10.0)
    fx.add(ins.hit(rng, 3.0, metal=0.5, crack=0.5, sub=1.1, space=0.5), shriek, -12.0)
    fx.add(ins.whoosh(rng, 0.45, 300, 3000, -0.2, 0.2), at('versus', 'LUNGE') - 0.1, -10.0)
    for k in range(4):
        fx.add(in_room(ins.claw_step(rng, 1.0)), at('versus', 'LUNGE') + k * 0.11, -12.0)

    # The sheet: the page, the pencils as they draw.
    sh = start('sheet')
    fx.add(ins.paper(rng, 0.6), sh + 0.02, -16.0)
    for a0, a1 in ((0.9, 1.4), (1.5, 1.9), (2.05, 2.55), (2.5, 3.0)):
        fx.add(ins.pencil(rng, a1 - a0), sh + a0, -15.0, pan=rng.uniform(-0.2, 0.2))

    # The blackout: the button, the last set; the power going; the torch.
    fx.add(ins.relay(rng, 1.0), at('blackout', 'CLICK') - 0.02, -10.0)
    fx.add(ins.tv_on(rng), at('blackout', 'CLICK'), -10.0)
    fx.add(dsp.fade(loop_to(static, at('blackout', 'CUT') - at('blackout', 'CLICK')), 0.05, 0.01), at('blackout', 'CLICK') + 0.05, -18.0)
    lit_a, lit_b = at('blackout', 'CUT'), at('blackout', 'POWER')
    fx.add(span(hum, lit_a, lit_b, 0.01, 0.005), lit_a, -24.0)
    fx.add(ins.power_cut(rng), at('blackout', 'POWER'), -2.0)
    fx.add(ins.hit(rng, 2.0, metal=0.2, crack=0.4, sub=1.0, space=0.3), at('blackout', 'POWER'), -8.0)
    fx.add(ins.relay(rng, 0.7), at('blackout', 'TORCH'), -14.0)
    # What is left: the sets hissing somewhere, far.
    fx.add(far(span(static, at('blackout', 'POWER') + 0.3, end('chase'), 0.6, 0.1)), at('blackout', 'POWER') + 0.3, -26.0)

    # The chase: it comes, low under the fire door; a door slams; it is on them.
    ch = start('chase')
    when = ch + 0.05
    while when < at('chase', 'SLAM') - 0.05:
        fx.add(in_hall(ins.claw_step(rng, 0.8 + 0.3 * (when - ch)), 0.3), when, -13.0)
        when += 0.13
    fx.add(in_hall(bangs[1], 0.25), at('chase', 'SLAM'), -7.0)
    fx.add(ins.whoosh(rng, 0.35, 400, 3200, 0.4, -0.4), at('chase', 'TURN') - 0.1, -9.0)
    fx.add(in_room(ins.screech(rng, 0.6, 300, 800), 0.2), at('chase', 'TURN') + 0.05, -13.0)
    fx.add(ins.hit(rng, 1.6, metal=0.9, crack=0.9, sub=1.0, space=0.3), at('chase', 'THRUST'), -10.0)

    # The execution: taken up; its breath; the arm held back too long; the blow.
    ex = start('execution')
    # The scream only as it takes them; then the held beat, nearly silent.
    fx.add(dsp.fade(scream[:n_of(1.05)], 0.0, 0.35), at('execution', 'LIFT') - 0.05, -12.0)
    fx.add(in_room(breath[n_of(4.0):n_of(4.0 + at('execution', 'HIT') - ex)], 0.2), ex + 0.6, -14.0)
    fx.add(ins.breath(rng, at('execution', 'ARM') - at('execution', 'LIFT'), rate=2.8, strength=0.7, panicked=True), at('execution', 'LIFT') + 0.6, -20.0)
    fx.add(in_room(ins.creak(rng, 0.25, 18, 8, 0.6), 0.2), at('execution', 'ARM'), -16.0)
    fx.add(arm_hit, at('execution', 'HIT') - 0.22, -5.0)
    fx.add(ins.hit(rng, 0.8, metal=0.6, crack=1.0, sub=1.2, space=0.2), at('execution', 'HIT'), -10.0)
    fx.add(dsp.fade(dead[:n_of(end('execution') - at('execution', 'STATIC'))], 0.005, 0.04), at('execution', 'STATIC'), -14.0)

    # The code: four keys, the tone, the lock; running for the car; the doors.
    for k in marks('keypad')['KEYS']:
        fx.add(ins.key_beep(rng), start('keypad') + k, -14.0)
    tone = at('keypad', 'TONE')
    fx.add(ins.key_beep(rng, ins.note_hz('C6'), 0.12), tone, -13.0)
    fx.add(ins.key_beep(rng, ins.note_hz('G6'), 0.2), tone + 0.14, -13.0)
    fx.add(in_room(ins.bolt(rng), 0.2), at('keypad', 'OPEN') - 0.05, -9.0)
    fx.add(in_room(ins.creak(rng, 0.4, 30, 14, 0.8), 0.25), at('keypad', 'OPEN') + 0.05, -18.0)
    cutk = at('keypad', 'CUT')
    for k in range(6):
        fx.add(in_room(ins.footstep(rng, 0.9, carpet=k < 3), 0.2), cutk + 0.02 + k * 0.17, -10.0, pan=(0.25 if k % 2 else -0.25))
    fx.add(ins.breath(rng, 2.6, rate=2.2, strength=0.9, panicked=True), cutk, -18.0)
    fx.add(far(chitter[3]), at('keypad', 'TURNED') + 0.5, -18.0)
    fx.add(ins.relay(rng, 0.4), at('keypad', 'TURNED') - 0.15, -20.0)
    c0, c1 = at('keypad', 'CLOSE', 0), at('keypad', 'CLOSE', 1)
    fx.add(ins.lift_doors(rng, c1 - c0), c0, -8.0)

    # The car going down, and the picture going with it.
    fx.add(ins.lift_motor(rng, end('lift') - at('lift', 'DOWN') + 0.2), at('lift', 'DOWN'), -12.0)
    lose = at('lift', 'LOSE')
    fx.add(ins.glitch(rng, end('lift') - lose), lose, -12.0)

    # The archive: the rows written, the glimpses of what was not recovered.
    for r in marks('database')['ROWS']:
        for i in range(0, 26, 2):
            fx.add(ins.tick(rng, 0.8), start('database') + r + i / 90.0, -22.0)
    for f in marks('database')['FLASH']:
        fx.add(ins.data_burst(rng, 0.16), start('database') + f, -12.0)
    fx.add(dsp.fade(static[:n_of(0.22)], 0.01, 0.05), start('database') + 1.62, -18.0)

    # The end of the tape: the snow; the mask coming out of it; the blows.
    e = start('endtape')
    black = at('endtape', 'BLACK')
    fx.add(dsp.fade(loop_to(static, black - e), 0.05, 0.003), e, -15.0)
    m0, m1 = at('endtape', 'EMERGE', 0), at('endtape', 'NEAR', 1)
    fx.add(dsp.fade(riser[:n_of(m1 - m0)], 0.3, 0.05), m0, -16.0)
    fx.add(breath[n_of(6.0):n_of(6.0 + black - at('endtape', 'NEAR', 0))], at('endtape', 'NEAR', 0), -16.0)
    hits = marks('endtape')['HITS']
    fx.add(knocks[0], e + hits[0], -3.0)
    fx.add(ins.hit(rng, 0.6, metal=0.5, crack=0.8, sub=1.0, space=0.2), e + hits[0], -9.0)
    fx.add(knocks[2], e + hits[1], -2.0)
    fx.add(dsp.fade(shatter[:n_of(black - e - hits[1])], 0.0, 0.01), e + hits[1], -10.0)
    fx.add(ins.hit(rng, 0.5, metal=0.6, crack=1.0, sub=1.1, space=0.2), e + hits[1], -7.0)

    # The title: a relay for each lamp; three of them off again; the one
    # left humming to the cut.
    ti = start('title')
    lamps = marks('title')['LAMPS']
    for h in lamps:
        fx.add(ins.relay(rng, 0.9), ti + h - 0.01, -14.0)
    out = at('title', 'OUT')
    for k in range(3):
        fx.add(ins.relay(rng, 0.6), out + k * 0.05, -16.0)
    first = ins.lamp_hum(rng, at('title', 'CUT') - ti - lamps[0])
    fx.add(dsp.fade(first, 0.02, 0.003), ti + lamps[0], -30.0)
    for h in lamps[1:]:
        fx.add(dsp.fade(ins.lamp_hum(rng, out - ti - h, 100.0 * 1.003), 0.02, 0.01), ti + h, -32.0)
    return fx


# --- Mix -------------------------------------------------------------------------------------

## Stretches where only the voice may sound (the cut to black after the tape
## ends) and where everything stops dead (after the last frame).
def hard_cuts():
    return [(at('endtape', 'BLACK'), end('endtape')), (at('title', 'CUT') + 0.004, LENGTH_S)]


def mute(x, spans):
    t = np.arange(len(x)) / SR
    gain = np.ones(len(x))
    for a, b in spans:
        inside = (t >= a) & (t < b)
        gain[inside] = 0.0
    # A few milliseconds either side, so nothing clicks.
    gain = dsp.lp(gain, 400, 1)
    return x * gain[:, None]


## The limiter's ceiling on the PCM mix: AAC overshoots the peaks it is given
## by a dB or more, so the mix leaves room for it and the encoded files stay
## under -1 dBTP (encode.py).
CEILING = -3.0


def master(voice, music, fx):
    """The mix, and the three stems as they sit in it (at the same final
    gain, so they can be measured)."""
    spans = hard_cuts()
    music_p = mute(dsp.duck(music.buf, voice.buf, amount_db=-9.0, attack=0.03, release=0.45, threshold=0.02), spans)
    fx_p = mute(dsp.duck(fx.buf, voice.buf, amount_db=-4.0, attack=0.03, release=0.35, threshold=0.02), spans)
    voice_p = voice.buf * dsp.db(3.0)
    stems = [dsp.hp(x, 30, 4) for x in (voice_p, music_p, fx_p)]
    mix = sum(stems)
    pre = dsp.compress(mix, threshold=-16.0, ratio=2.0, attack=0.02, release=0.25, makeup=0.0)
    gain = dsp.db(-14.0 - dsp.lufs(pre))
    out = pre * gain
    for _ in range(3):
        out = dsp.limit(out, CEILING)
        trim_db = dsp.db(-14.0 - dsp.lufs(out))
        out = out * trim_db
        gain *= trim_db
    out = dsp.limit(out, CEILING)
    return out, [x * gain for x in stems]


def main():
    os.makedirs(OUT, exist_ok=True)
    voice = voice_track(np.random.default_rng(11))
    music = score(np.random.default_rng(22))
    fx = effects(np.random.default_rng(33))
    mix, stems = master(voice, music, fx)
    for track, stem in zip((voice, music, fx), stems):
        dsp.write(os.path.join(OUT, track.name + '.wav'), stem)
    dsp.write(os.path.join(OUT, 'mix.wav'), mix)
    for ident, when in voice_cues():
        print('  %-10s %6.2f s' % (ident, when))
    print('mix: %.2f LUFS, true peak %.2f dBTP, %.2f s' % (dsp.lufs(mix), dsp.true_peak(mix), len(mix) / SR))


if __name__ == '__main__':
    main()
