"""Checks tools/props/ingest_models.py: the hotel's files still come out byte for
byte (every material's .tres and the MODELS block of docs/ASSETS.md), and the
parts added for the offices work on small synthetic files (specular-glossiness
materials, zipped downloads).

    python -E -P tools/props/check_ingest_models.py

Prints one line per part, then CHECK_INGEST_MODELS ok (exit 0) or
CHECK_INGEST_MODELS failed (exit 1). Run it with python -E -P: it imports PIL.
"""
import importlib.util
import json
import os
import re
import shutil
import sys
import tempfile
import zipfile

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
mod = None

## A glTF with two materials: one with a diffuse and a specular-glossiness
## image, one with plain factors. Both are specular-glossiness.
GLOSS_GLTF = {
    "asset": {"version": "2.0"},
    "images": [{"uri": "diffuse.png"}, {"uri": "specgloss.png"}],
    "textures": [{"source": 0}, {"source": 1}],
    "materials": [
        {"name": "glossy", "extensions": {"KHR_materials_pbrSpecularGlossiness": {"diffuseTexture": {"index": 0}, "specularGlossinessTexture": {"index": 1}, "glossinessFactor": 1.0}}},
        {"name": "matte", "extensions": {"KHR_materials_pbrSpecularGlossiness": {"diffuseFactor": [0.5, 0.5, 0.5, 1], "glossinessFactor": 0.25}}},
    ],
}


