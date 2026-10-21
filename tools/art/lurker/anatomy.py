"""The Lurker, the creature of the second floor, measured: skeleton, and the
distance fields that are sculpted around it.

Blender axes: Z up, the creature faces -Y, its left side is +X. Everything is
written for the left side and mirrored. The rest pose is a spider's: the body
level and low, the eight arms radiating from it with the elbows up, apart, so
no limb melts into another when the fields are joined.

From the reference picture the author brought, and what the author said of the
first model (21 Oct 2026): a pale skull of a face, huge black sockets with a
white eye and a large pupil, the jaw a triangle ending in a pointed chin and
the mouth a long V of needle teeth; no legs and no trunk, a spider's body that
is a dark, smooth, shapeless centre; eight arms all of one shape and of four
sizes, with hooked claws; and big spikes grafted into the back.
"""

import math
import zlib

import numpy as np

import sdf
from sdf import Ellipsoid, RoundCone, Sphere, Subtract, Torus, TriPrism, Union, Displace, Warp, normalize, v3

# ---------------------------------------------------------------- landmarks

BODY_Z = 0.42
BODY_CENTER = v3(0.0, 0.0, BODY_Z)
ABDOMEN_CENTER = v3(0.0, 0.22, BODY_Z + 0.03)
HEAD_CENTER = v3(0.0, -0.265, BODY_Z + 0.14)
EYE_LOCAL = v3(0.03, -0.056, 0.011)
EYE_RADIUS = 0.0095
JAW_HINGE_LOCAL = v3(0.0, 0.004, -0.04)
# the jaw ends where its tip begins: the tip is a part of its own
TIP_LOCAL = v3(0.0, -0.07, -0.157)
CHIN_LOCAL = v3(0.0, -0.075, -0.2)
# where the skull ends and the jaw begins (head-local): the cut runs under the
# top edge of the mouth and back to the hinge; the tip is cut off below TIP_Z
TIP_Z = -0.158
PIECE_GAP = 0.0016

# Four pairs of arms, front to back, all of one shape: the angle round the body
# from straight ahead (degrees) and the size. The front pair is the one with
# the enormous hands of the picture.
PAIRS = {"a": (32.0, 1.0), "b": (64.0, 0.62), "c": (98.0, 0.82), "d": (136.0, 0.74)}


def arm_config(angle, s):
    a = math.radians(angle)
    out = v3(math.sin(a), -math.cos(a), 0.0)
    socket = BODY_CENTER + v3(0.0, -0.02, 0.0) + v3(0.112 * out[0], 0.135 * out[1], 0.035)
    inner = BODY_CENTER + v3(0.035 * out[0], 0.04 * out[1] - 0.02, 0.03)
    return dict(
        clavicle=inner, shoulder=socket,
        upper_dir=out + v3(0, 0, 0.36), upper_len=0.42 * s,
        fore_dir=out + v3(0, 0, -0.62), fore_len=0.42 * s,
        radii=tuple(r * s ** 0.7 for r in (0.036, 0.022, 0.025, 0.018, 0.015)),
        scale=1.3 * s, thick=1.02 * s ** 0.85,
        palm=0.118 * s, palm_width=0.068 * s, palm_thick=0.027 * s ** 0.85,
    )


ARMS = {k: arm_config(*v) for k, v in PAIRS.items()}

# Index, middle, ring, little: phalanx lengths of the big hand, how far round the
# palm's edge the knuckle sits (+ towards the thumb), and the fan angle.
FINGERS = [
    ("index", (0.072, 0.052, 0.044), 0.86, 0.96, 0.22),
    ("middle", (0.082, 0.058, 0.049), 0.30, 1.00, 0.06),
    ("ring", (0.078, 0.055, 0.046), -0.27, 0.97, -0.1),
    ("pinky", (0.063, 0.046, 0.039), -0.84, 0.90, -0.27),
]
THUMB = (0.046, 0.043, 0.037)
FINGER_RADII = (0.0104, 0.009, 0.0071, 0.0024)
REST_CURL = (0.18, 0.26, 0.22)

# Spikes: thin black rods out of the body in every direction, as the author
# drew them over the picture, some of them bent once like a broken stalk.
SPIKE_COUNT = 17


