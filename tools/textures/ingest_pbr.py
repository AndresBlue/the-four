"""Scanned material sets (docs/REALISM.md, phase 3; the offices' sets too).

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

The offices (--set=office) read the two registers in source_assets/oficinas/
(materiales/registro.json and registro_materiales_2.json): every entry marked
ok, as the set office_<id>, from its own folder. cgbookcase packs are zips of
PNG maps with a DirectX normal (turned to OpenGL here) and no metalness map,
so their metal is whole (metal = 1). Their register goes to docs/ASSETS.md
between the OFFICE_SCANS markers.

    python -E -P tools/textures/ingest_pbr.py [--only=<set>]
    python -E -P tools/textures/ingest_pbr.py --set=office [--only=office_<id>]
"""
import io
import json
import os
import re
import sys
import zipfile

from PIL import Image, ImageChops

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SOURCE = os.path.join(ROOT, "source_assets", "textures")
TARGET = os.path.join(ROOT, "assets", "textures")
REGISTER = os.path.join(ROOT, "docs", "ASSETS.md")

## The offices' materials (--set=office): every entry of their two registers
## marked ok, as the set office_<id> (the folder's name without acg_, ph_ or
## cgb_), out to assets/textures/office_<id>/.
OFFICE = os.path.join(ROOT, "source_assets", "oficinas")
OFFICE_SOURCE = os.path.join(OFFICE, "materiales")
OFFICE_SECOND = os.path.join(OFFICE, "registro_materiales_2.json")
PREFIXES = {"acg_": "ambientcg", "ph_": "polyhaven", "cgb_": "cgbookcase"}

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


def polyhaven_maps(folder):
    files = os.listdir(folder)

    def pick(pattern):
        return Image.open(os.path.join(folder, next(f for f in files if re.search(pattern, f))))

    maps = {
        "albedo": pick(r"_(diff|albedo)_2k\.jpg$").convert("RGB"),
        "normal": pick(r"_nor_gl_2k\.jpg$").convert("RGB"),
        "orm": pick(r"_arm_2k\.jpg$").convert("RGB"),
    }
    return maps


def polyhaven_credit(set_id, folder=None):
    folder = folder or os.path.join(SOURCE, set_id)
    info = json.load(open(os.path.join(folder, "info.json"), encoding="utf-8"))
    credit = {
        "name": info["name"],
        "authors": ", ".join(info["authors"]),
        "url": "https://polyhaven.com/a/" + set_id,
        "source": "Poly Haven",
        "metres": info["dimensions"][0] / 1000.0 if info.get("dimensions") else None,
    }
    return credit


def polyhaven(set_id, folder=None):
    folder = folder or os.path.join(SOURCE, set_id)
    return polyhaven_maps(folder), polyhaven_credit(set_id, folder)


def ambientcg_credit(asset):
    credit = {
        "name": asset,
        "authors": "Lennart Demes (ambientCG)",
        "url": "https://ambientcg.com/view?id=" + asset,
        "source": "ambientCG",
        "metres": None,
    }
    return credit


def ambientcg(asset, archive_path=None):
    archive = zipfile.ZipFile(archive_path or os.path.join(SOURCE, asset + "_2K-JPG.zip"))
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
    return maps, ambientcg_credit(asset)


def cgbookcase(archive_path):
    """A cgbookcase metal-roughness pack: PNG maps, DirectX normals."""
    archive = zipfile.ZipFile(archive_path)
    names = archive.namelist()

    def read(suffix, mode):
        name = next((n for n in names if n.endswith("_" + suffix + ".png")), None)
        return Image.open(io.BytesIO(archive.read(name))).convert(mode) if name else None

    colour = read("BaseColor", "RGB")
    size = colour.size
    occlusion = read("AO", "L") or Image.new("L", size, 255)
    roughness = read("Roughness", "L") or Image.new("L", size, 128)
    # The packs here are metals with no metalness map (their register: metallic = 1).
    metalness = read("Metalness", "L") or read("Metallic", "L") or Image.new("L", size, 255)
    r, g, b = read("Normal", "RGB").split()
    # DirectX to OpenGL: the green flipped.
    normal = Image.merge("RGB", [r, ImageChops.invert(g), b])
    return {
        "albedo": colour,
        "normal": normal,
        "orm": Image.merge("RGB", [occlusion.resize(size), roughness.resize(size), metalness.resize(size)]),
    }


