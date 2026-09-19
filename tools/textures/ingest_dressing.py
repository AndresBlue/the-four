"""Decals and paintings for the hotel (docs/REALISM.md, phase 4).

Decals: the ambientCG zips in source_assets/decals/ become
assets/decals/<name>.png, 512 px RGBA: colour, and the decal's opacity in
alpha (from its Opacity map; the footprints take theirs from the relief, the
smear from how far its roughness strays from the mean). Relief decals also get
<name>_normal.png. Imported lossless: Godot copies them into its decal atlas.

Paintings: the Art Institute of Chicago images in source_assets/paintings/
(with info.json) become assets/paintings/<id>.jpg, 1024 px wide, VRAM
compressed, and assets/paintings/paintings.json (title, artist, date, aspect).

Both registers go to docs/ASSETS.md between the DRESSING markers.

    python tools/textures/ingest_dressing.py
"""
import io
import json
import os
import re
import zipfile

from PIL import Image, ImageChops, ImageFilter, ImageOps, ImageStat

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DECALS_IN = os.path.join(ROOT, "source_assets", "decals")
DECALS_OUT = os.path.join(ROOT, "assets", "decals")
PAINTINGS_IN = os.path.join(ROOT, "source_assets", "paintings")
PAINTINGS_OUT = os.path.join(ROOT, "assets", "paintings")
REGISTER = os.path.join(ROOT, "docs", "ASSETS.md")
SIZE = 512
# name: (what it is, alpha from, keep normal)
DECALS = {
    "Leaking001": ("humedad que baja por la pared", "Opacity", True),
    "Leaking003": ("humedad que baja por la pared", "Opacity", True),
    "Leaking005": ("humedad que baja por la pared", "Opacity", True),
    "Leaking008": ("gotera bajo el techo", "Opacity", True),
    "Leaking009": ("gotera bajo el techo", "Opacity", True),
    "ChewingGum001": ("chicles pegados al suelo", "Opacity", True),
    "Fingerprints002": ("huellas de dedos junto a las puertas", "Opacity", False),
    "Fingerprints004": ("huellas de dedos junto a las puertas", "Opacity", False),
    "Smear003": ("manchas en espejos y azulejo", "Roughness", False),
    "Footsteps003": ("pisadas en el suelo", "Displacement", True),
    "SurfaceImperfections001": ("manchas en suelos y paredes", "Opacity", False),
    "SurfaceImperfections013": ("manchas en suelos y paredes", "Opacity", False),
    "SurfaceImperfections017": ("manchas en suelos y paredes", "Opacity", False),
}

IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="{path}"

[params]

