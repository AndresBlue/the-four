"""The trailer's sound: the archivist's voice, the score and the effects, laid
on the edit (timeline.json) at the marks each shot module exports (the
`export const` lines of web/shots/*.js), mixed and mastered to -14 LUFS, with
room under -1 dBTP for the encoder.

    python tools/trailer3d/audio/mix.py    -> evidence/trailer3d/audio/mix.wav (+ stems)

Everything is synthesized here (dsp.py, instruments.py) or is a sound this
project generated for the game (assets/audio/dread, intro, events), plus the
game's own three execution recordings. The voice is the archivist's recorded
lines (timeline.json voice.dir)."""
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
VOICE_DIR = os.path.join(ROOT, 'evidence', 'trailer3d', 'voice', TIMELINE['voice']['dir'])
LENGTH_S = TIMELINE['shots'][-1]['end']
LENGTH = n_of(LENGTH_S)

# --- The edit ----------------------------------------------------------------------------

SHOTS = {s['id']: s for s in TIMELINE['shots']}
## The archive module films four shots, each with its own set of marks.
ARCHIVE = {'vcr': 'VCR', 'crt': 'CRT', 'database': 'DB'}
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

## Each line and where it starts: timeline.json places it (shot, at), so the
## picture's subtitles and the sound read the same numbers.
def voice_cues():
    return [(l['id'], start(l['shot']) + l['at']) for l in TIMELINE['voice']['lines']]


def line(ident):
    """A recorded line (timeline.json voice.lines), cut to its from/to."""
    spec = next(l for l in TIMELINE['voice']['lines'] if l['id'] == ident)
    x = dsp.load(os.path.join(VOICE_DIR, spec['file']))
    a = n_of(spec.get('from', 0.0))
    b = n_of(spec['to']) if 'to' in spec else len(x)
    return x[a:b]


def trim(x, floor_db=-42.0):
    """The line without the silence around it."""
    env = dsp.envelope_follow(x, 0.002, 0.03)
    loud = np.where(env > np.max(env) * dsp.db(floor_db))[0]
    if len(loud) == 0: return x
    a = max(0, loud[0] - n_of(0.012))
    b = min(len(x), loud[-1] + n_of(0.06))
    return dsp.fade(x[a:b], 0.004, 0.03)


def archivist(x, rng):
    """The archive's narrator, as recorded, put on a cassette dub: dry,
    band-limited, a touch of saturation and of wow and flutter."""
    x = dsp.normalize(trim(x), 0.5)
    x = dsp.hp(x, 90, 2)
    x = dsp.lp(x, 9000, 2)
    x = dsp.compress(x, threshold=-24, ratio=2.5, attack=0.005, release=0.12, makeup=4.0)
    x = dsp.saturate(x * 1.15, 1.2) * 0.85
    x = dsp.wobble(x, depth_cents=4.0, rate=0.6, flutter_cents=2.0, flutter_rate=7.2, rng=rng)
    booth = dsp.impulse(0.25, 0.12, rng, damping=6000, predelay=0.004, width=0.4)
    return dsp.convolve(x, booth, wet=0.05, dry=1.0)


def voice_track(rng):
    track = Track('voice')
    for ident, when in voice_cues():
        track.add(archivist(line(ident), rng), when, 0.0)
    return track


# --- The score -------------------------------------------------------------------------------

def motif(k, rng, tape=True):
    """A note of the motif as the tape holds it: a slow waver on it."""
    x = ins.motif_note(k, rng)
    return dsp.wobble(x, depth_cents=9.0, rate=0.45, flutter_cents=3.0, rng=rng) if tape else x


