"""The trailer's picture: the filmed shots (tools/trailer/shots.gd) cut to the
edit (timeline.py), with the rule cards, the words on screen, the title and
the end card drawn over them, encoded with the mix (audio.py).

    python tools/trailer/cut.py                 -> evidence/trailer/The_Four_trailer.mp4
    python tools/trailer/cut.py --stills 12.5,30  -> evidence/trailer/stills/*.png only
    python tools/trailer/cut.py --from 40 --to 48 -> a part, for checking
"""
import argparse
import functools
import os
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, os.path.dirname(__file__))
import timeline as tl
from dsp import ffmpeg

W, H = 1920, 1080
OUT = os.path.join(tl.ROOT, 'evidence', 'trailer')
FONTS = 'C:/Windows/Fonts/'
OSD = FONTS + 'consolab.ttf'
SERIF = FONTS + 'GARA.TTF'
VCR_BLUE = (27, 42, 146)
INK = (240, 238, 228)
AMBER = (245, 199, 102)
RED = (238, 72, 52)


# --- Frames of the shots ---------------------------------------------------------------

@functools.lru_cache(maxsize=48)
def shot_frame(shot, index):
    folder = os.path.join(tl.SHOTS, shot)
    path = os.path.join(folder, 'f_%04d.png' % index)
    if not os.path.exists(path):
        frames = sorted(f for f in os.listdir(folder) if f.startswith('f_'))
        path = os.path.join(folder, frames[-1] if index >= 0 else frames[0])
    image = Image.open(path).convert('RGB')
    if image.size != (W, H): image = image.resize((W, H), Image.LANCZOS)
    return np.asarray(image).astype(np.float32) / 255.0


# --- Type ------------------------------------------------------------------------------------

def font(path, size): return ImageFont.truetype(path, size)


def text_width(text, face, tracking):
    return sum(face.getlength(c) for c in text) + tracking * face.size * max(0, len(text) - 1)


def text_layer(text, face, colour, tracking=0.0, pad=40, glow=0.0, shadow=0.8):
    """Text on a transparent layer: numpy (h, w, 4), colour premultiplied by
    alpha, with a soft dark shadow for legibility and an optional glow of its
    own colour."""
    w = int(text_width(text, face, tracking)) + pad * 2
    h = int(face.size * 1.5) + pad * 2
    mask = Image.new('L', (w, h), 0)
    draw = ImageDraw.Draw(mask)
    x = pad
    for ch in text:
        draw.text((x, pad), ch, font=face, fill=255)
        x += face.getlength(ch) + tracking * face.size
    return shade(mask, colour, face.size, glow, shadow)


def shade(mask, colour, size, glow=0.0, shadow=0.8):
    """A white-on-black mask made into a premultiplied RGBA layer with its
    shadow and glow."""
    m = np.asarray(mask).astype(np.float32) / 255.0
    col = np.array(colour, np.float32) / 255.0
    alpha = np.zeros_like(m)
    prem = np.zeros(m.shape + (3,), np.float32)
    if shadow:
        alpha = np.asarray(mask.filter(ImageFilter.GaussianBlur(size * 0.12))).astype(np.float32) / 255.0 * shadow
    if glow:
        g = np.asarray(mask.filter(ImageFilter.GaussianBlur(size * 0.18))).astype(np.float32) / 255.0 * glow
        prem = col * g[..., None] + prem * (1 - g[..., None])
        alpha = g + alpha * (1 - g)
    prem = col * m[..., None] + prem * (1 - m[..., None])
    alpha = m + alpha * (1 - m)
    return np.dstack([prem, alpha])


def play_layer(size=34):
    """The deck's ▶ PLAY (the triangle drawn: the type has no such glyph)."""
    face = font(OSD, size)
    word = 'PLAY'
    w = int(size * 1.2 + text_width(word, face, 0.05)) + 60
    h = int(size * 1.5) + 60
    mask = Image.new('L', (w, h), 0)
    draw = ImageDraw.Draw(mask)
    top, side = 30 + size * 0.22, size * 0.72
    draw.polygon([(30, top), (30, top + side), (30 + side * 0.86, top + side / 2)], fill=255)
    draw.text((30 + size * 1.2, 30), word, font=face, fill=255)
    return shade(mask, INK, size, 0.1, 0.6)

