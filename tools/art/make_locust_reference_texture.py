"""Recolours The Locust's texture after the reference picture
(assets/images/the-locust.png): an ink-black body under a pale, warm mask of a
face with hollow eyes and a dark mouth. The model's own face island is kept and
re-graded; everything else goes to near black with a trace of its detail.

Writes assets/enemies/locust_reference_basecolor.png; the original is untouched.

    python tools/art/make_locust_reference_texture.py
"""
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/enemies/locust_locust_by-doumty_basecolor_tex.png"
TARGET = ROOT / "assets/enemies/locust_reference_basecolor.png"
FACE_SEED = (150, 770)  # (row, column) inside the face island


def island(lum, seed, threshold=0.12):
    mask = np.zeros(lum.shape, bool)
    queue = deque([seed])
    mask[seed] = True
    height, width = lum.shape
    while queue:
        y, x = queue.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < height and 0 <= nx < width and not mask[ny, nx] and lum[ny, nx] > threshold:
                mask[ny, nx] = True
                queue.append((ny, nx))
    return mask


def main():
    source = np.array(Image.open(SOURCE).convert("RGBA")).astype(np.float64) / 255.0
    rgb = source[..., :3]
    lum = rgb.mean(axis=2)
    face = island(lum, FACE_SEED)
    ys, xs = np.nonzero(face)
    top, bottom, left, right = ys.min(), ys.max(), xs.min(), xs.max()
    # Holes inside the face box (eyes, mouth) are part of the face too.
    box = np.zeros_like(face)
    box[top:bottom + 1, left:right + 1] = True
    filled = np.array(Image.fromarray((face * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.MinFilter(9))) > 0
    face_area = filled & box
    # Body: ink black keeping a faint trace of the original detail.
    out = rgb * 0.06 + np.array([0.018, 0.014, 0.014])
    # Face: pale warm skin graded from the original shading, rosier towards the edges.
    shade = np.clip((lum - 0.25) / 0.7, 0.0, 1.0)[..., None]
    skin = np.array([0.93, 0.80, 0.70]) * (0.55 + 0.45 * shade) + np.array([0.06, -0.02, -0.03]) * (1.0 - shade)
    holes = face_area & (lum < 0.3)
    # Hollow eyes and mouth: wider and darker than the model's pin-prick eyes.
    grown = np.array(Image.fromarray((holes * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(7)).filter(ImageFilter.GaussianBlur(1.5))).astype(np.float64)[..., None] / 255.0
    face_colour = skin * (1.0 - grown) + np.array([0.05, 0.015, 0.012]) * grown
    weight = np.array(Image.fromarray((face_area * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2.0))).astype(np.float64)[..., None] / 255.0
    out = out * (1.0 - weight) + face_colour * weight
    result = np.concatenate([np.clip(out, 0, 1), source[..., 3:4]], axis=2)
    Image.fromarray((result * 255).astype(np.uint8), "RGBA").save(TARGET, optimize=True)
    print("face island", left, right, top, bottom, "->", TARGET.name)


if __name__ == "__main__":
    main()
