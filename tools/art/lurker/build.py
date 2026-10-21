"""Builds the creature in Blender: meshes from the distance fields, the
skeleton, weights, vertex colours, eyes, teeth, claws and hair.

    blender -b --factory-startup -P tools/art/lurker/build.py -- --out art/lurker/lurker.blend

--only head,hand_a.L limits it to some parts (for looking at one piece);
--fast meshes everything coarser.
"""

import math
import os
import sys
import time

import bpy
import bmesh
import numpy as np
from mathutils import Matrix, Vector
from mathutils.kdtree import KDTree

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import anatomy  # noqa: E402
import sdf  # noqa: E402
from anatomy import ARMS, HEAD_CENTER  # noqa: E402

RNG = np.random.default_rng(2110)

BLACK = np.array([0.0062, 0.006, 0.006])


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = {"out": None, "only": None, "fast": False, "fur": 1.0}
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--out":
            out["out"] = argv[i + 1]
            i += 1
        elif a == "--only":
            out["only"] = set(argv[i + 1].split(","))
            i += 1
        elif a == "--fast":
            out["fast"] = True
        elif a == "--fur":
            out["fur"] = float(argv[i + 1])
            i += 1
        i += 1
    return out


def log(*a):
    print("[lurker]", *a, flush=True)


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


# ---------------------------------------------------------------- scene

def clear_scene():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.armatures, bpy.data.materials, bpy.data.actions, bpy.data.images):
        for d in list(coll):
            coll.remove(d)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.render.fps = 30


def collection(name):
    c = bpy.data.collections.get(name)
    if c is None:
        c = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(c)
    return c


def mesh_object(name, verts, faces, coll):
    me = bpy.data.meshes.new(name)
    faces = faces.tolist() if isinstance(faces, np.ndarray) else [list(f) for f in faces]
    me.from_pydata(verts.tolist(), [], faces)
    me.validate(clean_customdata=False)
    me.update()
    ob = bpy.data.objects.new(name, me)
    coll.objects.link(ob)
    return ob