def paste(frame, layer, x, y, alpha=1.0):
    """Composite a premultiplied RGBA layer onto frame at (x, y)."""
    h, w = layer.shape[:2]
    x0, y0 = int(round(x)), int(round(y))
    fx0, fy0 = max(0, x0), max(0, y0)
    fx1, fy1 = min(W, x0 + w), min(H, y0 + h)
    if fx1 <= fx0 or fy1 <= fy0: return
    sub = layer[fy0 - y0:fy1 - y0, fx0 - x0:fx1 - x0]
    a = sub[..., 3:4] * alpha
    region = frame[fy0:fy1, fx0:fx1]
    frame[fy0:fy1, fx0:fx1] = region * (1 - a) + sub[..., :3] * alpha

def chroma(layer, offset=2):
    """The colour fringe of a character generator on tape: red one way, blue
    the other."""
    out = layer.copy()
    out[:, offset:, 0] = layer[:, :-offset, 0]
    out[:, :-offset, 2] = layer[:, offset:, 2]
    return out


@functools.lru_cache(maxsize=64)
def caption_layer(text, red, count):
    face = font(OSD, 58)
    colour = RED if red else INK
    shown = text[:count]
    return chroma(text_layer(shown, face, colour, tracking=0.08, glow=0.4, shadow=1.0), 2)


@functools.lru_cache(maxsize=16)
def feature_layer(text):
    return chroma(text_layer(text, font(OSD, 34), AMBER, tracking=0.14, glow=0.25, shadow=0.9), 1)


def draw_rule(frame, item, t):
    """A caption typed on bottom centre, as a character generator writes."""
    text = item['text']
    typed = int(np.clip((t - item['at']) * 38.0, 0, len(text)))
    if typed <= 0: return
    alpha = np.clip((item['to'] - t) / 0.18, 0, 1)
    layer = caption_layer(text, bool(item.get('red')), typed)
    full = caption_layer(text, bool(item.get('red')), len(text))
    x = (W - full.shape[1]) / 2
    paste(frame, layer, x, H - 215, alpha)
    # The cursor while it types.
    if typed < len(text) and int(t * 12) % 2 == 0:
        face = font(OSD, 58)
        cx = x + 40 + text_width(text[:typed], face, 0.08) + 0.08 * 58
        y0 = H - 215 + 50
        frame[y0:y0 + 60, int(cx):int(cx) + 30] = frame[y0:y0 + 60, int(cx):int(cx) + 30] * (1 - alpha) + np.array(INK) / 255.0 * alpha


def draw_feature(frame, item, t):
    alpha = min(np.clip((t - item['at']) / 0.25, 0, 1), np.clip((item['to'] - t) / 0.25, 0, 1))
    layer = feature_layer(item['text'])
    x, y = 96, 110
    # A dark plate under it, so it reads on the paper of the sheet as well as
    # on the dark of a corridor.
    w = layer.shape[1] - 80
    y0, y1, x0, x1 = y - 22, y + 58, x - 24, x + w + 24
    frame[y0:y1, x0:x1] *= 1 - 0.55 * alpha
    paste(frame, layer, x - 40, y - 40, alpha)
    # A thin rule above it.
    width = int(min(layer.shape[1] - 80, 520) * np.clip((t - item['at']) / 0.35, 0, 1))
    frame[y - 12:y - 10, x:x + width] = frame[y - 12:y - 10, x:x + width] * (1 - alpha) + np.array(AMBER) / 255.0 * alpha


# --- Cards -----------------------------------------------------------------------------------

def tape_texture(frame, rng, lines=0.08, grain=0.035):
    """Scanlines and grain, so drawn cards sit on the same tape as the shots."""
    frame[::2] *= (1 - lines)
    frame += rng.normal(0, grain, frame.shape[:2])[..., None].astype(np.float32)
    return frame


@functools.lru_cache(maxsize=8)
def rule_card_base(number):
    card = np.zeros((H, W, 3), np.float32) + np.array(VCR_BLUE, np.float32) / 255.0
    # A little darker at the edges, as a tube's picture is.
    yy, xx = np.mgrid[0:H, 0:W]
    vignette = 1 - 0.25 * (((xx - W / 2) / (W / 2)) ** 2 + ((yy - H / 2) / (H / 2)) ** 2)
    card *= vignette[..., None].astype(np.float32)
    label = chroma(text_layer('NORMA', font(OSD, 46), INK, tracking=0.5, glow=0.2, shadow=0.7), 2)
    big = chroma(text_layer(number, font(OSD, 250), INK, tracking=0.0, glow=0.25, shadow=0.8), 3)
    paste(card, label, (W - label.shape[1]) / 2 + 12, H / 2 - 250)
    paste(card, big, (W - big.shape[1]) / 2, H / 2 - 190)
    corner = text_layer('%s/4' % number, font(OSD, 34), INK, tracking=0.1, glow=0.1, shadow=0.6)
    paste(card, corner, W - 250, 40)
    paste(card, play_layer(34), 26, 10)
    return card


