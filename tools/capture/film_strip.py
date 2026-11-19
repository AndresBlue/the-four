"""Frames of a film the engine's movie writer made (an AVI, one JPEG a frame;
tools/capture/tape_movie.gd), laid out on a sheet to be looked at one by one,
and as a GIF to be watched.

    python tools/capture/film_strip.py <film.avi> <out, without extension> [--from=0] [--to=0] [--every=3] [--columns=6] [--wide=420] [--gif-every=4] [--gif-wide=480] [--fps=60]

--from and --to are frames (0 for --to is the last one); --every and
--gif-every take one frame in so many. Needs Pillow.
"""
import io, struct, sys
from PIL import Image, ImageDraw


def frames_of(path):
    data = open(path, "rb").read()
    assert data[:4] == b"RIFF" and data[8:12] == b"AVI ", "not an AVI"
    found = []

    def walk(start, end):
        at = start
        while at + 8 <= end:
            tag = data[at:at + 4]
            size = struct.unpack("<I", data[at + 4:at + 8])[0]
            if tag == b"LIST": walk(at + 12, at + 8 + size)
            elif tag[2:] in (b"dc", b"db") and size > 0: found.append((at + 8, size))
            at += 8 + size + (size & 1)
    walk(12, len(data))
    return data, found


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return
    options = dict(piece[2:].split("=", 1) for piece in sys.argv[3:] if piece.startswith("--") and "=" in piece)
    data, found = frames_of(sys.argv[1])
    first = int(options.get("from", 0))
    last = int(options.get("to", 0)) or len(found)
    fps = float(options.get("fps", 60))

    def picture(index, wide):
        at, size = found[index]
        image = Image.open(io.BytesIO(data[at:at + size])).convert("RGB")
        return image.resize((wide, int(image.height * wide / image.width)), Image.LANCZOS)

    every, columns, wide = int(options.get("every", 3)), int(options.get("columns", 6)), int(options.get("wide", 420))
    picked = list(range(first, last, every))
    cells = [picture(index, wide) for index in picked]
    tall = cells[0].height + 14
    sheet = Image.new("RGB", (columns * (wide + 4) + 4, ((len(cells) + columns - 1) // columns) * tall + 4), (40, 40, 40))
    draw = ImageDraw.Draw(sheet)
    for i, cell in enumerate(cells):
        x, y = 4 + (i % columns) * (wide + 4), 4 + (i // columns) * tall
        draw.text((x + 2, y), "%d  %.2f s" % (picked[i], picked[i] / fps), fill=(255, 255, 0))
        sheet.paste(cell, (x, y + 12))
    sheet.save(sys.argv[2] + ".png")
    step, gif_wide = int(options.get("gif-every", 4)), int(options.get("gif-wide", 480))
    moving = [picture(index, gif_wide).quantize(colors=128, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE) for index in range(first, last, step)]
    moving[0].save(sys.argv[2] + ".gif", save_all=True, append_images=moving[1:], duration=int(1000.0 * step / fps), loop=0, optimize=False)
    print("FILM %s: %d frames; sheet of %d, gif of %d" % (sys.argv[1], len(found), len(cells), len(moving)))


if __name__ == "__main__":
    main()
