"""docs/asset_hashes.json: the size and SHA-256 of asset files, by path from
the project root.

    python -I tools/dev/asset_hashes.py add <file or folder>...
        adds or updates their entries (a folder: every file under it but
        .import and .uid, in sorted order); new ones go at the end
    python -I tools/dev/asset_hashes.py check
        says which entries are missing or changed (exits with 1 if any)
"""
import hashlib
import json
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
HASHES = os.path.join(ROOT, "docs", "asset_hashes.json")
# Read big assets in blocks, not all at once.
BLOCK = 1024 * 1024


def digest(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(BLOCK), b""):
            h.update(block)
    return {"bytes": os.path.getsize(path), "sha256": h.hexdigest()}


def key_of(path):
    # Keys always use "/", so the file is the same on every platform.
    try:
        key = os.path.relpath(os.path.abspath(path), ROOT).replace("\\", "/")
    except ValueError:
        # Another drive: there is no relative path.
        print("OUTSIDE %s" % path)
        sys.exit(2)
    if key == ".." or key.startswith("../"):
        print("OUTSIDE %s" % path)
        sys.exit(2)
    return key


def load(path=HASHES):
    # Keep the file's own line ending, so saving it again changes nothing else.
    with open(path, "rb") as f:
        raw = f.read()
    newline = "\r\n" if b"\r\n" in raw else "\n"
    return json.loads(raw.decode("utf-8")), newline


def save(data, newline, path=HASHES):
    with open(path, "w", encoding="utf-8", newline=newline) as f:
        f.write(json.dumps(data, indent=2, ensure_ascii=False) + "\n")


def add(args):
    # Check every argument before writing anything.
    for arg in args:
        key_of(arg)
        if not (os.path.isfile(arg) or os.path.isdir(arg)):
            print("NOFILE %s" % arg)
            sys.exit(2)
    files = []
    for arg in args:
        if os.path.isdir(arg):
            found = []
            for folder, _dirs, names in os.walk(arg):
                for name in names:
                    if name.endswith(".import") or name.endswith(".uid"):
                        continue
                    found.append(os.path.join(folder, name))
            # Sorted by key, so the order does not depend on the walk.
            files.extend(sorted(found, key=key_of))
        else:
            files.append(arg)
    data, newline = load()
    added = 0
    updated = 0
    unchanged = 0
    for path in files:
        key = key_of(path)
        value = digest(path)
        if key not in data:
            data[key] = value
            added += 1
        elif data[key] != value:
            data[key] = value
            updated += 1
        else:
            unchanged += 1
            continue
        print("HASH %s %d" % (key, value["bytes"]))
    if added + updated > 0:
        save(data, newline)
    print("HASHES added=%d updated=%d unchanged=%d" % (added, updated, unchanged))
    return 0


def check():
    data, _ = load()
    missing = 0
    changed = 0
    for key, entry in data.items():
        path = os.path.join(ROOT, *key.split("/"))
        if not os.path.isfile(path):
            print("MISSING %s" % key)
            missing += 1
        elif digest(path) != entry:
            print("CHANGED %s" % key)
            changed += 1
    print("HASHES_CHECK entries=%d missing=%d changed=%d" % (len(data), missing, changed))
    return 1 if missing + changed > 0 else 0


def main(argv):
    if len(argv) >= 3 and argv[1] == "add":
        return add(argv[2:])
    if len(argv) == 2 and argv[1] == "check":
        return check()
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
