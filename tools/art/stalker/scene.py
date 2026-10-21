"""The reference picture rebuilt: a narrow carpeted staircase between two
plaster walls, the creature coming down it, a camera at the foot of the stairs.
Renders the comparison still (and puts the scene in the .blend when asked).

    blender -b art/stalker/stalker.blend -P tools/art/stalker/scene.py -- --out DIR [--samples 128] [--save]
"""

import math
import os
import sys

import bpy
import bmesh
from mathutils import Euler, Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import animate  # noqa: E402
import preview  # noqa: E402
from animate import V, deg, rot, curl_all, toes_curl  # noqa: E402

TREAD = 0.26
RISE = 0.18
FIRST = -1.0  # y of the first riser
HALF = 0.48  # half the corridor's width
CREATURE_Y = 0.12


def step_z(y):
    if y < FIRST:
        return 0.0
    return (math.floor((y - FIRST) / TREAD) + 1) * RISE


def mat(name, color, rough=0.9, noise=0.0, scale=40.0, bump=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes.get("Principled BSDF")
    b.inputs["Roughness"].default_value = rough
    b.inputs["Specular IOR Level"].default_value = 0.2
    if noise or bump:
        tex = nt.nodes.new("ShaderNodeTexNoise")
        tex.inputs["Scale"].default_value = scale
        tex.inputs["Detail"].default_value = 8.0
        ramp = nt.nodes.new("ShaderNodeMix")
        ramp.data_type = "RGBA"
        ramp.inputs["A"].default_value = (*[c * (1 - noise) for c in color], 1)
        ramp.inputs["B"].default_value = (*[min(1.0, c * (1 + noise)) for c in color], 1)
        nt.links.new(tex.outputs["Fac"], ramp.inputs["Factor"])
        nt.links.new(ramp.outputs["Result"], b.inputs["Base Color"])
        if bump:
            bp = nt.nodes.new("ShaderNodeBump")
            bp.inputs["Strength"].default_value = bump
            nt.links.new(tex.outputs["Fac"], bp.inputs["Height"])
            nt.links.new(bp.outputs["Normal"], b.inputs["Normal"])
    else:
        b.inputs["Base Color"].default_value = (*color, 1)
    return m


def box(bm, lo, hi):
    r = bmesh.ops.create_cube(bm, size=1.0)
    for v in r["verts"]:
        v.co = Vector((lo[i] + (hi[i] - lo[i]) * (v.co[i] + 0.5) for i in range(3)))


def obj(name, bm, material, coll):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(material)
    ob = bpy.data.objects.new(name, me)
    coll.objects.link(ob)
    return ob


def build_stairs(coll):
    carpet = mat("stair_carpet", (0.014, 0.019, 0.027), 1.0, noise=0.35, scale=180.0, bump=0.25)
    plaster = mat("stair_plaster", (0.42, 0.36, 0.27), 0.95, noise=0.12, scale=12.0, bump=0.05)
    ceiling = mat("stair_ceiling", (0.55, 0.5, 0.44), 0.95, noise=0.08, scale=8.0)
    bm = bmesh.new()
    box(bm, (-HALF, -5.0, -0.1), (HALF, FIRST, 0.0))
    for i in range(34):
        y0 = FIRST + i * TREAD
        box(bm, (-HALF, y0, 0.0), (HALF, y0 + TREAD, (i + 1) * RISE))
    obj("stairs", bm, carpet, coll)
    bm = bmesh.new()
    for sx in (-1, 1):
        x = sx * HALF
        box(bm, (x + (0.0 if sx > 0 else -0.05), -5.0, -0.1), (x + (0.05 if sx > 0 else 0.0), 10.0, 9.5))
    obj("walls", bm, plaster, coll)
    bm = bmesh.new()
    # the ceiling follows the stairs, 2.35 m above the nosing line
    slope = RISE / TREAD
    v = [bm.verts.new((-HALF, y, 3.3 if y < FIRST else 2.35)) for y in (-5.0, FIRST)]
    v += [bm.verts.new((HALF, y, 3.3 if y < FIRST else 2.35)) for y in (FIRST, -5.0)]
    v2 = [bm.verts.new((-HALF, 10.0, 2.35 + (10.0 - FIRST) * slope)), bm.verts.new((HALF, 10.0, 2.35 + (10.0 - FIRST) * slope))]
    bm.faces.new([v[0], v[3], v[2], v[1]])
    bm.faces.new([v[1], v[2], v2[1], v2[0]])
    obj("ceiling", bm, ceiling, coll)


def stair_pose(rig):
    """The picture's pose on these stairs: the steps ahead of it are lower."""
    zc = step_z(CREATURE_Y)
    return animate.loom_pose(rig, ground=lambda y: step_z(CREATURE_Y + y) - zc)


def apply_pose(rig_ob, spec):
    """Puts the pose on the rig as a one-frame action, reference_pose, and
    makes it the active one (the clips stay in the NLA)."""
    rig = animate.Rig(rig_ob)
    basis, _ = rig.solve(spec)
    act, slot = animate.write_action(rig, "reference_pose", [basis], loop=False)
    rig_ob.animation_data_create()
    rig_ob.animation_data.action = act
    rig_ob.animation_data.action_slot = slot
    bpy.context.scene.frame_set(1)


def lights(coll):
    def area(name, loc, target, power, size, color):
        ld = bpy.data.lights.new(name, "AREA")
        ld.energy = power
        ld.size = size
        ld.color = color
        ob = bpy.data.objects.new(name, ld)
        coll.objects.link(ob)
        ob.location = Vector(loc)
        ob.rotation_euler = (Vector(target) - ob.location).to_track_quat("-Z", "Y").to_euler()
    warm = (1.0, 0.9, 0.78)
    area("flash", (0.12, -1.55, 1.58), (0.0, 0.3, 1.9), 45.0, 0.2, warm)
    area("landing", (0.0, 3.4, 4.4), (0.0, 0.5, 2.0), 70.0, 1.0, (1.0, 0.9, 0.78))
    area("bounce", (0.0, -1.2, 2.6), (0.0, 0.8, 0.8), 15.0, 0.8, warm)


def camera(coll):
    cd = bpy.data.cameras.new("stair_cam")
    cd.lens = 15.0
    cd.sensor_fit = "VERTICAL"
    cd.sensor_height = 24.0
    ob = bpy.data.objects.new("stair_cam", cd)
    coll.objects.link(ob)
    ob.location = Vector((0.03, -1.42, 1.36))
    ob.rotation_euler = Euler((math.radians(98.0), 0.0, 0.0))
    bpy.context.scene.camera = ob
    return ob


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = argv[argv.index("--out") + 1] if "--out" in argv else "."
    samples = int(argv[argv.index("--samples") + 1]) if "--samples" in argv else 128
    scene = bpy.context.scene
    coll = bpy.data.collections.new("Reference staircase")
    scene.collection.children.link(coll)
    build_stairs(coll)
    lights(coll)
    camera(coll)
    w = bpy.data.worlds.get("stair_world") or bpy.data.worlds.new("stair_world")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.05, 0.04, 0.03, 1)
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.3
    scene.world = w
    # the creature stays at the origin: the stairs move under it
    offset = Vector((0.0, -CREATURE_Y, -step_z(CREATURE_Y)))
    for ob in coll.objects:
        ob.location += offset
    rig = bpy.data.objects["stalker_rig"]
    apply_pose(rig, stair_pose(rig))
    preview.setup_cycles(samples)
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.render.resolution_x = 736
    scene.render.resolution_y = 996
    scene.cycles.samples = samples
    if "--no-render" not in argv:
        os.makedirs(out, exist_ok=True)
        scene.render.filepath = os.path.join(out, "stairs.png")
        bpy.ops.render.render(write_still=True)
        print("[scene] wrote", scene.render.filepath, flush=True)
    if "--save" in argv:
        bpy.context.preferences.filepaths.save_version = 0
        bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath, compress=True)


if __name__ == "__main__":
    main()
