"""Signed distance fields in numpy, and the surface nets that turn them into a mesh.

The creature is sculpted as distance fields (negative inside): round cones for
bones and fingers, ellipsoids for the skull, smooth unions so a finger grows out
of the palm instead of being stuck on it, smooth subtractions for sockets and
mouth, and noise for the skin. Each part is sampled on its own grid and meshed
with naive surface nets, one quad per grid edge that crosses the surface.

Pure numpy: it runs inside Blender's Python and outside it.
"""

import math

import numpy as np

BIG = 1.0e3


# ---------------------------------------------------------------- small maths

def v3(x, y=None, z=None):
    if y is None:
        return np.asarray(x, dtype=np.float64)
    return np.array([x, y, z], dtype=np.float64)


def normalize(v):
    v = np.asarray(v, dtype=np.float64)
    n = np.linalg.norm(v)
    return v / n if n > 1e-12 else v


def smin(a, b, k):
    """Polynomial smooth minimum: a union whose seam is rounded over k metres."""
    if k <= 0.0:
        return np.minimum(a, b)
    h = np.maximum(k - np.abs(a - b), 0.0) / k
    return np.minimum(a, b) - h * h * k * 0.25


def smax(a, b, k):
    return -smin(-a, -b, k)


def rotation_to(frame_x, frame_y, frame_z):
    """Rows are the local axes expressed in world space."""
    return np.array([normalize(frame_x), normalize(frame_y), normalize(frame_z)])


# ---------------------------------------------------------------- noise

def _hash(ix, iy, iz, seed):
    n = (ix * 374761393 + iy * 668265263 + iz * 1274126177 + seed * 144665) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    n = n ^ (n >> 16)
    return (n & 0xFFFF).astype(np.float64) / 32767.5 - 1.0


def value_noise(p, seed=0):
    """Smooth value noise in [-1, 1] for points p (N, 3)."""
    pi = np.floor(p).astype(np.int64)
    pf = p - pi
    w = pf * pf * (3.0 - 2.0 * pf)
    x0, y0, z0 = pi[:, 0], pi[:, 1], pi[:, 2]
    x1, y1, z1 = x0 + 1, y0 + 1, z0 + 1
    wx, wy, wz = w[:, 0], w[:, 1], w[:, 2]
    c000 = _hash(x0, y0, z0, seed)
    c100 = _hash(x1, y0, z0, seed)
    c010 = _hash(x0, y1, z0, seed)
    c110 = _hash(x1, y1, z0, seed)
    c001 = _hash(x0, y0, z1, seed)
    c101 = _hash(x1, y0, z1, seed)
    c011 = _hash(x0, y1, z1, seed)
    c111 = _hash(x1, y1, z1, seed)
    x00 = c000 + (c100 - c000) * wx
    x10 = c010 + (c110 - c010) * wx
    x01 = c001 + (c101 - c001) * wx
    x11 = c011 + (c111 - c011) * wx
    y0_ = x00 + (x10 - x00) * wy
    y1_ = x01 + (x11 - x01) * wy
    return y0_ + (y1_ - y0_) * wz


def fbm(p, freq, octaves=3, seed=0, gain=0.5, scale=None):
    """Fractal noise. scale stretches the lattice per axis (anisotropic grain)."""
    q = p * freq
    if scale is not None:
        q = q * np.asarray(scale, dtype=np.float64)
    total = np.zeros(len(p))
    amp = 1.0
    norm = 0.0
    for o in range(octaves):
        total += amp * value_noise(q, seed + 17 * o)
        norm += amp
        amp *= gain
        q = q * 2.03
    return total / norm


# ---------------------------------------------------------------- nodes

class Node:
    """A distance field with a bounding box. eval returns None when the box is
    outside the block being sampled, which a union reads as 'nothing here'."""

    lo = None
    hi = None

    def touches(self, lo, hi):
        return bool(np.all(self.hi >= lo) and np.all(self.lo <= hi))

    def eval(self, p, lo=None, hi=None):
        if lo is not None and not self.touches(lo, hi):
            return None
        return self._eval(p, lo, hi)

    def full(self, p):
        d = self.eval(p)
        return np.full(len(p), BIG) if d is None else d


