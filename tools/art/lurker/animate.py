"""The creature's animations, written as poses solved frame by frame.

Each clip is a function of time that says where the body is, how the neck
and head bend, where every hand goes, and how the fingers curl. A two-bone
solver places the elbows, everything is turned into each bone's
local rotation, and the keys are written straight onto the rig's actions (one
key per frame, linear), so the exported clips are plain bone rotations that
need no constraint at the other end.

The clips play in place: the game moves the body. Their speeds are in SPEEDS.
"""

import math
import os
import sys
import zlib

import bpy
import numpy as np
from bpy_extras import anim_utils
from mathutils import Euler, Matrix, Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import anatomy  # noqa: E402

FPS = 30
LIMBS = [p + "." + s for p in "abcd" for s in "LR"]
FINGERS = ("thumb", "index", "middle", "ring", "pinky")

# metres per second the body travels while a locomotion clip plays (towards -Y,
# the way it faces; retreat goes the other way)
SPEEDS = {"crawl": 1.0, "crawl_fast": 2.6, "vent_crawl": 0.55, "retreat": -1.5}


def chain(limb):
    arm, s = limb.split(".")
    sfx = "_%s.%s" % (arm, s)
    return "clavicle" + sfx, "upperarm" + sfx, "forearm" + sfx, "hand" + sfx


def digit_bones(limb):
    arm, s = limb.split(".")
    return {f: ["%s_%02d_%s.%s" % (f, j, arm, s) for j in (1, 2, 3)] for f in FINGERS}


def V(x):
    return Vector((float(x[0]), float(x[1]), float(x[2])))


def mirror(v, limb_or_side):
    side = limb_or_side[-1]
    v = V(v)
    if side == "R":
        v.x = -v.x
    return v


