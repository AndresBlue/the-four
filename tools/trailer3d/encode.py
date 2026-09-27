"""The trailer's files, from the rendered frames and the mix.

    python tools/trailer3d/encode.py            frames/ + audio/mix.wav -> The_Four_trailer.mp4 (master)
                                                and final/: 1080p, 720p and ligero (under 30 MB, for a phone)
    python tools/trailer3d/encode.py --preview  preview/ (half size) + the mix -> preview.mp4

All paths under evidence/trailer3d/. Needs an ffmpeg with libx264 (audio/dsp.py
finds a known one, or set FFMPEG)."""
import json
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, 'audio'))
from dsp import ffmpeg

ROOT = os.path.dirname(os.path.dirname(HERE))
EVIDENCE = os.path.join(ROOT, 'evidence', 'trailer3d')
with open(os.path.join(HERE, 'timeline.json'), encoding='utf-8') as f:
    FPS = json.load(f)['fps']
BT709 = ['-colorspace', 'bt709', '-color_primaries', 'bt709', '-color_trc', 'bt709']


def run(args):
    subprocess.run([ffmpeg(), '-y', '-v', 'error'] + args, check=True)


def from_frames(folder, out, crf):
    """PNG frames and the mix into one file: x264 tuned for grain, AAC 320k."""
    run(['-framerate', str(FPS), '-i', os.path.join(EVIDENCE, folder, '%05d.png'),
         '-i', os.path.join(EVIDENCE, 'audio', 'mix.wav'),
         '-map', '0:v', '-map', '1:a', '-c:v', 'libx264', '-preset', 'slow', '-crf', str(crf), '-tune', 'grain',
         '-pix_fmt', 'yuv420p'] + BT709 + ['-c:a', 'aac', '-b:a', '320k', '-ar', '48000', '-movflags', '+faststart', '-shortest', out])


def two_pass(master, out, rate, maxrate, bufsize, scale=None, audio=('copy',)):
    """A fixed rate in two passes: the tape's grain is new on every frame, and
    a rate cap keeps the file to its size without starving the dark scenes."""
    vf = ['-vf', 'scale=%s:flags=lanczos' % scale] if scale else []
    with tempfile.TemporaryDirectory() as tmp:
        log = os.path.join(tmp, 'pass')
        run(['-i', master] + vf + ['-c:v', 'libx264', '-preset', 'slow', '-b:v', rate, '-pass', '1', '-passlogfile', log, '-an', '-f', 'null', os.devnull])
        run(['-i', master] + vf + ['-c:v', 'libx264', '-preset', 'slow', '-b:v', rate, '-maxrate', maxrate, '-bufsize', bufsize,
             '-pass', '2', '-passlogfile', log, '-pix_fmt', 'yuv420p'] + BT709 + ['-c:a'] + list(audio) + ['-movflags', '+faststart', out])


def main():
    if '--preview' in sys.argv:
        out = os.path.join(EVIDENCE, 'preview.mp4')
        from_frames('preview', out, 20)
        print(out)
        return
    master = os.path.join(EVIDENCE, 'The_Four_trailer.mp4')
    from_frames('frames', master, 14)
    final = os.path.join(EVIDENCE, 'final')
    os.makedirs(final, exist_ok=True)
    two_pass(master, os.path.join(final, 'The_Four_trailer_1080p.mp4'), '14M', '20M', '28M')
    two_pass(master, os.path.join(final, 'The_Four_trailer_720p.mp4'), '6M', '9M', '12M', '1280:720', ('aac', '-b:a', '192k'))
    two_pass(master, os.path.join(final, 'The_Four_trailer_ligero.mp4'), '3200k', '5M', '7M', '1280:720', ('aac', '-b:a', '160k'))
    for name in sorted(os.listdir(final)):
        print('%-32s %6.1f MB' % (name, os.path.getsize(os.path.join(final, name)) / 1e6))


if __name__ == '__main__':
    main()
