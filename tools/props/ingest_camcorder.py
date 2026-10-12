"""The camcorder and the tape (docs/ASSETS.md, «Videocámara y cinta»), step one.

The author's two downloads are in models/ (outside git):

    panasonic-vhs-c-movie-camera-nv-a3.zip   an OBJ and its maps, two materials
    vhs.zip                                  a Collada file and its maps

This unpacks each into source_assets/<name>/ (outside git too) and writes
what the game is built from to assets/props/<name>/:

    camcorder_body.obj, camcorder_glass.obj   the OBJ, cut in two by its
                                              groups: it names one material
                                              for everything, and the three
                                              glasses of the lens are another
    vhs_tape.dae                              as it came
    *.jpg, *.png                              the maps, at most MAX_SIZE px,
                                              with a .import beside each

The maker's name, the tape format's logo, the type plate and the owner's
initials in marker are painted over on the camera's colour and roughness
maps (PATCHES): what is left is a camcorder, not that one. Step two, in
Godot, bakes the meshes: tools/props/build_camcorder.gd.

    python tools/props/ingest_camcorder.py
"""
import io
import os
import shutil
import zipfile

from PIL import Image, ImageFilter, ImageStat

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MAX_SIZE = 1024

## Rectangles of the camera's maps, in the 0-1024 space of the picture as it
## is looked at (x0, y0, x1, y1), filled with what is around them.
PATCHES = [
    (528, 496, 630, 532),   # the maker's name and the line under it, on the side
    (630, 560, 704, 614),   # the gold badge with the maker's name and the format's
    (410, 250, 480, 272),   # the maker's name, on the top
    (108, 722, 158, 740),   # and over the lens
    (748, 436, 804, 612),   # the type plate
    (914, 480, 946, 542),   # the format's logo
    (568, 684, 618, 704),   # the maker's word for a small camcorder
    (34, 660, 98, 706),     # the owner's initials, in marker
]
PATCHED = {"Camera_BC.png", "Camera_R.png"}
## Groups of the OBJ that are the lens's glasses; everything else is the body.
GLASS = "LensGlass"

IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="res://{folder}/{file}"

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

JOBS = [
    {
        "archive": "models/panasonic-vhs-c-movie-camera-nv-a3.zip",
        "inner": "source/LAATSTE VERSIE.zip",
        "source": "source_assets/camcorder",
        "target": "assets/props/camcorder",
        "model": "LAATSTE VERSIE.obj",
        "maps": {
            "Camera_BC.png": "body_albedo.jpg", "Camera_N.png": "body_normal.png", "Camera_R.png": "body_roughness.jpg",
            "Camera_MT.png": "body_metallic.jpg", "Camera_AO.png": "body_ao.jpg",
            "Lens_BC.png": "lens_albedo.jpg", "Lens_N.png": "lens_normal.png", "Lens_R.png": "lens_roughness.jpg",
        },
    },
    {
        "archive": "models/vhs.zip",
        "inner": "source/model.zip",
        "source": "source_assets/vhs_tape",
        "target": "assets/props/vhs_tape",
        "model": "model.dae",
        "maps": {
            "None_albedo.jpeg": "albedo.jpg", "None_normal.png": "normal.png", "None_roughness.jpeg": "roughness.jpg",
            "None_metallic.jpeg": "metallic.jpg", "None_AO.jpeg": "ao.jpg",
        },
    },
]


def safe(name: str) -> bool:
    return not (name.endswith("/") or ".." in name or name.startswith("/") or ":" in name)


def unpack(job: dict) -> None:
    source = os.path.join(ROOT, job["source"])
    if os.path.isdir(source):
        return
    os.makedirs(source)
    outer = zipfile.ZipFile(os.path.join(ROOT, job["archive"]))
    for info in outer.infolist():
        if not safe(info.filename):
            continue
        if info.filename == job["inner"]:
            nested = zipfile.ZipFile(io.BytesIO(outer.read(info)))
            for sub in nested.infolist():
                if not safe(sub.filename):
                    continue
                folder = "source/textures" if "textures/" in sub.filename else "source"
                path = os.path.join(source, folder, os.path.basename(sub.filename))
                os.makedirs(os.path.dirname(path), exist_ok=True)
                with open(path, "wb") as out:
                    out.write(nested.read(sub))
            continue
        path = os.path.join(source, info.filename)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "wb") as out:
            out.write(outer.read(info))