def decimate(ob, target_tris):
    me = ob.data
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    if tris <= target_tris:
        return
    mod = ob.modifiers.new("Decimate", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = target_tris / tris
    mod.use_symmetry = False
    deps = bpy.context.evaluated_depsgraph_get()
    ev = ob.evaluated_get(deps)
    new = bpy.data.meshes.new_from_object(ev)
    ob.modifiers.remove(mod)
    old = ob.data
    name = old.name
    ob.data = new
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


def verts_np(me):
    v = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", v)
    return v.reshape(-1, 3)


def normals_np(me):
    n = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("normal", n)
    return n.reshape(-1, 3)


def tris_np(me):
    me.calc_loop_triangles()
    t = np.empty(len(me.loop_triangles) * 3, dtype=np.int64)
    me.loop_triangles.foreach_get("vertices", t)
    return t.reshape(-1, 3)


def set_colors(me, rgb, name="Col"):
    attr = me.color_attributes.get(name) or me.color_attributes.new(name, "FLOAT_COLOR", "POINT")
    rgba = np.concatenate([np.clip(rgb, 0, 1), np.ones((len(rgb), 1))], axis=1)
    attr.data.foreach_set("color", rgba.astype(np.float32).ravel())
    me.color_attributes.active_color = attr
    me.color_attributes.render_color_index = me.color_attributes.find(name)


def shade_smooth(me):
    me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
    me.update()


# ---------------------------------------------------------------- weights

def seg_dist(p, a, b):
    ab = b - a
    l2 = float(ab @ ab)
    if l2 < 1e-12:
        return np.linalg.norm(p - a, axis=1)
    t = np.clip(((p - a) @ ab) / l2, 0.0, 1.0)
    return np.linalg.norm(p - (a + t[:, None] * ab), axis=1)


def bone_weights(p, bones, names, power=8.0, keep=4):
    """Each vertex to the bones it is nearest, measured against each bone's
    thickness; joints blend over about one radius either side."""
    D = []
    for n in names:
        b = bones[n]
        d = np.min([seg_dist(p, a, c) for a, c in b.segs], axis=0)
        D.append(d / b.radius)
    D = np.stack(D, axis=1)
    W = (D + 1e-4) ** (-power)
    if W.shape[1] > keep:
        cut = np.sort(W, axis=1)[:, -keep][:, None]
        W = np.where(W >= cut, W, 0.0)
    W /= W.sum(axis=1, keepdims=True)
    return W


def head_weights(p):
    q = p - HEAD_CENTER
    x, y, z = q[:, 0], q[:, 1], q[:, 2]
    t = np.clip((y + 0.1) / 0.104, 0.0, 1.0)
    z_split = -0.089 + (0.053) * t
    band = 0.007 + 0.016 * np.clip(np.abs(x) / 0.05, 0.0, 1.0)
    jaw = smoothstep(z_split + band, z_split - band, z)
    neck = smoothstep(-0.06, -0.13, z) * smoothstep(-0.005, 0.04, y)
    jaw *= 1.0 - neck
    head = np.clip(1.0 - jaw - neck, 0.0, 1.0)
    return np.stack([neck, head, jaw], axis=1)


def assign_groups(ob, names, W, threshold=0.002):
    for j, n in enumerate(names):
        vg = ob.vertex_groups.get(n) or ob.vertex_groups.new(name=n)
        col = W[:, j]
        idx = np.nonzero(col > threshold)[0]
        for i in idx:
            vg.add([int(i)], float(col[i]), "REPLACE")


# ---------------------------------------------------------------- colours

def body_colors(node, p, n, seed=0):
    ao = sdf.ambient_occlusion(node, p, n, step=0.004, samples=4)
    var = sdf.fbm(p, 24.0, 3, seed)
    base = BLACK[None, :] * (1.0 + 0.45 * var)[:, None]
    return base * (0.45 + 0.55 * ao)[:, None]


def face_mask(q):
    x, y, z = q[:, 0], q[:, 1], q[:, 2]
    front = smoothstep(-0.02, -0.055, y)
    e = (x / 0.06) ** 2 + ((z + 0.05) / 0.125) ** 2
    oval = smoothstep(1.06, 0.82, e)
    return front * oval


def head_colors(node, feats, p, n):
    q = p - HEAD_CENTER
    x, y, z = q[:, 0], q[:, 1], q[:, 2]
    local = node.node
    ao = sdf.ambient_occlusion(local, q, n, step=0.003, samples=5, strength=1.15)
    # mean curvature from the field: bony ridges catch the light
    # measured on the bone, without the skin's grain, so only real ridges shine
    bone = feats["bone"]
    e = 0.004
    lap = np.zeros(len(q))
    d0 = bone.full(q)
    for axis in range(3):
        o = np.zeros(3)
        o[axis] = e
        lap += bone.full(q + o) + bone.full(q - o) - 2.0 * d0
    lap /= e * e
    ridge = np.clip((lap - 40.0) / 160.0, -1.0, 1.0)

    pale = np.array([0.215, 0.138, 0.118])
    tone = 1.0 + 0.22 * sdf.fbm(q, 55.0, 3, 77)
    col = pale[None, :] * tone[:, None]
    # grime: the pale is only on the bone; the hollows between are dirty
    grime = smoothstep(-0.1, 0.5, sdf.fbm(q, 1.0, 3, 13, scale=(90.0, 90.0, 12.0)))
    col *= (1.0 - 0.3 * grime)[:, None]
    # streaks: dark drips under the eyes and down the cheeks
    streak = sdf.fbm(q, 1.0, 3, 41, scale=(190.0, 120.0, 11.0))
    drip_zone = smoothstep(0.02, -0.02, z) * smoothstep(-0.03, -0.06, y)
    under_eye = np.exp(-(((np.abs(x) - 0.03) / 0.013) ** 2 + ((z + 0.022) / 0.035) ** 2))
    dark = np.clip(smoothstep(0.05, 0.3, np.abs(streak)) * drip_zone + 0.7 * under_eye * smoothstep(0.0, 0.25, np.abs(streak)), 0.0, 1.0)
    col *= (1.0 - 0.8 * dark)[:, None]
    # and the cords of stretched skin between them, pale, the way the picture
    # draws the cheeks round the mouth: light and dark lines side by side
    cords = sdf.fbm(q, 1.0, 2, 57, scale=(115.0, 80.0, 8.0))
    cheek = smoothstep(0.0, -0.035, z) * smoothstep(-0.035, -0.07, y) * smoothstep(0.012, 0.03, np.abs(x))
    col *= (1.0 + 1.5 * cheek * smoothstep(0.12, 0.38, cords))[:, None]
    col *= (1.0 - 0.75 * cheek * smoothstep(-0.1, -0.32, cords))[:, None]
    col *= (0.55 + 3.6 * np.clip(ridge, 0.0, 1.0) ** 0.75)[:, None]
    col *= (ao ** 2.0)[:, None]
    # the holes are black
    for key, inner, rim in (("sockets", 0.0065, 0.0095), ("mouth", 0.006, 0.009), ("nasal", 0.004, 0.0)):
        d = feats[key].full(q)
        hole = smoothstep(inner, 0.0, d)
        col *= (1.0 - 0.985 * hole)[:, None]
        if rim > 0:
            ring = np.exp(-((d - rim) / 0.0028) ** 2) * (1.0 - hole)
            col *= (1.0 + 3.6 * ring)[:, None]
    m = face_mask(q)
    out = col * m[:, None] + body_colors(local, q, n, seed=9) * (1.0 - m)[:, None]
    return out


# ---------------------------------------------------------------- parts

def part_list(fast):
    k = 1.6 if fast else 1.0
    parts = [("head", lambda: anatomy.head_node(), 0.00115 * k, 17000, ["neck", "head", "jaw"])]
    torso_bones = ["hips", "spine_01", "spine_02", "chest", "neck"]
    for s in "LR":
        torso_bones += ["clavicle_%s.%s" % (a, s) for a in ARMS] + ["upperarm_%s.%s" % (a, s) for a in ARMS] + ["thigh." + s]
    parts.append(("torso", lambda: anatomy.torso_node(), 0.004 * k, 7000, torso_bones))
    for s in "LR":
        for a in ARMS:
            sfx = "_%s.%s" % (a, s)
            parts.append(("arm" + sfx, (lambda a=a, s=s: anatomy.arm_node(a, s)), 0.0028 * k, 2600,
                          ["chest", "clavicle" + sfx, "upperarm" + sfx, "forearm" + sfx, "hand" + sfx]))
            fingers = ["%s_%02d%s" % (f, j, sfx) for f in ("thumb", "index", "middle", "ring", "pinky") for j in (1, 2, 3)]
            hh = {"a": 0.0013, "b": 0.0010, "c": 0.0012}[a] * k
            tris = {"a": 6500, "b": 4200, "c": 5200}[a]
            parts.append(("hand" + sfx, (lambda a=a, s=s: anatomy.hand_node(a, s)), hh, tris,
                          ["forearm" + sfx, "hand" + sfx] + fingers))
        parts.append(("leg." + s, (lambda s=s: anatomy.leg_node(s)), 0.003 * k, 3000, ["hips", "thigh." + s, "shin." + s, "foot." + s]))
        toes = ["toe%d_%02d.%s" % (t, j, s) for t in (1, 2, 3, 4) for j in (1, 2)]
        parts.append(("foot." + s, (lambda s=s: anatomy.foot_node(s)), 0.0014 * k, 3600, ["shin." + s, "foot." + s] + toes))
    return parts


def build_parts(opts, bones, coll):
    built = {}
    for name, make, h, tris, names in part_list(opts["fast"]):
        if opts["only"] and name not in opts["only"]:
            continue
        t0 = time.time()
        made = make()
        node, feats = made if isinstance(made, tuple) else (made, None)
        v, q = sdf.mesh_node(node, h)
        ob = mesh_object("lurker_" + name, v, q, coll)
        decimate(ob, tris)
        me = ob.data
        shade_smooth(me)
        p = verts_np(me)
        n = normals_np(me)
        if name == "head":
            W = head_weights(p)
            col = head_colors(node, feats, p, n)
        else:
            W = bone_weights(p, bones, names)
            col = body_colors(node, p, n, seed=len(built))
        assign_groups(ob, names, W)
        set_colors(me, col)
        built[name] = dict(ob=ob, node=node, feats=feats, names=names, W=W, p=p, n=n, tris=tris_np(me))
        log("%-12s %7d tris  %.1fs" % (name, len(built[name]["tris"]), time.time() - t0))
    return built


# ---------------------------------------------------------------- face texture

def linear_to_srgb(c):
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, 12.92 * c, 1.055 * np.power(c, 1.0 / 2.4) - 0.055)


