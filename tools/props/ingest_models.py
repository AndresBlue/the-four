"""Furniture and props for the hotel (docs/REALISM.md, phase 4), step one.

Reads the glTF downloads in source_assets/props/<id>/ (outside git; Poly Haven
glTF with its textures and info.json) and writes, for each model, to
assets/props/hotel/<id>/:

    <image>.jpg          its textures, at most MAX_SIZE px (2048 for the big
                         pieces in KEEP_2K), with a .import beside each (VRAM
                         compressed, mipmaps; normal maps as normal maps)
    <material>.tres      one material per glTF material: ORMMaterial3D when
                         the model packs occlusion, roughness and metalness in
                         one image (Poly Haven's "arm"), else StandardMaterial3D

Step two, in Godot, bakes the meshes with these materials:
tools/props/build_catalogue.gd. The register (source, authors, licence) goes
to docs/ASSETS.md between the MODELS markers.

    python tools/props/ingest_models.py
"""
import json
import os
import re

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SOURCE = os.path.join(ROOT, "source_assets", "props")
TARGET = os.path.join(ROOT, "assets", "props", "hotel")
REGISTER = os.path.join(ROOT, "docs", "ASSETS.md")

MAX_SIZE = 1024
# Big pieces seen close up keep 2048 px.
KEEP_2K = {"GothicBed_01", "Sofa_01", "sofa_03", "ArmChair_01", "wooden_bookshelf_worn", "GothicCommode_01", "ClassicConsole_01"}

IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="res://assets/props/hotel/{model}/{file}"

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
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/size_limit=0
detect_3d/compress_to=0
"""


def safe(name):
    return re.sub(r"[^A-Za-z0-9_]+", "_", name).strip("_") or "material"


def copy_image(model, source_folder, uri, normal, size):
    image = Image.open(os.path.join(source_folder, uri))
    alpha = image.mode in ("RGBA", "LA", "P") and "A" in image.convert("RGBA").getbands()
    file = safe(os.path.splitext(os.path.basename(uri))[0]) + (".png" if alpha else ".jpg")
    path = os.path.join(TARGET, model, file)
    if image.width > size:
        image = image.resize((size, round(image.height * size / image.width)), Image.LANCZOS)
    if alpha:
        image.convert("RGBA").save(path, optimize=True)
    else:
        image.convert("RGB").save(path, quality=90)
    if not os.path.exists(path + ".import"):
        with open(path + ".import", "w", newline="\n") as f:
            f.write(IMPORT.format(model=model, file=file, normal=1 if normal else 2))
    return file


def material_tres(model, gltf, material, textures):
    pbr = material.get("pbrMetallicRoughness", {})

    def image_of(ref):
        return gltf["images"][gltf["textures"][ref["index"]]["source"]]["uri"] if ref else None

    albedo = image_of(pbr.get("baseColorTexture"))
    mr = image_of(pbr.get("metallicRoughnessTexture"))
    occlusion = image_of(material.get("occlusionTexture"))
    normal = image_of(material.get("normalTexture"))
    orm = mr is not None and (occlusion is None or occlusion == mr)
    resources = []
    lines = []

    def texture(uri, key, is_normal=False):
        file = textures.setdefault(uri, copy_image(model, os.path.join(SOURCE, model), uri, is_normal, textures["__size"]))
        resources.append(file)
        lines.append(f'{key} = ExtResource("{len(resources)}")')

    colour = pbr.get("baseColorFactor", [1, 1, 1, 1])
    lines.append("albedo_color = Color(%g, %g, %g, %g)" % tuple(colour))
    if albedo: texture(albedo, "albedo_texture")
    if orm:
        texture(mr, "orm_texture")
    else:
        lines.append("metallic = %g" % pbr.get("metallicFactor", 1.0 if mr else 0.0))
        lines.append("roughness = %g" % pbr.get("roughnessFactor", 1.0))
        if mr:
            texture(mr, "metallic_texture")
            lines.append("metallic_texture_channel = 2")
            texture(mr, "roughness_texture")
            lines.append("roughness_texture_channel = 1")
        if occlusion:
            lines.append("ao_enabled = true")
            texture(occlusion, "ao_texture")
    if normal:
        lines.append("normal_enabled = true")
        texture(normal, "normal_texture", True)
    mode = material.get("alphaMode", "OPAQUE")
    if mode == "MASK":
        lines.append("transparency = 2")
        lines.append("alpha_scissor_threshold = %g" % material.get("alphaCutoff", 0.5))
    elif mode == "BLEND" and "glass" in material["name"].lower():
        lines.append("transparency = 1")
    elif mode == "BLEND":
        # Cut-out cloth fringes and crate holes: scissored, so they stay in
        # the depth pass and cast shadows.
        lines.append("transparency = 2")
        lines.append("alpha_scissor_threshold = 0.5")
    if material.get("doubleSided"):
        lines.append("cull_mode = 2")
    kind = "ORMMaterial3D" if orm else "StandardMaterial3D"
    head = [f'[gd_resource type="{kind}" load_steps={len(resources) + 1} format=3]', ""]
    for k, file in enumerate(resources):
        head.append(f'[ext_resource type="Texture2D" path="res://assets/props/hotel/{model}/{file}" id="{k + 1}"]')
    return "\n".join(head + ["", "[resource]", f'resource_name = "{material["name"]}"'] + lines) + "\n"


def ingest(model):
    folder = os.path.join(SOURCE, model)
    gltf_file = next(f for f in os.listdir(folder) if f.endswith(".gltf"))
    gltf = json.load(open(os.path.join(folder, gltf_file), encoding="utf-8"))
    os.makedirs(os.path.join(TARGET, model), exist_ok=True)
    textures = {"__size": 2048 if model in KEEP_2K else MAX_SIZE}
    names = []
    for material in gltf.get("materials", []):
        name = safe(material["name"])
        with open(os.path.join(TARGET, model, name + ".tres"), "w", encoding="utf-8", newline="\n") as f:
            f.write(material_tres(model, gltf, material, textures))
        names.append(name)
    info = json.load(open(os.path.join(folder, "info.json"), encoding="utf-8"))
    return info, names


def register(rows):
    lines = [
        "<!-- MODELS: generado por tools/props/ingest_models.py, no editar a mano -->",
        "## Mobiliario y objetos (fase 4 de REALISM.md)",
        "",
        "Poly Haven, CC0 (dominio público): no exigen atribución, se acreditan igualmente. Descargas originales en `source_assets/props/` (fuera de git); en `assets/props/hotel/<id>/` quedan las texturas (1024 px, 2048 en los muebles grandes) y los materiales, y `tools/props/build_catalogue.gd` hornea `assets/props/hotel/<id>.res`.",
        "",
        "| Modelo | Autoría | Licencia |",
        "|---|---|---|",
    ]
    for model, info in rows:
        lines.append(f"| [{info['name']}](https://polyhaven.com/a/{model}) | {', '.join(info['authors'])} | CC0 1.0 |")
    lines.append("<!-- /MODELS -->")
    block = "\n".join(lines)
    text = open(REGISTER, encoding="utf-8").read()
    if "<!-- MODELS" in text:
        text = re.sub(r"<!-- MODELS.*?<!-- /MODELS -->", lambda _: block, text, flags=re.S)
    else:
        text = text.replace("\n## Modelos aportados", "\n" + block + "\n\n## Modelos aportados", 1)
    open(REGISTER, "w", encoding="utf-8", newline="\n").write(text)


def main():
    rows = []
    for model in sorted(os.listdir(SOURCE)):
        if not os.path.isdir(os.path.join(SOURCE, model)): continue
        info, names = ingest(model)
        rows.append((model, info))
        print(model, names)
    register(rows)


if __name__ == "__main__":
    main()