def paint_over(image: Image.Image) -> Image.Image:
    """Each rectangle of PATCHES filled with the colour round it, edge softened."""
    scale = image.width / 1024.0
    result = image.copy()
    for x0, y0, x1, y1 in PATCHES:
        box = tuple(int(round(v * scale)) for v in (x0, y0, x1, y1))
        ring = int(round(5 * scale))
        outer = image.crop((box[0] - ring, box[1] - ring, box[2] + ring, box[3] + ring))
        mask = Image.new("L", outer.size, 255)
        mask.paste(0, (ring, ring, outer.width - ring, outer.height - ring))
        colour = tuple(int(v) for v in ImageStat.Stat(outer, mask).median)
        if image.mode == "L":
            colour = colour[0]
        soft = Image.new("L", outer.size, 0)
        soft.paste(255, (ring, ring, outer.width - ring, outer.height - ring))
        soft = soft.filter(ImageFilter.GaussianBlur(ring * 0.5))
        flat = Image.new(image.mode, outer.size, colour)
        result.paste(Image.composite(flat, outer, soft), (box[0] - ring, box[1] - ring))
    return result


def split_obj(path: str, target: str) -> None:
    """The OBJ as two: the lens's glasses, and the rest."""
    vertices, coords, normals = [], [], []
    faces = {"body": [], "glass": []}
    part = "body"
    with open(path, encoding="utf-8", errors="replace") as handle:
        for line in handle:
            if line.startswith("v "):
                vertices.append(line.split()[1:4])
            elif line.startswith("vt "):
                coords.append(line.split()[1:3])
            elif line.startswith("vn "):
                normals.append(line.split()[1:4])
            elif line.startswith("g "):
                part = "glass" if GLASS in line else "body"
            elif line.startswith("f "):
                faces[part].append([tuple(int(i) if i else 0 for i in corner.split("/")) for corner in line.split()[1:]])
    for part, listed in faces.items():
        remap = [{}, {}, {}]
        pools = [vertices, coords, normals]
        out = [[], [], []]
        lines = []
        for face in listed:
            corners = []
            for corner in face:
                corner = tuple(corner) + (0,) * (3 - len(corner))
                indices = []
                for kind in range(3):
                    index = corner[kind]
                    if index == 0:
                        indices.append("")
                        continue
                    if index not in remap[kind]:
                        out[kind].append(pools[kind][index - 1])
                        remap[kind][index] = len(out[kind])
                    indices.append(str(remap[kind][index]))
                corners.append("/".join(indices))
            lines.append("f " + " ".join(corners))
        with open(os.path.join(target, "camcorder_%s.obj" % part), "w", newline="\n") as handle:
            handle.write("# %s of the camcorder (tools/props/ingest_camcorder.py)\n" % part)
            for v in out[0]:
                handle.write("v %s\n" % " ".join(v))
            for vt in out[1]:
                handle.write("vt %s\n" % " ".join(vt))
            for vn in out[2]:
                handle.write("vn %s\n" % " ".join(vn))
            handle.write("\n".join(lines) + "\n")
        print("   camcorder_%s.obj  %d vertices, %d faces" % (part, len(out[0]), len(lines)))


def bring(job: dict) -> None:
    source = os.path.join(ROOT, job["source"])
    target = os.path.join(ROOT, job["target"])
    os.makedirs(target, exist_ok=True)
    model = os.path.join(source, "source", job["model"])
    if model.endswith(".obj"):
        split_obj(model, target)
    else:
        shutil.copyfile(model, os.path.join(target, "vhs_tape.dae"))
    for name, out in job["maps"].items():
        image = Image.open(os.path.join(source, "textures", name))
        if name in PATCHED:
            image = paint_over(image)
        if out.endswith(".jpg"):
            image = image.convert("RGB")
        if max(image.size) > MAX_SIZE:
            image = image.resize((MAX_SIZE, MAX_SIZE), Image.LANCZOS)
        path = os.path.join(target, out)
        if out.endswith(".jpg"):
            image.save(path, quality=90)
        else:
            image.save(path, optimize=True)
        if not os.path.exists(path + ".import"):
            with open(path + ".import", "w", newline="\n") as handle:
                handle.write(IMPORT.format(folder=job["target"], file=out, normal=1 if "normal" in out else 2))
        print("   %-22s -> %s" % (name, out))


if __name__ == "__main__":
    for job in JOBS:
        print(job["archive"])
        unpack(job)
        bring(job)