def bake_face(ob, node, feats, size=1024):
    """The face's colour baked texel by texel: the same shading as the vertex
    colours, but its streaks and rims no longer depend on how dense the mesh is."""
    t0 = time.time()
    view = bpy.context.view_layer
    for o in view.objects:
        o.select_set(False)
    view.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60.0), island_margin=0.004, area_weight=0.0, correct_aspect=True)
    bpy.ops.object.mode_set(mode="OBJECT")
    ob.select_set(False)
    me = ob.data
    me.calc_loop_triangles()
    nt = len(me.loop_triangles)
    loops = np.empty(nt * 3, dtype=np.int64)
    me.loop_triangles.foreach_get("loops", loops)
    tv = np.empty(nt * 3, dtype=np.int64)
    me.loop_triangles.foreach_get("vertices", tv)
    tv = tv.reshape(-1, 3)
    uv = np.empty(len(me.loops) * 2)
    me.uv_layers.active.data.foreach_get("uv", uv)
    UV = uv.reshape(-1, 2)[loops].reshape(-1, 3, 2) * size
    P = verts_np(me)
    N = normals_np(me)
    pix, tri_id, bary = [], [], []
    for t in range(nt):
        a, b, c = UV[t]
        lo = np.floor(np.minimum(np.minimum(a, b), c)).astype(int)
        hi = np.ceil(np.maximum(np.maximum(a, b), c)).astype(int)
        lo = np.clip(lo, 0, size - 1)
        hi = np.clip(hi, 0, size - 1)
        xs, ys = np.meshgrid(np.arange(lo[0], hi[0] + 1), np.arange(lo[1], hi[1] + 1))
        px = np.stack([xs.ravel() + 0.5, ys.ravel() + 0.5], axis=1)
        d = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(d) < 1e-12:
            continue
        w0 = ((b[1] - c[1]) * (px[:, 0] - c[0]) + (c[0] - b[0]) * (px[:, 1] - c[1])) / d
        w1 = ((c[1] - a[1]) * (px[:, 0] - c[0]) + (a[0] - c[0]) * (px[:, 1] - c[1])) / d
        w2 = 1.0 - w0 - w1
        inside = (w0 >= -0.02) & (w1 >= -0.02) & (w2 >= -0.02)
        if not np.any(inside):
            continue
        sel = px[inside].astype(int)
        pix.append(sel[:, 1] * size + sel[:, 0])
        tri_id.append(np.full(len(sel), t))
        bary.append(np.stack([w0[inside], w1[inside], w2[inside]], axis=1))
    pix = np.concatenate(pix)
    tri_id = np.concatenate(tri_id)
    bary = np.clip(np.concatenate(bary), 0.0, 1.0)
    bary /= bary.sum(axis=1, keepdims=True)
    pix, first = np.unique(pix, return_index=True)
    tri_id = tri_id[first]
    bary = bary[first]
    vi = tv[tri_id]
    p = (P[vi] * bary[:, :, None]).sum(axis=1)
    n = (N[vi] * bary[:, :, None]).sum(axis=1)
    n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-9)
    col = head_colors(node, feats, p, n)
    img = np.zeros((size * size, 3))
    filled = np.zeros(size * size, dtype=bool)
    img[pix] = col
    filled[pix] = True
    # bleed the islands outwards so the seams never show the empty background
    img = img.reshape(size, size, 3)
    filled = filled.reshape(size, size)
    for _ in range(12):
        acc = np.zeros_like(img)
        cnt = np.zeros((size, size))
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            acc += np.roll(np.roll(img * filled[..., None], dy, 0), dx, 1)
            cnt += np.roll(np.roll(filled, dy, 0), dx, 1)
        grow = (~filled) & (cnt > 0)
        img[grow] = acc[grow] / cnt[grow][:, None]
        filled = filled | grow
    rgba = np.concatenate([linear_to_srgb(img), np.ones((size, size, 1))], axis=2)
    image = bpy.data.images.new("lurker_face", size, size, alpha=False)
    image.pixels.foreach_set(rgba.astype(np.float32).ravel())
    image.pack()
    set_colors(me, np.ones((len(me.vertices), 3)))
    log("face baked %dx%d in %.1fs" % (size, size, time.time() - t0))
    return image


