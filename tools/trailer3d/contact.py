"""Contact sheet of rendered stills, to review a shot at a glance.
    python contact.py stills/14.90s.png stills/15.80s.png ... [--cols 4] [--width 480] [--out sheet.png]
Paths are relative to evidence/trailer3d/. Writes evidence/trailer3d/contact.png by default."""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parents[2] / "evidence" / "trailer3d"
args = sys.argv[1:]
cols, width, out = 4, 480, "contact.png"
paths = []
i = 0
while i < len(args):
    a = args[i]
    if a == "--cols": cols = int(args[i + 1]); i += 2; continue
    if a == "--width": width = int(args[i + 1]); i += 2; continue
    if a == "--out": out = args[i + 1]; i += 2; continue
    paths.append(a); i += 1
images = [Image.open(root / p).convert("RGB") for p in paths]
h = int(width * images[0].height / images[0].width)
rows = (len(images) + cols - 1) // cols
sheet = Image.new("RGB", (cols * width, rows * (h + 22)), (18, 18, 18))
draw = ImageDraw.Draw(sheet)
try:
    font = ImageFont.truetype("consola.ttf", 16)
except OSError:
    font = ImageFont.load_default()
for k, (p, im) in enumerate(zip(paths, images)):
    x, y = (k % cols) * width, (k // cols) * (h + 22)
    sheet.paste(im.resize((width, h), Image.LANCZOS), (x, y + 22))
    draw.text((x + 6, y + 3), Path(p).stem, fill=(220, 220, 210), font=font)
sheet.save(root / out)
print(root / out)