class Sphere(Node):
    def __init__(self, c, r):
        self.c = v3(c)
        self.r = float(r)
        self.lo = self.c - self.r
        self.hi = self.c + self.r

    def _eval(self, p, lo, hi):
        return np.linalg.norm(p - self.c, axis=1) - self.r


class Ellipsoid(Node):
    """Axis radii r in a frame whose rows are rot (world directions)."""

    def __init__(self, c, r, rot=None):
        self.c = v3(c)
        self.r = v3(r)
        self.rot = np.eye(3) if rot is None else np.asarray(rot, dtype=np.float64)
        m = float(np.max(self.r))
        self.lo = self.c - m
        self.hi = self.c + m

    def _eval(self, p, lo, hi):
        q = (p - self.c) @ self.rot.T
        k0 = np.linalg.norm(q / self.r, axis=1)
        k1 = np.linalg.norm(q / (self.r * self.r), axis=1)
        return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)


class RoundCone(Node):
    """A capsule whose radius goes from ra at a to rb at b (exact, after iq)."""

    def __init__(self, a, b, ra, rb=None):
        self.a = v3(a)
        self.b = v3(b)
        self.ra = float(ra)
        self.rb = float(ra if rb is None else rb)
        m = max(self.ra, self.rb)
        self.lo = np.minimum(self.a, self.b) - m
        self.hi = np.maximum(self.a, self.b) + m

    def _eval(self, p, lo, hi):
        a, b, r1, r2 = self.a, self.b, self.ra, self.rb
        ba = b - a
        l2 = float(ba @ ba)
        if l2 < 1e-12:
            return np.linalg.norm(p - a, axis=1) - max(r1, r2)
        rr = r1 - r2
        a2 = l2 - rr * rr
        il2 = 1.0 / l2
        pa = p - a
        y = pa @ ba
        z = y - l2
        xv = pa * l2 - np.outer(y, ba)
        x2 = np.einsum("ij,ij->i", xv, xv)
        y2 = y * y * l2
        z2 = z * z * l2
        k = math.copysign(1.0, rr) * rr * rr * x2
        d_tip = np.sqrt(x2 + z2) * il2 - r2
        d_base = np.sqrt(x2 + y2) * il2 - r1
        d_side = (np.sqrt(np.maximum(x2 * a2 * il2, 0.0)) + y * rr) * il2 - r1
        out = np.where(np.sign(y) * a2 * y2 < k, d_base, d_side)
        out = np.where(np.sign(z) * a2 * z2 > k, d_tip, out)
        return out


class Torus(Node):
    """A ring of radius `major` and thickness `minor` round `axis` at c."""

    def __init__(self, c, axis, major, minor):
        self.c = v3(c)
        self.axis = normalize(axis)
        self.major = float(major)
        self.minor = float(minor)
        m = self.major + self.minor
        self.lo = self.c - m
        self.hi = self.c + m

    def _eval(self, p, lo, hi):
        q = p - self.c
        h = q @ self.axis
        r = np.linalg.norm(q - np.outer(h, self.axis), axis=1)
        return np.sqrt((r - self.major) ** 2 + h * h) - self.minor


def sd_triangle2(p, a, b, c):
    """Exact distance to a 2-D triangle (after iq), points p (N, 2)."""
    a, b, c = (np.asarray(v, dtype=np.float64) for v in (a, b, c))
    e0, e1, e2 = b - a, c - b, a - c
    v0, v1, v2 = p - a, p - b, p - c

    def seg(v, e):
        t = np.clip((v @ e) / (e @ e), 0.0, 1.0)
        q = v - np.outer(t, e)
        return np.einsum("ij,ij->i", q, q)

    s = math.copysign(1.0, e0[0] * e2[1] - e0[1] * e2[0])
    dx = np.minimum(np.minimum(seg(v0, e0), seg(v1, e1)), seg(v2, e2))
    dy = np.minimum(np.minimum(s * (v0[:, 0] * e0[1] - v0[:, 1] * e0[0]),
                               s * (v1[:, 0] * e1[1] - v1[:, 1] * e1[0])),
                    s * (v2[:, 0] * e2[1] - v2[:, 1] * e2[0]))
    return -np.sqrt(dx) * np.sign(dy)


