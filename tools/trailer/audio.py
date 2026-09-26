"""The trailer's sound: voice, score and effects laid on the edit
(tools/trailer/timeline.py), mixed and mastered to -14 LUFS, -1 dBTP.
Everything is synthesized here (dsp.py, instruments.py) or taken from sounds
this project synthesized itself (assets/audio/dread, assets/audio/intro), plus
one recording credited on the end card (the scream, CC BY 4.0).

    python tools/trailer/audio.py            -> evidence/trailer/audio/mix.wav (+ stems)

Run after the shots are filmed: their events.json put the hits in sync."""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import dsp
import instruments as ins
import timeline as tl
from dsp import SR, n_of

OUT = os.path.join(tl.ROOT, 'evidence', 'trailer', 'audio')
VOICE_DIR = os.path.join(tl.ROOT, 'evidence', 'trailer', 'voice')
ASSETS = os.path.join(tl.ROOT, 'assets', 'audio')
LENGTH = n_of(tl.LENGTH)


def at_clip(shot, nth=0):
    """Where the nth clip of a shot starts, and where it ends."""
    clips = [c for c in tl.CLIPS if c.get('shot') == shot]
    clip = clips[nth]
    return clip['at'], clip['at'] + clip['len']


HALL = at_clip('hall')
CARDS = [c['at'] for c in tl.CLIPS if c.get('shot') == 'card']
RUN = at_clip('run')
LISTEN = at_clip('listen')
TV_LOCUST = at_clip('tv_locust')
GLASS = at_clip('intro_glass')
PHANTOM = at_clip('phantom')
VERSUS = at_clip('versus')
MONTAGE = (at_clip('blackout')[0], at_clip('kill')[1])
BLACK = at_clip('black')
FLOORS = at_clip('floors')
TITLE = at_clip('title')
TOGETHER = at_clip('together')
SHEET = at_clip('sheet')


class Track:
    def __init__(self, name):
        self.name = name
        self.buf = np.zeros((LENGTH, 2))

    def add(self, x, at, gain=0.0, pan=0.0):
        """x (mono or stereo) placed at `at` seconds, `gain` dB."""
        if x is None or at is None: return
        x = dsp.stereo(x, pan) if x.ndim == 1 else x
        start = n_of(at)
        if start < 0:
            x = x[-start:]
            start = 0
        end = min(LENGTH, start + len(x))
        if end <= start: return
        self.buf[start:end] += x[:end - start] * dsp.db(gain)


def asset(*parts):
    return dsp.load(os.path.join(ASSETS, *parts))


def loop_to(x, seconds):
    n = n_of(seconds)
    reps = int(np.ceil(n / len(x)))
    return np.tile(x, (reps,) + (1,) * (x.ndim - 1))[:n]


def span(x, start, end, fin=0.3, fout=0.5):
    """A loop cut to [start, end] with fades."""
    return dsp.fade(loop_to(x, end - start), fin, fout)


# --- The voice ------------------------------------------------------------------------

def pa_voice(x, rng, hall):
    """A recorded announcement played over the hotel's speakers: band-limited,
    pushed a little into the horn, in the corridor's space."""
    x = dsp.hp(x, 150, 2)
    x = dsp.lp(x, 7200, 2)
    x = dsp.eq(x, 'peak', 2300, 0.9, 3.5)
    x = dsp.eq(x, 'peak', 420, 1.1, -2.5)
    x = dsp.eq(x, 'lowshelf', 220, 0.7, 2.0)
    x = dsp.compress(x, threshold=-26, ratio=3.0, attack=0.004, release=0.12, makeup=6.0)
    horn = dsp.bp(dsp.saturate(x * 1.4, 1.8), 280, 5200, 2)
    mix = 0.62 * x + 0.38 * horn
    wet = dsp.convolve(mix, hall, wet=0.2, dry=1.0)
    slap = dsp.delay(dsp.mono(wet), 0.085, feedback=0.25, mix=0.12, damp=2500)
    return dsp.stereo(slap) * 0.5 + wet * 0.5


