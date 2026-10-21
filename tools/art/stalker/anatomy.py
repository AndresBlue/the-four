"""The creature of the second floor, measured: skeleton, and the distance fields
that are sculpted around it.

Blender axes: Z up, the creature faces -Y, its left side is +X. Everything is
written for the left side and mirrored. The rest pose stands it upright with the
six arms fanned out and apart, so no limb melts into another when the fields are
joined; the animations crouch it, lay it flat and put it on the walls.

From the reference picture the author brought (21 Oct 2026): a pale, skull-like
face with huge black sockets, small white eyes and a mouth unhinged into a long
oval of needle teeth, sunk into a mane of black hair; a small shaggy body; six
spindly arms, the upper pair with enormous hooked hands; two long legs whose
feet are hands too.
"""

import math
import zlib

import numpy as np

import sdf
from sdf import Ellipsoid, RoundCone, Sphere, Subtract, Union, Displace, normalize, v3

# ---------------------------------------------------------------- landmarks

HEAD_CENTER = v3(0.0, -0.07, 1.61)
EYE_LOCAL = v3(0.03, -0.055, 0.011)
EYE_RADIUS = 0.0086
JAW_HINGE_LOCAL = v3(0.0, 0.004, -0.036)
CHIN_LOCAL = v3(0.0, -0.083, -0.158)

# The three pairs of arms. Points are the left side's rest pose.
ARMS = {
    "a": dict(  # the upper pair: the enormous hands on the walls
        clavicle=v3(0.025, 0.0, 1.385), shoulder=v3(0.135, 0.022, 1.405),
        upper_dir=v3(1.0, 0.12, 0.42), upper_len=0.43,
        fore_dir=v3(1.0, -0.06, 0.82), fore_len=0.42,
        radii=(0.04, 0.026, 0.027, 0.019, 0.0162),
        scale=1.3, thick=1.02, palm=0.118, palm_width=0.068, palm_thick=0.027,
    ),
    "b": dict(  # the thin pair from the shoulder blades, reaching up
        clavicle=v3(0.02, 0.05, 1.33), shoulder=v3(0.11, 0.078, 1.36),
        upper_dir=v3(0.55, 0.25, 1.0), upper_len=0.31,
        fore_dir=v3(0.18, 0.06, 1.0), fore_len=0.30,
        radii=(0.029, 0.019, 0.019, 0.014, 0.0105),
        scale=0.64, palm=0.07, palm_width=0.048, palm_thick=0.018,
    ),
    "c": dict(  # the lower pair, under the ribs
        clavicle=v3(0.02, 0.012, 1.215), shoulder=v3(0.115, 0.025, 1.215),
        upper_dir=v3(1.0, -0.15, -0.3), upper_len=0.36,
        fore_dir=v3(0.8, -0.22, -0.75), fore_len=0.35,
        radii=(0.03, 0.019, 0.022, 0.016, 0.0125),
        scale=0.82, palm=0.088, palm_width=0.058, palm_thick=0.022,
    ),
}

LEG = dict(
    hip=v3(0.085, 0.025, 0.91),
    thigh_dir=v3(0.22, -0.18, -1.0), thigh_len=0.46,
    shin_dir=v3(0.06, 0.2, -1.0), shin_len=0.42,
    radii=(0.04, 0.021, 0.024, 0.016, 0.0135),
)

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

TOES = [
    ("toe1", (0.06, 0.05), 0.75, -0.0, 0.32),
    ("toe2", (0.068, 0.056), 0.25, 0.0, 0.1),
    ("toe3", (0.066, 0.054), -0.25, 0.0, -0.1),
    ("toe4", (0.058, 0.048), -0.75, 0.0, -0.3),
]


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
    """Wrist, finger direction f, palm normal n and thumb side t (left side
    built, then mirrored, so t points the right way on both)."""
    a = ARMS[arm]
    shoulder = a["shoulder"]
    elbow = shoulder + a["upper_len"] * normalize(a["upper_dir"])
    wrist = elbow + a["fore_len"] * normalize(a["fore_dir"])
    f = normalize(wrist - elbow)
    n = v3(0.0, -1.0, 0.0)
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