class TriPrism(Node):
    """A triangle drawn in the x-z plane (front view), rounded by `round` and
    pushed through y from y0 to y1."""

    def __init__(self, a, b, c, y0, y1, round=0.0):
        self.tri = [np.asarray(v, dtype=np.float64) for v in (a, b, c)]
        self.yc = 0.5 * (y0 + y1)
        self.h = 0.5 * abs(y1 - y0)
        self.round = float(round)
        xs = [v[0] for v in self.tri]
        zs = [v[1] for v in self.tri]
        self.lo = v3(min(xs) - self.round, min(y0, y1) - self.round, min(zs) - self.round)
        self.hi = v3(max(xs) + self.round, max(y0, y1) + self.round, max(zs) + self.round)

    def _eval(self, p, lo, hi):
        d2 = sd_triangle2(p[:, [0, 2]], *self.tri)
        wy = np.abs(p[:, 1] - self.yc) - self.h
        wx = d2
        inside = np.minimum(np.maximum(wx, wy), 0.0)
        outside = np.sqrt(np.maximum(wx, 0.0) ** 2 + np.maximum(wy, 0.0) ** 2)
        return inside + outside - self.round


class Union(Node):
    def __init__(self, children, k=0.0):
        self.children = [c for c in children if c is not None]
        self.k = float(k)
        self.lo = np.min([c.lo for c in self.children], axis=0) - self.k
        self.hi = np.max([c.hi for c in self.children], axis=0) + self.k

    def _eval(self, p, lo, hi):
        d = None
        for c in self.children:
            e = c.eval(p, lo, hi)
            if e is None:
                continue
            d = e if d is None else smin(d, e, self.k)
        return d


class Subtract(Node):
    """a minus b, with the cut's lip rounded over k."""

    def __init__(self, a, b, k=0.0):
        self.a = a
        self.b = b
        self.k = float(k)
        self.lo = a.lo
        self.hi = a.hi

    def _eval(self, p, lo, hi):
        d = self.a.eval(p, lo, hi)
        if d is None:
            return None
        e = self.b.eval(p, lo, hi)
        if e is None:
            return d
        return smax(d, -e, self.k)


class Intersect(Node):
    def __init__(self, a, b, k=0.0):
        self.a = a
        self.b = b
        self.k = float(k)
        self.lo = np.maximum(a.lo, b.lo)
        self.hi = np.minimum(a.hi, b.hi)

    def _eval(self, p, lo, hi):
        d = self.a.eval(p, lo, hi)
        e = self.b.eval(p, lo, hi)
        if d is None or e is None:
            return None
        return smax(d, e, self.k)


class Displace(Node):
    """Adds fn(p) to the child's distance (negative fn swells it). amp bounds |fn|."""

    def __init__(self, child, fn, amp):
        self.child = child
        self.fn = fn
        self.amp = float(amp)
        self.lo = child.lo - self.amp
        self.hi = child.hi + self.amp

    def _eval(self, p, lo, hi):
        d = self.child.eval(p, lo, hi)
        if d is None:
            return None
        # only near the surface: far away the sign is all that matters
        near = np.abs(d) < self.amp * 2.0 + 0.004
        if np.any(near):
            d = d.copy()
            d[near] += self.fn(p[near])
        return d


class Warp(Node):
    """The child seen through a slow, small distortion of space: an outline
    that wobbles the way a hand-drawn one does. amp bounds the shift."""

    def __init__(self, child, amp, freq, seed=0):
        self.child = child
        self.amp = float(amp)
        self.freq = float(freq)
        self.seed = seed
        self.lo = child.lo - self.amp
        self.hi = child.hi + self.amp

    def _eval(self, p, lo, hi):
        if lo is not None:
            lo = lo - self.amp
            hi = hi + self.amp
        shift = np.stack([fbm(p, self.freq, 2, self.seed + k * 31) for k in range(3)], axis=1) * self.amp
        return self.child.eval(p + shift, lo, hi)


