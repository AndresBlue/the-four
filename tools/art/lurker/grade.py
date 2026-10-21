"""The analogue look of the reference photo, on a render: warm sepia, soft
focus, grain and a vignette. Outside Blender:

    python tools/art/lurker/grade.py in.png out.png [reference.png]

With a reference it also writes out_vs.png, the two side by side.
"""

import sys

import numpy as np
from PIL import Image, ImageFilter


def grade(src):
    im = Image.open(src).convert("RGB")
    im = im.filter(ImageFilter.GaussianBlur(0.8))
    a = np.asarray(im).astype(np.float32) / 255.0
    lum = a @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    sepia = np.stack([lum * 1.05, lum * 0.93, lum * 0.76], axis=-1)
    a = a * 0.45 + sepia * 0.55
    # lift the blacks a touch, as paper does, and press the highlights
    a = 0.025 + a * 0.95
    a = a / (1.0 + 0.25 * a)
    h, w = lum.shape
    yy, xx = np.mgrid[0:h, 0:w]
    r = np.sqrt(((xx - w / 2) / (w / 2)) ** 2 + ((yy - h / 2) / (h / 2)) ** 2)
    a *= (1.0 - 0.32 * np.clip(r - 0.35, 0, 1) ** 1.5)[..., None]
    rng = np.random.default_rng(7)
    grain = rng.normal(0.0, 0.035, (h, w)).astype(np.float32)
    grain = np.asarray(Image.fromarray(((grain + 0.5) * 255).clip(0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6))) / 255.0 - 0.5
    a += grain[..., None] * 0.9
    return Image.fromarray((a.clip(0, 1) * 255).astype(np.uint8))


def main():
    out = grade(sys.argv[1])
    out.save(sys.argv[2])
    if len(sys.argv) > 3:
        ref = Image.open(sys.argv[3]).convert("RGB").resize(out.size)
        both = Image.new("RGB", (out.width * 2 + 12, out.height), (20, 20, 20))
        both.paste(out, (0, 0))
        both.paste(ref, (out.width + 12, 0))
        both.save(sys.argv[2].replace(".png", "_vs.png"))


if __name__ == "__main__":
    main()
