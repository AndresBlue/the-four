"""Studio renders of the built creature, for looking at it.

    blender -b <file.blend> -P tools/art/lurker/preview.py -- --outdir DIR [--views face,body] [--clay] [--samples 64]
"""

import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import anatomy  # noqa: E402


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = {"outdir": ".", "views": None, "clay": False, "samples": 48, "res": 900, "pose": None, "frame": None}
    i = 0
    while i < len(argv):
        a = argv[i]
        if a in ("--outdir", "--views", "--samples", "--res", "--pose", "--frame"):
            out[a[2:]] = argv[i + 1]
            i += 1
        elif a == "--clay":
            out["clay"] = True
        i += 1
    out["samples"] = int(out["samples"])
    out["res"] = int(out["res"])
    if out["views"]:
        out["views"] = out["views"].split(",")
    return out


def setup_cycles(samples):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    prefs = bpy.context.preferences.addons["cycles"].preferences
    for kind in ("OPTIX", "CUDA"):
        try:
            prefs.compute_device_type = kind
            prefs.get_devices()
            if any(d.type == kind for d in prefs.devices):
                for d in prefs.devices:
                    d.use = d.type == kind
                scene.cycles.device = "GPU"
                break
        except Exception:
            continue
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"


def world(color=(0.18, 0.18, 0.19), strength=1.0):
    w = bpy.data.worlds.get("preview") or bpy.data.worlds.new("preview")
    w.use_nodes = True
    bg = w.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (*color, 1.0)
    bg.inputs["Strength"].default_value = strength
    bpy.context.scene.world = w


def area_light(name, loc, target, power, size, color=(1, 1, 1)):
    ld = bpy.data.lights.new(name, "AREA")
    ld.energy = power
    ld.size = size
    ld.color = color
    ob = bpy.data.objects.new(name, ld)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = Vector(loc)
    d = Vector(target) - ob.location
    ob.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    return ob


def camera(loc, target, lens=50.0, ortho=None):
    cd = bpy.data.cameras.get("preview_cam") or bpy.data.cameras.new("preview_cam")
    cd.lens = lens
    cd.clip_start = 0.01
    if ortho:
        cd.type = "ORTHO"
        cd.ortho_scale = ortho
    else:
        cd.type = "PERSP"
    ob = bpy.data.objects.get("preview_cam") or bpy.data.objects.new("preview_cam", cd)
    if ob.name not in bpy.context.scene.collection.objects:
        bpy.context.scene.collection.objects.link(ob)
    ob.location = Vector(loc)
    d = Vector(target) - ob.location
    ob.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = ob
    return ob


def clay():
    m = bpy.data.materials.new("clay")
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (0.5, 0.48, 0.46, 1)
    b.inputs["Roughness"].default_value = 0.6
    bpy.context.view_layer.material_override = m


def floor():
    me = bpy.data.meshes.new("floor")
    s = 6.0
    me.from_pydata([(-s, -s, 0), (s, -s, 0), (s, s, 0), (-s, s, 0)], [], [(0, 1, 2, 3)])
    ob = bpy.data.objects.new("floor", me)
    bpy.context.scene.collection.objects.link(ob)
    m = bpy.data.materials.new("floor")
    m.use_nodes = True
    m.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value = (0.25, 0.25, 0.26, 1)
    me.materials.append(m)


hc = anatomy.HEAD_CENTER
VIEWS = {
    "face": dict(cam=(0.0, -0.55, hc[2] + 0.0), target=(0, hc[1], hc[2] - 0.03), lens=85),
    "face34": dict(cam=(0.32, -0.45, hc[2] + 0.06), target=(0, hc[1], hc[2] - 0.03), lens=85),
    "faceside": dict(cam=(0.55, hc[1], hc[2]), target=(0, hc[1], hc[2] - 0.03), lens=85),
    "body": dict(cam=(0.0, -4.2, 1.2), target=(0, 0, 1.05), lens=50),
    "body34": dict(cam=(2.6, -3.2, 1.6), target=(0, 0, 1.05), lens=50),
    "bodyside": dict(cam=(4.2, 0.0, 1.2), target=(0, 0, 1.05), lens=50),
    "handa": dict(cam=None, target=None, lens=60, hand="a"),
    "handb": dict(cam=None, target=None, lens=60, hand="b"),
    "handc": dict(cam=None, target=None, lens=60, hand="c"),
    "foot": dict(cam=(0.5, -0.6, 0.35), target=(0.2, -0.05, 0.05), lens=60),
}


def main():
    o = args()
    setup_cycles(o["samples"])
    scene = bpy.context.scene
    scene.render.resolution_x = o["res"]
    scene.render.resolution_y = o["res"]
    world()
    if o["clay"]:
        clay()
    if o["pose"]:
        rig = bpy.data.objects.get("lurker_rig")
        act = bpy.data.actions.get(o["pose"])
        if rig and act:
            rig.animation_data_create()
            rig.animation_data.action = act
            if rig.animation_data.action_slot is None and len(act.slots):
                rig.animation_data.action_slot = act.slots[0]
            scene.frame_set(int(o["frame"] or act.frame_range[0]))
    views = o["views"] or ["face", "face34", "body", "handa"]
    os.makedirs(o["outdir"], exist_ok=True)
    lights = []
    for name in views:
        for ob in lights:
            bpy.data.objects.remove(ob, do_unlink=True)
        v = VIEWS[name]
        if v.get("hand"):
            fr, fingers = anatomy.hand_points(v["hand"])
            c = fr["wrist"] + fr["f"] * 0.12 * anatomy.ARMS[v["hand"]]["scale"]
            cam = c + fr["n"] * 0.55 * anatomy.ARMS[v["hand"]]["scale"] + fr["t"] * 0.12
            camera(tuple(cam), tuple(c), v["lens"])
            target = c
        else:
            camera(v["cam"], v["target"], v["lens"])
            target = Vector(v["target"])
        cam_ob = scene.camera
        t = Vector(target)
        cl = cam_ob.location
        right = (t - cl).cross(Vector((0, 0, 1))).normalized()
        dist = (t - cl).length
        lights = [
            area_light("key", cl + right * dist * 0.6 + Vector((0, 0, dist * 0.5)), t, 60 * dist * dist, dist * 0.5),
            area_light("fill", cl - right * dist * 0.8, t, 15 * dist * dist, dist * 0.8),
            area_light("rim", t + (t - cl).normalized() * dist * 0.8 + Vector((0, 0, dist * 0.6)), t, 120 * dist * dist, dist * 0.4, (1, 0.95, 0.9)),
        ]
        scene.render.filepath = os.path.join(o["outdir"], name + (".clay" if o["clay"] else "") + ".png")
        bpy.ops.render.render(write_still=True)
        print("[preview] wrote", scene.render.filepath, flush=True)


if __name__ == "__main__":
    main()