class Shell(Node):
    """Any callable field, bounded by a box."""

    def __init__(self, fn, lo, hi):
        self.fn = fn
        self.lo = v3(lo)
        self.hi = v3(hi)

    def _eval(self, p, lo, hi):
        return self.fn(p)


# ---------------------------------------------------------------- sampling

def sample_grid(node, lo, hi, h, block=40, pad=None):
    """Samples node on a regular grid covering [lo, hi] with spacing h."""
    lo = v3(lo)
    hi = v3(hi)
    if pad is None:
        pad = 2.0 * h
    lo = lo - pad
    hi = hi + pad
    shape = np.maximum(np.ceil((hi - lo) / h).astype(int) + 1, 2)
    F = np.full(tuple(shape), BIG, dtype=np.float32)
    nx, ny, nz = shape
    for i0 in range(0, nx, block):
        i1 = min(i0 + block, nx)
        for j0 in range(0, ny, block):
            j1 = min(j0 + block, ny)
            for k0 in range(0, nz, block):
                k1 = min(k0 + block, nz)
                blo = lo + h * np.array([i0, j0, k0])
                bhi = lo + h * np.array([i1 - 1, j1 - 1, k1 - 1])
                if not node.touches(blo - h, bhi + h):
                    continue
                ii, jj, kk = np.meshgrid(np.arange(i0, i1), np.arange(j0, j1), np.arange(k0, k1), indexing="ij")
                p = lo + h * np.stack([ii.ravel(), jj.ravel(), kk.ravel()], axis=1)
                d = node.eval(p, blo - h, bhi + h)
                if d is None:
                    continue
                F[i0:i1, j0:j1, k0:k1] = d.reshape(ii.shape)
    return F, lo


_CORNERS = np.array([
    (0, 0, 0), (1, 0, 0), (0, 1, 0), (1, 1, 0),
    (0, 0, 1), (1, 0, 1), (0, 1, 1), (1, 1, 1),
])
_EDGES = [
    (0, 1), (2, 3), (4, 5), (6, 7),
    (0, 2), (1, 3), (4, 6), (5, 7),
    (0, 4), (1, 5), (2, 6), (3, 7),
]


def surface_nets(F, origin, h):
    """Quad mesh of the zero level of F (negative inside), outward normals."""
    s = F < 0.0
    nx, ny, nz = F.shape
    cnt = np.zeros((nx - 1, ny - 1, nz - 1), dtype=np.int8)
    for dx, dy, dz in _CORNERS:
        cnt += s[dx:nx - 1 + dx, dy:ny - 1 + dy, dz:nz - 1 + dz]
    active = (cnt > 0) & (cnt < 8)
    ci = np.argwhere(active)
    m = len(ci)
    if m == 0:
        return np.zeros((0, 3)), np.zeros((0, 4), dtype=np.int64)
    vals = np.empty((m, 8), dtype=np.float64)
    for n, (dx, dy, dz) in enumerate(_CORNERS):
        vals[:, n] = F[ci[:, 0] + dx, ci[:, 1] + dy, ci[:, 2] + dz]
    acc = np.zeros((m, 3))
    num = np.zeros(m)
    for a, b in _EDGES:
        va = vals[:, a]
        vb = vals[:, b]
        cross = (va < 0.0) != (vb < 0.0)
        denom = np.where(cross, va - vb, 1.0)
        t = np.clip(np.where(cross, va / denom, 0.0), 0.0, 1.0)
        pos = _CORNERS[a][None, :] + t[:, None] * (_CORNERS[b] - _CORNERS[a])[None, :]
        acc += np.where(cross[:, None], pos, 0.0)
        num += cross
    verts = origin + h * (ci + acc / np.maximum(num, 1)[:, None])
    vid = np.full(active.shape, -1, dtype=np.int64)
    vid[active] = np.arange(m)

    quads = []
    # x edges
    e = s[:-1, 1:-1, 1:-1] != s[1:, 1:-1, 1:-1]
    i, j, k = np.nonzero(e)
    j = j + 1
    k = k + 1
    inside_low = s[i, j, k]
    q = np.stack([vid[i, j - 1, k - 1], vid[i, j, k - 1], vid[i, j, k], vid[i, j - 1, k]], axis=1)
    q[~inside_low] = q[~inside_low][:, ::-1]
    quads.append(q)
    # y edges
    e = s[1:-1, :-1, 1:-1] != s[1:-1, 1:, 1:-1]
    i, j, k = np.nonzero(e)
    i = i + 1
    k = k + 1
    inside_low = s[i, j, k]
    q = np.stack([vid[i - 1, j, k - 1], vid[i - 1, j, k], vid[i, j, k], vid[i, j, k - 1]], axis=1)
    q[~inside_low] = q[~inside_low][:, ::-1]
    quads.append(q)
    # z edges
    e = s[1:-1, 1:-1, :-1] != s[1:-1, 1:-1, 1:]
    i, j, k = np.nonzero(e)
    i = i + 1
    j = j + 1
    inside_low = s[i, j, k]
    q = np.stack([vid[i - 1, j - 1, k], vid[i, j - 1, k], vid[i, j, k], vid[i - 1, j, k]], axis=1)
    q[~inside_low] = q[~inside_low][:, ::-1]
    quads.append(q)
    quads = np.concatenate(quads, axis=0)
    return verts, quads