def mirror(p, side):
    p = np.array(p, dtype=np.float64)
    if side == "R":
        p[..., 0] = -p[..., 0]
    return p


def rotate(v, axis, angle):
    """Rodrigues rotation of v about a unit axis."""
    axis = normalize(axis)
    c = math.cos(angle)
    s = math.sin(angle)
    return v * c + np.cross(axis, v) * s + axis * (axis @ v) * (1.0 - c)


def z_from_x(y_dir, x_axis):
    """The Z axis a bone along y_dir needs for its X axis to be x_axis."""
    y = normalize(y_dir)
    x = normalize(x_axis - y * (x_axis @ y))
    return np.cross(x, y)


class Bone:
    def __init__(self, name, head, tail, parent, z_hint, radius, segs=None, deform=True):
        self.name = name
        self.head = v3(head)
        self.tail = v3(tail)
        self.parent = parent
        self.z_hint = normalize(z_hint)
        self.radius = float(radius)
        self.segs = segs if segs is not None else [(self.head, self.tail)]
        self.deform = deform


# ---------------------------------------------------------------- skeleton

def hand_frame(arm, side):
    """Wrist, finger direction f, palm normal n (down, towards the ground the
    hand stands on) and thumb side t, built for the left side."""
    a = ARMS[arm]
    shoulder = a["shoulder"]
    elbow = shoulder + a["upper_len"] * normalize(a["upper_dir"])
    wrist = elbow + a["fore_len"] * normalize(a["fore_dir"])
    f = normalize(wrist - elbow)
    n = v3(0.0, 0.0, -1.0)
    n = normalize(n - f * (n @ f))
    t = np.cross(n, f)
    return dict(shoulder=shoulder, elbow=elbow, wrist=wrist, f=f, n=n, t=t)


def hand_points(arm):
    """Every joint of a left hand, from its frame."""
    a = ARMS[arm]
    fr = hand_frame(arm, "L")
    w, f, n, t = fr["wrist"], fr["f"], fr["n"], fr["t"]
    s = a["scale"]
    palm = a["palm"]
    half = a["palm_width"] * 0.5
    fingers = {}
    for name, lens, side_off, fwd, fan in FINGERS:
        knuckle = w + f * palm * fwd + t * half * side_off - n * a["palm_thick"] * 0.12
        d = normalize(math.cos(fan) * f + math.sin(fan) * t)
        axis = normalize(np.cross(d, n))
        pts = [knuckle]
        dirs = []
        cur = d
        for j, ln in enumerate(lens):
            cur = rotate(cur, axis, REST_CURL[j])
            dirs.append(cur)
            pts.append(pts[-1] + cur * ln * s)
        fingers[name] = dict(points=pts, dirs=dirs, axis=axis)
    base = w + f * palm * 0.2 + t * half * 0.95 - n * a["palm_thick"] * 0.2
    d = normalize(f * 0.6 + t * 0.72 + n * 0.32)
    axis = normalize(np.cross(d, n))
    pts = [base]
    dirs = []
    cur = d
    for j, ln in enumerate(THUMB):
        cur = rotate(cur, axis, (0.05, 0.16, 0.14)[j])
        dirs.append(cur)
        pts.append(pts[-1] + cur * ln * s)
    fingers["thumb"] = dict(points=pts, dirs=dirs, axis=axis)
    return fr, fingers