def face_material(image):
    m = bpy.data.materials.new("lurker_face")
    try:
        m.use_nodes = True
    except Exception:
        pass
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.location = (-400, 200)
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.95
    bsdf.inputs["Specular IOR Level"].default_value = 0.08
    m.diffuse_color = (0.2, 0.15, 0.13, 1.0)
    m.use_backface_culling = True
    return m


# ---------------------------------------------------------------- armature

def build_armature(bones, coll):
    arm = bpy.data.armatures.new("lurker_rig")
    ob = bpy.data.objects.new("lurker_rig", arm)
    coll.objects.link(ob)
    arm.display_type = "OCTAHEDRAL"
    ob.show_in_front = True
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.edit_bones
    for b in bones.values():
        e = eb.new(b.name)
        e.head = Vector(b.head)
        e.tail = Vector(b.tail)
        e.align_roll(Vector(b.z_hint))
        e.use_deform = b.deform
        if b.parent:
            e.parent = eb[b.parent]
            e.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in ob.pose.bones:
        pb.rotation_mode = "QUATERNION"
    # colour the bone groups so the rig reads at a glance
    for b in arm.bones:
        if b.name.startswith(("thumb", "index", "middle", "ring", "pinky", "toe")):
            b.color.palette = "THEME03"
        elif "_a." in b.name:
            b.color.palette = "THEME01"
        elif "_b." in b.name:
            b.color.palette = "THEME04"
        elif "_c." in b.name:
            b.color.palette = "THEME09"
    return ob