def voice_track(rng):
    track = Track('voice')
    hall = dsp.impulse(2.6, 1.5, rng, damping=5000, predelay=0.02, width=0.8)
    for ident, at in tl.VOICE:
        path = os.path.join(VOICE_DIR, ident + '.wav')
        raw = dsp.load(path)
        raw = dsp.normalize(raw, 0.5)
        line = pa_voice(raw, rng, hall)
        # The last announcement, as the tape gives out: it wavers.
        if ident == 'estancia': line = dsp.wobble(line, depth_cents=22, rate=0.8, flutter_cents=6)
        gain = -1.0 if ident.startswith('n') else 0.0
        track.add(line, at, gain)
    # The chime before the first announcement.
    track.add(ins.pa_chime(rng), HALL[0] + 0.07, -9.0)
    return track


# --- The score ------------------------------------------------------------------------

WALTZ = [  # (note, beats), 3/4
    ('A5', 2), ('F5', 1), ('D5', 2), ('E5', 1), ('F5', 1), ('G5', 1), ('A5', 1),
    ('Bb5', 2), ('A5', 1), ('G5', 2), ('E5', 1), ('C#5', 2), ('E5', 1), ('D5', 3),
]
WALTZ_BASS = ['D4', 'D4', 'F4', 'G4', 'E4', 'A3', 'D4']


def waltz(rng, beat=0.56, bars=7, detune=0.0):
    """The hotel's tune on a music box: melody and a note on each downbeat."""
    total = sum(b for _, b in WALTZ) * beat + 3.0
    out = np.zeros(n_of(total))
    at = 0.0
    for name, beats in WALTZ:
        f = ins.note_hz(name) * 2 ** (detune / 1200)
        tone = ins.music_box(f, rng, 2.6)
        s = n_of(at)
        out[s:s + len(tone)] += tone[:len(out) - s]
        at += beats * beat
    for bar, name in enumerate(WALTZ_BASS[:bars]):
        tone = ins.music_box(ins.note_hz(name) * 2 ** (detune / 1200), rng, 2.4) * 0.55
        for beat_in_bar, amp in ((0, 1.0), (1, 0.35), (2, 0.35)):
            s = n_of((bar * 3 + beat_in_bar) * beat)
            if beat_in_bar and bar < len(WALTZ_BASS):
                chordtone = ins.music_box(ins.note_hz(name) * 1.5 * 2 ** (detune / 1200), rng, 1.6) * 0.35
                out[s:s + len(chordtone)] += chordtone[:len(out) - s] * amp
            elif s < len(out):
                out[s:s + len(tone)] += tone[:len(out) - s] * amp
    return out


def distant(x, rng, room):
    """Music from a speaker in another room: thin, warbling, far."""
    x = dsp.hp(x, 300, 2)
    x = dsp.lp(x, 3800, 2)
    x = dsp.wobble(x, depth_cents=14, rate=0.5, flutter_cents=5)
    return dsp.convolve(x, room, wet=0.55, dry=0.55)


