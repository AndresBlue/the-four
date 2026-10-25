"""Checks tools/textures/ingest_pbr.py without writing any asset.

    python -E -P tools/textures/check_ingest_pbr.py

Prints CHECK_SCANS (the hotel's register in docs/ASSETS.md against what the
script would write), CHECK_OFFICE_SETS (the office sets of the two registers),
CHECK_CGBOOKCASE (a synthetic pack), CHECK_SHAPE (a set of another shape keeps
it, in a temporary folder) and CHECK_INGEST_PBR; exits with 1 if a check fails.
"""
import importlib.util
import io
import os
import sys
import tempfile
import zipfile

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
REGISTER = os.path.join(ROOT, "docs", "ASSETS.md")
END = "<!-- /SCANS -->"

# Office sets the registers must give, each with its source kind.
EXPECTED = {
    "office_tiles110": "ambientcg",
    "office_walnut_veneer": "polyhaven",
    "office_galvanizedsteel02": "cgbookcase",
    "office_terrazzo003": "ambientcg",
    "office_teak_veneer": "polyhaven",
}


def load_ingest():
    spec = importlib.util.spec_from_file_location("ingest_pbr", os.path.join(HERE, "ingest_pbr.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def check_scans(mod):
    rows = [(n, mod.polyhaven_credit(a) if s == "polyhaven" else mod.ambientcg_credit(a), u) for n, (s, a, u) in mod.SETS.items()]
    expected = mod.scans_block(rows)
    with open(REGISTER, encoding="utf-8") as f:
        text = f.read()
    start = text.find("<!-- SCANS")
    end = text.find(END)
    actual = text[start:end + len(END)] if start >= 0 and end >= 0 else ""
    same = actual == expected
    print("CHECK_SCANS", "same" if same else "different")
    return same


def check_sets(mod):
    sets = mod.office_sets()
    missing = [n for n, kind in EXPECTED.items() if n not in sets or sets[n][0] != kind]
    ok = len(sets) == 41 and not missing
    if ok:
        print("CHECK_OFFICE_SETS ok sets=41")
    else:
        print(f"CHECK_OFFICE_SETS failed sets={len(sets)} missing={' '.join(missing)}")
    return ok


def png(mode, colour, size=(4, 4)):
    buffer = io.BytesIO()
    Image.new(mode, size, colour).save(buffer, format="PNG")
    return buffer.getvalue()


def check_cgbookcase(mod):
    with tempfile.TemporaryDirectory() as folder:
        path = os.path.join(folder, "X_cgbookcase.zip")
        with zipfile.ZipFile(path, "w") as archive:
            archive.writestr("X_1K_BaseColor.png", png("RGB", (10, 20, 30)))
            archive.writestr("X_1K_Normal.png", png("RGB", (128, 50, 255)))
            archive.writestr("X_1K_Roughness.png", png("L", 100))
            archive.writestr("X_1K_AO.png", png("L", 200))
        maps = mod.cgbookcase(path)
        normal = maps["normal"].getpixel((0, 0))
        orm = maps["orm"].getpixel((0, 0))
    ok = normal == (128, 205, 255) and orm == (200, 100, 255)
    if ok:
        print("CHECK_CGBOOKCASE ok")
    else:
        print(f"CHECK_CGBOOKCASE failed normal={normal} orm={orm}")
    return ok


def check_shape(mod):
    """A 2048 x 1024 set keeps its shape; a map of another shape is refused."""
    sizes = [mod.target_size((2048, 1024), 2048), mod.target_size((2048, 1024), 1024), mod.target_size((1024, 2048), 1024), mod.target_size((1000, 1000), 2048)]
    fits = sizes == [(2048, 1024), (1024, 512), (512, 1024), (1000, 1000)]
    saved = mod.TARGET
    with tempfile.TemporaryDirectory() as folder:
        mod.TARGET = folder
        try:
            wide = {"albedo": Image.new("RGB", (2048, 1024)), "normal": Image.new("RGB", (2048, 1024)), "orm": Image.new("RGB", (2048, 1024))}
            mod.write("shape_test", wide, keep_shape=True)
            written = []
            for name in ("albedo.jpg", "albedo_1k.jpg", "normal_1k.jpg", "orm.jpg"):
                with Image.open(os.path.join(folder, "shape_test", name)) as image:
                    written.append(image.size)
            try:
                mod.write("shape_test2", {"albedo": Image.new("RGB", (2048, 1024)), "normal": Image.new("RGB", (1024, 1024))}, keep_shape=True)
                refused = False
            except ValueError:
                refused = True
        finally:
            mod.TARGET = saved
    ok = fits and written == [(2048, 1024), (1024, 512), (1024, 512), (2048, 1024)] and refused
    if ok:
        print("CHECK_SHAPE ok")
    else:
        print(f"CHECK_SHAPE failed sizes={sizes} written={written} refused={refused}")
    return ok


def main():
    mod = load_ingest()
    results = [check_scans(mod), check_sets(mod), check_cgbookcase(mod), check_shape(mod)]
    ok = all(results)
    print("CHECK_INGEST_PBR ok" if ok else "CHECK_INGEST_PBR failed")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