def skeleton():
    """Bones in parent-first order. Bone X axes are the bending axes: pitch for
    the head, curl for the fingers, the hinge for the jaw."""
    X = v3(1, 0, 0)
    bones = []

    def add(*args, **kw):
        b = Bone(*args, **kw)
        bones.append(b)
        return b

    hc = HEAD_CENTER
    bc = BODY_CENTER
    add("root", (0, 0, 0), (0, -0.3, 0), None, (0, 0, 1), 0.1, segs=[], deform=False)
    add("body", bc + v3(0, 0.12, 0), bc + v3(0, -0.14, 0), "root", (0, 0, 1), 0.13,
        segs=[(bc + v3(0, 0.1, 0), bc + v3(0, -0.12, 0.02))])
    add("abdomen", bc + v3(0, 0.12, 0.02), ABDOMEN_CENTER + v3(0, 0.14, 0.01), "body", (0, 0, 1), 0.11,
        segs=[(ABDOMEN_CENTER - v3(0, 0.08, 0), ABDOMEN_CENTER + v3(0, 0.1, 0))])
    neck_root = bc + v3(0, -0.11, 0.05)
    neck_top = hc + v3(0.0, 0.05, -0.05)
    add("neck", neck_root, neck_top, "body", z_from_x(neck_top - neck_root, X), 0.045)
    add("head", neck_top, neck_top + v3(0, 0, 0.17), "neck", z_from_x((0, 0, 1), X), 0.07,
        segs=[(hc + v3(0, 0.02, 0.03), hc + v3(0, -0.04, -0.02))])
    hinge = hc + JAW_HINGE_LOCAL
    tip = hc + TIP_LOCAL
    chin = hc + CHIN_LOCAL
    add("jaw", hinge, tip, "head", z_from_x(tip - hinge, X), 0.04)
    add("jaw_tip", tip, chin, "jaw", z_from_x(chin - tip, X), 0.012)
    for side in "LR":
        e = hc + mirror(EYE_LOCAL, side)
        add("eye." + side, e, e + v3(0, -0.025, 0), "head", z_from_x((0, -1, 0), X), 0.012)

    for side in "LR":
        m = lambda p: mirror(p, side)
        for arm, a in ARMS.items():
            fr, fingers = hand_points(arm)
            sh, el, wr = fr["shoulder"], fr["elbow"], fr["wrist"]
            n = fr["n"]
            bend = normalize(np.cross(normalize(el - sh), normalize(wr - el)))
            sfx = "_%s.%s" % (arm, side)
            add("clavicle" + sfx, m(a["clavicle"]), m(sh), "body", m(z_from_x(sh - a["clavicle"], v3(0, 0, 1))), a["radii"][0])
            add("upperarm" + sfx, m(sh), m(el), "clavicle" + sfx, m(z_from_x(el - sh, bend)), a["radii"][1])
            add("forearm" + sfx, m(el), m(wr), "upperarm" + sfx, m(z_from_x(wr - el, bend)), a["radii"][3])
            knuckles = [fingers[k]["points"][0] for k in ("index", "middle", "ring", "pinky")]
            hand_tail = fingers["middle"]["points"][0]
            hsegs = [(m(wr), m(k)) for k in knuckles] + [(m(wr), m(fingers["thumb"]["points"][0]))]
            add("hand" + sfx, m(wr), m(hand_tail), "forearm" + sfx, m(n), a["radii"][4] * 1.2, segs=hsegs)
            for fname in ("thumb", "index", "middle", "ring", "pinky"):
                fd = fingers[fname]
                pts = fd["points"]
                parent = "hand" + sfx
                for j in range(3):
                    name = "%s_%02d%s" % (fname, j + 1, sfx)
                    z = np.cross(fd["axis"], normalize(pts[j + 1] - pts[j]))
                    add(name, m(pts[j]), m(pts[j + 1]), parent, mirror(z, side),
                        FINGER_RADII[j] * a.get("thick", a["scale"]) * 1.4)
                    parent = name
    return bones


# ---------------------------------------------------------------- fields

def skin_noise(amp, freq, seed, octaves=3, scale=None):
    def fn(p):
        return amp * sdf.fbm(p, freq, octaves, seed, scale=scale)
    return fn