def gradient(node, p, eps=2.5e-4):
    g = np.zeros_like(p)
    for axis in range(3):
        d = np.zeros(3)
        d[axis] = eps
        g[:, axis] = (node.full(p + d) - node.full(p - d)) / (2.0 * eps)
    return g


def project(node, verts, h, iterations=2):
    """Pulls the surface-net vertices onto the true zero level."""
    p = verts.copy()
    for _ in range(iterations):
        d = node.full(p)
        g = gradient(node, p, eps=h * 0.25)
        gl2 = np.maximum(np.einsum("ij,ij->i", g, g), 1e-12)
        step = (d / gl2)[:, None] * g
        sl = np.linalg.norm(step, axis=1)
        clamp = np.minimum(1.0, (0.75 * h) / np.maximum(sl, 1e-12))
        p -= step * clamp[:, None]
    return p


def largest_component(verts, quads):
    """Drops floating crumbs: keeps components with at least 2 % of the faces."""
    n = len(verts)
    parent = np.arange(n)

    def find(x):
        root = x
        while parent[root] != root:
            root = parent[root]
        while parent[x] != root:
            nxt = parent[x]
            parent[x] = root
            x = nxt
        return root

    for q in quads:
        r0 = find(q[0])
        for v in q[1:]:
            r = find(v)
            if r != r0:
                parent[r] = r0
    roots = np.array([find(v) for v in range(n)])
    face_roots = roots[quads[:, 0]]
    uniq, counts = np.unique(face_roots, return_counts=True)
    keep_roots = set(uniq[counts >= max(1, int(0.02 * len(quads)))].tolist())
    keep_faces = np.array([r in keep_roots for r in face_roots])
    quads = quads[keep_faces]
    used = np.unique(quads)
    remap = np.full(n, -1, dtype=np.int64)
    remap[used] = np.arange(len(used))
    return verts[used], remap[quads]


def mesh_node(node, h, lo=None, hi=None, iterations=2, keep_largest=True):
    lo = node.lo if lo is None else v3(lo)
    hi = node.hi if hi is None else v3(hi)
    F, origin = sample_grid(node, lo, hi, h)
    verts, quads = surface_nets(F, origin, h)
    if len(verts) == 0:
        return verts, quads
    if keep_largest:
        verts, quads = largest_component(verts, quads)
    verts = project(node, verts, h, iterations)
    return verts, quads


def ambient_occlusion(node, p, n, step=0.004, samples=5, strength=1.0):
    """The usual distance-field occlusion: how much closer the field gets than
    expected when stepping out along the normal. 1 open, 0 buried."""
    occ = np.zeros(len(p))
    w = 1.0
    for i in range(1, samples + 1):
        dist = step * i
        d = node.full(p + n * dist)
        occ += w * np.maximum(dist - d, 0.0) / dist
        w *= 0.6
    return np.clip(1.0 - strength * occ / 2.0, 0.0, 1.0)