def rule_card(number, local, rng):
    card = rule_card_base(number).copy()
    # It comes on in a jolt: the first frames roll up a little.
    if local < 0.1:
        shift = int((0.1 - local) * 900)
        card = np.roll(card, -shift, axis=0)
    return tape_texture(card, rng, 0.07, 0.03)


@functools.lru_cache(maxsize=1)
def end_card_base():
    card = np.zeros((H, W, 3), np.float32)
    logo = text_layer('THE FOUR', font(OSD, 120), INK, tracking=0.32, glow=0.3, shadow=0.0)
    paste(card, logo, (W - logo.shape[1]) / 2, 250)
    sub = text_layer('PISO 1  ·  THE LOCUST', font(OSD, 36), AMBER, tracking=0.4, glow=0.2, shadow=0.0)
    paste(card, sub, (W - sub.shape[1]) / 2, 450)
    line = text_layer('COOPERATIVO DE 2 A 5  ·  VERSUS  ·  PC', font(OSD, 34), INK, tracking=0.12, glow=0.1, shadow=0.0)
    paste(card, line, (W - line.shape[1]) / 2, 560)
    dev = text_layer('EN DESARROLLO', font(OSD, 34), INK, tracking=0.35, glow=0.1, shadow=0.0)
    paste(card, dev, (W - dev.shape[1]) / 2, 640)
    small = font(OSD, 20)
    for k, words in enumerate(['PROYECTO FAN NO OFICIAL.  THE LOCUST: PERSONAJE DE DOCTOR NOWHERE, MODELO DE DOUMTY.',
                               'GRITO: «JUMPSCARE SOUND», ENCLOSUREX_STUDIOS (CC BY 4.0).  IMAGEN CAPTURADA EN EL MOTOR DEL JUEGO.']):
        layer = text_layer(words, small, (150, 148, 140), tracking=0.06, glow=0.0, shadow=0.0, pad=10)
        paste(card, layer, (W - layer.shape[1]) / 2, 900 + k * 34)
    return card


# --- The title ---------------------------------------------------------------------------------

@functools.lru_cache(maxsize=1)
def title_layers():
    logo = chroma(text_layer('THE FOUR', font(OSD, 112), INK, tracking=0.26, glow=0.45, shadow=0.9), 3)
    sub = chroma(text_layer('PISO 1  ·  THE LOCUST', font(OSD, 30), AMBER, tracking=0.34, glow=0.3, shadow=0.9), 2)
    return logo, sub


def draw_title(frame, local, rng):
    """THE FOUR on the wall beside the door, arriving with the blast."""
    logo, sub = title_layers()
    start = 0.18
    if local < start: return
    k = local - start
    # It flickers on, like a tube warming: two false starts, then steady.
    flicker = 1.0
    if k < 0.3: flicker = [0.0, 0.8, 0.1, 0.0, 1.0, 0.3, 1.0, 1.0, 0.6][min(8, int(k * 30))]
    x, y = 70, 640
    jitter = rng.integers(-2, 3) if k < 0.4 else 0
    paste(frame, logo, x + jitter, y, flicker)
    sub_alpha = np.clip((k - 0.9) / 0.6, 0, 1)
    paste(frame, sub, x + 8, y + 158, sub_alpha)


# --- Transitions -------------------------------------------------------------------------------

def tear(frame, amount, rng):
    """Tape tearing: bands of the picture thrown sideways, the colours split,
    a white line of dropout."""
    out = frame.copy()
    bands = int(6 + 20 * amount)
    for _ in range(bands):
        y0 = rng.integers(0, H - 10)
        h = rng.integers(6, int(20 + 120 * amount))
        dx = int(rng.normal(0, 180 * amount))
        out[y0:y0 + h] = np.roll(out[y0:y0 + h], dx, axis=1)
    s = int(4 + 20 * amount)
    out[:, s:, 0] = out[:, :-s, 0]
    out[:, :-s, 2] = out[:, s:, 2]
    for _ in range(int(3 * amount) + 1):
        y = rng.integers(0, H - 3)
        out[y:y + 2] = np.clip(out[y:y + 2] + 0.8, 0, 1)
    out += rng.normal(0, 0.12 * amount, out.shape[:2])[..., None]
    return out