def leg_points():
    g = LEG
    hip = g["hip"]
    knee = hip + g["thigh_len"] * normalize(g["thigh_dir"])
    ankle = knee + g["shin_len"] * normalize(g["shin_dir"])
    f = normalize(v3(0.12, -1.0, -0.16))
    n = v3(0.0, 0.0, -1.0)
    n = normalize(n - f * (n @ f))
    t = np.cross(n, f)
    ball = ankle + f * 0.105
    toes = {}
    for name, lens, side_off, _, fan in TOES:
        k = ball + t * 0.03 * side_off
        d = normalize(math.cos(fan) * f + math.sin(fan) * t)
        axis = normalize(np.cross(d, n))
        pts = [k]
        dirs = []
        cur = d
        for j, ln in enumerate(lens):
            cur = rotate(cur, axis, (0.12, 0.28)[j])
            dirs.append(cur)
            pts.append(pts[-1] + cur * ln)
        toes[name] = dict(points=pts, dirs=dirs, axis=axis)
    return dict(hip=hip, knee=knee, ankle=ankle, ball=ball, f=f, n=n, t=t, toes=toes)


def skeleton():
    """Bones in parent-first order. Bone X axes are the bending axes: pitch for
    the spine and head, curl for the fingers, the hinge for the jaw."""
    X = v3(1, 0, 0)
    bones = []

    def add(*args, **kw):
        b = Bone(*args, **kw)
        bones.append(b)
        return b

    hc = HEAD_CENTER
    add("root", (0, 0, 0), (0, -0.3, 0), None, (0, 0, 1), 0.1, segs=[], deform=False)
    add("hips", (0, 0.025, 0.9), (0, 0.03, 1.0), "root", z_from_x((0, 0.05, 1), X), 0.08)
    add("spine_01", (0, 0.03, 1.0), (0, 0.035, 1.12), "hips", z_from_x((0, 0.05, 1), X), 0.065)
    add("spine_02", (0, 0.035, 1.12), (0, 0.035, 1.25), "spine_01", z_from_x((0, 0, 1), X), 0.08)
    add("chest", (0, 0.035, 1.25), (0, 0.02, 1.4), "spine_02", z_from_x((0, -0.1, 1), X), 0.1)
    neck_top = hc + v3(0.0, 0.03, -0.072)
    add("neck", (0, 0.02, 1.4), neck_top, "chest", z_from_x(neck_top - v3(0, 0.02, 1.4), X), 0.035)
    add("head", neck_top, neck_top + v3(0, 0, 0.17), "neck", z_from_x((0, 0, 1), X), 0.07,
        segs=[(hc + v3(0, 0.02, 0.03), hc + v3(0, -0.04, -0.02))])
    hinge = hc + JAW_HINGE_LOCAL
    chin = hc + CHIN_LOCAL
    add("jaw", hinge, chin, "head", z_from_x(chin - hinge, X), 0.04)
    for side in "LR":
        e = hc + mirror(EYE_LOCAL, side)
        add("eye." + side, e, e + v3(0, -0.025, 0), "head", z_from_x((0, -1, 0), X), 0.012)

    for side in "LR":
        m = lambda p: mirror(p, side)
        sx = 1.0 if side == "L" else -1.0
        for arm, a in ARMS.items():
            fr, fingers = hand_points(arm)
            sh, el, wr = fr["shoulder"], fr["elbow"], fr["wrist"]
            n = fr["n"]
            bend = normalize(np.cross(normalize(el - sh), normalize(wr - el)))
            if np.linalg.norm(np.cross(normalize(el - sh), normalize(wr - el))) < 1e-4:
                bend = v3(0, 1, 0)
            sfx = "_%s.%s" % (arm, side)
            add("clavicle" + sfx, m(a["clavicle"]), m(sh), "chest", m(z_from_x(sh - a["clavicle"], v3(0, 1, 0))), a["radii"][0])
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
        lg = leg_points()
        sfx = "." + side
        knee_bend = normalize(np.cross(normalize(lg["knee"] - lg["hip"]), normalize(lg["ankle"] - lg["knee"])))
        add("thigh" + sfx, m(lg["hip"]), m(lg["knee"]), "hips", m(z_from_x(lg["knee"] - lg["hip"], knee_bend)), LEG["radii"][1])
        add("shin" + sfx, m(lg["knee"]), m(lg["ankle"]), "thigh" + sfx, m(z_from_x(lg["ankle"] - lg["knee"], knee_bend)), LEG["radii"][3])
        fsegs = [(m(lg["ankle"]), m(td["points"][0])) for td in lg["toes"].values()]
        add("foot" + sfx, m(lg["ankle"]), m(lg["ball"]), "shin" + sfx, m(lg["n"]), 0.02, segs=fsegs)
        for tname, td in lg["toes"].items():
            pts = td["points"]
            parent = "foot" + sfx
            for j in range(2):
                name = "%s_%02d%s" % (tname, j + 1, sfx)
                z = np.cross(td["axis"], normalize(pts[j + 1] - pts[j]))
                add(name, m(pts[j]), m(pts[j + 1]), parent, mirror(z, side), 0.011)
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
        parts.append(RoundCone(m(w - f * 0.06), m(w + f * 0.012), rw * 1.05, rw * 0.88))
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
        # knuckles: bony knots on the back of the first two joints, a pad under the tip
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
            joints.append((m(pts[j]), m(d), FINGER_RADII[j] * a.get("thick", s)))
    jp = np.array([q[0] for q in joints])
    jd = np.array([q[1] for q in joints])
    jr = np.array([q[2] for q in joints])
    back = m(-n) if side == "L" else mirror(-n, side)

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
    """Shoulder to wrist (or hip to ankle): bony, thin, knotted at the joint."""
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
        parts.append(Sphere(m(el + knob_dir * re * 0.35), re * 0.95))
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
    bend_out = normalize(np.cross(np.cross(normalize(fr["elbow"] - fr["shoulder"]), normalize(fr["wrist"] - fr["elbow"])), normalize(fr["wrist"] - fr["shoulder"])))
    knob = -normalize((fr["wrist"] + fr["shoulder"]) * 0.5 - fr["elbow"])
    return limb_node((fr["shoulder"], fr["elbow"], fr["wrist"]), a["radii"], side, seed=zlib.crc32((arm + side).encode()) % 97, knob_dir=knob)


