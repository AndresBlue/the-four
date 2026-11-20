"""The interface's font, made from a pixel font: narrower, and with the
antialiasing of a low picture baked into it.

    python tools/dev/osd_font.py <in.ttf> <out, without extension> <share, e.g. 0.85> ["Family name"] [--soft=0.32] [--size=80] [--dense=0.22] [--dense-size=128]

Writes three fonts:

  <out>.ttf       the pixel font with its outlines and its advances scaled
                  across by the share (and without its SVG copy of the glyphs,
                  which would still be the wide ones);
  <out>-Soft.fnt  that one drawn at --size pixels and blurred by --soft of one
  <out>-Soft.png  of its own cells: a bitmap font (AngelCode's text format)
                  whose letters keep their grid of dots and have greys along
                  the edges of its staircases;
  <out>-Dense.fnt the same for what is written large (a title): drawn at
  <out>-Dense.png --dense-size, blurred by --dense of a cell and then put on
                  a grid of dots twice as fine as the font's own, each dot one
                  grey. Only Latin-1: the rest falls back on the first.

Home Video (assets/fonts/home_video) is drawn on a grid of 50 units, with
strokes two cells thick. Shown large, every diagonal of it is a staircase of
hard squares, and the author saw a game of blocks where he wanted a recording.
What he asked for is antialiasing, not another shape: the squares stay where
they are and their edges go grey, by the same share of a cell at every size.
A filter over the screen cannot do that (it does not know how big the letters
under it are), so it is in the font. Only the glyphs a Spanish interface can
want go into the bitmap; the rest come from the .ttf, which the game sets as
its fallback. Large, a blur by a share of a cell is a blur one can see: a
title came out soft, and the author asked for its dots back, more of them
and smaller, not for the squares of the font itself ("as if I zoomed in on
the interface's text"): that is the third font. For a TrueType font with no
composite glyphs and no kerning.
Needs fontTools and Pillow.
"""
import math, os, sys
from fontTools.ttLib import TTFont
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from PIL import Image, ImageDraw, ImageFilter, ImageFont

## Drawn this many times the size and brought down: the greys are areas, not guesses.
OVER = 4
## Units of the font to a cell of its grid.
CELL = 50
## Latin and its accents, the Cyrillic of a credit, punctuation, arrows,
## signs, boxes, shapes and symbols.
RANGES = [(0x20, 0x24F), (0x400, 0x45F), (0x2000, 0x209F), (0x20A0, 0x20BF), (0x2100, 0x23FF), (0x2500, 0x27BF)]
## What a title is written with.
LATIN = [(0x20, 0x7E), (0xA1, 0xFF)]
## Dots of the dense font to a cell of the font's own grid, down; across they
## are narrower by the share the font was narrowed by, as its cells are.
DENSITY = 2


def narrowed(source, target, share, family):
    font = TTFont(source)
    assert "GPOS" not in font and "kern" not in font, "kerning would have to be scaled too"
    glyphs = font.getGlyphSet()
    table = font["glyf"]
    for name in font.getGlyphOrder():
        pen = TTGlyphPen(None)
        glyphs[name].draw(TransformPen(pen, (share, 0, 0, 1, 0, 0)))
        table[name] = pen.glyph()
    metrics = font["hmtx"].metrics
    for name in metrics:
        table[name].recalcBounds(table)
        metrics[name] = (round(metrics[name][0] * share), table[name].xMin if table[name].numberOfContours else 0)
    font["hhea"].advanceWidthMax = max(advance for advance, _ in metrics.values())
    font["OS/2"].xAvgCharWidth = round(font["OS/2"].xAvgCharWidth * share)
    if "SVG " in font: del font["SVG "]
    if family:
        for record in font["name"].names:
            if record.nameID in (1, 4, 16): record.string = family
            if record.nameID == 6: record.string = family.replace(" ", "")
    font.save(target)
    return len(metrics)


