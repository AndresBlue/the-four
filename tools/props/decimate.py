"""Brings a downloaded model under a triangle budget, or only converts it,
as a glTF with its textures beside it (spec_rediseno 5.1: small pieces under
5 k triangles, large ones under 20 k). glTF, GLB, FBX or OBJ in; the result
for a download goes to its _gltf/ folder, which tools/props/ingest_models.py
reads first.

    blender -b --factory-startup -P tools/props/decimate.py -- --in <model> --out <folder>/_gltf/<name>.gltf --tris 5000

--tris 0 only converts.
"""

import os
import sys

import bmesh
import bpy


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = {"in": None, "out": None, "tris": 0}
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--in":
            out["in"] = argv[i + 1]
            i += 1
        elif a == "--out":
            out["out"] = argv[i + 1]
            i += 1
        elif a == "--tris":
            out["tris"] = int(argv[i + 1])
            i += 1
        i += 1
    return out


def load(path):
    ext = os.path.splitext(path)[1].lower()
    if ext in (".gltf", ".glb"):
        bpy.ops.import_scene.gltf(filepath=path)
    elif ext == ".fbx":
        bpy.ops.import_scene.fbx(filepath=path)
    elif ext == ".obj":
        bpy.ops.wm.obj_import(filepath=path)
    else:
        print("DECIMATE_FAILED unknown format")
        sys.exit(1)


def tris_of(ob):
    # Polygons are counted as fans: a quad is two triangles.
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def shrink(ob, ratio):
    mod = ob.modifiers.new("Decimate", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = ratio
    mod.use_symmetry = False
    deps = bpy.context.evaluated_depsgraph_get()
    ev = ob.evaluated_get(deps)
    new = bpy.data.meshes.new_from_object(ev)
    ob.modifiers.remove(mod)
    old = ob.data
    name = old.name
    ob.data = new
    # A mesh may be shared by several objects: gone only when none is left.
    if old.users == 0:
        bpy.data.meshes.remove(old)
    new.name = name
    # collapsing leaves the odd degenerate face behind
    bm = bmesh.new()
    bm.from_mesh(new)
    bmesh.ops.dissolve_degenerate(bm, dist=1e-6, edges=bm.edges)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(new)
    bm.free()
    new.validate(clean_customdata=False)
    new.update()


def main():
    opts = args()
    if not opts["in"] or not opts["out"]:
        print(__doc__)
        sys.exit(2)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    load(opts["in"])
    meshes = [ob for ob in bpy.context.scene.objects if ob.type == "MESH"]
    before = sum(tris_of(ob) for ob in meshes)
    budget = opts["tris"]
    if budget > 0 and before > budget:
        # Every mesh gets the same ratio, so the total lands near the budget.
        ratio = budget / before
        for ob in meshes:
            shrink(ob, ratio)
    after = sum(tris_of(ob) for ob in meshes)
    os.makedirs(os.path.dirname(os.path.abspath(opts["out"])), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=os.path.abspath(opts["out"]), export_format="GLTF_SEPARATE")
    print("DECIMATE before=%d after=%d objects=%d out=%s" % (before, after, len(meshes), opts["out"]))


if __name__ == "__main__":
    main()