def leg_node(side):
    lg = leg_points()
    knob = -normalize((lg["ankle"] + lg["hip"]) * 0.5 - lg["knee"])
    return limb_node((lg["hip"], lg["knee"], lg["ankle"]), LEG["radii"], side, seed=7 if side == "L" else 8, knob_dir=knob)


def foot_node(side):
    lg = leg_points()
    m = lambda p: mirror(p, side)
    a, b, f, n, t = lg["ankle"], lg["ball"], lg["f"], lg["n"], lg["t"]
    parts = [RoundCone(m(a - normalize(a - lg["knee"]) * 0.05), m(a), 0.018, 0.017),
             Sphere(m(a + v3(0, 0.012, 0.0)), 0.02)]
    for td in lg["toes"].values():
        k = td["points"][0]
        parts.append(RoundCone(m(a), m(k - n * 0.003), 0.012, 0.0095))
    sole = Union(parts, k=0.012)
    digits = []
    for td in lg["toes"].values():
        pts = td["points"]
        r = (0.0095, 0.0078, 0.0036)
        segs = [RoundCone(m(pts[j]), m(pts[j + 1]), r[j], r[j + 1]) for j in range(2)]
        segs += [Sphere(m(pts[j] - n * r[j] * 0.2), r[j] * 1.25) for j in range(2)]
        digits.append(Union(segs, k=0.004))
    foot = Union([sole] + digits, k=0.007)
    return Displace(foot, skin_noise(0.0005, 220.0, 31, 3), 0.001)