def score(rng):
    music = Track('music')
    room = dsp.impulse(3.0, 2.0, rng, damping=3500, predelay=0.03)
    # The hotel's tune from the corridor to the first rule, where the tape
    # stops dead.
    tune = distant(waltz(rng, beat=0.53), rng, room)
    tune_start, tune_stop = HALL
    tune = tune[:n_of(tune_stop - tune_start)]
    tune = dsp.tape_stop(tune, 0.75)
    music.add(dsp.fade(tune, 0.8, 0.0), tune_start, -12.0)
    # Each rule card: the tune's first two notes, from far off, a semitone
    # lower every time.
    cards = [c for c in tl.CLIPS if c.get('shot') == 'card']
    for k, clip in enumerate(cards):
        pair = np.zeros(n_of(3.0))
        for j, name in enumerate(('A5', 'F5')):
            tone = ins.music_box(ins.note_hz(name) * 2 ** (-k / 12), rng, 2.4)
            at = n_of(0.28 * j)
            pair[at:at + len(tone)] += tone[:len(pair) - at]
        music.add(distant(pair, rng, room), clip['at'] + 0.05, -19.0)
    # Under everything until the cut to black: the dread drone, swelling.
    drone = asset('dread', 'dread_drone.wav')
    bed = span(drone, 0.0, BLACK[0], 2.5, 0.05)
    t = np.arange(len(bed)) / SR
    swell = 0.55 + 0.45 * np.clip((t - CARDS[0]) / (MONTAGE[0] - CARDS[0]), 0, 1)
    music.add(dsp.lp(bed * swell, 900), 0.0, -21.0)
    # The rules: a slow heartbeat and the hotel's clock under them.
    beat = 60.0 / 64.0
    at = CARDS[0]
    k = 0
    while at < MONTAGE[0] - 0.2:
        rising = np.clip((at - CARDS[0]) / (MONTAGE[0] - CARDS[0]), 0, 1)
        music.add(ins.heartbeat(rng, 1.0), at, -19.0 + 6.0 * rising)
        music.add(ins.clock_tick(rng, tock=k % 2 == 1), at + beat * 0.5, -25.0 + 3.0 * rising, pan=0.25)
        at += beat * (1.0 - 0.18 * rising)
        k += 1
    # Tension under rule three and four.
    music.add(ins.strings(rng, 6.5, ('D3', 'Eb3', 'A3', 'D4'), tremolo=0.25, cutoff=1100, attack=2.5), CARDS[2] + 1.55, -16.0)
    music.add(ins.strings(rng, 6.0, ('D3', 'E3', 'Bb3', 'Eb4'), tremolo=0.45, cutoff=1500, attack=1.8), CARDS[3] + 0.6, -15.0)
    # Versus: the low string cluster rising into the montage.
    music.add(ins.strings(rng, 8.8, ('D2', 'A2', 'Eb3', 'D4', 'Ab4'), tremolo=0.6, cutoff=2200, attack=3.0), VERSUS[0] - 0.5, -15.0)
    # The montage: a driving pulse, a riser, and it all stops at the black.
    montage_start, montage_end = MONTAGE
    step = 60.0 / 138.0 / 2
    at = montage_start
    k = 0
    while at < montage_end - 0.05:
        if k % 4 == 0: music.add(ins.kick(rng, 1.2), at, -6.0)
        if k % 4 == 2: music.add(ins.tom(rng, 82.0), at, -9.0)
        music.add(ins.clock_tick(rng, k % 2 == 1), at, -18.0)
        at += step
        k += 1
    rise = ins.riser(rng, montage_end - montage_start - 0.6)
    music.add(rise, montage_start + 0.6, -9.0)
    # The floor indicator: something low holds under it.
    music.add(dsp.lp(span(drone, FLOORS[0], FLOORS[1], 1.2, 0.8), 400), FLOORS[0], -18.0)
    # The title: the tune again, slower, further off, a little out of tune.
    reprise = distant(waltz(rng, beat=0.7, detune=-35.0), rng, room)
    reprise = dsp.fade(reprise[:n_of(6.2)], 1.0, 2.0)
    music.add(reprise, TITLE[0] + 0.55, -16.0)
    music.add(dsp.lp(span(drone, TITLE[0], tl.LENGTH, 0.6, 2.5), 500), TITLE[0], -19.0)
    return music


# --- Effects --------------------------------------------------------------------------------

