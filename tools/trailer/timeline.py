"""The trailer's edit, in one place: which frames of which shot go where, what
the voice says when, what is written on screen and where the sound hits.
tools/trailer/cut.py builds the picture from it and tools/trailer/audio.py
the sound, so the two can never drift apart.

Times are seconds on the trailer's clock; a clip's `src` is the first frame of
its shot it uses (evidence/trailer/shots/<shot>/f_NNNN.png, 30 fps).
"""
import json
import os

FPS = 30
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SHOTS = os.path.join(ROOT, 'evidence', 'trailer', 'shots')

# --- Picture -------------------------------------------------------------------
# at, shot, src (first frame), length (s); `card` clips are drawn by cut.py.
# fx: 'fadein' (from black), 'fadeout' (to black), 'flash' (white frame on the
# cut), 'tear' (tape tear into the next clip), 'hold' (freeze on its last frame).
CLIPS = [
    # The tape starts: headphones, the VCR blue, the picture breaking up.
    dict(at=0, shot='boot', src=18, len=1.30, fx=['fadein']),
    dict(at=1.3, shot='boot', src=98, len=1.35),
    dict(at=2.65, shot='boot', src=140, len=1.20, fx=['tear']),
    # Welcome: the corridor, and down it, something that stops to look.
    dict(at=3.85, shot='hall', src=33, len=6.80),
    # Rule one.
    dict(at=10.65, shot='card', card='1', len=0.62),
    dict(at=11.27, shot='run', src=8, len=2.50),
    dict(at=13.77, shot='listen', src=10, len=3.10),
    # Rule two.
    dict(at=16.87, shot='card', card='2', len=0.62),
    dict(at=17.49, shot='tv_on', src=0, len=2.45),
    dict(at=19.94, shot='tv_locust', src=4, len=2.95),
    dict(at=22.89, shot='intro_glass', src=6, len=0.55, fx=['flash']),
    # Rule three.
    dict(at=23.44, shot='card', card='3', len=0.62),
    dict(at=24.06, shot='hide', src=0, len=5.75),
    # Rule four.
    dict(at=29.81, shot='card', card='4', len=0.62),
    dict(at=30.43, shot='phantom', src=40, len=4.50, fx=['tear']),
    # Together, the sheet, or one of you is it.
    dict(at=34.93, shot='together', src=10, len=2.15),
    dict(at=37.08, shot='sheet', src=18, len=1.55),
    dict(at=38.63, shot='versus', src=16, len=3.45),
    # The montage.
    # On the montage's pulse (138 bpm quavers, audio.py): cuts on 0, 3, 7, 9.
    dict(at=42.08, shot='blackout', src=8, len=0.652),
    dict(at=42.732, shot='charge', src=22, len=0.870, fx=['flash']),
    dict(at=43.602, shot='strike', src=2, len=0.435, fx=['flash']),
    dict(at=44.037, shot='kill', src=10, len=2.833),
    # Silence, then the floor indicator.
    dict(at=46.87, shot='black', len=0.85),
    dict(at=47.72, shot='floors', src=0, len=5.55),
    # The title over the room with the door ajar.
    dict(at=53.27, shot='title', src=0, len=4.60, fx=['fadein_fast']),
    dict(at=57.87, shot='endcard', len=2.13, fx=['fadeout']),
]
LENGTH = 60.0

# --- The voice (tools/trailer/voice.ps1 ids) -------------------------------------
VOICE = [
    ('bienvenidos', 4.8),
    ('normas', 7.05),
    ('n1', 10.72),
    ('r1', 11.45),
    ('oye', 14.9),
    ('n2', 16.94),
    ('r2', 17.45),
    ('usa', 20.55),
    ('n3', 23.6),
    ('r3', 24.25),
    ('entrar', 28.35),
    ('n4', 29.88),
    ('r4', 33.95),
    ('juntos', 35.55),
    ('uno_de', 38.7),
    ('primer', 48.35),
    ('quedan', 50.35),
    ('estancia', 55.6),
]

# --- Words on screen -------------------------------------------------------------
# kind: 'rule' (a caption typed on over the picture), 'feature' (a small
# line in the corner), 'title', 'end'. from/to in trailer seconds.
TEXT = [
    dict(kind='rule', text='NO CORRAN POR LOS PASILLOS', at=11.45, to=13.7),
    dict(kind='rule', text='ÉL LES OYE', at=14.9, to=16.8, red=True),
    dict(kind='rule', text='ENCIENDAN LOS TELEVISORES', at=17.45, to=19.9),
    dict(kind='rule', text='ÉL TAMBIÉN LOS USA', at=20.55, to=22.85, red=True),
    dict(kind='rule', text='SI LES PERSIGUE, ESCÓNDANSE', at=24.25, to=27.4),
    dict(kind='rule', text='QUE NADIE LES VEA ENTRAR', at=28.35, to=29.75, red=True),
    dict(kind='rule', text='NO CREAN TODO LO QUE VEN', at=33.95, to=34.9),
    dict(kind='feature', text='COOPERATIVO · DE 2 A 5 JUGADORES', at=35.1, to=37.05),
    dict(kind='feature', text='UN HOTEL DISTINTO EN CADA PARTIDA', at=37.12, to=38.6),
    dict(kind='feature', text='VERSUS · UNO DE USTEDES ES THE LOCUST', at=38.8, to=42),
]

def frame(seconds):
    return int(round(seconds * FPS))

def frames_total():
    return frame(LENGTH)

def shot_events(shot):
    """The marks a shot left when it was filmed (shots.gd mark())."""
    path = os.path.join(SHOTS, shot, 'events.json')
    if not os.path.exists(path): return []
    with open(path, encoding='utf-8') as f:
        return json.load(f).get('events', [])

def when(shot, what, nth=0):
    """Trailer time of a shot's event, through the first clip of that shot
    that contains it; None if no clip shows it."""
    found = [e for e in shot_events(shot) if e[1] == what]
    if len(found) <= nth: return None
    at_frame = found[nth][0]
    for clip in CLIPS:
        if clip.get('shot') != shot: continue
        start = clip.get('src', 0)
        if start <= at_frame < start + clip['len'] * FPS:
            return clip['at'] + (at_frame - start) / FPS
    return None

def when_frame(shot, at_frame):
    """Trailer time of a frame of a shot, through the clip that shows it."""
    for clip in CLIPS:
        if clip.get('shot') != shot: continue
        start = clip.get('src', 0)
        if start <= at_frame < start + clip['len'] * FPS:
            return clip['at'] + (at_frame - start) / FPS
    return None

def clip_start(shot):
    return next(c for c in CLIPS if c.get('shot') == shot)['at']

def kill_grab():
    """The grab is the kill shot's frame 0 (shots.gd shot_kill), even when the
    clip starts after it."""
    clip = next(c for c in CLIPS if c.get('shot') == 'kill')
    return clip['at'] - clip.get('src', 0) / FPS

def clip_at(seconds):
    for clip in CLIPS:
        if clip['at'] <= seconds < clip['at'] + clip['len']: return clip
    return None
