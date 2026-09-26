"""Picture against sound, measured on the encoded trailer: every hard change of
picture (a cut, a flash, a tear) and every sharp attack in the sound, and
which of the planned beats land within a frame or two of each other.

    python tools/trailer/sync_check.py [evidence/trailer/final/The_Four_trailer_1080p.mp4]"""
import os
import subprocess
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import dsp
import timeline as tl

W, H = 192, 108


def frames(path):
    cmd = [dsp.ffmpeg(), '-v', 'error', '-i', path, '-vf', 'scale=%d:%d' % (W, H), '-f', 'rawvideo', '-pix_fmt', 'gray', '-']
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.uint8).reshape(-1, H, W).astype(np.float32) / 255.0


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(tl.ROOT, 'evidence', 'trailer', 'final', 'The_Four_trailer_1080p.mp4')
    video = frames(path)
    change = np.abs(np.diff(video, axis=0)).mean(axis=(1, 2))
    cuts = [(i + 1) / tl.FPS for i in range(len(change)) if change[i] > max(0.06, 4 * np.median(change[max(0, i - 15):i + 15]))]
    # Attacks are looked for in the effects stem as it sits in the mix (the
    # voice and the score would bury them): energy in 10 ms steps against the
    # 60 ms before, rising by 6 dB or more.
    fx_path = os.path.join(tl.ROOT, 'evidence', 'trailer', 'audio', 'effects.wav')
    audio = dsp.mono(dsp.load(fx_path, mono=False))
    step = dsp.n_of(0.01)
    energy = np.array([np.mean(audio[i:i + step] ** 2) for i in range(0, len(audio) - step, step)])
    level = 10 * np.log10(np.maximum(energy, 1e-10))
    onsets = []
    for i in range(6, len(level)):
        before = level[i - 6:i].max()
        if level[i] - before >= 6.0 and level[i] > -50:
            t = i * 0.01
            if not onsets or t - onsets[-1] > 0.15: onsets.append(t)
    print('%d picture changes, %d sound attacks' % (len(cuts), len(onsets)))
    planned = [(c['at'], c['shot']) for c in tl.CLIPS]
    print('planned cuts, the nearest picture change and sound attack (ms):')
    for at, shot in planned:
        pc = min(cuts, key=lambda c: abs(c - at)) if cuts else None
        so = min(onsets, key=lambda o: abs(o - at)) if onsets else None
        dp = (pc - at) * 1000 if pc is not None else float('nan')
        ds = (so - at) * 1000 if so is not None else float('nan')
        note = ''
        if abs(dp) > 70: note += '  imagen?'
        print('  %6.2f  %-12s  corte %+6.0f   golpe %+6.0f%s' % (at, shot, dp, ds, note))
    for what, shot, name in (('pasillo: mira', 'hall', 'stare'), ('escucha: gira', 'listen', 'snap'), ('tele: se enciende', 'tv_on', 'tv_on'),
                             ('tele: se abalanza', 'tv_locust', 'lunge'), ('cristal', 'intro_glass', 'blow'), ('armario: cierra', 'hide', 'shut'),
                             ('fantasma: se va', 'phantom', 'vanish'), ('versus: chillido', 'versus', 'shriek'), ('apagón', 'blackout', 'blackout'), ('título: tic', 'title', 'twitch')):
        at = tl.when(shot, name)
        if at is None:
            print('  %-20s (no está en el montaje)' % what)
            continue
        so = min(onsets, key=lambda o: abs(o - at)) if onsets else None
        print('  %-20s %6.2f s   golpe más cercano %+6.0f ms' % (what, at, (so - at) * 1000 if so is not None else float('nan')))


if __name__ == '__main__':
    main()
