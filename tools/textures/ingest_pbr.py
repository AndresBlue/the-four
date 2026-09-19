"""Scanned material sets for the hotel (docs/REALISM.md, phase 3).

Reads the downloads in source_assets/textures/ (outside git) and writes each
set to assets/textures/<set>/ the way the game loads it:

    albedo.jpg    colour, sRGB
    normal.jpg    normal map, OpenGL convention (green up)
    orm.jpg       occlusion, roughness, metalness in R, G, B
    *_1k.jpg      the same at 1024 px, for the Bajo preset

with a .import beside each image (VRAM compressed, mipmaps; normals as a
normal map), so Godot imports them right the first time. The register of
every set (source, authors, licence) is written to docs/ASSETS.md between
the SCANS markers.

Downloads: Poly Haven sets are the 2K JPG diffuse, nor_gl and arm maps in
source_assets/textures/<id>/ (with the asset's info.json); ambientCG sets are
the 2K-JPG zip, source_assets/textures/<id>_2K-JPG.zip.

    python tools/textures/ingest_pbr.py
"""
import io
import json
import os
import re
import zipfile

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SOURCE = os.path.join(ROOT, "source_assets", "textures")
TARGET = os.path.join(ROOT, "assets", "textures")
REGISTER = os.path.join(ROOT, "docs", "ASSETS.md")

# set: (source, id, what it is in the hotel)
SETS = {
    "carpet016": ("ambientcg", "Carpet016", "pelo de la moqueta, bajo el medallón procedural"),
    "wallpaper001a": ("ambientcg", "Wallpaper001A", "papel de las paredes, bajo el motivo procedural"),
    "decrepit_wallpaper": ("polyhaven", "decrepit_wallpaper", "paredes de salones vacíos y almacenes"),
    "ceiling_interior": ("polyhaven", "ceiling_interior", "techo de estuco"),
    "officeceiling001": ("ambientcg", "OfficeCeiling001", "falso techo de lavandería, almacén, mantenimiento y oficina"),
    "lacquered_cherry_wood": ("polyhaven", "lacquered_cherry_wood", "muebles de madera"),
    "dark_wood": ("polyhaven", "dark_wood", "arrimaderos y molduras"),
    "tiles036": ("ambientcg", "Tiles036", "azulejo de baños y zonas de servicio"),
    "metal048b": ("ambientcg", "Metal048B", "latón"),
    "velour_velvet": ("polyhaven", "velour_velvet", "tapicería"),
    "quatrefoil_jacquard_fabric": ("polyhaven", "quatrefoil_jacquard_fabric", "colchas"),
    "brown_leather": ("polyhaven", "brown_leather", "maletas"),
}

SIZES = {"": 2048, "_1k": 1024}
QUALITY = 92

IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="res://assets/textures/{set}/{file}"

[params]

compress/mode=2
compress/high_quality=false
compress/lossy_quality=0.7
compress/hdr_compression=1
compress/normal_map={normal}
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
process/fix_alpha_border=false
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/size_limit=0
detect_3d/compress_to=0
"""


def polyhaven(set_id):
    folder = os.path.join(SOURCE, set_id)
    files = os.listdir(folder)

    def pick(pattern):
        return Image.open(os.path.join(folder, next(f for f in files if re.search(pattern, f))))

    info = json.load(open(os.path.join(folder, "info.json"), encoding="utf-8"))
    maps = {
        "albedo": pick(r"_(diff|albedo)_2k\.jpg$").convert("RGB"),
        "normal": pick(r"_nor_gl_2k\.jpg$").convert("RGB"),
        "orm": pick(r"_arm_2k\.jpg$").convert("RGB"),
    }
    credit = {
        "name": info["name"],
        "authors": ", ".join(info["authors"]),
        "url": "https://polyhaven.com/a/" + set_id,
        "source": "Poly Haven",
        "metres": info["dimensions"][0] / 1000.0 if info.get("dimensions") else None,
    }
    return maps, credit


def ambientcg(asset):
    archive = zipfile.ZipFile(os.path.join(SOURCE, asset + "_2K-JPG.zip"))
    names = archive.namelist()

    def read(suffix, mode):
        name = next((n for n in names if n.endswith("_" + suffix + ".jpg")), None)
        return Image.open(io.BytesIO(archive.read(name))).convert(mode) if name else None

    colour = read("Color", "RGB")
    size = colour.size
    occlusion = read("AmbientOcclusion", "L") or Image.new("L", size, 255)
    roughness = read("Roughness", "L") or Image.new("L", size, 128)
    metalness = read("Metalness", "L") or Image.new("L", size, 0)
    maps = {
        "albedo": colour,
        "normal": read("NormalGL", "RGB"),
        "orm": Image.merge("RGB", [occlusion.resize(size), roughness.resize(size), metalness.resize(size)]),
    }
    credit = {
        "name": asset,
        "authors": "Lennart Demes (ambientCG)",
        "url": "https://ambientcg.com/view?id=" + asset,
        "source": "ambientCG",
        "metres": None,
    }
    return maps, credit


def write(set_name, maps):
    folder = os.path.join(TARGET, set_name)
    os.makedirs(folder, exist_ok=True)
    total = 0
    for suffix, size in SIZES.items():
        for kind, image in maps.items():
            file = kind + suffix + ".jpg"
            path = os.path.join(folder, file)
            image.resize((size, size), Image.LANCZOS).save(path, quality=QUALITY, subsampling=0 if kind != "albedo" else 2)
            total += os.path.getsize(path)
            import_path = path + ".import"
            # Godot keeps the uid and the params it finds; only a new image
            # gets a fresh .import.
            if not os.path.exists(import_path):
                with open(import_path, "w", newline="\n") as f:
                    f.write(IMPORT.format(set=set_name, file=file, normal=1 if kind == "normal" else 2))
    return total


def register(rows):
    lines = [
        "<!-- SCANS: generado por tools/textures/ingest_pbr.py, no editar a mano -->",
        "## Materiales escaneados (fase 3 de REALISM.md)",
        "",
        "Todos CC0 (dominio público): no exigen atribución, se acreditan igualmente. Descargas originales en `source_assets/textures/` (fuera de git); en `assets/textures/<set>/` quedan color, normal (OpenGL) y ORM a 2048 px y a 1024 px (`_1k`, preset Bajo).",
        "",
        "| Set | Asset | Autoría | Fuente | Licencia | Uso |",
        "|---|---|---|---|---|---|",
    ]
    for set_name, credit, use in rows:
        lines.append(f"| `{set_name}` | [{credit['name']}]({credit['url']}) | {credit['authors']} | {credit['source']} | CC0 1.0 | {use} |")
    lines.append("<!-- /SCANS -->")
    block = "\n".join(lines)
    text = open(REGISTER, encoding="utf-8").read()
    if "<!-- SCANS" in text:
        text = re.sub(r"<!-- SCANS.*?<!-- /SCANS -->", lambda _: block, text, flags=re.S)
    else:
        text = text.replace("\n## Modelos aportados", "\n" + block + "\n\n## Modelos aportados", 1)
    open(REGISTER, "w", encoding="utf-8", newline="\n").write(text)


def main():
    rows = []
    for set_name, (source, asset, use) in SETS.items():
        maps, credit = polyhaven(asset) if source == "polyhaven" else ambientcg(asset)
        size = write(set_name, maps)
        rows.append((set_name, credit, use))
        print(f"{set_name}: {size / 1e6:.1f} MB")
    register(rows)


if __name__ == "__main__":
    main()