def hand_node(arm, side, with_wrist=True):
    a = ARMS[arm]
    fr, fingers = hand_points(arm)
    m = lambda p: mirror(p, side)
    s = a["scale"]
    tk = a.get("thick", s)  # fingers can be long without being fat
    w, f, n, t = fr["wrist"], fr["f"], fr["n"], fr["t"]
    palm, half, thick = a["palm"], a["palm_width"] * 0.5, a["palm_thick"]
    rw = a["radii"][4]
    parts = []
    rot = _mirror_rot(sdf.rotation_to(t, n, f), side)
    # the palm: a plate, the heel of the thumb and the edge under the little finger
    plate_c = w + f * palm * 0.55
    parts.append(Ellipsoid(m(plate_c), (half * 0.92, thick * 0.4, palm * 0.5), rot))
    th = fingers["thumb"]["points"][0]
    parts.append(Ellipsoid(m(w + f * palm * 0.32 + t * half * 0.5 + n * thick * 0.18), (half * 0.42, thick * 0.42, palm * 0.3), rot))
    parts.append(Ellipsoid(m(w + f * palm * 0.5 - t * half * 0.62 + n * thick * 0.1), (half * 0.3, thick * 0.34, palm * 0.36), rot))
    parts.append(RoundCone(m(w + f * palm * 0.1), m(th), rw * 0.62, FINGER_RADII[0] * tk * 1.25))
    if with_wrist:
        parts.append(RoundCone(m(w - f * 0.06 * s), m(w + f * 0.012), rw * 1.05, rw * 0.88))
        parts.append(Sphere(m(w - t * rw * 0.55 - n * rw * 0.2), rw * 0.42))  # the knob of the wrist
    palm_node = Union(parts, k=0.011 * s + 0.002)
    # the back of the hand: one cord per finger, wrist to knuckle
    cords = []
    for k in ("index", "middle", "ring", "pinky"):
        kn = fingers[k]["points"][0]
        root = w + f * palm * 0.08 + t * ((kn - w) @ t) * 0.3
        cords.append(RoundCone(m(root - n * thick * 0.3), m(kn - n * thick * 0.33), rw * 0.2, FINGER_RADII[0] * tk * 0.62))
    palm_node = Union([palm_node] + cords, k=0.0045 * s + 0.001)

    digits = []
    for k in ("thumb", "index", "middle", "ring", "pinky"):
        pts = fingers[k]["points"]
        r = [FINGER_RADII[0] * tk, FINGER_RADII[1] * tk, FINGER_RADII[2] * tk, FINGER_RADII[3] * tk]
        if k == "thumb":
            r = [r[0] * 1.2, r[0] * 1.02, r[1] * 1.0, r[3] * 1.15]
        segs = []
        for j in range(3):
            segs.append(RoundCone(m(pts[j]), m(pts[j + 1]), r[j], r[j + 1]))
        # knuckles: bony knots on the back of the first two joints
        for j, (grow, back) in enumerate(((1.12, 0.38), (1.05, 0.36))):
            d = fingers[k]["dirs"][j]
            segs.append(Ellipsoid(m(pts[j] - n * r[j] * back), (r[j] * grow, r[j] * grow * 0.85, r[j] * grow * 0.9),
                                  _mirror_rot(sdf.rotation_to(np.cross(d, n), n, d), side)))
        digits.append(Union(segs, k=0.003 * tk + 0.0008))
    hand = Union([palm_node] + digits, k=0.006 * s + 0.0015)
    wrinkles = skin_noise(0.0004 * s, 280.0, 11, 3)
    # creases across the back of every joint, the way skin folds over a knuckle
    joints = []
    for k in ("thumb", "index", "middle", "ring", "pinky"):
        pts = fingers[k]["points"]
        dirs = fingers[k]["dirs"]
        for j in range(3):
            d = dirs[j] if j == 0 else normalize(dirs[j - 1] + dirs[j])
            joints.append((m(pts[j]), m(d), FINGER_RADII[j] * tk))
    jp = np.array([q[0] for q in joints])
    jd = np.array([q[1] for q in joints])
    jr = np.array([q[2] for q in joints])
    back = mirror(-n, side)

    def creases(p):
        out = np.zeros(len(p))
        for c, d, r in zip(jp, jd, jr):
            q = p - c
            along = q @ d
            near = np.exp(-(along / (r * 1.1)) ** 2)
            if not np.any(near > 0.01):
                continue
            radial = q - np.outer(along, d)
            dist = np.linalg.norm(radial, axis=1)
            dorsal = np.clip((radial @ back) / np.maximum(dist, 1e-9), 0.0, 1.0)
            ring = np.exp(-((dist - r * 1.1) / (r * 0.9)) ** 2)
            out += 0.00042 * s * near * dorsal * ring * np.cos(along * (2 * math.pi / (0.0026 * s)))
        return out

    return Displace(hand, lambda p: wrinkles(p) + creases(p), 0.0011)


