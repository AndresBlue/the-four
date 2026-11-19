"""A font made narrower: every outline and every advance by the same share.

    python tools/dev/condense_font.py <in.ttf> <out.ttf> <share, e.g. 0.85> ["Family name"]

For a TrueType font with no composite glyphs and no kerning tables (Home
Video, assets/fonts/home_video): its outlines are scaled across, its
advances with them, and its SVG copy of the glyphs, which would still be the
wide ones, is dropped. Needs fontTools.
"""
import sys
from fontTools.ttLib import TTFont
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen


def main():
    if len(sys.argv) < 4:
        print(__doc__)
        return
    source, target, share = sys.argv[1], sys.argv[2], float(sys.argv[3])
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
    if len(sys.argv) > 4:
        for record in font["name"].names:
            if record.nameID in (1, 4, 16): record.string = sys.argv[4]
            if record.nameID == 6: record.string = sys.argv[4].replace(" ", "")
    font.save(target)
    print("CONDENSED %s -> %s x %.2f, %d glyphs" % (source, target, share, len(metrics)))


if __name__ == "__main__":
    main()