def load():
    global mod
    spec = importlib.util.spec_from_file_location("ingest_models", os.path.join(HERE, "ingest_models.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)


def read_bytes(path):
    with open(path, "rb") as f:
        return f.read()


def hotel():
    saved = mod.TARGET
    tmp = tempfile.mkdtemp()
    mod.TARGET = tmp
    materials = getattr(mod, "ingest_materials", None) or (lambda m: mod.ingest(m)[1])
    info_folder = getattr(mod, "folder_of", None) or (lambda m: os.path.join(mod.SOURCE, m))
    ok = 0
    diffs = 0
    rows = []
    try:
        for model in sorted(os.listdir(mod.SOURCE)):
            if not os.path.isdir(os.path.join(mod.SOURCE, model)) or model in mod.SKIP: continue
            if not any(f.endswith(".gltf") for f in os.listdir(os.path.join(mod.SOURCE, model))): continue
            for name in materials(model):
                made = os.path.join(tmp, model, name + ".tres")
                kept = os.path.join(mod.ROOT, "assets", "props", "hotel", model, name + ".tres")
                if os.path.exists(made) and os.path.exists(kept) and read_bytes(made) == read_bytes(kept):
                    ok += 1
                else:
                    diffs += 1
                    print("DIFF", model, name)
            with open(os.path.join(info_folder(model), "info.json"), encoding="utf-8") as f:
                rows.append((model, json.load(f)))
    finally:
        mod.TARGET = saved
        shutil.rmtree(tmp, ignore_errors=True)
    # The register's block: the same text as models_block() makes from the same rows.
    block = "skipped"
    if hasattr(mod, "models_block"):
        with open(mod.REGISTER, encoding="utf-8") as f:
            found = re.search(r"<!-- MODELS.*?<!-- /MODELS -->", f.read(), flags=re.S)
        block = "same" if found and found.group(0) == mod.models_block(rows) else "different"
    print(f"CHECK_HOTEL ok={ok} diffs={diffs} block={block}")
    return diffs == 0 and block != "different"


def gloss():
    if not hasattr(mod, "rough_from_gloss"):
        print("CHECK_GLOSS skipped")
        return True
    saved = (mod.TARGET, mod.RES)
    tmp = tempfile.mkdtemp()
    try:
        src = os.path.join(tmp, "src")
        os.makedirs(src)
        Image.new("RGB", (8, 8), (200, 100, 50)).save(os.path.join(src, "diffuse.png"))
        Image.new("RGBA", (8, 8), (40, 40, 40, 64)).save(os.path.join(src, "specgloss.png"))
        with open(os.path.join(src, "test.gltf"), "w", encoding="utf-8") as f:
            json.dump(GLOSS_GLTF, f)
        mod.TARGET = os.path.join(tmp, "out")
        mod.RES = "res://assets/props/office/"
        mod.FOLDERS["gloss_test"] = src
        names = mod.ingest_materials("gloss_test")
        out = os.path.join(mod.TARGET, "gloss_test")
        with open(os.path.join(out, "glossy.tres"), encoding="utf-8") as f:
            glossy = f.read()
        with open(os.path.join(out, "matte.tres"), encoding="utf-8") as f:
            matte = f.read()
        checks = [
            names == ["glossy", "matte"],
            'albedo_texture = ExtResource("1")' in glossy,
            "metallic = 0\n" in glossy,
            "roughness = 1\n" in glossy,
            "roughness_texture = ExtResource(" in glossy,
            "roughness_texture_channel = 0" in glossy,
            'path="res://assets/props/office/gloss_test/' in glossy,
            os.path.exists(os.path.join(out, "specgloss_rough.jpg")),
            "roughness = 0.75" in matte,
            "albedo_color = Color(0.5, 0.5, 0.5, 1)" in matte,
        ]
    finally:
        mod.TARGET, mod.RES = saved
        mod.FOLDERS.pop("gloss_test", None)
        shutil.rmtree(tmp, ignore_errors=True)
    ok = all(checks)
    print("CHECK_GLOSS ok" if ok else "CHECK_GLOSS failed")
    return ok


def zipped():
    if not hasattr(mod, "gltf_folder"):
        print("CHECK_ZIP skipped")
        return True
    tmp = tempfile.mkdtemp()
    try:
        good = os.path.join(tmp, "good")
        bad = os.path.join(tmp, "bad")
        plain = os.path.join(tmp, "plain")
        for folder in (good, bad, plain):
            os.makedirs(folder)
        with zipfile.ZipFile(os.path.join(good, "model.zip"), "w") as archive:
            archive.writestr("sub/scene.gltf", "{}")
            archive.writestr("sub/scene.bin", "")
        # A member that climbs out of the folder: refused, nothing written.
        with zipfile.ZipFile(os.path.join(bad, "model.zip"), "w") as archive:
            archive.writestr("../scene.gltf", "{}")
        with open(os.path.join(plain, "a.gltf"), "w", encoding="utf-8") as f:
            f.write("{}")
        checks = [
            mod.gltf_folder(good) == os.path.join(good, "_zip", "sub"),
            mod.gltf_folder(bad) is None,
            mod.gltf_folder(plain) == plain,
            not os.path.exists(os.path.join(tmp, "scene.gltf")),
        ]
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    ok = all(checks)
    print("CHECK_ZIP ok" if ok else "CHECK_ZIP failed")
    return ok


def office_kits():
    """--set=office leaves out the kits the hotel bakes by id, and no others."""
    if not hasattr(mod, "office_bakes"):
        print("CHECK_OFFICE_KITS skipped")
        return True
    entries = mod.office_entries()
    baked = mod.office_bakes(entries)
    checks = [slug in entries for slug in mod.OFFICE_HOTEL_KITS]
    # Each kit's Poly Haven id must be a download the hotel bakes (not in its SKIP).
    for slug in mod.OFFICE_HOTEL_KITS:
        pid = entries[slug][1]["url"].rstrip("/").split("/")[-1]
        checks.append(os.path.isdir(os.path.join(mod.SOURCE, pid)) and pid not in mod.SKIP)
    checks += [slug not in baked for slug in mod.OFFICE_HOTEL_KITS]
    checks.append("fichero_vintage_wooden_drawer_01" in baked)
    ok = all(checks)
    print("CHECK_OFFICE_KITS ok" if ok else "CHECK_OFFICE_KITS failed")
    return ok


def main():
    load()
    # All four run, in this order, whatever the others say.
    results = [hotel(), gloss(), zipped(), office_kits()]
    ok = all(results)
    print("CHECK_INGEST_MODELS ok" if ok else "CHECK_INGEST_MODELS failed")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