def smooth(t):
    t = min(max(t, 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


def smoother(t):
    t = min(max(t, 0.0), 1.0)
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


def back_out(t, s=1.6):
    t = min(max(t, 0.0), 1.0) - 1.0
    return t * t * ((s + 1.0) * t + s) + 1.0


def noise1(t, seed, freq=1.0):
    """Smooth 1-D value noise in [-1, 1], periodic over 64/freq seconds."""
    x = t * freq
    i = math.floor(x)
    f = x - i
    def h(n):
        n = (int(n) % 64) * 374761393 + seed * 668265263
        n = (n ^ (n >> 13)) * 1274126177
        return ((n ^ (n >> 16)) & 0xFFFF) / 32767.5 - 1.0
    w = f * f * (3 - 2 * f)
    return h(i) * (1 - w) + h(i + 1) * w


class Rig:
    def __init__(self, ob):
        self.ob = ob
        self.order = [b.name for b in ob.data.bones]
        self.rest = {b.name: b.matrix_local.copy() for b in ob.data.bones}
        self.parent = {b.name: (b.parent.name if b.parent else None) for b in ob.data.bones}
        self.rel = {}
        for n, p in self.parent.items():
            self.rel[n] = self.rest[n] if p is None else self.rest[p].inverted() @ self.rest[n]
        self.length = {b.name: b.length for b in ob.data.bones}

    def shoulder(self, limb):
        c, u, f, h = chain(limb)
        return self.rest[u].translation.copy()

    # ---------------------------------------------------------------- solve

    def solve(self, spec):
        local = spec.get("local", {})
        ik = spec.get("ik", {})
        curls = spec.get("curl", {})
        body = spec.get("body")
        over = {}
        if body is not None:
            # the spec says where the body's centre goes; the bone's head is
            # behind it, and turns with it
            pos, rot = body
            r = self.rest["body"].to_3x3()
            m = (rot @ r).to_4x4()
            m.translation = V(pos) + rot @ (self.rest["body"].translation - V(anatomy.BODY_CENTER))
            over["body"] = m
        upper_of = {}
        for limb, k in ik.items():
            c, u, f, h = chain(limb)
            upper_of[u] = (limb, k)
        for limb, fingers in curls.items():
            bones = digit_bones(limb)
            for fname, vals in fingers.items():
                names = bones.get(fname)
                if not names:
                    continue
                spread = vals[-1] if len(vals) > len(names) else 0.0
                # mirrored bones turn the other way about their Z axis
                if limb.endswith(".R"):
                    spread = -spread
                for j, name in enumerate(names):
                    e = local.get(name, (0.0, 0.0, 0.0))
                    local[name] = (e[0] + vals[j], e[1], e[2] + (spread if j == 0 else 0.0))
        pose = {}
        basis = {}
        for name in self.order:
            p = self.parent[name]
            parent_pose = pose[p] if p else Matrix.Identity(4)
            if name in upper_of:
                limb, k = upper_of[name]
                self._ik(limb, k, parent_pose, over)
            look = spec.get("look")
            if look is not None and (name == "head" or name.startswith("eye.")) and name not in over:
                # the face and the eyes turned on a point: the head part of
                # the way (its +Z is the face), the eyes all of it (their +Y)
                e = local.get(name)
                b0 = Matrix.Identity(4) if e is None else (e if isinstance(e, Matrix) else Euler(e, "XYZ").to_matrix().to_4x4())
                m0 = parent_pose @ self.rel[name] @ b0
                axis_col = 2 if name == "head" else 1
                ahead = m0.col[axis_col].to_3d().normalized()
                origin = m0.translation + (m0.col[1].to_3d() * 0.07 if name == "head" else Vector((0, 0, 0)))
                wanted = (V(look) - origin).normalized()
                angle = min(ahead.angle(wanted), math.radians(60.0 if name == "head" else 40.0))
                axis = ahead.cross(wanted)
                if axis.length > 1e-6:
                    r = Matrix.Rotation(angle, 4, axis.normalized())
                    m1 = r @ m0
                    m1.translation = m0.translation
                    over[name] = m1
            if name in over:
                m = over[name]
                b = self.rel[name].inverted() @ (parent_pose.inverted() @ m)
            else:
                e = local.get(name)
                if e is None:
                    b = Matrix.Identity(4)
                elif isinstance(e, Matrix):
                    b = e
                else:
                    b = Euler(e, "XYZ").to_matrix().to_4x4()
                m = parent_pose @ self.rel[name] @ b
            pose[name] = m
            basis[name] = b
        return basis, pose

    def _ik(self, limb, k, parent_pose, over):
        c, u, f, h = chain(limb)
        s = (parent_pose @ self.rel[u]).translation
        l1 = self.length[u]
        l2 = self.length[f]
        t = V(k["target"])
        pole = V(k["pole"]).normalized()
        d = t - s
        dist = d.length
        dist = min(max(dist, abs(l1 - l2) + 1e-3), (l1 + l2) * ARM_SPAN)
        axis = d.normalized()
        a = (l1 * l1 - l2 * l2 + dist * dist) / (2 * dist)
        hgt = math.sqrt(max(l1 * l1 - a * a, 0.0))
        v = pole - axis * pole.dot(axis)
        if v.length < 1e-6:
            v = axis.orthogonal()
        v.normalize()
        e = s + axis * a + v * hgt
        t = s + axis * dist
        y1 = (e - s).normalized()
        y2 = (t - e).normalized()
        bend = y1.cross(y2)
        if bend.length < 1e-5:
            bend = axis.cross(v)
        bend.normalize()

        def frame(y, x, origin):
            x = (x - y * x.dot(y)).normalized()
            z = x.cross(y)
            m = Matrix((
                (x.x, y.x, z.x, origin.x),
                (x.y, y.y, z.y, origin.y),
                (x.z, y.z, z.z, origin.z),
                (0, 0, 0, 1)))
            return m

        over[u] = frame(y1, bend, s)
        over[f] = frame(y2, bend, e)
        if "f" in k and "n" in k:
            fy = V(k["f"]).normalized()
            n = V(k["n"])
            n = (n - fy * n.dot(fy)).normalized()
            x = fy.cross(n)
            over[h] = frame(fy, x, t)


# ---------------------------------------------------------------- writing

def write_action(rig, name, frames, loop=True):
    """frames: list of basis dicts. Writes rotation (and location where it
    moves) for every bone, one key per frame."""
    act = bpy.data.actions.get(name)
    if act:
        bpy.data.actions.remove(act)
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    slot = act.slots.new(id_type="OBJECT", name=rig.ob.name)
    cb = anim_utils.action_ensure_channelbag_for_slot(act, slot)
    n = len(frames)
    xs = np.arange(n, dtype=np.float64) + 1.0
    for bone in rig.order:
        quats = []
        locs = []
        prev = None
        for fr in frames:
            b = fr[bone]
            loc, rot, _ = b.decompose()
            q = rot.normalized()
            if prev is not None and prev.dot(q) < 0:
                q = Quaternion((-q.w, -q.x, -q.y, -q.z))
            prev = q
            quats.append((q.w, q.x, q.y, q.z))
            locs.append((loc.x, loc.y, loc.z))
        quats = np.array(quats)
        locs = np.array(locs)
        path = 'pose.bones["%s"]' % bone
        for i in range(4):
            fc = cb.fcurves.new(path + ".rotation_quaternion", index=i, group_name=bone)
            fc.keyframe_points.add(n)
            fc.keyframe_points.foreach_set("co", np.stack([xs, quats[:, i]], axis=1).ravel())
            fc.keyframe_points.foreach_set("interpolation", [1] * n)
            fc.update()
        if np.abs(locs).max() > 1e-5:
            for i in range(3):
                fc = cb.fcurves.new(path + ".location", index=i, group_name=bone)
                fc.keyframe_points.add(n)
                fc.keyframe_points.foreach_set("co", np.stack([xs, locs[:, i]], axis=1).ravel())
                fc.keyframe_points.foreach_set("interpolation", [1] * n)
                fc.update()
    act["loop"] = bool(loop)
    act["fps"] = FPS
    return act, slot


def bake(rig, name, clip, length, loop=True):
    n = int(round(length * FPS)) + (0 if loop else 1)
    frames = []
    for i in range(n):
        spec = clip(i / FPS)
        basis, _ = rig.solve(spec)
        frames.append(basis)
    if loop:
        # the last key repeats the first so the clip closes on itself
        frames.append(frames[0])
    return write_action(rig, name, frames, loop)


# ---------------------------------------------------------------- poses

def rot(pitch=0.0, roll=0.0, yaw=0.0):
    """Body orientation in armature space, degrees: pitch tips its front down
    (negative rears it up), roll leans it to its left (+X), yaw turns it left."""
    return (Matrix.Rotation(math.radians(yaw), 3, "Z") @ Matrix.Rotation(math.radians(-roll), 3, "Y")
            @ Matrix.Rotation(math.radians(pitch), 3, "X"))


def deg(x, y=0.0, z=0.0):
    return (math.radians(x), math.radians(y), math.radians(z))


def curl_all(limb, c1, c2, c3, spread=0.0, thumb=None):
    out = {}
    for f in FINGERS:
        sp = {"thumb": 0.0, "index": spread, "middle": spread * 0.3, "ring": -spread * 0.3, "pinky": -spread}[f]
        out[f] = (c1, c2, c3, sp)
    if thumb is not None:
        out["thumb"] = thumb
    return out


def socket(limb):
    a = anatomy.ARMS[limb[0]]
    return mirror(a["shoulder"], limb)


def reach(limb):
    a = anatomy.ARMS[limb[0]]
    return a["upper_len"] + a["fore_len"]


def outward(limb):
    angle = math.radians(anatomy.PAIRS[limb[0]][0])
    return mirror((math.sin(angle), -math.cos(angle), 0.0), limb)


class Stance:
    """A spider stance: the body low and level, every hand on the ground round
    it at a share of that arm's reach, the elbows lifted by `pole_up`."""

    def __init__(self, height, pitch, spread, pole_up, head, lift=0.12, wrist=0.05):
        self.height = height
        self.pitch = pitch
        self.spread = spread
        self.pole_up = pole_up
        self.head = head
        self.lift = lift
        self.wrist = wrist

    def home(self, limb):
        s = socket(limb)
        o = outward(limb)
        p = Vector((s.x, s.y, 0.0)) + o * reach(limb) * self.spread
        p.z = self.wrist * anatomy.PAIRS[limb[0]][1]
        return p

    def pole(self, limb):
        return outward(limb) * 0.6 + Vector((0, 0, self.pole_up))


CRAWL = Stance(height=0.34, pitch=4.0, spread=0.62, pole_up=1.8, head={"neck": deg(-6), "head": deg(-4)}, lift=0.22)
LURK = Stance(height=0.24, pitch=6.0, spread=0.58, pole_up=1.9, head={"neck": deg(-12), "head": deg(-8)}, lift=0.18)
VENT = Stance(height=0.15, pitch=0.0, spread=0.42, pole_up=0.15, head={"neck": deg(4), "head": deg(-6)}, lift=0.05, wrist=0.035)

# alternating tetrapods, with a little wave from front to back
PHASE = {"a.L": 0.0, "b.R": 0.06, "c.L": 0.12, "d.R": 0.18,
         "a.R": 0.5, "b.L": 0.56, "c.R": 0.62, "d.L": 0.68}


def flat_dir(frm, to):
    d = V(to) - V(frm)
    d.z = 0.0
    return d.normalized() if d.length > 1e-6 else Vector((0, -1, 0))


def ground_hand(rig, limb, pos, lift=0.0):
    """IK entry for a hand resting on the floor at pos, palm down."""
    s = rig.shoulder(limb)
    f = flat_dir(s, pos)
    f = (f + Vector((0, 0, -0.25 - 0.4 * lift))).normalized()
    return dict(target=pos, f=f, n=Vector((0, 0, -1)))


def grip(lift=0.0):
    return dict(c=(0.32 + 0.45 * lift, 0.45 + 0.5 * lift, 0.35 + 0.4 * lift), spread=0.12 - 0.1 * lift,
                thumb=(0.1 + 0.3 * lift, 0.2 + 0.3 * lift, 0.2, 0.0))


def put_grip(spec, limb, lift=0.0):
    g = grip(lift)
    spec["curl"][limb] = curl_all(limb, *g["c"], g["spread"], thumb=g["thumb"])


def gait(rig, stance, t, period, duty, speed, sway=1.0, bob=0.015):
    spec = {"local": dict(stance.head), "ik": {}, "curl": {}}
    stride = speed * duty * period
    fwd = Vector((0, -1, 0))
    for limb in LIMBS:
        u = (t / period + PHASE[limb]) % 1.0
        home = stance.home(limb)
        if u < duty:
            s = u / duty
            p = home + fwd * stride * (0.5 - s)
            lift = 0.0
        else:
            s = (u - duty) / (1.0 - duty)
            p = home + fwd * stride * (-0.5 + smoother(s))
            lift = math.sin(math.pi * s)
            p.z += stance.lift * lift * anatomy.PAIRS[limb[0]][1]
        entry = ground_hand(rig, limb, p, lift=lift)
        entry["pole"] = stance.pole(limb)
        spec["ik"][limb] = entry
        put_grip(spec, limb, lift)
    w = 2 * math.pi * t / period
    roll = 3.0 * math.sin(w) * sway
    yaw = 2.5 * math.sin(w + 0.6) * sway
    spec["body"] = (Vector((0.0, 0.0, stance.height + bob * math.cos(2 * w))), rot(stance.pitch, roll, yaw))
    # the head stays on whatever it is looking at
    add_local(spec, "neck", deg(0, -yaw * 0.6, 0))
    add_local(spec, "abdomen", deg(2 * math.sin(2 * w), 0, 4 * math.sin(w + 1.0) * sway))
    return spec


def static_stance(rig, stance):
    spec = {"local": dict(stance.head), "ik": {}, "curl": {}}
    for limb in LIMBS:
        entry = ground_hand(rig, limb, stance.home(limb))
        entry["pole"] = stance.pole(limb)
        spec["ik"][limb] = entry
        put_grip(spec, limb)
    spec["body"] = (Vector((0.0, 0.0, stance.height)), rot(stance.pitch))
    return spec


def add_local(spec, bone, e):
    cur = spec["local"].get(bone, (0.0, 0.0, 0.0))
    spec["local"][bone] = tuple(a + b for a, b in zip(cur, e))


# ---------------------------------------------------------------- the picture

# The most of its length an arm ever reaches: never straight, the elbow always
# shows (the same in the game, lurker_limbs.gd).
ARM_SPAN = 0.86


def loom_pose(rig, ground=None):
    """The reference picture: reared up in a corridor a metre wide, the big
    hands high on both walls in a V, the small pair up by the head, the third
    pair clawing the walls lower down and the back pair reaching down the steps
    towards whoever looks. ground(y) is the height of the floor at y (rig
    space); flat when not given."""
    s = ground or (lambda y: 0.0)
    up = 0.0 if ground else 0.12
    spec = {"local": {}, "ik": {}, "curl": {}}
    spec["body"] = (Vector((0.0, 0.06, 0.5 + up)), rot(-58.0, 3.0, -4.0))
    spec["local"].update({
        # the abdomen folds back behind it instead of hanging like a trunk
        "abdomen": deg(68), "neck": deg(30, 0, 2), "head": deg(30, 3, 5), "jaw": deg(26),
        "eye.L": deg(-10), "eye.R": deg(-10),
    })
    # the big hands high on the walls of a passage a metre wide, the elbows
    # riding up between: palms on the wall, fingers spread and hooked into it
    spec["ik"]["a.R"] = dict(target=(-0.34, -0.08, 1.22 + up), pole=(-0.35, 0.3, 1.0), f=(-0.15, -0.25, 1.0), n=(-1.0, 0.15, 0.0))
    spec["ik"]["a.L"] = dict(target=(0.34, -0.12, 1.26 + up), pole=(0.35, 0.3, 1.0), f=(0.15, -0.25, 1.0), n=(1.0, 0.15, 0.0))
    spec["curl"]["a.R"] = curl_all("a.R", -0.05, 0.3, 0.55, 0.7, thumb=(-0.2, 0.2, 0.45, 0.0))
    spec["curl"]["a.L"] = curl_all("a.L", -0.05, 0.3, 0.55, 0.7, thumb=(-0.2, 0.2, 0.45, 0.0))
    # the small pair, up by the head
    spec["ik"]["b.L"] = dict(target=(0.24, -0.14, 1.1 + up), pole=(1.0, 0.3, -0.6), f=(0.3, -0.3, 1.0), n=(0.0, -1.0, 0.0))
    spec["ik"]["b.R"] = dict(target=(-0.26, -0.1, 1.06 + up), pole=(-1.0, 0.3, -0.6), f=(-0.3, -0.1, 1.0), n=(0.0, -1.0, 0.0))
    spec["curl"]["b.L"] = curl_all("b.L", 0.15, 0.35, 0.45, 0.35)
    spec["curl"]["b.R"] = curl_all("b.R", 0.3, 0.5, 0.5, 0.2)
    # the third pair: like a spider's legs, the elbows high and the hands low
    # on the walls, the claws hooked down into them
    spec["ik"]["c.R"] = dict(target=(-0.35, -0.16, 0.6 + up), pole=(-0.4, 0.2, 1.0), f=(-0.1, -0.45, -0.9), n=(-1.0, 0.0, 0.0))
    spec["ik"]["c.L"] = dict(target=(0.35, -0.1, 0.54 + up), pole=(0.4, 0.2, 1.0), f=(0.1, -0.45, -0.9), n=(1.0, 0.0, 0.0))
    spec["curl"]["c.R"] = curl_all("c.R", 0.25, 0.75, 0.9, 0.3, thumb=(0.1, 0.4, 0.6, 0.0))
    spec["curl"]["c.L"] = curl_all("c.L", 0.3, 0.8, 0.85, 0.25, thumb=(0.1, 0.4, 0.6, 0.0))
    # the back pair: down the steps towards the camera
    for limb, x, y in (("d.L", 0.28, -0.42), ("d.R", -0.3, -0.3)):
        spec["ik"][limb] = dict(target=(x, y, s(y) + 0.04), pole=mirror((1.0, 0.2, 0.8), limb),
                                f=mirror((0.3, -0.9, -0.5), limb), n=(0.0, 0.0, -1.0))
        spec["curl"][limb] = curl_all(limb, 0.4, 0.85, 0.85, 0.2, thumb=(0.3, 0.5, 0.6, 0.0))
    return spec


def jitter_curls(spec, t, amount, freq, seed):
    for limb, fingers in spec["curl"].items():
        for i, (f, vals) in enumerate(list(fingers.items())):
            j = amount * noise1(t, seed + zlib.crc32((limb + f).encode()) % 997, freq)
            fingers[f] = tuple(v + j * (0.6 + 0.4 * k) for k, v in enumerate(vals[:3])) + tuple(vals[3:])


def lerp_spec(a, b, w):
    """Blends two specs; w=0 is a, w=1 is b (w may overshoot)."""
    out = {"local": {}, "ik": {}, "curl": {}}
    for k in set(a["local"]) | set(b["local"]):
        ea = a["local"].get(k, (0.0, 0.0, 0.0))
        eb = b["local"].get(k, (0.0, 0.0, 0.0))
        out["local"][k] = tuple(x + (y - x) * w for x, y in zip(ea, eb))
    for limb in LIMBS:
        ka, kb = a["ik"][limb], b["ik"][limb]
        e = {}
        for key in ("target", "pole", "f", "n"):
            va, vb = V(ka[key]), V(kb[key])
            e[key] = va + (vb - va) * w
        out["ik"][limb] = e
        ca, cbb = a["curl"][limb], b["curl"][limb]
        out["curl"][limb] = {f: tuple(x + (y - x) * w for x, y in zip(ca[f], cbb[f])) for f in ca}
    pa, ra = a["body"]
    pb, rb = b["body"]
    qa, qb = ra.to_quaternion(), rb.to_quaternion()
    d = qa.inverted() @ qb
    if d.w < 0:
        d.negate()
    q = qa @ Quaternion(d.axis, d.angle * w) if d.angle > 1e-6 else qa
    out["body"] = (V(pa) + (V(pb) - V(pa)) * w, q.to_matrix())
    return out


# ---------------------------------------------------------------- clips

def clip_idle(rig):
    """Lurking low: breathing, the head turning slowly and tilting too far,
    one small arm raised and its fingers working, a big hand drumming."""
    L = 4.0

    def f(t):
        spec = static_stance(rig, LURK)
        w = 2 * math.pi * t / L
        breath = math.sin(w * 2)
        add_local(spec, "abdomen", deg(3 * breath))
        twitch = math.exp(-((t - 1.7) / 0.06) ** 2) * 18 + math.exp(-((t - 3.1) / 0.05) ** 2) * -10
        add_local(spec, "head", deg(4 * math.sin(w), 22 * math.sin(w + 0.4), 14 * math.sin(w) + twitch))
        add_local(spec, "neck", deg(0, 8 * math.sin(w + 0.2), 0))
        spec["local"]["jaw"] = deg(9 + 3 * math.sin(w * 2 + 1.0))
        spec["local"]["eye.L"] = spec["local"]["eye.R"] = deg(4 * math.sin(w * 3), 0, 10 * math.sin(w * 2 + 0.5))
        # its left small arm lifted off the floor, the fingers flexing
        lift = 0.5 + 0.5 * math.sin(w)
        spec["ik"]["b.L"] = dict(target=Vector((0.3, -0.42, 0.34 + 0.06 * lift)), pole=Vector((0.8, 0.2, 1.0)),
                                 f=Vector((0.2, -1.0, 0.3)), n=Vector((0, 0, -1)))
        spec["curl"]["b.L"] = {fn: (0.2 + 0.5 * (0.5 + 0.5 * math.sin(w * 2 + i * 0.7)), 0.3 + 0.6 * (0.5 + 0.5 * math.sin(w * 2 + i * 0.7 + 0.4)),
                                    0.3 + 0.5 * (0.5 + 0.5 * math.sin(w * 2 + i * 0.7 + 0.8)), 0.2) for i, fn in enumerate(FINGERS)}
        # drumming on the floor, little finger to index, once a second
        drum = spec["curl"]["a.R"]
        for i, fn in enumerate(("pinky", "ring", "middle", "index")):
            ph = (t - i * 0.09) % 1.0
            up = math.exp(-((ph - 0.15) / 0.06) ** 2)
            c = drum[fn]
            drum[fn] = (c[0] - 0.55 * up, c[1] - 0.2 * up, c[2], c[3])
        return spec

    return f, L, True


def clip_crawl(rig):
    T = 2.2

    def f(t):
        spec = gait(rig, CRAWL, t, T, 0.62, SPEEDS["crawl"])
        spec["local"]["jaw"] = deg(8)
        return spec

    return f, T, True


def clip_crawl_fast(rig):
    T = 1.0
    st = Stance(height=0.3, pitch=8.0, spread=0.66, pole_up=1.6, head={"neck": deg(-8), "head": deg(-6)}, lift=0.24)

    def f(t):
        spec = gait(rig, st, t, T, 0.5, SPEEDS["crawl_fast"], sway=1.6, bob=0.025)
        spec["local"]["jaw"] = deg(14)
        return spec

    return f, T, True


def clip_vent(rig):
    """Flat in a duct half a metre high: elbows out to the sides, never up;
    the small pair pressed flat against the duct's roof."""
    T = 2.4

    def f(t):
        spec = gait(rig, VENT, t, T, 0.72, SPEEDS["vent_crawl"], sway=0.6, bob=0.006)
        w = 2 * math.pi * t / T
        for limb in ("b.L", "b.R"):
            u = (t / T + PHASE[limb]) % 1.0
            reach_ = math.sin(2 * math.pi * u)
            spec["ik"][limb] = dict(target=mirror((0.2, -0.32 + 0.1 * reach_, 0.44), limb), pole=mirror((1.0, 0.2, -0.2), limb),
                                    f=mirror((0.3, -1.0, 0.0), limb), n=Vector((0, 0, 1)))
            spec["curl"][limb] = curl_all(limb, 0.1, 0.2, 0.3, 0.25)
        add_local(spec, "head", deg(0, 6 * math.sin(w), 4 * math.sin(w + 1)))
        spec["local"]["jaw"] = deg(5)
        return spec

    return f, T, True


def clip_retreat(rig):
    T = 1.2
    st = Stance(height=0.26, pitch=-4.0, spread=0.6, pole_up=1.7, head={"neck": deg(-10), "head": deg(-8)}, lift=0.22)

    def f(t):
        spec = gait(rig, st, t, T, 0.55, SPEEDS["retreat"], sway=1.2, bob=0.02)
        spec["local"]["jaw"] = deg(20)
        return spec

    return f, T, True


def clip_loom(rig):
    """The picture, held: breathing, a slow tilt of the head, the hands
    trembling on the walls."""
    L = 3.0

    def f(t):
        spec = loom_pose(rig)
        w = 2 * math.pi * t / L
        add_local(spec, "abdomen", deg(3 * math.sin(w * 2)))
        add_local(spec, "head", deg(2 * math.sin(w), 5 * math.sin(w + 0.5), 7 * math.sin(w)))
        spec["local"]["jaw"] = deg(26 + 4 * math.sin(w * 2 + 0.6))
        spec["local"]["eye.L"] = spec["local"]["eye.R"] = deg(-10, 0, 3 * math.sin(w * 3))
        for limb, amp in (("a.L", 0.04), ("a.R", 0.04), ("c.R", 0.03), ("c.L", 0.03)):
            fing = spec["curl"][limb]
            for i, fn in enumerate(FINGERS):
                tr = amp * math.sin(w * 9 + i * 1.3)
                c = fing[fn]
                fing[fn] = (c[0] + tr, c[1] + tr * 1.3, c[2] + tr, c[3])
        return spec

    return f, L, True


def clip_scare(rig):
    """From the crouch to the picture in half a second: it gathers, rears,
    throws its arms to the walls and lunges with the jaw dropping, shaking."""
    L = 2.0
    crouch = static_stance(rig, LURK)

    def f(t):
        loom = loom_pose(rig)
        if t < 0.25:
            w = -0.08 * smooth(t / 0.25)
        else:
            w = back_out((t - 0.25) / 0.38, 1.4)
        spec = lerp_spec(crouch, loom, w)
        peak = math.exp(-((t - 0.62) / 0.16) ** 2)
        hold = smooth((t - 0.45) / 0.15) * (1.0 - smooth((t - 1.55) / 0.35))
        # the neck throws the head forward, the head tips back to keep its face
        # on whoever is in front of it
        add_local(spec, "neck", deg(24 * peak))
        add_local(spec, "head", deg(-34 * peak - 10 * hold))
        spec["local"]["jaw"] = deg(9 + 34 * smooth((t - 0.3) / 0.2) - 13 * smooth((t - 1.4) / 0.5))
        shake = hold * 1.0
        add_local(spec, "head", deg(5 * shake * noise1(t, 3, 22), 6 * shake * noise1(t, 5, 19), 7 * shake * noise1(t, 7, 25)))
        add_local(spec, "abdomen", deg(3 * shake * noise1(t, 9, 17), 0, 3 * shake * noise1(t, 11, 15)))
        jitter_curls(spec, t, 0.18 * hold, 18, 13)
        spec["local"]["eye.L"] = spec["local"]["eye.R"] = deg(-8 * hold, 0, 0)
        return spec

    return f, L, False


def clip_peek(rig):
    """Behind a corner on its left: the head slides out, tilted far over, a big
    hand curls round the edge; it watches, then it is gone."""
    L = 4.0
    base = static_stance(rig, LURK)

    def f(t):
        out = smoother((t - 0.8) / 1.2) * (1.0 - smoother((t - 3.2) / 0.22))
        spec = lerp_spec(base, base, 0.0)
        spec["body"] = (V(base["body"][0]) + Vector((0.14 * out, -0.06 * out, 0.08 * out)), rot(LURK.pitch - 6 * out, 14 * out, 10 * out))
        add_local(spec, "neck", deg(-6 * out, 14 * out, 20 * out))
        twitch = math.exp(-((t - 2.45) / 0.05) ** 2) * 12
        add_local(spec, "head", deg(4 * out, 12 * out, 42 * out + twitch))
        spec["local"]["jaw"] = deg(9 + 6 * out)
        dart = 0.0 if t < 2.0 else 14 * math.sin(6 * t)
        spec["local"]["eye.L"] = spec["local"]["eye.R"] = deg(-4 * out, 0, -dart * out)
        g = smooth((t - 0.5) / 0.6) * (1.0 - smooth((t - 3.25) / 0.25))
        edge = dict(target=Vector((0.4, -0.5, 0.62)), pole=Vector((0.4, 0.6, -0.6)), f=Vector((-0.2, -1.0, 0.4)), n=Vector((1.0, 0.0, 0.0)))
        spec["ik"]["a.L"] = {k: V(spec["ik"]["a.L"][k]) + (V(edge[k]) - V(spec["ik"]["a.L"][k])) * g for k in edge}
        spec["curl"]["a.L"] = curl_all("a.L", 0.32 + 0.4 * g, 0.45 + 0.6 * g, 0.35 + 0.5 * g, 0.12)
        return spec

    return f, L, False


CLIPS = [
    ("idle", clip_idle),
    ("crawl", clip_crawl),
    ("crawl_fast", clip_crawl_fast),
    ("vent_crawl", clip_vent),
    ("retreat", clip_retreat),
    ("loom", clip_loom),
    ("scare", clip_scare),
    ("peek", clip_peek),
]


def build_all(rig_ob):
    rig = Rig(rig_ob)
    rig_ob.animation_data_create()
    ad = rig_ob.animation_data
    for tr in list(ad.nla_tracks):
        ad.nla_tracks.remove(tr)
    made = []
    for name, make in CLIPS:
        clip, length, loop = make(rig)
        act, slot = bake(rig, name, clip, length, loop)
        tr = ad.nla_tracks.new()
        tr.name = name
        st = tr.strips.new(name, 1, act)
        st.action_slot = slot
        tr.mute = True
        made.append((act, slot))
        print("[lurker] clip %-11s %4d frames%s" % (name, int(act.frame_range[1]), " loop" if loop else ""), flush=True)
    act, slot = made[0]
    ad.action = act
    ad.action_slot = slot
    return made