def _mirror_rot(rot, side):
    if side == "L":
        return rot
    r = rot.copy()
    r[:, 0] = -r[:, 0]
    return r


def limb_node(points, radii, side, seed, knob_dir=None, sinews=True):
    """Shoulder to wrist: bony, thin, knotted at the elbow."""
    m = lambda p: mirror(p, side)
    sh, el, wr = points
    rs, ru, re, rf, rw = radii
    mid_u = sh + (el - sh) * 0.45
    mid_f = el + (wr - el) * 0.5
    parts = [
        Sphere(m(sh), rs),
        RoundCone(m(sh), m(mid_u), rs * 0.9, ru),
        RoundCone(m(mid_u), m(el), ru, re),
        RoundCone(m(el), m(mid_f), re, rf),
        RoundCone(m(mid_f), m(wr), rf, rw),
    ]
    if knob_dir is not None:
        parts.append(Sphere(m(el + knob_dir * re * 0.5), re * 1.1))
        parts.append(RoundCone(m(el + knob_dir * re * 0.9), m(el + knob_dir * (re * 0.9 + 0.022 * (re / 0.025))), re * 0.55, 0.0025))
    if sinews:
        d = normalize(wr - el)
        side_a = normalize(np.cross(d, v3(0, 0, 1)) if abs(d[2]) < 0.9 else np.cross(d, v3(1, 0, 0)))
        side_b = np.cross(d, side_a)
        for off in (side_a * 0.7 + side_b * 0.5, -side_a * 0.6 + side_b * 0.6):
            parts.append(RoundCone(m(el + d * re + off * re * 0.6), m(wr - d * rw * 0.5 + off * rw * 0.55), re * 0.32, rw * 0.3))
    node = Union(parts, k=0.012)
    knot = skin_noise(0.0012, 55.0, seed, 3)
    return Displace(node, knot, 0.0015)


def arm_node(arm, side):
    fr = hand_frame(arm, "L")
    a = ARMS[arm]
    knob = -normalize((fr["wrist"] + fr["shoulder"]) * 0.5 - fr["elbow"])
    return limb_node((fr["shoulder"], fr["elbow"], fr["wrist"]), a["radii"], side, seed=zlib.crc32((arm + side).encode()) % 97, knob_dir=knob)


def body_node():
    """A spider's body, not a trunk: the front mass the arms grow from, a waist
    and the bulb behind, all smooth and lumpy, with no clear outline."""
    bc = BODY_CENTER
    parts = [
        Ellipsoid(bc + v3(0, -0.02, 0), (0.125, 0.15, 0.095)),
        RoundCone(bc + v3(0, 0.06, 0.0), bc + v3(0, 0.14, 0.02), 0.07, 0.075),
        Ellipsoid(ABDOMEN_CENTER, (0.105, 0.145, 0.1)),
        RoundCone(bc + v3(0, -0.1, 0.04), HEAD_CENTER + v3(0, 0.07, -0.06), 0.06, 0.042),
    ]
    rng = np.random.default_rng(42)
    for i in range(14):
        # lumps under the skin, so the mass has no clean shape
        c = (bc if i < 8 else ABDOMEN_CENTER) + v3(rng.uniform(-0.09, 0.09), rng.uniform(-0.11, 0.11), rng.uniform(-0.03, 0.08))
        parts.append(Sphere(c, rng.uniform(0.035, 0.06)))
    for side in "LR":
        m = lambda p: mirror(p, side)
        for arm in ARMS:
            parts.append(Sphere(m(ARMS[arm]["shoulder"]), ARMS[arm]["radii"][0] * 1.12))
    body = Union(parts, k=0.045)
    knot = skin_noise(0.004, 14.0, 3, 3)
    fine = skin_noise(0.0007, 80.0, 4, 2)
    return Displace(body, lambda p: knot(p) + fine(p), 0.006)


# ---------------------------------------------------------------- the head