# --- The cut ---------------------------------------------------------------------------------------

def render_frame(index):
    t = index / tl.FPS
    rng = np.random.default_rng(index * 7919 + 13)
    clip = tl.clip_at(t)
    if clip is None: return np.zeros((H, W, 3), np.float32)
    local = t - clip['at']
    shot = clip['shot']
    if shot == 'card':
        frame = rule_card(clip['card'], local, rng)
    elif shot == 'black':
        frame = np.zeros((H, W, 3), np.float32)
    elif shot == 'endcard':
        frame = end_card_base().copy() * np.clip(local / 0.25, 0, 1)
        frame = tape_texture(frame, rng, 0.05, 0.02)
    else:
        src = clip.get('src', 0) + int(round(local * tl.FPS))
        frame = shot_frame(shot, src).copy()
    fx = clip.get('fx', [])
    remaining = clip['len'] - local
    if 'fadein' in fx: frame *= np.clip(local / 0.45, 0, 1)
    if 'fadein_fast' in fx: frame *= np.clip(local / 0.12, 0, 1)
    if 'fadeout' in fx: frame *= np.clip(remaining / 0.7, 0, 1) ** 1.5
    if 'flash' in fx and local < 2.0 / tl.FPS:
        frame = frame + (1 - frame) * (0.85 if local < 1.0 / tl.FPS else 0.35)
    if 'tear' in fx and remaining < 5.0 / tl.FPS:
        frame = tear(frame, 1.0 - remaining / (5.0 / tl.FPS), rng)
    # The frame after a tear keeps a little of it.
    previous = tl.clip_at(t - 1.5 / tl.FPS)
    if previous is not None and previous is not clip and 'tear' in previous.get('fx', []) and local < 2.0 / tl.FPS:
        frame = tear(frame, 0.6 if local < 1.0 / tl.FPS else 0.25, rng)
    if shot == 'title': draw_title(frame, local, rng)
    for item in tl.TEXT:
        if not (item['at'] <= t < item['to']): continue
        if item['kind'] == 'rule': draw_rule(frame, item, t)
        elif item['kind'] == 'feature': draw_feature(frame, item, t)
    return np.clip(frame, 0, 1)


def to_bytes(frame):
    return (frame * 255.0 + 0.5).astype(np.uint8).tobytes()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--stills', default='')
    parser.add_argument('--from', dest='start', type=float, default=0.0)
    parser.add_argument('--to', dest='end', type=float, default=tl.LENGTH)
    parser.add_argument('--out', default=os.path.join(OUT, 'The_Four_trailer.mp4'))
    parser.add_argument('--audio', default=os.path.join(OUT, 'audio', 'mix.wav'))
    args = parser.parse_args()
    if args.stills:
        folder = os.path.join(OUT, 'stills')
        os.makedirs(folder, exist_ok=True)
        for value in args.stills.split(','):
            index = tl.frame(float(value))
            Image.fromarray((render_frame(index) * 255 + 0.5).astype(np.uint8)).save(os.path.join(folder, 'still_%06.2f.png' % float(value)))
        print('stills in', folder)
        return
    first, last = tl.frame(args.start), min(tl.frames_total(), tl.frame(args.end))
    cmd = [ffmpeg(), '-y', '-v', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', '%dx%d' % (W, H), '-r', str(tl.FPS), '-i', '-']
    has_audio = os.path.exists(args.audio)
    if has_audio: cmd += ['-ss', '%.3f' % args.start, '-t', '%.3f' % ((last - first) / tl.FPS), '-i', args.audio]
    cmd += ['-map', '0:v']
    if has_audio: cmd += ['-map', '1:a', '-c:a', 'aac', '-b:a', '320k', '-ar', '48000']
    cmd += ['-c:v', 'libx264', '-preset', 'slow', '-crf', '14', '-tune', 'grain', '-pix_fmt', 'yuv420p',
            '-colorspace', 'bt709', '-color_primaries', 'bt709', '-color_trc', 'bt709', '-movflags', '+faststart', '-shortest', args.out]
    process = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    for index in range(first, last):
        process.stdin.write(to_bytes(render_frame(index)))
        if index % 150 == 0: print('frame', index, '/', last, flush=True)
    process.stdin.close()
    process.wait()
    print('wrote', args.out)


if __name__ == '__main__':
    main()
