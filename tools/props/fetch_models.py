"""Downloads Poly Haven models (CC0) into source_assets/props/<id>/, as
tools/props/ingest_models.py reads them: the glTF, its buffer and textures,
and info.json (name, authors) for the register in docs/ASSETS.md.

    python tools/props/fetch_models.py fire_alarm ceiling_fan
    python tools/props/fetch_models.py --2k vintage_grandfather_clock_01

1k textures unless --2k (the big pieces ingest_models.py keeps at 2048 px).
A model already there is left alone. source_assets/ is outside git: only
what ingest_models.py brings into assets/props/hotel/ is tracked.
"""
import hashlib
import json
import os
import sys
import urllib.request

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SOURCE = os.path.join(ROOT, "source_assets", "props")
API = "https://api.polyhaven.com"
AGENT = {"User-Agent": "TheFour-assets/1.0"}


def get(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers=AGENT), timeout=120).read()


def save(url, path, md5):
    data = get(url)
    if md5 and hashlib.md5(data).hexdigest() != md5:
        raise RuntimeError("md5 of %s does not match" % url)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(data)
    return len(data)


def fetch(model, size):
    folder = os.path.join(SOURCE, model)
    if os.path.isdir(folder) and any(f.endswith(".gltf") for f in os.listdir(folder)):
        print("%-34s already in source_assets" % model)
        return
    files = json.loads(get("%s/files/%s" % (API, model)))
    entry = files["gltf"][size]["gltf"]
    total = save(entry["url"], os.path.join(folder, os.path.basename(entry["url"])), entry.get("md5"))
    for relative, part in entry.get("include", {}).items():
        total += save(part["url"], os.path.join(folder, *relative.split("/")), part.get("md5"))
    info = get("%s/info/%s" % (API, model))
    with open(os.path.join(folder, "info.json"), "wb") as f:
        f.write(info)
    print("%-34s %s  %.1f MB  %s" % (model, size, total / 1048576, ", ".join(json.loads(info)["authors"])))


if __name__ == "__main__":
    size = "2k" if "--2k" in sys.argv else "1k"
    for name in [a for a in sys.argv[1:] if not a.startswith("--")]:
        fetch(name, size)