class HeadLocal(sdf.Node):
    """Evaluates a node written in head-local coordinates."""

    def __init__(self, node, center):
        self.node = node
        self.center = v3(center)
        self.lo = node.lo + self.center
        self.hi = node.hi + self.center

    def _eval(self, p, lo, hi):
        if lo is not None:
            lo = lo - self.center
            hi = hi - self.center
        return self.node.eval(p - self.center, lo, hi)


class Region(sdf.Node):
    """A node cut down to where fn(p) <= 0, its cut edge rounded over k."""

    def __init__(self, child, fn, k=0.002, lo=None, hi=None):
        self.child = child
        self.fn = fn
        self.k = float(k)
        self.lo = child.lo if lo is None else np.maximum(child.lo, v3(lo))
        self.hi = child.hi if hi is None else np.minimum(child.hi, v3(hi))

    def _eval(self, p, lo, hi):
        d = self.child.eval(p, lo, hi)
        if d is None:
            return None
        return sdf.smax(d, self.fn(p), self.k)


def jaw_zone(p):
    """Negative inside the jaw's share of the head (head-local)."""
    y, z = p[:, 1], p[:, 2]
    cut = -0.051 + 0.013 * np.clip((y + 0.1) / 0.1, 0.0, 1.0)
    return np.maximum(z - cut, y - 0.016)


def crack_lines(node):
    """Segments (a, b, ra, rb) of the cracks, in head-local coordinates: random
    walks over the skull's surface, some of them forking, snapped onto it."""
    rng = np.random.default_rng(4401)
    starts = [(0.02, 0.0, 0.1), (-0.035, 0.04, 0.09), (0.05, 0.03, 0.05), (-0.055, -0.02, 0.04),
              (0.0, -0.075, 0.05), (0.04, -0.05, 0.065), (-0.03, 0.08, 0.06), (0.05, -0.06, -0.09),
              (-0.04, -0.06, -0.11)]
    paths = []
    for start in starts:
        point = v3(start)
        heading = normalize(v3(rng.normal(), rng.normal(), -0.6))
        path = [point]
        for step in range(int(rng.integers(6, 13))):
            heading = normalize(heading + v3(*rng.normal(size=3)) * 0.55)
            point = point + heading * rng.uniform(0.006, 0.01)
            path.append(point)
            if rng.random() < 0.18 and len(paths) < 30:
                fork = [point]
                fh = normalize(heading + v3(*rng.normal(size=3)) * 1.2)
                fp = point
                for _ in range(int(rng.integers(2, 5))):
                    fh = normalize(fh + v3(*rng.normal(size=3)) * 0.5)
                    fp = fp + fh * rng.uniform(0.005, 0.008)
                    fork.append(fp)
                paths.append(fork)
        paths.append(path)
    out = []
    for path in paths:
        pts = np.array(path)
        # onto the surface, then a hair inside it
        for _ in range(4):
            d = node.full(pts)
            g = sdf.gradient(node, pts, 3e-4)
            gl = np.maximum(np.linalg.norm(g, axis=1, keepdims=True), 1e-9)
            pts = pts - (d[:, None] * g / gl / gl)
        g = sdf.gradient(node, pts, 3e-4)
        pts = pts - g / np.maximum(np.linalg.norm(g, axis=1, keepdims=True), 1e-9) * 0.0003
        n = len(pts)
        for i in range(n - 1):
            ra = 0.0015 * (1.0 - 0.6 * i / n)
            rb = 0.0015 * (1.0 - 0.6 * (i + 1) / n)
            out.append((pts[i], pts[i + 1], ra, rb))
    return out