def torso_node():
    parts = [
        Ellipsoid((0, 0.03, 0.935), (0.095, 0.065, 0.065)),
        RoundCone((0, 0.04, 0.97), (0, 0.04, 1.17), 0.058, 0.07),
        Ellipsoid((0, 0.038, 1.29), (0.108, 0.082, 0.14)),
        RoundCone((0, 0.025, 1.36), (0, 0.0, 1.47), 0.05, 0.034),
    ]
    for side in "LR":
        m = lambda p: mirror(p, side)
        parts.append(Ellipsoid(m((0.058, 0.098, 1.33)), (0.045, 0.016, 0.055)))  # shoulder blades
        parts.append(RoundCone(m((0.0, -0.02, 1.385)), m(ARMS["a"]["shoulder"]), 0.016, 0.022))  # collarbone
        for arm in ARMS:
            parts.append(Sphere(m(ARMS[arm]["shoulder"]), ARMS[arm]["radii"][0] * 1.08))
        parts.append(Sphere(m(LEG["hip"]), 0.045))
    for i in range(17):
        z = 0.95 + i * 0.03
        y = 0.095 + 0.012 * math.sin((z - 0.95) / 0.5 * math.pi)
        parts.append(Sphere((0, y, z), 0.011))  # the spine, knot by knot
    body = Union(parts, k=0.03)

    def ribs(p):
        # ribs show through on the flanks of the chest
        q = p - v3(0, 0.038, 1.29)
        band = np.clip(1.0 - (q[:, 2] / 0.13) ** 2, 0.0, 1.0) * np.clip(np.abs(q[:, 0]) / 0.06, 0.0, 1.0)
        wave = np.sin((q[:, 2] - 0.18 * q[:, 0] ** 2 / 0.01) * (2 * math.pi / 0.026))
        return -0.0022 * band * np.maximum(wave, 0.0) ** 2

    knot = skin_noise(0.0016, 40.0, 3, 3)
    return Displace(body, lambda p: ribs(p) + knot(p), 0.004)


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


