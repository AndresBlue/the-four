shader_type spatial;
// The pool under a body (game/app/blood.gd): one quad on the floor, and on it
// what has run out of somebody since they were let fall -- spreading fast at
// first and ever slower (its radius goes with the cube root of the time, as
// that of a thick liquid let out on a level floor does), ragged where the
// floor is not quite level, held back by whatever stands in its way (`reach`,
// sixteen ways round it: it does not go under a wall into the next room), and
// with the edge every liquid that wets a floor has: a bead, standing.
//
// On a hard floor it is a mirror of whatever lamp is over it. On carpet
// (`soak` 1) there is no pool: the pile takes it, and what is left is a dark,
// wet patch, two thirds the size, shining most where it is still coming.
render_mode blend_mix, depth_draw_never, cull_back, shadows_disabled, world_vertex_coords;

// Seconds since it began to form; under 0 there is none.
uniform float age = 1000.0;
// How wide the quad is (metres) and how far the pool gets in the end.
uniform float span = 1.5;
uniform float radius = 0.42;
// How long it takes to be as wide as it gets.
uniform float spread_time = 30.0;
// How far it can go each way before something stops it, from +x round to +z.
uniform float reach[16];
uniform float soak = 0.0;
uniform float seed = 0.0;
uniform vec3 film_color : source_color = vec3(0.34, 0.012, 0.008);
uniform vec3 deep_color : source_color = vec3(0.045, 0.002, 0.002);

void vertex() {
	vec3 to_eye = CAMERA_POSITION_WORLD - VERTEX;
	VERTEX += normalize(to_eye) * (0.002 + 0.0025 * length(to_eye));
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// How far inside the pool's edge a point is (metres; under 0, outside it).
float depth_at(vec2 p, float grown) {
	float around = atan(p.y, p.x) / TAU;
	float slot = fract(around + 1.0) * 16.0;
	int first = int(floor(slot)) % 16;
	int next = (first + 1) % 16;
	float held = mix(reach[first], reach[next], fract(slot));
	vec2 way = length(p) > 0.0001 ? normalize(p) : vec2(1.0, 0.0);
	// Lobes: it goes further where the floor falls away, and that is not the
	// same all round.
	float lobes = 0.72 + 0.5 * noise(way * 1.6 + seed) + 0.16 * noise(way * 4.3 + seed * 1.7);
	float edge = min(grown * lobes, held - 0.015);
	float ragged = (noise(p * 17.0 + seed) - 0.5) * mix(0.02, 0.045, soak) + (noise(p * 70.0 + seed) - 0.5) * 0.02 * soak;
	return edge - length(p) + ragged;
}

void fragment() {
	if (age < 0.0) discard;
	float grown = radius * mix(1.0, 0.7, soak) * pow(clamp(age / spread_time, 0.0, 1.0), 0.3333);
	vec2 p = (UV - 0.5) * span;
	float inside = depth_at(p, grown);
	float cover = smoothstep(0.0, mix(0.008, 0.03, soak), inside);
	if (cover < 0.02) discard;
	// Shallow at its edge and deep towards its middle, with the bead along
	// the edge; and the slope of that is what the lamps catch.
	float step_size = 0.004;
	float here = smoothstep(0.0, 0.07, inside) * 0.8 + exp(-pow((inside - 0.014) / 0.009, 2.0)) * 0.35 * (1.0 - soak);
	float beside = depth_at(p + vec2(step_size, 0.0), grown);
	float beyond = depth_at(p + vec2(0.0, step_size), grown);
	float there_x = smoothstep(0.0, 0.07, beside) * 0.8 + exp(-pow((beside - 0.014) / 0.009, 2.0)) * 0.35 * (1.0 - soak);
	float there_z = smoothstep(0.0, 0.07, beyond) * 0.8 + exp(-pow((beyond - 0.014) / 0.009, 2.0)) * 0.35 * (1.0 - soak);
	vec2 slope = vec2(there_x - here, there_z - here) / step_size * 0.012;
	NORMAL_MAP = vec3(clamp(0.5 - slope.x, 0.0, 1.0), clamp(0.5 - slope.y, 0.0, 1.0), 1.0);
	NORMAL_MAP_DEPTH = mix(1.0, 0.2, soak);
	// Still coming at its middle for as long as it spreads: there the carpet
	// has more than it can take, and it shines.
	float fresh = (1.0 - smoothstep(0.0, 0.5, length(p) / max(grown, 0.001))) * (1.0 - clamp(age / (spread_time * 1.5), 0.0, 1.0));
	float dull = soak * (1.0 - 0.75 * fresh);
	ALBEDO = mix(mix(film_color, deep_color, smoothstep(0.0, 0.45, here)), deep_color, soak);
	ALPHA = cover * mix(mix(0.75, 0.98, smoothstep(0.0, 0.4, here)), 0.92, soak);
	ROUGHNESS = mix(0.07, mix(0.3, 0.46, dull), soak);
	SPECULAR = mix(0.6, 0.28, soak);
}
