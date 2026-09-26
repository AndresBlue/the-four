"""Contact sheets: many frames on one picture, labelled, to judge framing and
motion at a glance.

    python tools/trailer/contact.py <out.png> <images or folders...> [--cols 3] [--width 640] [--every N]

A folder stands for its frames (f_*.png), every Nth of them."""
import sys, os, glob
from PIL import Image, ImageDraw, ImageFont

def main():
    args = sys.argv[1:]
    cols, width, every = 3, 640, 1
    paths = []
    out = args[0]
    # Options first, wherever they were given, so they apply to every path.
    rest = []
    i = 1
    while i < len(args):
        a = args[i]
        if a == '--cols': cols = int(args[i + 1]); i += 2; continue
        if a == '--width': width = int(args[i + 1]); i += 2; continue
        if a == '--every': every = int(args[i + 1]); i += 2; continue
        rest.append(a)
        i += 1
    for a in rest:
        if os.path.isdir(a): paths += sorted(glob.glob(os.path.join(a, 'f_*.png')))[::every]
        else: paths += sorted(glob.glob(a))
    if not paths: sys.exit('nothing to lay out')
    first = Image.open(paths[0])
    height = round(width * first.height / first.width)
    rows = (len(paths) + cols - 1) // cols
    sheet = Image.new('RGB', (cols * width, rows * height), (20, 20, 20))
    font = ImageFont.truetype('C:/Windows/Fonts/consola.ttf', 16)
    draw = ImageDraw.Draw(sheet)
    for n, p in enumerate(paths):
        im = Image.open(p).convert('RGB').resize((width, height), Image.LANCZOS)
        x, y = (n % cols) * width, (n // cols) * height
        sheet.paste(im, (x, y))
        label = os.path.splitext(os.path.basename(p))[0]
        if label.startswith('f_'): label = os.path.basename(os.path.dirname(p)) + ' ' + label
        draw.rectangle((x, y, x + 8 + 9 * len(label), y + 22), fill=(0, 0, 0))
        draw.text((x + 4, y + 3), label, font=font, fill=(255, 230, 120))
    sheet.save(out)
    print(out, sheet.size)

main()
