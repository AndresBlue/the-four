"""Makes an office download into the pieces the game needs, as a glTF for
tools/props/ingest_models.py (the _gltf/ folder it reads first), by the
download's entry in tools/props/fit_models.json:

    blender -b --factory-startup -P tools/props/fit_model.py -- <group>/<slug>

Each part of the entry is some of the download's objects (by a pattern for
their names; "source" takes them from another download, the hinges a door
borrows), turned ("turn", degrees about the vertical, after the entry's own),
and fitted into a box given in the game's frame (x, y up, z; metres): the
bounding box of the objects "fit" names (the part's own by default) is
stretched onto it, so a door's casing can be fitted by its leaf's opening.
An axis given as null takes the mean of the other axes' stretch, centred on
0 (floor at 0 for y) as the fit's bounds are; {"self": [a, b]} fits that axis by the part's own
extent instead. "places" puts a copy in each of several boxes; "repeat" lays
n copies side by side along x, each in its share of the box; "mirror" copies
the objects it names onto the other face (z mirrored about the fit's middle):
a lever modelled on one face only; "flip" mirrors them so instead (the
other shoe of a pair). "shrink" collapses the objects it names to
a share of their triangles (welded first, tools/props/decimate.py). A stretch
of the face (x against y) past "max_stretch" (default 1.1) is reported.
Every part's objects are named <part>_<n>, for build_catalogue.gd's PARTS.
"""
import json
import math
import os
import re
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from decimate import shrink, tris_of, weld  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SPECS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fit_models.json")


def imported(path):
    """The mesh objects a glTF brings, transforms applied, unparented."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [ob for ob in bpy.data.objects if ob not in before]
    meshes = [ob for ob in new if ob.type == "MESH"]
    for ob in meshes:
        world = ob.matrix_world.copy()
        ob.parent = None
        ob.data = ob.data.copy()
        ob.data.transform(world)
        ob.matrix_world = Matrix.Identity(4)
    for ob in new:
        if ob.type != "MESH": bpy.data.objects.remove(ob)
    return meshes


def turn(ob, degrees):
    if degrees: ob.data.transform(Matrix.Rotation(math.radians(degrees), 4, "Z"))


def bounds(objects):
    points = [v.co for ob in objects for v in ob.data.vertices]
    return Vector([min(p[i] for p in points) for i in range(3)]), Vector([max(p[i] for p in points) for i in range(3)])


def to_blender(box):
    """A box in the game's frame ([x], [y], [z]) as Blender's ([x], [y], [z]):
    Blender y is the game's -z, Blender z its y."""
    x, y, z = box

    def flip(axis):
        if axis is None: return None
        if isinstance(axis, dict): return {"self": [-axis["self"][1], -axis["self"][0]]}
        return [-axis[1], -axis[0]]
    return [x, flip(z), y]


def fit(objects, reference, box, own):
    """Stretches `objects` so `reference`'s bounds fill `box` (Blender axes)."""
    lo, hi = bounds(reference)
    own_lo, own_hi = bounds(objects)
    scale = [None] * 3
    for i, axis in enumerate(box):
        if isinstance(axis, list): scale[i] = (axis[1] - axis[0]) / max(hi[i] - lo[i], 1e-9)
        elif isinstance(axis, dict): scale[i] = (axis["self"][1] - axis["self"][0]) / max(own_hi[i] - own_lo[i], 1e-9)
    given = [s for s in scale if s is not None]
    mean = sum(given) / len(given)
    shift = [0.0] * 3
    for i, axis in enumerate(box):
        if scale[i] is None:
            scale[i] = mean
            # The fit's bounds centred across, on the floor upright.
            shift[i] = -lo[i] * mean if i == 2 else -(lo[i] + hi[i]) * 0.5 * mean
        elif isinstance(axis, dict):
            shift[i] = axis["self"][0] - own_lo[i] * scale[i]
        else:
            shift[i] = axis[0] - lo[i] * scale[i]
    matrix = Matrix.Translation(Vector(shift)) @ Matrix.Diagonal(Vector(scale + [1.0]))
    for ob in objects: ob.data.transform(matrix)
    return scale