def target_size(shape, size):
    """The size of a map of a download of this shape: its longer side at
    size, never past the download's, the other side in proportion."""
    w, h = shape
    scale = min(size, max(w, h)) / max(w, h)
    return max(1, round(w * scale)), max(1, round(h * scale))


def write(set_name, maps, keep_shape=False):
    folder = os.path.join(TARGET, set_name)
    os.makedirs(folder, exist_ok=True)
    total = 0
    if keep_shape:
        # A map of another shape would come out stretched: refuse the set.
        w, h = maps["albedo"].size
        for kind, image in maps.items():
            if image.width * h != image.height * w:
                raise ValueError(f"{set_name}: {kind} is {image.size}, its albedo {maps['albedo'].size}")
    for suffix, size in SIZES.items():
        # The hotel's maps are square at size; the offices' keep the download's
        # shape. Never scaled up past the download: a 1K pack stays 1024.
        dims = target_size(maps["albedo"].size, size) if keep_shape else (size, size)
        for kind, image in maps.items():
            file = kind + suffix + ".jpg"
            path = os.path.join(folder, file)
            image.resize(dims, Image.LANCZOS).save(path, quality=QUALITY, subsampling=0 if kind != "albedo" else 2)
            total += os.path.getsize(path)
            import_path = path + ".import"
            # Godot keeps the uid and the params it finds; only a new image
            # gets a fresh .import.
            if not os.path.exists(import_path):
                with open(import_path, "w", newline="\n") as f:
                    f.write(IMPORT.format(set=set_name, file=file, normal=1 if kind == "normal" else 2))
    return total


def scans_block(rows):
    lines = [
        "<!-- SCANS: generado por tools/textures/ingest_pbr.py, no editar a mano -->",
        "## Materiales escaneados (fase 3 de REALISM.md)",
        "",
        "Todos CC0 (dominio público): no exigen atribución: constan aquí y no en los créditos del juego. Descargas originales en `source_assets/textures/` (fuera de git); en `assets/textures/<set>/` quedan color, normal (OpenGL) y ORM a 2048 px y a 1024 px (`_1k`, preset Bajo).",
        "",
        "| Set | Asset | Autoría | Fuente | Licencia | Uso |",
        "|---|---|---|---|---|---|",
    ]
    for set_name, credit, use in rows:
        lines.append(f"| `{set_name}` | [{credit['name']}]({credit['url']}) | {credit['authors']} | {credit['source']} | CC0 1.0 | {use} |")
    lines.append("<!-- /SCANS -->")
    return "\n".join(lines)


def register(rows):
    block = scans_block(rows)
    text = open(REGISTER, encoding="utf-8").read()
    if "<!-- SCANS" in text:
        text = re.sub(r"<!-- SCANS.*?<!-- /SCANS -->", lambda _: block, text, flags=re.S)
    else:
        text = text.replace("\n## Modelos aportados", "\n" + block + "\n\n## Modelos aportados", 1)
    open(REGISTER, "w", encoding="utf-8", newline="\n").write(text)


def write_block(name, block):
    text = open(REGISTER, encoding="utf-8").read()
    if f"<!-- {name}:" in text:
        text = re.sub(rf"<!-- {name}:.*?<!-- /{name} -->", lambda _: block, text, flags=re.S)
    else:
        text = text.replace("\n## Modelos aportados", "\n" + block + "\n\n## Modelos aportados", 1)
    open(REGISTER, "w", encoding="utf-8", newline="\n").write(text)