def head_local_node():
    def both(make):
        return [make("L"), make("R")]

    cranium = Ellipsoid((0, 0.02, 0.024), (0.063, 0.088, 0.079))
    face = Ellipsoid((0, -0.026, -0.006), (0.059, 0.067, 0.09))
    cheeks = both(lambda s: Ellipsoid(mirror((0.048, -0.058, -0.02), s), (0.011, 0.021, 0.01)))
    maxilla = Ellipsoid((0, -0.067, -0.05), (0.034, 0.033, 0.021))
    # the jaw is a triangle: two straight bones meeting in a pointed chin
    wedge = TriPrism((-0.043, -0.04), (0.043, -0.04), (0.0, -0.19), -0.088, 0.01, 0.017)
    jaw = both(lambda s: RoundCone(mirror((0.047, 0.0, -0.04), s), (0.0, -0.074, -0.19), 0.011, 0.007))
    point = RoundCone((0, -0.071, -0.168), (0, -0.076, -0.202), 0.0085, 0.0025)
    neck = RoundCone((0, 0.03, -0.04), (0, 0.13, -0.09), 0.036, 0.042)
    # the edges the author marked: a rim round each socket, the cheekbone ridge,
    # a knot of bone at each corner of the mouth
    ridges = both(lambda s: RoundCone(mirror((0.05, -0.068, -0.013), s), mirror((0.064, -0.012, -0.017), s), 0.0055, 0.004))
    corners = both(lambda s: Sphere(mirror((0.043, -0.079, -0.048), s), 0.0072))
    # the cheeks swell out where the jaw meets the skull, one more than the other
    swells = [Ellipsoid((0.049, -0.06, -0.042), (0.012, 0.017, 0.014)),
              Ellipsoid((-0.047, -0.06, -0.044), (0.0095, 0.015, 0.012))]

    skull = Union([cranium, face, maxilla], k=0.016)
    bones_ = Union([skull] + cheeks, k=0.016)
    bones_ = Union([bones_, wedge] + jaw, k=0.022)
    bones_ = Union([bones_, neck], k=0.025)
    bones_ = Union([bones_] + ridges + corners + [point], k=0.005)
    bones_ = Union([bones_] + swells, k=0.012)

    cuts = []
    sockets = Union(both(lambda s: Ellipsoid(mirror((0.03, -0.08, 0.012), s), (0.0245, 0.032, 0.0255))))
    cuts.append((sockets, 0.0028))
    temples = Union(both(lambda s: Sphere(mirror((0.068, -0.03, 0.018), s), 0.023)))
    cuts.append((temples, 0.02))
    hollows = Union(both(lambda s: Ellipsoid(mirror((0.053, -0.056, -0.062), s), (0.014, 0.025, 0.03))))
    cuts.append((hollows, 0.012))
    # the mouth: a V, wide under the nose and narrowing down to the chin
    mouth = Union([TriPrism((-0.031, -0.045), (0.031, -0.045), (0.0, -0.145), -0.16, -0.036, 0.008),
                   RoundCone((0, -0.06, -0.08), (0, 0.012, -0.1), 0.024, 0.016)], k=0.012)
    cuts.append((mouth, 0.005))
    # the nose: no bridge, one black slit in the skull from between the eyes
    # down to just over the mouth
    nasal = Union([Ellipsoid((0.0, -0.098, -0.012), (0.0058, 0.02, 0.031)),
                   Ellipsoid((0.0, -0.1, -0.036), (0.0085, 0.016, 0.008))], k=0.004)
    cuts.append((nasal, 0.002))
    node = bones_
    for c, k in cuts:
        node = Subtract(node, c, k)
    # drawn by hand: nothing about it is quite round or quite symmetric
    node = Warp(node, 0.0035, 22.0, 9)
    # cracked: thin grooves wandering over the skull and the jaw
    cracks = crack_lines(node)
    node = Subtract(node, Union([RoundCone(a, b, ra, rb) for a, b, ra, rb in cracks], k=0.0), 0.0006)

    def grooves(p):
        # the skin of the cheeks dragged into cords down to the chin
        x, y, z = p[:, 0], p[:, 1], p[:, 2]
        mask = np.clip((-y - 0.025) / 0.03, 0.0, 1.0) * np.clip((-0.005 - z) / 0.025, 0.0, 1.0)
        mask *= np.clip(1.0 - np.abs(z + 0.1) / 0.095, 0.0, 1.0)
        streak = sdf.fbm(p, 1.0, 3, 41, scale=(190.0, 120.0, 11.0))
        return 0.0017 * mask * np.abs(streak) - 0.0005 * mask

    # bone that is pitted and uneven, not smooth
    pits = skin_noise(0.0007, 140.0, 6, 3)
    skin = skin_noise(0.00035, 320.0, 5, 3)
    whole = Displace(node, lambda p: grooves(p) + pits(p) + skin(p), 0.0028)
    g = PIECE_GAP
    pieces = dict(
        skull=Region(whole, lambda p: g - jaw_zone(p)),
        jaw=Region(whole, lambda p: np.maximum(jaw_zone(p) + g, (TIP_Z + g) - p[:, 2]), hi=(0.08, 0.03, -0.02)),
        tip=Region(whole, lambda p: np.maximum(jaw_zone(p) + g, p[:, 2] - (TIP_Z - g)), hi=(0.03, 0.0, TIP_Z + 0.004)),
    )
    return whole, dict(sockets=sockets, mouth=mouth, nasal=nasal, bone=node, pieces=pieces, cracks=cracks)