def effects(rng):
    fx = Track('effects')
    room = dsp.impulse(1.8, 0.9, rng, damping=5000, predelay=0.008)
    hallway = dsp.impulse(3.0, 1.8, rng, damping=4000, predelay=0.02)
    hiss_tv = asset('intro', 'tv_static.wav')
    whine = asset('intro', 'tv_whine.wav')
    hum = asset('dread', 'fluorescent_hum.wav')
    chitters = [asset('dread', 'chitter_%d.wav' % i) for i in range(4)]
    creature_breath = asset('dread', 'dread_breath.wav')
    knocks = [asset('intro', 'glass_knock_%d.wav' % i) for i in (1, 2, 3)]
    shatter = asset('intro', 'glass_shatter.wav')
    bangs = [asset('intro', 'door_bang_%d.wav' % i) for i in (1, 2, 3)]
    scream = asset('events', 'execution_scream.wav')

    def room_verb(x, wet=0.25): return dsp.convolve(x, room, wet=wet)
    def hall_verb(x, wet=0.35): return dsp.convolve(x, hallway, wet=wet)

    # The tape: a faint hiss under all of it, the deck at the start.
    tape = dsp.hp(dsp.noise(LENGTH, rng, 'pink'), 3000) * 0.02
    fx.add(dsp.fade(tape, 0.5, 1.0), 0.0, -12.0)
    fx.add(ins.vcr_clunk(rng), 1.18, -8.0)
    fx.add(span(whine, 1.3, 2.65, 0.05, 0.1), 1.3, -30.0)
    fx.add(dsp.fade(hiss_tv[:n_of(1.4)], 0.6, 0.05), 2.55, -9.0)
    fx.add(ins.glitch(rng, 0.35), HALL[0] - 0.15, -8.0)
    # Each rule card switches in like a channel: a blip of static and a thud,
    # and a smaller blip switching back out to the picture.
    for clip in tl.CLIPS:
        if clip.get('shot') != 'card': continue
        fx.add(dsp.fade(hiss_tv[:n_of(0.07)], 0.0, 0.03), clip['at'], -13.0)
        fx.add(ins.kick(rng, 0.9), clip['at'], -18.0)
        fx.add(dsp.fade(hiss_tv[n_of(0.5):n_of(0.55)], 0.0, 0.02), clip['at'] + clip['len'] - 0.02, -18.0)
    # The corridor: the lamps' hum and the ventilation.
    fx.add(span(hum, HALL[0], HALL[1], 0.1, 0.4), HALL[0], -30.0)
    fx.add(dsp.lp(span(dsp.noise(n_of(4.0), rng, 'pink'), HALL[0], HALL[1], 0.2, 0.5), 500) * 0.3, HALL[0], -12.0)
    cross = tl.when('hall', 'cross')
    stare = tl.when('hall', 'stare')
    if cross is not None:
        for k in range(8):
            fx.add(hall_verb(ins.claw_step(rng, 0.5)), cross + 0.3 + k * 0.42, -28.0, pan=-0.3 + 0.08 * k)
    if stare is not None:
        fx.add(hall_verb(chitters[0], 0.5), stare + 0.25, -20.0)
        fx.add(ins.reverse_swell(rng, 1.2), stare - 1.0, -20.0)
        fx.add(ins.hit(rng, 3.5, metal=0.2, crack=0.1, sub=0.7, space=0.5), stare + 0.2, -18.0)
    # Rule one: running feet, breath, and the head that snaps round.
    steps = [e for e in tl.shot_events('run') if e[1] == 'step']
    for e in steps:
        at = tl.when_frame('run', e[0])
        if at is not None: fx.add(room_verb(ins.footstep(rng, rng.uniform(0.8, 1.0))), at, -6.0, pan=rng.uniform(-0.15, 0.15))
    fx.add(ins.breath(rng, 2.5, rate=2.2, strength=1.0, panicked=True), RUN[0], -16.0)
    fx.add(ins.whoosh(rng, 0.5, 400, 3000, -0.4, 0.4), LISTEN[0] - 0.22, -14.0)
    snap = tl.when('listen', 'snap')
    if snap is not None:
        fx.add(ins.reverse_swell(rng, 0.9), snap - 0.9, -10.0)
        fx.add(ins.hit(rng, 3.0, metal=0.4, crack=0.4, sub=0.8, space=0.4), snap, -12.0)
        fx.add(room_verb(chitters[1]), snap + 0.05, -14.0, pan=0.1)
        fx.add(room_verb(creature_breath[:n_of(2.6)]), snap + 0.2, -16.0)
        for k in range(4):
            fx.add(room_verb(ins.claw_step(rng, 0.9)), snap + 1.4 + k * 0.45, -14.0)
    # Rule two: the set coming on, the static, the thing in it.
    tv = tl.when('tv_on', 'tv_on')
    if tv is not None:
        fx.add(ins.tv_on(rng), tv, -8.0)
        fx.add(dsp.fade(loop_to(hiss_tv, TV_LOCUST[0] - tv), 0.02, 0.1), tv, -12.0)
    fx.add(dsp.fade(loop_to(hiss_tv, TV_LOCUST[1] - TV_LOCUST[0]), 0.05, 0.05) * 0.6, TV_LOCUST[0], -16.0)
    fx.add(span(whine, TV_LOCUST[0], GLASS[0], 0.05, 0.05), TV_LOCUST[0], -34.0)
    lunge = tl.when('tv_locust', 'lunge')
    if lunge is not None:
        fx.add(ins.whoosh(rng, 0.45, 600, 3500, 0.0, 0.0), lunge - 0.3, -10.0)
        fx.add(knocks[1], lunge + 0.12, -4.0)
        fx.add(ins.hit(rng, 2.5, metal=0.5, crack=0.6, sub=0.8, space=0.35), lunge + 0.12, -8.0)
    blow = tl.when('intro_glass', 'blow')
    if blow is not None:
        fx.add(dsp.fade(knocks[2][:n_of(0.55)], 0.0, 0.3), blow, -6.0)
        fx.add(shatter[:n_of(0.5)], blow, -16.0)
        fx.add(dsp.fade(ins.hit(rng, 0.5, metal=0.5, crack=0.8, sub=0.8, space=0.2), 0.0, 0.35), blow, -10.0)
    # Rule three: the wardrobe.
    shut = tl.when('hide', 'shut')
    crack = tl.when('hide', 'crack')
    look = tl.when('hide', 'look')
    if shut is not None:
        fx.add(room_verb(ins.wood_close(rng, 1.0), 0.15), shut, -8.0)
        fx.add(room_verb(ins.wood_close(rng, 0.7), 0.15), shut + 0.09, -10.0)
        fx.add(ins.breath(rng, 2.2, rate=1.3, strength=0.8), shut + 0.3, -16.0)
    if crack is not None:
        fx.add(room_verb(ins.creak(rng, 0.8, 30, 14)), crack, -18.0)
        for k in range(7):
            fx.add(room_verb(ins.claw_step(rng, 0.7)), crack + 0.55 + k * 0.5, -15.0, pan=0.2 - 0.05 * k)
    if look is not None:
        fx.add(room_verb(chitters[2]), look, -15.0)
        fx.add(ins.reverse_swell(rng, 1.1), look - 1.1, -19.0)
        fx.add(ins.hit(rng, 3.0, metal=0.3, crack=0.1, sub=0.8, space=0.5), look, -15.0)
    # Rule four: the zoom going in, the head, the tape tearing.
    fx.add(ins.zoom_motor(rng, 1.0), PHANTOM[0] + 0.27, -14.0)
    peek = tl.when('phantom', 'peek')
    vanish = tl.when('phantom', 'vanish')
    if peek is not None:
        fx.add(dsp.lp(creature_breath[:n_of(3.0)], 1200), peek, -20.0)
    if vanish is not None:
        fx.add(ins.glitch(rng, 0.4), vanish - 0.05, -7.0)
        fx.add(dsp.fade(ins.hit(rng, 1.4, metal=0.6, crack=0.3, sub=0.9, space=0.45), 0.0, 0.6), vanish, -11.0)
    # Together: their steps, the sheet, the creature's hearing.
    for k in range(6):
        fx.add(room_verb(ins.footstep(rng, 0.5)), TOGETHER[0] + 0.07 + k * 0.38, -18.0, pan=(-0.3 if k % 2 else 0.3))
    fx.add(ins.paper(rng, 0.6), SHEET[0] - 0.03, -14.0)
    fx.add(ins.pencil(rng, 1.4), SHEET[0] + 0.22, -14.0)
    for k in range(int((VERSUS[1] - VERSUS[0] - 0.15) / 0.28)):
        at = VERSUS[0] + 0.07 + k * 0.28 + rng.uniform(-0.02, 0.02)
        fx.add(dsp.delay(ins.sonar_click(rng), 0.06, 0.4, 0.4), at, -21.0, pan=rng.uniform(-0.2, 0.2))
    shriek = tl.when('versus', 'shriek')
    if shriek is not None:
        fx.add(hall_verb(ins.screech(rng, 1.9, 190, 640), 0.45), shriek, -6.0)
        fx.add(hall_verb(dsp.resample_speed(scream, 0.72), 0.5), shriek + 0.02, -12.0)
        fx.add(ins.hit(rng, 3.0, metal=0.5, crack=0.5, sub=1.0, space=0.5), shriek, -7.0)
    # The montage.
    out = tl.when('blackout', 'blackout')
    if out is not None:
        fx.add(ins.power_cut(rng), out, -3.0)
        fx.add(ins.hit(rng, 2.0, metal=0.2, crack=0.4, sub=1.0, space=0.3), out, -8.0)
    charge_in = tl.clip_start('charge')
    fx.add(ins.braam(rng, 2.5, open_to=1800.0), charge_in, -9.0)
    for k in range(5):
        fx.add(room_verb(ins.claw_step(rng, 1.2)), charge_in + 0.02 + k * 0.14, -8.0)
    fx.add(ins.whoosh(rng, 0.5, 300, 2500, 0.0, 0.0), charge_in + 0.5, -8.0)
    # The blades up in the torchlight.
    strike_in = tl.clip_start('strike')
    fx.add(ins.whoosh(rng, 0.4, 500, 4200, -0.3, 0.3), strike_in - 0.12, -8.0)
    fx.add(ins.hit(rng, 1.6, metal=0.9, crack=0.9, sub=1.0, space=0.3), strike_in, -7.0)
    fx.add(ins.screech(rng, 0.5, 320, 820), strike_in + 0.02, -15.0)
    # Caught: the scream, the arm, the picture gone.
    # The clip starts after the grab itself (shots.gd shot_kill films it from
    # frame 0): the scream starts with the clip, the arm and the lost signal
    # fall on their own frames (hotel_main ARM_TIME 2.58 s, SIGNAL_TIME 2.92 s).
    kill_in = tl.clip_start('kill')
    arm = tl.when_frame('kill', int(round(2.58 * tl.FPS)))
    lost = tl.when_frame('kill', int(round(2.92 * tl.FPS)))
    fx.add(scream, kill_in - 0.03, -2.0)
    fx.add(ins.screech(rng, 1.2, 240, 700), kill_in + 0.05, -12.0)
    if arm is not None:
        fx.add(ins.whoosh(rng, 0.35, 500, 3500, 0.5, -0.5), arm - 0.25, -8.0)
        fx.add(ins.hit(rng, 1.5, metal=0.6, crack=1.0, sub=1.2, space=0.25), arm, -2.0)
    if lost is not None:
        fx.add(dsp.fade(hiss_tv[:n_of(max(0.05, BLACK[0] - lost))], 0.01, 0.0), lost, -3.0)
    # The floor indicator.
    fx.add(dsp.convolve(ins.lift_ding(rng), hallway, wet=0.3), FLOORS[0] + 0.13, -10.0)
    lamps = [e for e in tl.shot_events('floors') if e[1] == 'lamp']
    wrong = [0.943, 0.89, 0.667]
    for k, e in enumerate(lamps):
        at = tl.when_frame('floors', e[0])
        ding = ins.lift_ding(rng, 1318.5 * wrong[k % 3], 1.6)
        if k == 2: ding = dsp.saturate(ding * 2.5, 2.0)
        fx.add(dsp.convolve(ding, hallway, wet=0.3), at, -13.0 + k)
        fx.add(ins.glitch(rng, 0.12), at, -20.0)
    dark = tl.when('floors', 'out')
    if dark is not None:
        fx.add(ins.power_down(rng, 1.3), dark, -8.0)
        fx.add(ins.power_cut(rng), dark, -10.0)
    # The title: the blast as it comes up, the head's tilt.
    fx.add(ins.braam(rng, 2.6), TITLE[0] + 0.18, -9.0)
    fx.add(dsp.fade(ins.hit(rng, 3.0, metal=0.3, crack=0.2, sub=0.9, space=0.6), 0.0, 1.2), TITLE[0] + 0.18, -11.0)
    twitch = tl.when('title', 'twitch')
    if twitch is not None:
        fx.add(chitters[3], twitch, -10.0)
        fx.add(ins.metal_hit(rng, 1.4), twitch, -12.0)
        fx.add(ins.sub_drop(rng, 2.0, 70, 32, 0.3, 1.8), twitch, -10.0)
    return fx