def join(obs, name):
    """One mesh for the game: every part shares the skeleton, so one
    instance with a surface per material instead of twenty."""
    obs = [o for o in obs if o is not None]
    if len(obs) > 1:
        with bpy.context.temp_override(active_object=obs[0], object=obs[0], selected_objects=obs, selected_editable_objects=obs):
            bpy.ops.object.join()
    ob = obs[0]
    ob.name = name
    ob.data.name = name
    return ob


def bind(ob, rig):
    ob.parent = rig
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = rig


# ---------------------------------------------------------------- extras

def eye_meshes(bones, coll):
    obs = []
    for side in "LR":
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=40, v_segments=28, radius=anatomy.EYE_RADIUS)
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(90), 3, "X"))
        c = Vector(bones["eye." + side].head)
        bmesh.ops.translate(bm, verts=bm.verts, vec=c)
        me = bpy.data.meshes.new("lurker_eye." + side)
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new("lurker_eye." + side, me)
        coll.objects.link(ob)
        shade_smooth(me)
        p = verts_np(me) - np.array(c)
        d = p / np.linalg.norm(p, axis=1, keepdims=True)
        ang = np.arccos(np.clip(-d[:, 1], -1, 1))
        white = np.array([0.46, 0.43, 0.37])
        col = np.tile(white, (len(p), 1))
        col *= (0.55 + 0.45 * smoothstep(1.9, 0.8, ang))[:, None]
        iris = smoothstep(0.68, 0.6, ang)
        col = col * (1 - iris)[:, None] + np.array([0.09, 0.08, 0.07]) * iris[:, None]
        pupil = smoothstep(0.46, 0.4, ang)
        col = col * (1 - pupil)[:, None] + np.array([0.004, 0.004, 0.004]) * pupil[:, None]
        set_colors(me, col)
        ob.vertex_groups.new(name="eye." + side).add(list(range(len(me.vertices))), 1.0, "REPLACE")
        obs.append(ob)
    return obs


def tube(centers, radii, sides=6, flatten=1.0, up=None):
    """A tapered tube along a polyline, closed at the far end with a point."""
    centers = np.asarray(centers)
    verts = []
    faces = []
    n = len(centers)
    for i in range(n - 1):
        d = sdf.normalize(centers[min(i + 1, n - 1)] - centers[max(i - 1, 0)])
        ref = up if up is not None else (np.array([0, 0, 1.0]) if abs(d[2]) < 0.9 else np.array([1.0, 0, 0]))
        a = sdf.normalize(np.cross(d, ref))
        b = np.cross(d, a)
        for k in range(sides):
            t = 2 * math.pi * k / sides
            verts.append(centers[i] + radii[i] * (math.cos(t) * a * flatten + math.sin(t) * b))
    verts.append(centers[-1])
    tip = len(verts) - 1
    for i in range(n - 2):
        for k in range(sides):
            a0 = i * sides + k
            a1 = i * sides + (k + 1) % sides
            faces.append((a0, a1, a1 + sides, a0 + sides))
    base = (n - 2) * sides
    for k in range(sides):
        faces.append((base + k, base + (k + 1) % sides, tip))
    faces.append(tuple(range(sides - 1, -1, -1)))
    return np.array(verts), faces