def head_local_node():
    def both(make):
        return [make("L"), make("R")]

    cranium = Ellipsoid((0, 0.02, 0.024), (0.064, 0.088, 0.08))
    face = Ellipsoid((0, -0.026, -0.006), (0.061, 0.068, 0.09))
    brows = []
    cheeks = both(lambda s: Ellipsoid(mirror((0.048, -0.058, -0.02), s), (0.012, 0.022, 0.011)))
    arches = []
    maxilla = Ellipsoid((0, -0.067, -0.05), (0.035, 0.034, 0.022))
    lower = Union([Ellipsoid((0, -0.038, -0.088), (0.046, 0.058, 0.058)),
                   RoundCone((0, -0.04, -0.09), (0, -0.06, -0.14), 0.044, 0.026)], k=0.02)
    jaw = []
    for s in "LR":
        h = mirror((0.048, 0.0, -0.04), s)
        a = mirror((0.041, -0.034, -0.108), s)
        c = mirror((0.02, -0.076, -0.15), s)
        jaw += [RoundCone(h, a, 0.0105, 0.011), RoundCone(a, c, 0.011, 0.0105), RoundCone(c, (0, -0.082, -0.157), 0.0105, 0.011)]
    chin = Ellipsoid((0, -0.079, -0.152), (0.018, 0.016, 0.014))
    bridge = RoundCone((0, -0.093, 0.014), (0, -0.098, -0.03), 0.0042, 0.0038)
    neck = RoundCone((0, 0.03, -0.05), (0, 0.065, -0.15), 0.034, 0.033)

    skull = Union([cranium, face, maxilla, lower], k=0.022)
    bones_ = Union([skull] + cheeks, k=0.02)
    bones_ = Union([bones_] + jaw + [chin], k=0.014)
    bones_ = Union([bones_, neck], k=0.025)

    cuts = []
    sockets = Union(both(lambda s: Ellipsoid(mirror((0.03, -0.08, 0.012), s), (0.0245, 0.032, 0.0255))))
    cuts.append((sockets, 0.006))
    temples = Union(both(lambda s: Sphere(mirror((0.066, -0.03, 0.018), s), 0.018)))
    cuts.append((temples, 0.025))
    hollows = Union(both(lambda s: Ellipsoid(mirror((0.046, -0.074, -0.068), s), (0.014, 0.022, 0.036))))
    cuts.append((hollows, 0.015))
    mouth = Union([Ellipsoid((0, -0.097, -0.076), (0.038, 0.055, 0.04)),
                   Ellipsoid((0, -0.097, -0.106), (0.029, 0.053, 0.04)),
                   RoundCone((0, -0.06, -0.09), (0, 0.012, -0.104), 0.026, 0.017)], k=0.012)
    cuts.append((mouth, 0.007))
    # the nose is a skull's: a tall dark hole either side of a thin bridge
    nasal = Union(both(lambda s: RoundCone(mirror((0.0072, -0.098, 0.006), s), mirror((0.0105, -0.106, -0.034), s), 0.0036, 0.0066))
                  + [Ellipsoid((0, -0.104, -0.036), (0.013, 0.012, 0.007))], k=0.004)
    cuts.append((nasal, 0.003))
    node = bones_
    for c, k in cuts:
        node = Subtract(node, c, k)
    node = Union([node, bridge], k=0.003)

    def grooves(p):
        # the skin of the cheeks dragged into vertical cords by the open jaw
        x, y, z = p[:, 0], p[:, 1], p[:, 2]
        mask = np.clip((-y - 0.025) / 0.03, 0.0, 1.0) * np.clip((-0.005 - z) / 0.025, 0.0, 1.0)
        mask *= np.clip(1.0 - np.abs(z + 0.09) / 0.085, 0.0, 1.0)
        streak = sdf.fbm(p, 1.0, 3, 41, scale=(190.0, 120.0, 11.0))
        return 0.0017 * mask * np.abs(streak) - 0.0005 * mask

    skin = skin_noise(0.0003, 300.0, 5, 3)
    return Displace(node, lambda p: grooves(p) + skin(p), 0.0022), dict(
        sockets=sockets, mouth=mouth, nasal=nasal, bone=node)


def head_node():
    local, feats = head_local_node()
    return HeadLocal(local, HEAD_CENTER), feats


# ---------------------------------------------------------------- teeth

def teeth_layout():
    """Needles along the upper and lower gums, in head-local coordinates:
    (root, direction, length, radius, upper?). Few, long and uneven: in the
    picture they read as lines drawn from lip to lip."""
    rng = np.random.default_rng(81)
    out = []
    for t in np.linspace(-0.9, 0.9, 7):
        x = 0.03 * t + rng.normal() * 0.0012
        root = v3(x, -0.099 + 0.026 * t * t, -0.044 - 0.014 * t * t)
        length = (0.05 - 0.02 * t * t) * (0.85 + 0.3 * rng.random())
        d = normalize(v3(-0.1 * t + rng.normal() * 0.05, 0.1 + rng.normal() * 0.04, -1.0))
        out.append((root, d, length, 0.0022 - 0.0004 * t * t, True))
    for t in np.linspace(-0.78, 0.78, 6):
        x = 0.029 * t + rng.normal() * 0.0012
        root = v3(x, -0.099 + 0.026 * t * t, -0.137 + 0.016 * t * t)
        length = (0.052 - 0.018 * t * t) * (0.85 + 0.3 * rng.random())
        d = normalize(v3(-0.08 * t + rng.normal() * 0.05, 0.12 + rng.normal() * 0.04, 1.0))
        out.append((root, d, length, 0.002 - 0.0003 * t * t, False))
    return out
