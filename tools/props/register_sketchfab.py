"""Brings a Sketchfab glTF zip the author downloaded into the offices' sources
(docs/OFICINAS.md 12), step zero of tools/props/ingest_models.py --set=office:

    python -I tools/props/register_sketchfab.py <group> <slug> <zip> [--item=<words>] [--status=<status>] [--note=<words>]

moves the zip (from models/ or wherever it is) to
source_assets/oficinas/<group>/<slug>/, unpacks it into _zip/ there (nothing
written outside it: an archive with an absolute path or a ".." is refused),
and writes the download's entry in that group's registro.json (made if the
group is new): source, author, licence and the credit line read from the
zip's license.txt, its file, bytes and SHA-256. A licence with NC, ND or SA
is refused. A zip with no license.txt (an author's own upload) takes them
from --title=, --author=, --url=, --licence= and --attribution=; one with no
glTF beside it has the zips inside it unpacked where they are. The status is
"pendiente" until it is given (--status=ok once the
model is ready to bring in); --note= adds to the entry's notes. Prints the
glTF's triangles, materials and images. Run with -I: the zip is not trusted.
"""
import hashlib
import json
import os
import re
import shutil
import sys
import zipfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OFFICE_ROOT = os.path.join(ROOT, "source_assets", "oficinas")
BANNED = re.compile(r"\b(NC|ND|SA)\b|NonCommercial|NoDerivatives|ShareAlike")


def unsafe(name):
    return name.startswith(("/", "\\")) or ":" in name or ".." in name.replace("\\", "/").split("/")


def licence_of(text):
    """The fields of a Sketchfab license.txt."""
    field = {}
    for key in ("title", "source", "author", "license type"):
        found = re.search(r"\* " + key + r":\s*(.+)", text)
        field[key] = found.group(1).strip() if found else ""
    kind = re.match(r"(\S+)\s*\((\S+)\)", field["license type"])
    credit = text.split("wherever you share it:")[-1].strip() if "wherever you share it:" in text else ""
    author = re.match(r"(.+?)\s*\((\S+)\)$", field["author"])
    return {
        "title": field["title"],
        "url": field["source"],
        "author": author.group(1) if author else field["author"],
        "licence": kind.group(1).replace("-", " ") if kind else field["license type"],
        "licence_url": kind.group(2) if kind else "",
        "attribution": credit,
    }


def summary(gltf_path):
    gltf = json.load(open(gltf_path, encoding="utf-8"))
    tris = 0
    for mesh in gltf.get("meshes", []):
        for p in mesh["primitives"]:
            count = gltf["accessors"][p["indices"]]["count"] if "indices" in p else gltf["accessors"][p["attributes"]["POSITION"]]["count"]
            tris += count // 3
    materials = [m.get("name", "") for m in gltf.get("materials", [])]
    images = [i.get("uri", "") for i in gltf.get("images", [])]
    return tris, materials, images


def gltf_in(folder):
    """The first glTF under folder, or None."""
    for here, _, files in sorted(os.walk(folder)):
        for name in sorted(files):
            if name.endswith(".gltf"): return os.path.join(here, name)
    return None


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    opts = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--") and "=" in a)
    if len(args) != 3:
        print(__doc__)
        sys.exit(2)
    group, slug, archive = args
    folder = os.path.join(OFFICE_ROOT, group, slug)
    os.makedirs(folder, exist_ok=True)
    kept = os.path.join(folder, os.path.basename(archive))
    if os.path.abspath(archive) != os.path.abspath(kept) and not os.path.exists(kept):
        shutil.move(archive, kept)
    data = open(kept, "rb").read()
    unpacked = os.path.join(folder, "_zip")
    with zipfile.ZipFile(kept) as z:
        bad = [m for m in z.namelist() if unsafe(m)]
        if bad:
            print("REFUSED", slug, "paths", bad)
            sys.exit(1)
        if not os.path.isdir(unpacked):
            os.makedirs(unpacked)
            z.extractall(unpacked)
    if gltf_in(unpacked) is None:
        for here, _, files in list(os.walk(unpacked)):
            for name in files:
                if not name.lower().endswith(".zip"): continue
                with zipfile.ZipFile(os.path.join(here, name)) as inner:
                    if any(unsafe(m) for m in inner.namelist()):
                        print("REFUSED", slug, "paths in", name)
                        sys.exit(1)
                    inner.extractall(here)
    licence_path = os.path.join(unpacked, "license.txt")
    found = licence_of(open(licence_path, encoding="utf-8", errors="replace").read()) if os.path.exists(licence_path) else {}
    if not found and "licence" in opts:
        found = {"title": opts.get("title", ""), "url": opts.get("url", ""), "author": opts.get("author", ""), "licence": opts["licence"], "licence_url": "", "attribution": opts.get("attribution", "")}
    if not found or BANNED.search(found.get("licence", "")):
        print("REFUSED", slug, "licence", found.get("licence"))
        sys.exit(1)
    register = os.path.join(OFFICE_ROOT, group, "registro.json")
    entries = json.load(open(register, encoding="utf-8")) if os.path.exists(register) else []
    entry = next((e for e in entries if e.get("slug") == slug), None)
    if entry is None:
        entry = {"item": opts.get("item", found["title"]), "slug": slug, "notes": "", "status": "pendiente"}
        entries.append(entry)
    entry.update({"source": "Sketchfab", "url": found["url"], "author": found["author"], "licence": found["licence"], "licence_url": found["licence_url"], "attribution": found["attribution"], "files": [os.path.basename(kept)], "bytes": len(data), "sha256": {os.path.basename(kept): hashlib.sha256(data).hexdigest()}, "preview": found["url"]})
    if "item" in opts: entry["item"] = opts["item"]
    if "status" in opts: entry["status"] = opts["status"]
    if "note" in opts and opts["note"] not in entry.get("notes", ""): entry["notes"] = (entry.get("notes", "") + " " + opts["note"]).strip()
    with open(register, "w", encoding="utf-8", newline="\n") as f:
        f.write(json.dumps(entries, indent=2, ensure_ascii=False) + "\n")
    tris, materials, images = summary(gltf_in(unpacked))
    print("REGISTERED %s/%s %s bytes=%d tris=%d status=%s" % (group, slug, found["licence"], len(data), tris, entry["status"]))
    print("  materials", materials)
    print("  images", images)


if __name__ == "__main__":
    main()
