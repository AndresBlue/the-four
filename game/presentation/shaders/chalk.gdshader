shader_type spatial;
// A mark in chalk on a wall (hint_placement.gd, the trail): an arrow along
// the quad's x, or a cross beside a door. Dry and white, rough as the
// plaster it is on, worn where the stick skipped; lit by the room like
// anything else, so a dark corridor keeps it until a torch finds it.
render_mode blend_mix, depth_draw_opaque, cull_back, shadows_disabled;

uniform bool cross_mark = false;
// The quad is laid right-handed on the wall; the arrow points the other way
// along it when the trail does.
uniform bool flip = false;
uniform float seed = 0.0;

float grain(vec2 at) {
	return fract(sin(dot(at, vec2(12.9898, 78.233)) + seed) * 43758.5453);
}

// Distance from p to the segment a-b.
float segment(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

void fragment() {
	// The quad in its own proportions: x across it, y up.
	vec2 p = (UV - 0.5) * vec2(flip ? -2.0 : 2.0, -1.0);
	float d;
	if (cross_mark) {
		vec2 q = (UV - 0.5) * 2.0;
		d = min(segment(q, vec2(-0.7, -0.7), vec2(0.7, 0.75)), segment(q, vec2(-0.72, 0.68), vec2(0.66, -0.72)));
	} else {
		d = segment(p, vec2(-0.85, 0.02), vec2(0.8, -0.02));
		d = min(d, segment(p, vec2(0.82, -0.01), vec2(0.42, 0.34)));
		d = min(d, segment(p, vec2(0.82, -0.01), vec2(0.45, -0.36)));
	}
	float stroke = 1.0 - smoothstep(0.05, 0.11, d);
	// Where the chalk skipped on the plaster: a coarse grain across the line.
	float skip = grain(floor(UV * vec2(90.0, 46.0)));
	float worn = smoothstep(0.18, 0.55, skip);
	ALPHA = stroke * worn * 0.82;
	ALBEDO = vec3(0.86, 0.85, 0.8);
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