def pulse(rng, a, b, bpm=96.0):
    """The climax's pulse, from the lunge in the versus to the last lamp going
    out: a kick on the beat, a low E flat on the eighths, ticks on the
    sixteenths; denser and brighter as it goes, and nothing after b."""
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
            f = ins.note_hz('Eb1') * (2 if (k // 2) % 4 == 3 else 1)
            n = n_of(beat * 0.45)
            bass = dsp.lp(ins.saw(np.full(n, f), n, rng, harmonics=24), 160 + 800 * rise)
            bass = dsp.fade(bass, 0.004, beat * 0.2) * 0.5
            out[s:s + n] += dsp.stereo(bass)[:len(out) - s]
        tk = ins.clock_tick(rng, tock=k % 2 == 1) * (0.3 + 0.5 * rise)
        out[s:s + len(tk)] += dsp.stereo(tk, 0.3 if k % 2 else -0.3)[:len(out) - s]
        when += beat / 4
        k += 1
    return out


def dread(rng, dur, lo=40.0, hi=900.0):
    """A dark rising: a low cluster swelling and opening, noise climbing
    through a filter, to fill a fade with something coming."""
    n = n_of(dur)
    t = np.arange(n) / SR
    k = t / dur
    x = np.zeros(n)
    for f in (ins.note_hz('Eb1'), ins.note_hz('Bb1'), ins.note_hz('E2')):
        x += ins.saw(f * (1 + 0.004 * np.sin(2 * np.pi * 0.3 * t)), n, rng, harmonics=30)
    x = dsp.sweep_filter(x, lo + (hi - lo) * k ** 2, q=1.2)
    air = dsp.sweep_filter(dsp.noise(n, rng, 'pink'), 300 + 3000 * k ** 2, kind='bandpass', q=2.0) * 0.3
    return (x * 0.25 + air) * k ** 1.5


def score(rng):
    music = Track('music')
    drone = asset('dread', 'dread_drone.wav')
    room = dsp.impulse(3.2, 2.2, rng, damping=3500, predelay=0.03)
    # Under all of it, from the reception to the database: the drone, low,
    # swelling as the guests are lost.
    a, b = start('reception'), end('database')
    bed = span(drone, a, b, 2.0, 1.5)
    t = np.arange(len(bed)) / SR
    swell = 0.6 + 0.4 * np.clip((t - (start('guest1') - a)) / (start('versus') - start('guest1')), 0, 1)
    music.add(dsp.lp(bed * swell, 700), a, -16.0)
    # The sectors: the motif's first three notes, falling, one on each hit.
    for k, h in enumerate(marks('sectors')['HITS']):
        when = start('sectors') + h
        music.add(dsp.convolve(motif(k, rng), room, wet=0.35, dry=1.0), when, -8.0)
        music.add(ins.hit(rng, 3.0, metal=0.25, crack=0.2, sub=1.0, space=0.45), when, -11.0)
        music.add(ins.sub_drop(rng, 2.2, 80, 32, 0.25, 1.6), when, -13.0)
    # Risings into the dark before each guest is taken, and across the fades.
    music.add(dread(rng, at('guest1', 'CATCH') - start('guest1') - 0.3), start('guest1') + 0.3, -14.0)
    music.add(dread(rng, at('guest2', 'OUT') - start('guest2') - 0.4), start('guest2') + 0.4, -18.0)
    music.add(dread(rng, at('guest3', 'OPEN') - start('guest3')), start('guest3'), -13.0)
    music.add(dread(rng, end('guest4') - start('guest4')), start('guest4'), -17.0)
    music.add(ins.strings(rng, 5.0, ('Eb2', 'Bb2', 'E3', 'G3'), tremolo=0.3, cutoff=1000, attack=2.0), start('guest3') + 0.1, -19.0)
    music.add(ins.strings(rng, 5.0, ('Eb2', 'C3', 'G3', 'Bb3'), tremolo=0.4, cutoff=1300, attack=1.6), start('guest4') + 0.1, -19.0)
    # The black of the occupant: the low strings alone.
    music.add(ins.strings(rng, 3.0, ('C2', 'G2', 'Eb3'), tremolo=0.2, cutoff=700, attack=0.8), start('occupant'), -17.0)
    # The versus: strings climbing under its clicks into the shriek.
    music.add(ins.strings(rng, 3.0, ('Eb2', 'Bb2', 'E3', 'C4', 'F4'), tremolo=0.6, cutoff=2000, attack=1.2), start('versus'), -16.0)
    # The pulse: from the lunge to the last corridor lamp going out.
    pa = at('versus', 'LUNGE')
    pb = at('blackout', 'POWER') + 0.9
    music.add(pulse(rng, pa, pb), pa, -7.0)
    music.add(dsp.fade(ins.riser(rng, pb - pa - 0.3), 0.5, 0.0), pa + 0.3, -18.0)
    # The last set coming on: the motif's third note, once more.
    music.add(dsp.convolve(motif(2, rng), room, wet=0.3, dry=1.0), at('blackout', 'CLICK'), -11.0)
    # The chase: the dread again from the moment the torch finds it; a blast
    # as it is on them.
    music.add(dread(rng, at('chase', 'TURN') - at('chase', 'FIND') + 0.2), at('chase', 'FIND'), -12.0)
    music.add(ins.braam(rng, 1.6, open_to=1800.0), at('chase', 'TURN') - 0.05, -13.0)
    # The keypad: only the strings, low, and the rising as the door opens.
    music.add(ins.strings(rng, 3.0, ('Eb2', 'Bb2', 'C3', 'G3'), tremolo=0.15, cutoff=800, attack=1.0), start('keypad'), -21.0)
    # The database: something far down under the list.
    music.add(dread(rng, end('database') - start('database'), lo=30.0, hi=400.0), start('database'), -18.0)
    # The title: three notes as the first three lamps come on; a breath; the
    # fourth, heard for the first time, with the fourth lamp.
    lamps = marks('title')['LAMPS']
    for k, h in enumerate(lamps):
        note = dsp.convolve(motif(k, rng, tape=False), room, wet=0.35, dry=1.0)
        music.add(note, start('title') + h, -8.0 if k < 3 else -6.0)
    music.add(ins.sub_drop(rng, 3.5, 60, 28, 0.4, 2.8), start('title') + lamps[3], -10.0)
    music.add(dsp.fade(ins.strings(rng, 2.6, ('C2', 'G2', 'Eb3', 'Bb3'), cutoff=900, attack=0.6), 0.2, 1.0), start('title') + lamps[3], -20.0)
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
    bangs = [asset('intro', 'door_bang_%d.wav' % i) for i in (1, 2, 3)]
    # The recording is clipped square: the encoder overshoots its edges by
    # several dB. Rounded off above 9 kHz, a few milliseconds of attack, and
    # nothing below hearing.
    scream = dsp.lp(dsp.hp(dsp.fade(asset('events', 'execution_scream.wav'), 0.008, 0.0), 40, 2), 9000, 4)
    arm_hit = dsp.lp(asset('events', 'execution_hit.wav'), 11000, 4)
    dead = asset('events', 'execution_static.ogg')

    def in_room(x, wet=0.25): return dsp.convolve(x, room, wet=wet)
    def in_hall(x, wet=0.35): return dsp.convolve(x, hall, wet=wet)
    def far(x): return dsp.lp(in_hall(x, 0.7), 1800)

    # A big, dark space for the kill to ring on in: long, low, slow to die.
    cavern = dsp.impulse(5.5, 4.2, rng, damping=2200, predelay=0.04, width=1.0)

    def taken(when, gain=-9.0):
        """The game's execution, when it has someone: its screamer and the
        blow, ringing on long after in a dark space, an echo coming back."""
        cry = dsp.fade(scream[:n_of(1.1)], 0.0, 0.35)
        fx.add(cry, when - 0.02, gain)
        tail = dsp.convolve(dsp.fit(dsp.lp(cry, 5000), n_of(6.0)), cavern, wet=1.0, dry=0.0)
        tail = dsp.delay(dsp.mono(tail), 0.33, feedback=0.45, mix=0.4, damp=1800)
        fx.add(dsp.fade(tail, 0.0, 2.5), when - 0.02, gain - 5.0)
        fx.add(arm_hit, when + 0.18 - 0.22, gain + 2.0)
        fx.add(ins.hit(rng, 0.8, metal=0.6, crack=1.0, sub=1.2, space=0.2), when + 0.18, gain - 3.0)

    # The tape under all of it; the room it plays in before the picture.
    fx.add(dsp.fade(ins.tape_hiss(LENGTH, rng), 0.3, 0.02), 0.0, -40.0)
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
    t0 = at('crt', 'TEXT')
    for i in range(0, 72, 2):
        fx.add(ins.tick(rng, 0.8), t0 + i / 72.0, -22.0)
    dive = at('crt', 'DIVE')
    fx.add(ins.reverse_swell(rng, 0.8), dive - 0.55, -12.0)
    fx.add(dsp.fade(loop_to(static, end('crt') - dive), 0.5, 0.2), dive, -16.0)

    # The reception: the dark room; nervous feet; the door far off.
    a, b = start('reception'), end('reception')
    fx.add(dsp.lp(span(dsp.noise(n_of(3.0), rng, 'pink'), a, b, 0.3, 0.3), 250), a, -24.0)
    for k in range(5):
        fx.add(in_room(ins.footstep(rng, 0.35), 0.4), a + 0.2 + k * 0.33 + rng.uniform(-0.05, 0.05), -24.0, pan=rng.uniform(-0.5, 0.5))
    fx.add(far(bangs[0]), at('reception', 'CLACK'), -12.0, pan=0.45)

    # The rewinds: static under all three, the whine of each.
    ra = start('rewind')
    for p, q in marks('rewind')['REWINDS']:
        fx.add(ins.rewind(rng, q - p), ra + p, -12.0)
        fx.add(dsp.fade(static[:n_of(q - p)], 0.005, 0.02), ra + p, -16.0)
    for p, q in marks('rewind')['PASSES']:
        fx.add(dsp.lp(span(dsp.noise(n_of(1.0), rng, 'pink'), ra + p, ra + q, 0.02, 0.05), 300), ra + p, -26.0)
        fx.add(span(hum, ra + p, ra + q, 0.02, 0.05), ra + p, -34.0)

    # The sectors: what each hit shows sounds with it.
    h = [start('sectors') + x for x in marks('sectors')['HITS']]
    fx.add(ins.lamp_hum(rng, 0.7, 120.0) * dsp.fade(np.ones(n_of(0.7)), 0.005, 0.3), h[0], -26.0)
    fx.add(ins.tv_on(rng), h[1], -12.0)
    fx.add(dsp.fade(static[:n_of(0.7)], 0.01, 0.4), h[1] + 0.05, -16.0)
    fx.add(ins.paper(rng, 0.5), h[2], -16.0)

    # Guest one: running; a look back and it is there, closing; taken.
    g1 = start('guest1')
    caught = at('guest1', 'CATCH')
    when = g1 + 0.05
    while when < caught - 0.05:
        fx.add(in_room(ins.footstep(rng, rng.uniform(0.8, 1.0))), when, -10.0, pan=rng.uniform(-0.1, 0.1))
        when += 0.29 + rng.uniform(-0.02, 0.02)
    fx.add(dsp.fade(ins.breath(rng, caught - g1, rate=2.4, strength=1.0, panicked=True), 0.1, 0.05), g1, -16.0)
    look = at('guest1', 'LOOK', 0)
    fx.add(ins.whoosh(rng, 0.45, 400, 3000, 0.4, -0.4), look, -12.0)
    # Its claws behind him, gaining, from the moment he looks.
    when = look + 0.05
    while when < caught - 0.05:
        k = (when - look) / (caught - look)
        fx.add(in_hall(ins.claw_step(rng, 0.7 + 0.5 * k), 0.3), when, -12.0 + 5 * k)
        when += 0.16
    fx.add(in_hall(chitter[0], 0.3), look + 0.35, -15.0)
    taken(caught)
    snow = at('guest1', 'SNOW')
    fx.add(dsp.fade(loop_to(static, end('guest1') - snow), 0.0, 0.3), snow, -12.0)

    # Guest two: the click and the set; it comes up to the glass inside it;
    # the flashes; out.
    click = at('guest2', 'CLICK')
    fx.add(ins.relay(rng, 0.9), click - 0.03, -14.0)
    fx.add(ins.tv_on(rng), click, -9.0)
    out = at('guest2', 'OUT')
    swell = loop_to(static, out - click)
    swell = swell * np.linspace(0.3, 1.0, len(swell))
    fx.add(dsp.fade(swell, 0.05, 0.02), click + 0.05, -23.0)
    fx.add(span(whine, click, out, 0.1, 0.05), click, -30.0)
    for f in marks('guest2')['FLASHES']:
        fx.add(dsp.fade(static[:n_of(0.12)], 0.0, 0.05), start('guest2') + f, -11.0)
        fx.add(ins.glitch(rng, 0.12), start('guest2') + f, -15.0)
    fx.add(ins.hit(rng, 2.4, metal=0.4, crack=0.3, sub=1.2, space=0.5), out, -9.0)
    fx.add(in_room(chitter[1], 0.3), out + 0.1, -12.0)
    fx.add(in_room(breath[:n_of(end('guest2') - out)], 0.3), out, -15.0)

    # Guest three: shut in the wardrobe, his breath, his heart quickening; the
    # door a hair open, nothing; torn open, and it has him.
    g3 = start('guest3')
    caught = at('guest3', 'OPEN')
    fx.add(dsp.fade(ins.breath(rng, caught - g3, rate=0.8, strength=0.6), 0.3, 0.05), g3, -20.0)
    beat = 60 / 64
    when = g3 + 0.3
    while when < caught - 0.2:
        fx.add(ins.heartbeat(rng, 1.0), when, -14.0)
        when += beat * (1 - 0.3 * (when - g3) / (caught - g3))
    fx.add(in_room(ins.creak(rng, at('guest3', 'AJAR', 1) - at('guest3', 'AJAR', 0), 14, 5, 0.6), 0.2), at('guest3', 'AJAR', 0), -22.0)
    # Torn open, and it has him at once.
    fx.add(dsp.fade(ins.wood_close(rng, 1.2), 0.0, 0.1), at('guest3', 'OPEN'), -8.0)
    taken(at('guest3', 'OPEN') + 0.02)

    # Guest four: the warm corridor; the zoom; the head that was not there.
    g4 = start('guest4')
    fx.add(span(hum, g4, end('guest4'), 0.3, 0.5), g4, -30.0)
    z0, z1 = at('guest4', 'ZOOM_IN', 0), at('guest4', 'ZOOM_IN', 1)
    fx.add(ins.zoom_motor(rng, z1 - z0), z0, -18.0)
    z0, z1 = at('guest4', 'ZOOM_OUT', 0), at('guest4', 'ZOOM_OUT', 1)
    fx.add(ins.zoom_motor(rng, z1 - z0), z0, -20.0)
    fx.add(ins.relay(rng, 0.5), at('guest4', 'TORCH'), -18.0)
    # The door slammed on the face in it: the game's own slam, down the hall.
    fx.add(in_hall(asset('sfx', 'door', 'closing', 'close-hard-closing.ogg'), 0.35), at('guest4', 'SLAM') - 0.03, -11.0)
    fx.add(ins.reverse_swell(rng, 0.5), at('guest4', 'BLINK') - 0.5, -20.0)
    fx.add(ins.glitch(rng, 0.08), at('guest4', 'BLINK'), -16.0)

    # The occupant's black: only its breath, far off.
    fx.add(far(breath[n_of(3.0):n_of(3.0 + end('occupant') - start('occupant'))]), start('occupant'), -20.0)

    # Versus: its clicks and what they find; its cry, all rattle, no voice;
    # the lunge.
    for k, c in enumerate(marks('versus')['CLICKS']):
        when = start('versus') + c
        fx.add(dsp.delay(ins.sonar_click(rng), 0.07, 0.45, 0.45), when, -12.0, pan=rng.uniform(-0.15, 0.15))
        fx.add(in_hall(chitter[k % 4], 0.5), when + 0.02, -20.0)
    shriek = at('versus', 'SHRIEK')
    fx.add(ins.reverse_swell(rng, 0.5), shriek - 0.5, -14.0)
    for k in range(6):
        c = chitter[k % 4]
        fx.add(in_hall(dsp.resample_speed(c, 0.7 + 0.1 * k), 0.4), shriek + k * 0.07, -8.0, pan=rng.uniform(-0.3, 0.3))
    fx.add(ins.hit(rng, 3.0, metal=0.5, crack=0.5, sub=1.1, space=0.5), shriek, -12.0)
    fx.add(ins.whoosh(rng, 0.45, 300, 3000, -0.2, 0.2), at('versus', 'LUNGE') - 0.1, -11.0)
    # Running him down: its claws, and a click at each look.
    when = at('versus', 'LUNGE')
    while when < end('versus') - 0.1:
        fx.add(in_room(ins.claw_step(rng, 1.0)), when, -14.0)
        when += 0.14
    for c in marks('versus')['CHASE']:
        fx.add(dsp.delay(ins.sonar_click(rng), 0.07, 0.45, 0.45), start('versus') + c, -12.0)

    # The blackout: the button, the last set; it draws the power: the surge
    # buzzing up, the lamp by it stuttering and popping; the corridor's lamps
    # going one after another; the torch.
    click = at('blackout', 'CLICK')
    fx.add(ins.relay(rng, 1.0), click - 0.02, -10.0)
    fx.add(ins.tv_on(rng), click, -10.0)
    surge = at('blackout', 'SURGE')
    pop = at('blackout', 'POP')
    n = n_of(pop - surge + 0.05)
    tt = np.arange(n) / SR
    buzz = np.sign(np.sin(2 * np.pi * 100 * tt)) * 0.3 + dsp.bp(dsp.noise(n, rng), 1500, 6000) * 0.4 * (np.sin(2 * np.pi * 14 * tt) > 0.2)
    fx.add(dsp.fade(buzz * np.linspace(0.3, 1.0, n), 0.02, 0.01), surge, -18.0)
    fx.add(ins.glitch(rng, 0.12), pop, -12.0)
    fx.add(hp_pop(rng), pop, -8.0)
    lit_a = at('blackout', 'CUT')
    power = at('blackout', 'POWER')
    fx.add(span(hum, lit_a, power + 0.9, 0.01, 0.2), lit_a, -22.0)
    for i in range(12):
        fx.add(ins.relay(rng, 0.8 - i * 0.05), power + i * 0.075, -12.0 - i * 0.6, pan=rng.uniform(-0.2, 0.2))
    fx.add(ins.power_cut(rng), power + 0.85, -4.0)
    fx.add(ins.relay(rng, 0.7), at('blackout', 'TORCH'), -14.0)
    fx.add(far(span(static, power + 1.0, end('chase'), 0.6, 0.1)), power + 1.0, -26.0)

    # The chase: the torch looking; finding it; its claws coming; the door;
    # it is on them.
    ch = start('chase')
    find = at('chase', 'FIND')
    fx.add(ins.breath(rng, find - ch + 0.4, rate=1.9, strength=0.8, panicked=True), ch, -18.0)
    fx.add(ins.hit(rng, 1.4, metal=0.3, crack=0.2, sub=0.9, space=0.5), find, -14.0)
    when = find + 0.05
    while when < at('chase', 'SLAM') - 0.05:
        fx.add(in_hall(ins.claw_step(rng, 0.8 + 0.3 * (when - find)), 0.3), when, -13.0)
        when += 0.13
    fx.add(in_hall(asset('sfx', 'door', 'closing', 'close-hard-closing.ogg'), 0.3), at('chase', 'SLAM') - 0.03, -6.0)
    fx.add(ins.whoosh(rng, 0.35, 400, 3200, 0.4, -0.4), at('chase', 'TURN') - 0.1, -9.0)
    fx.add(in_room(chitter[2], 0.2), at('chase', 'TURN') + 0.05, -10.0)
    taken(at('chase', 'THRUST'), gain=-13.0)
    fx.add(dsp.fade(dead[:n_of(end('chase') - at('chase', 'THRUST') - 0.3)], 0.005, 0.25), at('chase', 'THRUST') + 0.3, -24.0)

    # The code, every sound on its own: four keys, the tone, the lock, the door.
    for k in marks('keypad')['KEYS']:
        fx.add(ins.key_beep(rng), start('keypad') + k, -14.0)
    tone = at('keypad', 'TONE')
    fx.add(ins.key_beep(rng, ins.note_hz('C6'), 0.1), tone, -13.0)
    fx.add(ins.key_beep(rng, ins.note_hz('G6'), 0.16), tone + 0.12, -13.0)
    # The door pulled open, quick: the game's own.
    fx.add(in_room(asset('sfx', 'door', 'opening', 'opening2.ogg'), 0.2), at('keypad', 'OPEN') - 0.15, -6.0)

    # The archive: the rows written, the glimpses of what was not recovered.
    for r in marks('database')['ROWS']:
        for i in range(0, 26, 2):
            fx.add(ins.tick(rng, 0.8), start('database') + r + i / 26.0, -22.0)
    for f in marks('database')['FLASH']:
        fx.add(ins.data_burst(rng, 0.16), start('database') + f, -12.0)

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


def hp_pop(rng):
    """A bulb going: a sharp pop and the tinkle of its filament."""
    k = n_of(0.3)
    tt = np.arange(k) / SR
    x = dsp.hp(rng.standard_normal(k), 1500) * np.exp(-tt / 0.006)
    x += np.sin(2 * np.pi * 3100 * tt) * np.exp(-tt / 0.05) * 0.15
    return x


# --- Mix -------------------------------------------------------------------------------------

## Where everything stops dead: after the last frame.
def hard_cuts():
    return [(at('title', 'CUT') + 0.004, LENGTH_S)]


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
    # Nothing above 15 kHz: a tape never had it, and the sharp edges of the
    # clicks, pops and clipped recordings are what AAC overshoots most.
    stems = [dsp.lp(dsp.hp(x, 30, 4), 15000, 4) for x in (voice_p, music_p, fx_p)]
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