compress/mode={mode}
compress/high_quality=false
compress/lossy_quality=0.7
compress/hdr_compression=1
compress/normal_map={normal}
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/size_limit=0
detect_3d/compress_to=0
"""


def write_import(path, res_path, mode, normal):
    if not os.path.exists(path + ".import"):
        with open(path + ".import", "w", newline="\n") as f:
            f.write(IMPORT.format(path=res_path, mode=mode, normal=normal))


def alpha_from(kind, maps):
    if kind == "Opacity":
        return maps["Opacity"].convert("L")
    if kind == "Displacement":
        # Pressed-in prints are the low parts of the relief.
        relief = maps["Displacement"].convert("L")
        mean = ImageStat.Stat(relief).mean[0]
        return relief.point(lambda v: max(0, min(255, int((mean - v) * 6))))
    # Smear: where the roughness strays from the surface's own.
    rough = maps["Roughness"].convert("L")
    mean = ImageStat.Stat(rough).mean[0]
    spread = rough.point(lambda v: min(255, int(abs(v - mean) * 5)))
    return spread.filter(ImageFilter.GaussianBlur(2))


def decals():
    os.makedirs(DECALS_OUT, exist_ok=True)
    rows = []
    for name, (use, alpha_kind, keep_normal) in DECALS.items():
        zip_name = next(f for f in os.listdir(DECALS_IN) if f.startswith(name + "_"))
        archive = zipfile.ZipFile(os.path.join(DECALS_IN, zip_name))
        maps = {}
        for entry in archive.namelist():
            match = re.search(r"_(Color|Opacity|NormalGL|Roughness|Displacement)\.(png|jpg)$", entry)
            if match: maps[match.group(1)] = Image.open(io.BytesIO(archive.read(entry)))
        colour = maps["Color"].convert("RGB").resize((SIZE, SIZE), Image.LANCZOS)
        alpha = alpha_from(alpha_kind, maps).resize((SIZE, SIZE), Image.LANCZOS)
        # A decal's edges must fade out, or its square shows.
        edge = Image.new("L", (SIZE, SIZE), 0)
        edge.paste(255, (24, 24, SIZE - 24, SIZE - 24))
        alpha = ImageChops.multiply(alpha, edge.filter(ImageFilter.GaussianBlur(14)))
        path = os.path.join(DECALS_OUT, name + ".png")
        Image.merge("RGBA", (*colour.split(), alpha)).save(path, optimize=True)
        write_import(path, f"res://assets/decals/{name}.png", 0, 2)
        if keep_normal and "NormalGL" in maps:
            path = os.path.join(DECALS_OUT, name + "_normal.png")
            maps["NormalGL"].convert("RGB").resize((SIZE, SIZE), Image.LANCZOS).save(path, optimize=True)
            write_import(path, f"res://assets/decals/{name}_normal.png", 0, 1)
        rows.append((name, use))
        print("decal", name)
    return rows


def paintings():
    os.makedirs(PAINTINGS_OUT, exist_ok=True)
    info = json.load(open(os.path.join(PAINTINGS_IN, "info.json"), encoding="utf-8"))
    entries = []
    for item in info:
        image = Image.open(os.path.join(PAINTINGS_IN, f"{item['id']}.jpg")).convert("RGB")
        path = os.path.join(PAINTINGS_OUT, f"{item['id']}.jpg")
        image.save(path, quality=90)
        write_import(path, f"res://assets/paintings/{item['id']}.jpg", 2, 2)
        artist = item["artist_display"].split("\n")[0]
        entries.append({"id": item["id"], "title": item["title"], "artist": artist, "date": item["date_display"], "aspect": round(image.width / image.height, 4)})
        print("painting", item["id"], item["title"])
    with open(os.path.join(PAINTINGS_OUT, "paintings.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(entries, f, ensure_ascii=False, indent=1)
    return entries


def register(decal_rows, painting_rows):
    lines = [
        "<!-- DRESSING: generado por tools/textures/ingest_dressing.py, no editar a mano -->",
        "## Decals y cuadros (fase 4 de REALISM.md)",
        "",
        "Decals de ambientCG (Lennart Demes), CC0 1.0, en `assets/decals/` (512 px); originales en `source_assets/decals/`.",
        "",
        "| Decal | Uso |",
        "|---|---|",
    ]
    for name, use in decal_rows:
        lines.append(f"| [{name}](https://ambientcg.com/view?id={name}) | {use} |")
    lines += [
        "",
        "Cuadros: imágenes de dominio público del Art Institute of Chicago (CC0, open access), en `assets/paintings/` (1024 px); originales en `source_assets/paintings/`.",
        "",
        "| Obra | Autor | Fecha |",
        "|---|---|---|",
    ]
    for item in painting_rows:
        lines.append(f"| [{item['title']}](https://www.artic.edu/artworks/{item['id']}) | {item['artist']} | {item['date']} |")
    lines.append("<!-- /DRESSING -->")
    block = "\n".join(lines)
    text = open(REGISTER, encoding="utf-8").read()
    if "<!-- DRESSING" in text:
        text = re.sub(r"<!-- DRESSING.*?<!-- /DRESSING -->", lambda _: block, text, flags=re.S)
    else:
        text = text.replace("\n## Modelos aportados", "\n" + block + "\n\n## Modelos aportados", 1)
    open(REGISTER, "w", encoding="utf-8", newline="\n").write(text)


if __name__ == "__main__":
    register(decals(), paintings())