def teeth_mesh(coll):
    allv, allf, colors, jaw = [], [], [], []
    off = 0
    for root, d, length, r0, upper in anatomy.teeth_layout():
        curve = np.array([0, 1.0, 0]) * length * 0.18
        ts = np.linspace(0, 1, 7)
        start = root - d * 0.005
        cs = [start + d * (length + 0.005) * t + curve * t * t for t in ts]
        rs = [0.75 * r0 * (1.0 - t) ** 0.85 + 0.0001 for t in ts]
        v, f = tube(cs, rs, sides=6)
        v = v + HEAD_CENTER
        allv.append(v)
        allf += [tuple(i + off for i in face) for face in f]
        along = np.clip(np.linalg.norm(v - (root + HEAD_CENTER), axis=1) / length, 0, 1)
        c = np.array([0.05, 0.035, 0.025])[None, :] * (1 - along[:, None]) + np.array([0.4, 0.34, 0.25])[None, :] * along[:, None]
        colors.append(c)
        jaw += [0.0 if upper else 1.0] * len(v)
        off += len(v)
    v = np.concatenate(allv)
    ob = mesh_object("lurker_teeth", v, allf, coll)
    shade_smooth(ob.data)
    set_colors(ob.data, np.concatenate(colors))
    jaw = np.array(jaw)
    assign_groups(ob, ["head", "jaw"], np.stack([1 - jaw, jaw], axis=1))
    return ob


def claw_meshes(bones, coll):
    allv, allf, groups = [], [], []
    off = 0
    names = []
    for side in "LR":
        for arm, a in ARMS.items():
            s = a["scale"]
            for f in ("thumb", "index", "middle", "ring", "pinky"):
                names.append(("%s_03_%s.%s" % (f, arm, side), 0.026 * s, anatomy.FINGER_RADII[3] * a.get("thick", s) * 1.3))
        for t in (1, 2, 3, 4):
            names.append(("toe%d_02.%s" % (t, side), 0.018, 0.0042))
    for bname, length, r in names:
        b = bones[bname]
        d = sdf.normalize(b.tail - b.head)
        palm = b.z_hint
        ts = np.linspace(0, 1, 7)
        start = b.tail - d * 0.006
        cs = [start + d * length * t + palm * length * 0.45 * t * t for t in ts]
        rs = [r * (1.0 - t) ** 0.9 + 0.00008 for t in ts]
        v, fcs = tube(cs, rs, sides=6, flatten=0.62, up=palm)
        allv.append(v)
        allf += [tuple(i + off for i in face) for face in fcs]
        groups.append((bname, off, len(v)))
        off += len(v)
    ob = mesh_object("lurker_claws", np.concatenate(allv), allf, coll)
    shade_smooth(ob.data)
    for bname, start, count in groups:
        vg = ob.vertex_groups.get(bname) or ob.vertex_groups.new(name=bname)
        vg.add(list(range(start, start + count)), 1.0, "REPLACE")
    v = verts_np(ob.data)
    set_colors(ob.data, np.tile(np.array([0.016, 0.014, 0.013]), (len(v), 1)))
    return ob


# ---------------------------------------------------------------- hair

def fur_spec(name):
    """count, length range, width range, how much it follows the normal, comb."""
    down = np.array([0, 0, -1.0])
    if name == "torso":
        return 4200, (0.035, 0.12), (0.003, 0.008), 0.42, lambda p, n: down + np.array([0, 0.15, 0])
    if name == "head":
        def comb(p, n):
            q = p - HEAD_CENTER
            back = np.stack([np.sign(q[:, 0]) * 0.4, np.full(len(q), 0.7), np.full(len(q), -0.6)], axis=1)
            return back
        return 2700, (0.045, 0.13), (0.002, 0.0045), 0.22, comb
    if name.startswith("arm"):
        a = name[4]
        fr = anatomy.hand_frame(a, "L")
        axis = sdf.normalize(fr["wrist"] - fr["shoulder"])
        if name.endswith(".R"):
            axis = anatomy.mirror(axis, "R")
        cnt = {"a": 1100, "b": 600, "c": 800}[a]
        return cnt, (0.008, 0.028), (0.0012, 0.003), 0.35, lambda p, n, axis=axis: axis * 0.8 + down * 0.5
    if name.startswith("leg"):
        return 700, (0.008, 0.03), (0.0012, 0.003), 0.4, lambda p, n: down
    if name.startswith("hand"):
        a = name[5]
        fr = anatomy.hand_frame(a, "L")
        f = fr["f"] if name.endswith(".L") else anatomy.mirror(fr["f"], "R")
        cnt = {"a": 240, "b": 140, "c": 180}[a]
        return cnt, (0.004, 0.013), (0.001, 0.002), 0.5, lambda p, n, f=f: np.tile(f, (len(p), 1))
    if name.startswith("foot"):
        return 90, (0.004, 0.012), (0.001, 0.002), 0.5, lambda p, n: np.tile(np.array([0, -1.0, 0]), (len(p), 1))
    return 0, None, None, None, None


def shoulder_of(name):
    a = name[4]
    sh = ARMS[a]["shoulder"]
    return anatomy.mirror(sh, "R") if name.endswith(".R") else sh


