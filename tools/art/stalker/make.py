"""The whole creature, start to finish: model, rig, animations, the .blend and
the GLB the game imports.

    blender -b --factory-startup -P tools/art/stalker/make.py -- --blend art/stalker/stalker.blend --glb assets/enemies/stalker/stalker.glb
"""

import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import animate  # noqa: E402
import build  # noqa: E402


def export_glb(path):
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    rig = bpy.data.objects["stalker_rig"]
    ad = rig.animation_data
    keep = (ad.action, ad.action_slot)
    bpy.ops.export_scene.gltf(
        filepath=os.path.abspath(path),
        export_format="GLB",
        export_yup=True,
        export_apply=True,
        export_texcoords=True,
        export_normals=True,
        export_tangents=False,
        export_materials="EXPORT",
        export_vertex_color="MATERIAL",
        export_cameras=False,
        export_lights=False,
        export_skins=True,
        export_influence_nb=4,
        export_def_bones=True,
        export_leaf_bone=False,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_force_sampling=True,
        export_frame_step=1,
        export_optimize_animation_size=True,
        export_anim_slide_to_zero=True,
        export_reset_pose_bones=True,
        export_extras=True,
    )
    ad.action, ad.action_slot = keep
    build.log("exported", path, "%.1f MB" % (os.path.getsize(path) / 1e6))


def main():
    opts = build.args()
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    blend = argv[argv.index("--blend") + 1] if "--blend" in argv else None
    glb = argv[argv.index("--glb") + 1] if "--glb" in argv else None
    rig = build.build(opts)
    animate.build_all(rig)
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = 120
    if blend:
        build.save(blend)
    if glb:
        export_glb(glb)


if __name__ == "__main__":
    main()
