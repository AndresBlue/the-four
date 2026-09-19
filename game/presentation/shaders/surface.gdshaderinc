// Shared helpers for architecture/prop surfaces built from scaled unit boxes.
// Boxes carry no meaningful UVs, so every surface is mapped from world space
// using the dominant face axis (all hotel geometry is axis aligned).
// Optional image maps replace the procedural base when a material enables
// the matching use_* flag; procedural wear is still layered on top.

varying vec3 wp;
varying vec3 wn;
// The room a batched surface belongs to, from its instance's custom data
// (hotel_geometry.flush()): half its width and depth round the room's origin,
// its ceiling height, and which sides are open (a hall goes on past them:
// 1 -x, 2 +x, 4 -z, 8 +z). Zero outside a room: no grime.
varying flat vec4 room_data;

// Usage inside vertex(): SURFACE_VERTEX;
#define SURFACE_VERTEX wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); room_data = INSTANCE_CUSTOM

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

// Detail of every procedural surface, set by the graphics preset
// (graphics_presets.gd surface_detail; declared in project.godot): how many
// of fbm's four octaves are worked out, and under 2.5 the finest terms go too.
global uniform float surface_detail;

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	int octaves = clamp(int(surface_detail), 1, 4);
	for (int i = 0; i < octaves; i++) {
		value += vnoise(p) * amplitude;
		p = p * 2.03 + vec2(17.1, 9.2);
		amplitude *= 0.5;
	}
	// Octaves left out add their mean, so the pattern keeps its level and only
	// loses its finest grain.
	for (int i = octaves; i < 4; i++) {
		value += 0.5 * amplitude;
		amplitude *= 0.5;
	}
	return value;
}

// The finest terms (carpet pile, paper fibre, wood pores, ceiling stipple):
// sub-pixel a few metres away, and aliasing grain at a low render scale. On a
// low surface_detail they are their mean.
float fine_noise(vec2 p) {
	if (surface_detail < 2.5) return 0.5;
	return vnoise(p);
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

// How much a point is tucked into its room's edges: 1 where two of the walls,
// floor and ceiling meet, 0 in the open. The two nearest of them count: on a
// wall, the floor, the ceiling or the next wall; on the floor, the nearest
// wall. Dust, soot and the missing bounce light gather there.
float room_edge(vec3 world, vec3 origin, out float by_floor, out float by_ceiling) {
	by_floor = 0.0;
	by_ceiling = 0.0;
	if (room_data.z <= 0.0) return 0.0;
	vec3 p = world - origin;
	float open = room_data.w + 0.5;
	// An open side is no wall: far away.
	vec4 far = step(vec4(1.0), mod(floor(vec4(open, open / 2.0, open / 4.0, open / 8.0)), 2.0)) * 10000.0;
	// Wall faces stand some 10-15 cm inside the rectangle (half core, panels).
	float wx = max(min(p.x + room_data.x + far.x, room_data.x + far.y - p.x) - 0.12, 0.0);
	float wz = max(min(p.z + room_data.y + far.z, room_data.y + far.w - p.z) - 0.12, 0.0);
	float h = max(p.y, 0.0);
	float t = max(room_data.z - p.y, 0.0);
	float v = min(h, t);
	float nearest = min(min(wx, wz), v);
	float two = wx + wz + v - max(max(wx, wz), v);
	float edge = exp(-two * 3.2) * smoothstep(0.4, 0.0, nearest);
	float wall = min(wx, wz);
	by_floor = exp(-(h + wall) * 6.0);
	by_ceiling = exp(-(t + wall) * 2.5) * step(t, h);
	return edge;
}

// Room grime on a surface's colour; the occlusion it adds (to AO) in ao.
vec3 room_grime(vec3 color, vec3 world, vec3 origin, inout float ao) {
	float by_floor;
	float by_ceiling;
	float edge = room_edge(world, origin, by_floor, by_ceiling);
	float patchy = 0.6 + 0.8 * vnoise(world.xz * 3.1 + world.y * 2.3);
	ao *= 1.0 - edge * 0.55;
	color *= 1.0 - edge * 0.22 * patchy;
	// Dust and mop water along the skirting, brown.
	color = mix(color, color * vec3(0.72, 0.62, 0.5), clamp(by_floor * patchy, 0.0, 1.0) * 0.5);
	// Old damp and smoke under the ceiling, yellowed.
	color = mix(color, color * vec3(0.86, 0.78, 0.6), clamp(by_ceiling * patchy, 0.0, 1.0) * 0.45);
	return color;
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