def fur_length(name):
    """Hair is longest where a limb leaves the body."""
    if name.startswith("arm"):
        sh = shoulder_of(name)
        return lambda p: 0.7 + 2.4 * smoothstep(0.3, 0.0, np.linalg.norm(p - sh, axis=1))
    if name.startswith("leg"):
        hip = anatomy.mirror(anatomy.LEG["hip"], "R") if name.endswith(".R") else anatomy.LEG["hip"]
        return lambda p: 0.6 + 1.4 * smoothstep(0.35, 0.0, np.linalg.norm(p - hip, axis=1))
    if name == "head":
        # a hood, not a dome: short on the crown, long down the sides and back
        return lambda p: 0.62 + 0.6 * smoothstep(0.06, -0.04, (p - HEAD_CENTER)[:, 2])
    return lambda p: np.ones(len(p))


def fur_mask(name, part, p, n):
    if name.startswith("arm"):
        sh = shoulder_of(name)
        return 0.3 + 0.7 * smoothstep(0.4, 0.0, np.linalg.norm(p - sh, axis=1))
    if name == "head":
        q = p - HEAD_CENTER
        m = 1.0 - smoothstep(0.05, 0.3, face_mask(q * np.array([0.93, 1.0, 0.95])))
        return m * smoothstep(-0.2, -0.12, q[:, 2])
    if name.startswith("hand"):
        a = name[5]
        fr = anatomy.hand_frame(a, "L")
        nn = fr["n"] if name.endswith(".L") else anatomy.mirror(fr["n"], "R")
        back = smoothstep(0.1, -0.5, n @ nn)
        w = fr["wrist"] if name.endswith(".L") else anatomy.mirror(fr["wrist"], "R")
        near = smoothstep(0.2, 0.06, np.linalg.norm(p - w, axis=1))
        return back * (0.25 + 0.75 * near)
    if name.startswith("foot"):
        return smoothstep(0.0, 0.5, n[:, 2])
    return np.ones(len(p))


def build_fur(built, coll, density=1.0):
    allv, allf, wsum = [], [], []
    groups = {}
    off = 0
    for name, part in built.items():
        count, lens, widths, normal_follow, comb = fur_spec(name)
        grow = fur_length(name)
        count = int(count * density)
        if count <= 0:
            continue
        p, n, tris = part["p"], part["n"], part["tris"]
        a, b, c = p[tris[:, 0]], p[tris[:, 1]], p[tris[:, 2]]
        area = 0.5 * np.linalg.norm(np.cross(b - a, c - a), axis=1)
        cen = (a + b + c) / 3.0
        cn = n[tris].mean(axis=1)
        cn /= np.linalg.norm(cn, axis=1, keepdims=True)
        prob = area * np.clip(fur_mask(name, part, cen, cn), 0, 1)
        if prob.sum() <= 0:
            continue
        pick = RNG.choice(len(tris), size=count, p=prob / prob.sum())
        r1 = np.sqrt(RNG.random(count))
        r2 = RNG.random(count)
        bary = np.stack([1 - r1, r1 * (1 - r2), r1 * r2], axis=1)
        tri = tris[pick]
        roots = (p[tri] * bary[:, :, None]).sum(axis=1)
        rn = (n[tri] * bary[:, :, None]).sum(axis=1)
        rn /= np.linalg.norm(rn, axis=1, keepdims=True)
        cdir = np.broadcast_to(comb(roots, rn), roots.shape).astype(np.float64)
        cdir = cdir /np.maximum(np.linalg.norm(cdir, axis=1, keepdims=True), 1e-9)
        # weights: the root's
        vw = part["W"][tri[:, 0]] * bary[:, :1] + part["W"][tri[:, 1]] * bary[:, 1:2] + part["W"][tri[:, 2]] * bary[:, 2:3]
        if vw.shape[1] > 4:
            cut = np.sort(vw, axis=1)[:, -4][:, None]
            vw = np.where(vw >= cut, vw, 0.0)
        vw /= vw.sum(axis=1, keepdims=True)
        L = (lens[0] + (lens[1] - lens[0]) * RNG.random(count) ** 1.6) * grow(roots)
        Wd = widths[0] + (widths[1] - widths[0]) * RNG.random(count)
        segs = 3
        for i in range(count):
            jitter = RNG.normal(size=3) * 0.35
            d = sdf.normalize(rn[i] * normal_follow + cdir[i] * (1.0 - normal_follow) + jitter)
            side = sdf.normalize(np.cross(d, sdf.normalize(RNG.normal(size=3))))
            up = np.cross(side, d)
            c0 = roots[i] - rn[i] * 0.0015
            centers = [c0]
            cur = d
            for k in range(segs):
                cur = sdf.normalize(cur + cdir[i] * 0.7 + np.array([0, 0, -0.45]))
                centers.append(centers[-1] + cur * L[i] / segs)
            rows = []
            for k in range(segs):
                w = Wd[i] * 0.5 * (1.0 - k / segs) ** 0.8
                cc = centers[k]
                rows.append([cc - side * w, cc + side * w])
            vlist = [v for row in rows for v in row] + [centers[-1]]
            tip = len(vlist) - 1
            fl = []
            for k in range(segs - 1):
                r0, r1_ = k * 2, (k + 1) * 2
                fl.append((r0, r0 + 1, r1_ + 1, r1_))
            r0 = (segs - 1) * 2
            fl.append((r0, r0 + 1, tip))
            allv.append(np.array(vlist))
            allf += [tuple(j + off for j in face) for face in fl]
            for j, bn in enumerate(part["names"]):
                if vw[i, j] > 0.002:
                    groups.setdefault(bn, []).append((off, len(vlist), float(vw[i, j])))
            off += len(vlist)
    if not allv:
        return None
    ob = mesh_object("lurker_fur", np.concatenate(allv), allf, coll)
    shade_smooth(ob.data)
    for bn, items in groups.items():
        vg = ob.vertex_groups.get(bn) or ob.vertex_groups.new(name=bn)
        for start, cnt, w in items:
            vg.add(list(range(start, start + cnt)), w, "REPLACE")
    v = verts_np(ob.data)
    tone = 1.0 + 0.5 * sdf.fbm(v, 40.0, 2, 3)
    set_colors(ob.data, BLACK[None, :] * 0.7 * tone[:, None])
    return ob


