"""Close-ups of the face and the hands, in the reference staircase with its
light, after scene.py has put the creature there.

    blender -b art/stalker/stalker.blend -P tools/art/stalker/beauty.py -- --out DIR [--samples 128]
"""

import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import preview  # noqa: E402


def bone_point(rig, name, along=0.0, offset=(0, 0, 0)):
    pb = rig.pose.bones[name]
    m = rig.matrix_world @ pb.matrix
    return m @ Vector((0.0, pb.length * along, 0.0)) + Vector(offset)


def shoot(scene, name, loc, target, lens, out, light=None):
    cd = bpy.data.cameras.get("closeup") or bpy.data.cameras.new("closeup")
    cd.lens = lens
    cd.sensor_fit = "AUTO"
    cd.clip_start = 0.01
    ob = bpy.data.objects.get("closeup") or bpy.data.objects.new("closeup", cd)
    if ob.name not in scene.collection.objects:
        scene.collection.objects.link(ob)
    ob.location = loc
    ob.rotation_euler = (target - loc).to_track_quat("-Z", "Y").to_euler()
    scene.camera = ob
    lamp = None
    if light:
        ld = bpy.data.lights.new("closeup_light", "AREA")
        ld.energy, ld.size, ld.color = light[1], 0.3, (1.0, 0.88, 0.74)
        lamp = bpy.data.objects.new("closeup_light", ld)
        scene.collection.objects.link(lamp)
        lamp.location = light[0]
        lamp.rotation_euler = (target - light[0]).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(out, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("[beauty] wrote", scene.render.filepath, flush=True)
    if lamp:
        bpy.data.objects.remove(lamp, do_unlink=True)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = argv[argv.index("--out") + 1]
    samples = int(argv[argv.index("--samples") + 1]) if "--samples" in argv else 128
    os.makedirs(out, exist_ok=True)
    scene = bpy.context.scene
    preview.setup_cycles(samples)
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.render.resolution_x = 1000
    scene.render.resolution_y = 1000
    rig = bpy.data.objects["stalker_rig"]
    scene.frame_set(1)
    head = bone_point(rig, "head", 0.0, (0, -0.07, 0.07))
    shoot(scene, "face", head + Vector((0.02, -0.62, -0.05)), head, 70, out,
          light=(head + Vector((0.25, -0.7, -0.3)), 6.0))
    shoot(scene, "face_low", head + Vector((-0.18, -0.5, -0.32)), head, 60, out,
          light=(head + Vector((-0.2, -0.45, -0.5)), 4.0))
    for arm, dist, lens in (("a.L", 0.62, 55), ("a.R", 0.62, 55), ("b.L", 0.42, 55), ("c.R", 0.5, 55)):
        a, s = arm.split(".")
        hand = bone_point(rig, "middle_02_%s.%s" % (a, s), 0.0)
        cam = hand + Vector((0.28 if s == "R" and a == "c" else 0.0, -dist, 0.12 if a == "c" else -0.08))
        shoot(scene, "hand_%s" % arm.replace(".", ""), cam, hand, lens, out, light=(hand + Vector((0.3, -0.5, -0.2)), 5.0))


if __name__ == "__main__":
    main()