def mirrored(ob, middle):
    """A copy of ob mirrored across the plane y = middle (Blender), faces turned back out."""
    copy = ob.copy()
    copy.data = ob.data.copy()
    bpy.context.scene.collection.objects.link(copy)
    copy.data.transform(Matrix.Translation((0, middle, 0)) @ Matrix.Diagonal((1, -1, 1, 1)) @ Matrix.Translation((0, -middle, 0)))
    bm = bmesh.new()
    bm.from_mesh(copy.data)
    bmesh.ops.reverse_faces(bm, faces=bm.faces)
    bm.to_mesh(copy.data)
    bm.free()
    return copy


def copies(objects):
    out = []
    for ob in objects:
        copy = ob.copy()
        copy.data = ob.data.copy()
        bpy.context.scene.collection.objects.link(copy)
        out.append(copy)
    return out


def main():
    key = sys.argv[sys.argv.index("--") + 1]
    group, slug = key.split("/")
    spec = json.load(open(SPECS, encoding="utf-8"))[slug]
    # props/<slug>: a Poly Haven download in source_assets/props/.
    folder = os.path.join(ROOT, "source_assets", "props", slug) if group == "props" else os.path.join(ROOT, "source_assets", "oficinas", group, slug)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sources = {}

    def source(path):
        if path not in sources:
            sources[path] = imported(os.path.join(folder, path))
            for ob in sources[path]: turn(ob, spec.get("turn", 0))
        return sources[path]
    source(spec["in"])
    made = []
    limit = spec.get("max_stretch", 1.1)
    for part in spec["parts"]:
        pool = source(part.get("source", spec["in"]))
        own = [ob for ob in pool if re.search(part["objects"], ob.name)]
        if not own:
            print("FIT_FAILED %s no objects for %s" % (slug, part["name"]))
            sys.exit(1)
        boxes = part.get("places") or [part["box"]]
        for box in boxes:
            repeat = int(part.get("repeat", 1))
            for k in range(repeat):
                cell = list(box)
                if repeat > 1:
                    wide = (box[0][1] - box[0][0]) / repeat
                    cell[0] = [box[0][0] + wide * k, box[0][0] + wide * (k + 1)]
                objects = copies(own)
                reference = copies([ob for ob in pool if re.search(part.get("fit", part["objects"]), ob.name)])
                for ob in objects + reference: turn(ob, part.get("turn", 0))
                lo, hi = bounds(reference)
                middle = (lo[1] + hi[1]) * 0.5
                # By the download's own names (a copy's has a suffix).
                names = {ob: src.name for ob, src in zip(objects, own)}
                if part.get("flip"):
                    twins = [mirrored(ob, middle) for ob in objects]
                    for ob in objects: bpy.data.objects.remove(ob)
                    objects = twins
                    names = {twin: src.name for twin, src in zip(objects, own)}
                if part.get("mirror"):
                    for ob in list(objects):
                        if re.search(part["mirror"], names[ob]):
                            twin = mirrored(ob, middle)
                            names[twin] = names[ob]
                            objects.append(twin)
                scale = fit(objects, reference, to_blender(cell), objects)
                for ob in reference: bpy.data.objects.remove(ob)
                stretch = max(scale[0], scale[2]) / min(scale[0], scale[2])
                print("FIT %s %s stretch=%.3f%s" % (slug, part["name"], stretch, "  WARN past %.2f" % limit if stretch > limit else ""))
                for pattern, ratio in part.get("shrink", {}).items():
                    for ob in objects:
                        if re.search(pattern, names[ob]):
                            weld(ob)
                            shrink(ob, ratio)
                made += [(part["name"], ob) for ob in objects]
    keep = {ob for _, ob in made}
    for ob in list(bpy.data.objects):
        if ob not in keep: bpy.data.objects.remove(ob)
    count = {}
    for name, ob in made:
        count[name] = count.get(name, 0) + 1
        ob.name = "%s_%d" % (name, count[name])
    for name in count:
        objects = [ob for n, ob in made if n == name]
        lo, hi = bounds(objects)
        size = hi - lo
        # In the game's frame: x, y (up), z.
        print("FIT_PART %s %s tris=%d size=(%.3f, %.3f, %.3f) x=%.3f..%.3f y=%.3f..%.3f z=%.3f..%.3f" % (slug, name, sum(tris_of(ob) for ob in objects), size.x, size.z, size.y, lo.x, hi.x, lo.z, hi.z, -hi.y, -lo.y))
    out = os.path.join(folder, spec["out"])
    os.makedirs(os.path.dirname(out), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLTF_SEPARATE")
    print("FIT_DONE %s %s" % (slug, out))


if __name__ == "__main__":
    main()