def baked(source, out, size, soft, ranges=RANGES, share=0.0):
    """`share` over 0: the dense font, its dots that much narrower than tall."""
    font = TTFont(source)
    em = font["head"].unitsPerEm
    ascent, descent = font["hhea"].ascent, -font["hhea"].descent
    cmap, metrics = font.getBestCmap(), font["hmtx"].metrics
    codes = [code for code in sorted(cmap) if any(low <= code <= high for low, high in ranges) and metrics[cmap[code]][0] > 0]
    face = ImageFont.truetype(source, size * OVER)
    sigma = soft * CELL / em * size * OVER
    pad = int(math.ceil(3.0 * sigma / OVER)) + 1
    line, base = int(round((ascent + descent) * size / em)), int(round(ascent * size / em))
    wide = max(int(math.ceil(metrics[cmap[code]][0] * size / em)) for code in codes) + pad * 2
    tall = line + pad * 2
    # A dot of the dense font, in the pixels it is drawn in; the letter starts
    # on one and stands on one, so the font's own cells are whole dots.
    dot = (CELL / em * size * OVER / DENSITY * share, CELL / em * size * OVER / DENSITY) if share > 0.0 else (0.0, 0.0)
    left, foot = pad * OVER, (pad + base) * OVER
    if share > 0.0:
        left, foot = math.ceil(left / dot[0]) * dot[0], math.ceil(foot / dot[1]) * dot[1]
        wide, tall = int(math.ceil(wide * OVER / dot[0])), int(math.ceil(tall * OVER / dot[1]))
        grid = (wide, tall)
        over = (int(round(wide * dot[0])), int(round(tall * dot[1])))
        wide, tall = int(math.ceil(over[0] / OVER)), int(math.ceil(over[1] / OVER))
    columns = 2048 // wide
    rows = (len(codes) + columns - 1) // columns
    sheet = Image.new("L", (2048, 1 << (rows * tall - 1).bit_length()), 0)
    lines = [
        'info face="%s" size=%d bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=0,0 outline=0' % (os.path.basename(out), size),
        "common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0 alphaChnl=0 redChnl=4 greenChnl=4 blueChnl=4" % (line, base, sheet.width, sheet.height),
        'page id=0 file="%s.png"' % os.path.basename(out),
        "chars count=%d" % len(codes),
    ]
    for index, code in enumerate(codes):
        x, y = (index % columns) * wide, (index // columns) * tall
        glyph = Image.new("L", (wide * OVER, tall * OVER), 0)
        ImageDraw.Draw(glyph).text((left, foot), chr(code), fill=255, font=face, anchor="ls")
        glyph = glyph.filter(ImageFilter.GaussianBlur(sigma))
        # Each dot the one grey of what falls in it, and its edges kept.
        if share > 0.0: glyph = glyph.crop((0, 0) + over).resize(grid, Image.BOX).resize(over, Image.NEAREST).crop((0, 0, wide * OVER, tall * OVER))
        sheet.paste(glyph.resize((wide, tall), Image.BOX), (x, y))
        lines.append("char id=%d x=%d y=%d width=%d height=%d xoffset=%d yoffset=%d xadvance=%d page=0 chnl=15" % (code, x, y, wide, tall, -int(round(left / OVER)), int(round(base - foot / OVER)), int(round(metrics[cmap[code]][0] * size / em))))
    # White all over, and the letters in the cover: nothing dark to bleed in
    # at their edges when the sheet is read between its pixels.
    picture = Image.merge("RGBA", [Image.new("L", sheet.size, 255)] * 3 + [sheet])
    picture.save(out + ".png", optimize=True)
    open(out + ".fnt", "w", encoding="utf-8", newline="\n").write("\n".join(lines) + "\n")
    return len(codes), sheet.size, sigma / OVER


def main():
    if len(sys.argv) < 4:
        print(__doc__)
        return
    source, out, share = sys.argv[1], sys.argv[2], float(sys.argv[3])
    family = next((piece for piece in sys.argv[4:] if not piece.startswith("--")), "")
    options = dict(piece[2:].split("=", 1) for piece in sys.argv[4:] if piece.startswith("--") and "=" in piece)
    count = narrowed(source, out + ".ttf", share, family)
    kept, sheet, blur = baked(out + ".ttf", out + "-Soft", int(options.get("size", 80)), float(options.get("soft", 0.32)))
    print("OSD FONT %s.ttf: %d glyphs x %.2f across; %s-Soft: %d of them, sheet %dx%d, blurred %.2f px at its size" % (out, count, share, out, kept, sheet[0], sheet[1], blur))
    kept, sheet, blur = baked(out + ".ttf", out + "-Dense", int(options.get("dense-size", 128)), float(options.get("dense", 0.22)), LATIN, share)
    print("OSD FONT %s-Dense: %d glyphs, sheet %dx%d, %d dots to a cell" % (out, kept, sheet[0], sheet[1], DENSITY))


if __name__ == "__main__":
    main()