# --- Mix -------------------------------------------------------------------------------------

## Where everything but a breath of reverb stops dead: the cut to black
## before the floor indicator.
SILENCE = BLACK


def silence(x):
    """Hard mute over SILENCE (a 25 ms fade out, a slow fade back in)."""
    n = len(x)
    t = np.arange(n) / SR
    a, b = SILENCE
    gain = np.ones(n)
    out = np.clip((t - a) / 0.025, 0, 1)
    back = np.clip((t - b) / 0.08, 0, 1)
    gain = np.where(t < a, 1.0, np.where(t < b, 1.0 - out, back)) * np.where((t >= a) & (t < b), 1.0, 1.0)
    gain = np.where((t >= a) & (t < b), (1.0 - out) * 0.0 + np.maximum(0.0, 1.0 - (t - a) / 0.025) * 1.0, gain)
    return x * gain[:, None]


def master(voice, music, fx):
    """The mix and the three stems as they sit in it (so they can be
    measured: analyze.py), all at the same final gain."""
    music_p = silence(dsp.duck(music.buf, voice.buf, amount_db=-9.0, attack=0.03, release=0.45, threshold=0.02))
    fx_p = silence(dsp.duck(fx.buf, voice.buf, amount_db=-8.0, attack=0.03, release=0.35, threshold=0.02))
    voice_p = voice.buf * dsp.db(5.5)
    stems = [voice_p, music_p, fx_p]
    stems = [dsp.hp(x, 32, 4) for x in stems]
    mix = sum(stems)
    mix = dsp.eq(mix, 'highshelf', 9000, 0.7, 1.5)
    pre = dsp.compress(mix, threshold=-16.0, ratio=2.0, attack=0.02, release=0.25, makeup=0.0)
    # Loudness first, then the ceiling, then loudness again (the limiter takes
    # a little off).
    gain = dsp.db(-14.0 - dsp.lufs(pre))
    out = pre * gain
    for i in range(3):
        out = dsp.limit(out, -1.0)
        trim = dsp.db(-14.0 - dsp.lufs(out))
        out = out * trim
        gain *= trim
    out = dsp.limit(out, -1.0)
    return out, [x * gain for x in stems]

def main():
    os.makedirs(OUT, exist_ok=True)
    rng = np.random.default_rng(1990)
    voice = voice_track(np.random.default_rng(11))
    music = score(np.random.default_rng(22))
    fx = effects(np.random.default_rng(33))
    mix, stems = master(voice, music, fx)
    for track, stem in zip((voice, music, fx), stems):
        dsp.write(os.path.join(OUT, track.name + '.wav'), stem)
    dsp.write(os.path.join(OUT, 'mix.wav'), mix)
    print('mix: %.2f LUFS, true peak %.2f dBTP, %.1f s' % (dsp.lufs(mix), dsp.true_peak(mix), len(mix) / SR))


if __name__ == '__main__':
    main()