def office_sets():
    """The offices' sets, by name: (kind, folder, entry), the entry with the
    first register's keys (source, url, author, licence, item)."""
    sets = {}

    def add(folder, entry):
        leaf = os.path.basename(folder)
        prefix = next((p for p in PREFIXES if leaf.startswith(p)), None)
        if prefix is not None:
            sets["office_" + leaf[len(prefix):]] = (PREFIXES[prefix], folder, entry)

    with open(os.path.join(OFFICE_SOURCE, "registro.json"), encoding="utf-8") as f:
        for entry in json.load(f):
            if entry.get("status") == "ok" and entry.get("files"):
                add(os.path.join(OFFICE_SOURCE, os.path.dirname(entry["files"][0])), entry)
    with open(OFFICE_SECOND, encoding="utf-8") as f:
        for entry in json.load(f):
            if entry.get("status") == "ok" and entry.get("archivos"):
                add(os.path.join(OFFICE, os.path.dirname(entry["archivos"][0]["ruta"])), {"source": entry["fuente"], "url": entry["url"], "author": entry["autor"], "licence": entry["licencia"], "item": entry["superficie"]})
    return sets


def office_maps(kind, folder):
    # The second register's Poly Haven folders have no info.json: maps only.
    if kind == "polyhaven":
        return polyhaven_maps(folder)
    archive = os.path.join(folder, next(f for f in sorted(os.listdir(folder)) if f.lower().endswith(".zip")))
    if kind == "ambientcg":
        return ambientcg(os.path.basename(archive).split("_")[0], archive)[0]
    return cgbookcase(archive)


def office_block(rows):
    lines = [
        "<!-- OFFICE_SCANS: generado por tools/textures/ingest_pbr.py --set=office, no editar a mano -->",
        "## Materiales escaneados de las oficinas (piso 2)",
        "",
        "Descargas originales en `source_assets/oficinas/materiales/` (fuera de git), con sus registros (`materiales/registro.json` y `registro_materiales_2.json`); en `assets/textures/<set>/` quedan color, normal (OpenGL) y ORM con el lado mayor a 2048 px (al de la descarga si es menor), con la proporción de la descarga, y a 1024 px (`_1k`).",
        "",
        "| Set | Asset | Autoría | Licencia | Uso |",
        "|---|---|---|---|---|",
    ]
    for set_name, entry in rows:
        lines.append(f"| `{set_name}` | [{entry['source']}]({entry['url']}) | {entry['author']} | {entry['licence']} | {entry['item']} |")
    lines.append("<!-- /OFFICE_SCANS -->")
    return "\n".join(lines)


def office_main(only):
    sets = office_sets()
    if only and only not in sets:
        print("SKIP", only, "not ok in the registers")
    for set_name, (kind, folder, entry) in sets.items():
        if only and set_name != only:
            continue
        maps = office_maps(kind, folder)
        size = write(set_name, maps, keep_shape=True)
        print(f"{set_name}: {size / 1e6:.1f} MB")
        # As the models do: a licence that is not CC0 is printed for the game's credits.
        if not entry["licence"].strip().upper().startswith("CC0"):
            print("CREDIT", set_name, entry["licence"], entry["author"])
    write_block("OFFICE_SCANS", office_block([(n, sets[n][2]) for n in sorted(sets) if os.path.exists(os.path.join(TARGET, n, "albedo.jpg"))]))


def main():
    args = sys.argv[1:]
    only = next((a[len("--only="):] for a in args if a.startswith("--only=")), "")
    if "--set=office" in args:
        office_main(only)
        return
    rows = []
    for set_name, (source, asset, use) in SETS.items():
        if only and set_name != only:
            # Only the credit: the register keeps every set.
            rows.append((set_name, polyhaven_credit(asset) if source == "polyhaven" else ambientcg_credit(asset), use))
            continue
        maps, credit = polyhaven(asset) if source == "polyhaven" else ambientcg(asset)
        size = write(set_name, maps)
        rows.append((set_name, credit, use))
        print(f"{set_name}: {size / 1e6:.1f} MB")
    register(rows)


if __name__ == "__main__":
    main()