# ---------------------------------------------------------------- materials

def material(name, rough, spec, double_sided=False, sheen=0.0):
    m = bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except Exception:
        pass
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    attr.location = (-400, 200)
    nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Specular IOR Level"].default_value = spec
    if sheen:
        bsdf.inputs["Sheen Weight"].default_value = sheen
    m.use_backface_culling = not double_sided
    m.diffuse_color = (0.02, 0.02, 0.02, 1.0)
    return m


def materials():
    return dict(
        skin=material("lurker_skin", 1.0, 0.03),
        fur=material("lurker_fur", 1.0, 0.0, double_sided=True),
        eyes=material("lurker_eyes", 0.18, 0.5),
        teeth=material("lurker_teeth", 0.55, 0.35),
        claws=material("lurker_claws", 0.7, 0.15),
    )


def build(opts):
    t0 = time.time()
    clear_scene()
    bones = {b.name: b for b in anatomy.skeleton()}
    coll = collection("Lurker")
    rig = build_armature(bones, coll)
    mats = materials()
    built = build_parts(opts, bones, coll)
    body = []
    for name, part in built.items():
        if name == "head":
            part["ob"].data.materials.append(face_material(bake_face(part["ob"], part["node"], part["feats"])))
        else:
            part["ob"].data.materials.append(mats["skin"])
        body.append(part["ob"])
    if not opts["only"] or "head" in opts["only"]:
        for ob in eye_meshes(bones, coll):
            ob.data.materials.append(mats["eyes"])
            body.append(ob)
        ob = teeth_mesh(coll)
        ob.data.materials.append(mats["teeth"])
        body.append(ob)
    if not opts["only"]:
        ob = claw_meshes(bones, coll)
        ob.data.materials.append(mats["claws"])
        body.append(ob)
    if opts["fur"] > 0:
        fur = build_fur(built, coll, opts["fur"])
        if fur:
            fur.data.materials.append(mats["fur"])
            bind(fur, rig)
            log("fur %d tris" % sum(len(pl.vertices) - 2 for pl in fur.data.polygons))
    if body:
        bind(join(body, "lurker_body"), rig)
    total = 0
    for ob in coll.objects:
        if ob.type == "MESH":
            total += sum(len(pl.vertices) - 2 for pl in ob.data.polygons)
    log("total %d tris in %.1fs" % (total, time.time() - t0))
    return rig


def save(path):
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(path), compress=True)
    log("saved", path)


def main():
    opts = args()
    build(opts)
    if opts["out"]:
        save(opts["out"])


if __name__ == "__main__":
    main()
