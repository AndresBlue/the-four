"""Renders every clip at a few moments, from a fixed camera, for checking the
animations by eye.

    blender -b art/lurker/lurker.blend -P tools/art/lurker/poses.py -- --outdir DIR [--clips crawl,loom] [--frames 4]
"""

import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import preview  # noqa: E402


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    outdir = argv[argv.index("--outdir") + 1]
    clips = argv[argv.index("--clips") + 1].split(",") if "--clips" in argv else None
    nframes = int(argv[argv.index("--frames") + 1]) if "--frames" in argv else 4
    cam_name = argv[argv.index("--cam") + 1] if "--cam" in argv else "34"
    res = int(argv[argv.index("--res") + 1]) if "--res" in argv else 520
    clay = "--clay" in argv
    preview.setup_cycles(int(argv[argv.index("--samples") + 1]) if "--samples" in argv else 20)
    scene = bpy.context.scene
    scene.render.resolution_x = res
    scene.render.resolution_y = res
    preview.world((0.2, 0.2, 0.21), 1.0)
    preview.floor()
    if clay:
        preview.clay()
    cams = {
        "34": ((2.4, -2.6, 1.5), (0, -0.2, 0.6)),
        "front": ((0.0, -3.4, 1.0), (0, -0.2, 0.8)),
        "side": ((3.4, -0.2, 0.9), (0, -0.2, 0.6)),
        "top": ((0.01, -0.3, 3.8), (0, -0.25, 0.0)),
    }
    loc, tgt = cams[cam_name]
    preview.camera(loc, tgt, 40)
    t = Vector(tgt)
    cl = Vector(loc)
    right = (t - cl).cross(Vector((0, 0, 1))).normalized()
    dist = (t - cl).length
    preview.area_light("key", cl + right * dist * 0.6 + Vector((0, 0, dist * 0.6)), t, 70 * dist * dist, dist * 0.6)
    preview.area_light("fill", cl - right * dist * 0.8, t, 20 * dist * dist, dist)
    preview.area_light("rim", t + (t - cl).normalized() * dist + Vector((0, 0, dist * 0.7)), t, 160 * dist * dist, dist * 0.5)
    rig = bpy.data.objects["lurker_rig"]
    ad = rig.animation_data
    os.makedirs(outdir, exist_ok=True)
    for act in bpy.data.actions:
        if clips and act.name not in clips:
            continue
        ad.action = act
        ad.action_slot = act.slots[0]
        f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
        for i in range(nframes):
            fr = f0 + round((f1 - f0) * i / max(nframes, 1)) if act.get("loop") else f0 + round((f1 - f0) * i / max(nframes - 1, 1))
            scene.frame_set(fr)
            scene.render.filepath = os.path.join(outdir, "%s_%s_%03d.png" % (act.name, cam_name, fr))
            bpy.ops.render.render(write_still=True)
            print("[poses] wrote", scene.render.filepath, flush=True)


if __name__ == "__main__":
    main()