def head_node():
    local, feats = head_local_node()
    feats["world_pieces"] = {k: HeadLocal(v, HEAD_CENTER) for k, v in feats["pieces"].items()}
    return HeadLocal(local, HEAD_CENTER), feats


# ---------------------------------------------------------------- teeth

def teeth_layout():
    """Needles deep in the V of the mouth, in head-local coordinates: (root,
    direction, length, radius, which bone). They grow from well inside, so
    the top of the mouth stays black and they show from its middle down, as
    in the picture."""
    rng = np.random.default_rng(81)
    out = []
    for t in np.linspace(-0.85, 0.85, 7):
        x = 0.026 * t + rng.normal() * 0.001
        root = v3(x, -0.08 + 0.016 * t * t, -0.062 - 0.004 * t * t)
        length = (0.046 - 0.02 * t * t) * (0.85 + 0.3 * rng.random())
        d = normalize(v3(-0.1 * t + rng.normal() * 0.03, -0.12 + rng.normal() * 0.04, -1.0))
        out.append((root, d, length, 0.0021 - 0.0004 * t * t, "head"))
    corner = np.array([0.031, -0.045])
    tip = np.array([0.0, -0.145])
    for side in (1.0, -1.0):
        for u in (0.35, 0.56, 0.76):
            q = corner * np.array([side, 1.0]) + u * (tip - corner * np.array([side, 1.0]))
            inward = normalize(v3(-side * 0.22, -0.1, 1.0))
            root = v3(q[0] + side * 0.002, -0.084 + 0.01 * (1 - u), q[1] - 0.004)
            length = (0.034 - 0.014 * u) * (0.85 + 0.3 * rng.random())
            d = normalize(inward + v3(rng.normal() * 0.05, 0.0, 0.0))
            out.append((root, d, length, 0.0018, "jaw"))
    out.append((v3(0.0, -0.086, -0.15), normalize(v3(0.0, -0.08, 1.0)), 0.026, 0.0018, "jaw"))
    return out


# ---------------------------------------------------------------- spikes

def spikes():
    """Polylines for the spikes: (points, base radius, bone). Each grows out of
    the body's surface in its own direction, but never at the face."""
    rng = np.random.default_rng(1977)
    out = []
    tries = 0
    while len(out) < SPIKE_COUNT and tries < 400:
        tries += 1
        d = normalize(rng.normal(size=3))
        if d[1] < -0.45 or d[2] < -0.75:
            continue  # not through the face, not down into the floor
        behind = rng.random() < 0.45
        centre = ABDOMEN_CENTER if behind else BODY_CENTER + v3(0, -0.02, 0)
        radii = v3(0.1, 0.14, 0.095) if behind else v3(0.12, 0.145, 0.09)
        root = centre + d * (1.0 / np.linalg.norm(d / radii)) * 0.85
        length = rng.uniform(0.16, 0.42)
        r = rng.uniform(0.007, 0.011)
        pts = [root]
        if rng.random() < 0.45:
            # bent once, a little past halfway
            k = rng.uniform(0.5, 0.65)
            knee = root + d * length * k
            axis = normalize(np.cross(d, rng.normal(size=3)))
            d2 = rotate(d, axis, math.radians(rng.uniform(35.0, 70.0)))
            pts += [knee, knee + d2 * length * (1.0 - k)]
        else:
            pts.append(root + d * length)
        out.append((pts, r, "abdomen" if behind else "body"))
    return out
