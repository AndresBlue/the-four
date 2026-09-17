// Shared helpers for architecture/prop surfaces built from scaled unit boxes.
// Boxes carry no meaningful UVs, so every surface is mapped from world space
// using the dominant face axis (all hotel geometry is axis aligned).
// Optional image maps replace the procedural base when a material enables
// the matching use_* flag; procedural wear is still layered on top.

varying vec3 wp;
varying vec3 wn;

// Usage inside vertex(): SURFACE_VERTEX;
#define SURFACE_VERTEX wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz)

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		value += vnoise(p) * amplitude;
		p = p * 2.03 + vec2(17.1, 9.2);
		amplitude *= 0.5;
	}
	return value;
}

// Face-aligned coordinates in metres, oriented so that the image "up" points
// up on walls and the tangent frame stays right handed on mirrored faces.
vec2 face_uv() {
	vec3 a = abs(wn);
	if (a.y > a.x && a.y > a.z) return vec2(wp.x, wp.z * sign(wn.y));
	if (a.x > a.z) return vec2(-wp.z * sign(wn.x), -wp.y);
	return vec2(wp.x * sign(wn.z), -wp.y);
}

vec3 face_tangent() {
	vec3 a = abs(wn);
	if (a.y > a.x && a.y > a.z) return vec3(1.0, 0.0, 0.0);
	if (a.x > a.z) return vec3(0.0, 0.0, -sign(wn.x));
	return vec3(sign(wn.z), 0.0, 0.0);
}

vec3 face_bitangent() {
	vec3 a = abs(wn);
	if (a.y > a.x && a.y > a.z) return vec3(0.0, 0.0, -sign(wn.y));
	return vec3(0.0, 1.0, 0.0);
}

bool is_floor_face() { return wn.y > 0.5; }
bool is_ceiling_face() { return wn.y < -0.5; }

// Varies only with face orientation: continuous across a whole plane, so
// blemishes never show rectangular cuts where boxes or cells meet.
float plane_offset() {
	return dot(sign(wn) * step(0.5, abs(wn)), vec3(0.37, 0.71, 0.13));
}

// OpenGL-convention tangent-space normal (0..1 encoded) -> world normal.
// Z is rebuilt because imported normal maps may be stored as two channels.
vec3 map_normal_world(vec4 encoded, float strength) {
	vec2 xy = encoded.xy * 2.0 - 1.0;
	float z = sqrt(clamp(1.0 - dot(xy, xy), 0.0, 1.0));
	xy *= strength;
	return normalize(face_tangent() * xy.x + face_bitangent() * xy.y + wn * max(z, 0.05));
}

// Perturbs a world normal from screen derivatives of a height field
// (surface gradient). Derivatives are taken by the caller in fragment().
vec3 bump_world(vec3 base, vec3 dpdx, vec3 dpdy, float dhdx, float dhdy, float strength) {
	vec3 r1 = cross(dpdy, base);
	vec3 r2 = cross(base, dpdx);
	float det = dot(dpdx, r1);
	if (abs(det) < 1e-8) return base;
	vec3 grad = sign(det) * (dhdx * r1 + dhdy * r2) * strength;
	return normalize(abs(det) * base - grad);
}

// Usage inside fragment(), with a world normal N and height H:
//   NORMAL = BUMPED_VIEW_NORMAL(N, H, strength);
#define BUMPED_VIEW_NORMAL(N, H, S) normalize((VIEW_MATRIX * vec4(bump_world(N, dFdx(wp), dFdy(wp), dFdx(H), dFdy(H), S), 0.0)).xyz)
