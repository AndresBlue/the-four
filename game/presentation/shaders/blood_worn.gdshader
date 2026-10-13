shader_type spatial;
// Blood on whoever it came out of (game/player/avatars/avatar_visual.gd): a
// second pass over the clothes and the skin of a body the creature has run
// through, which draws nothing but what has soaked out round each wound --
// a stain that starts at the hole and grows, further down than up, because
// it runs.
//
// Each wound is given where it is in the world this frame and the frame of
// the bone it is in (so the stain's ragged edge is a matter of the body, and
// stays put on it however the body is thrown about), and how long ago it
// was made (under 0: not yet).
render_mode blend_mix, depth_draw_never, cull_back, shadows_disabled, world_vertex_coords;

uniform vec3 wound_at[2];
uniform mat3 wound_frame[2];
uniform float wound_age[2];
// How far it gets (metres) and how long it takes to.
uniform float reach = 0.17;
uniform float spread_time = 3.5;
uniform vec3 film_color : source_color = vec3(0.3, 0.012, 0.008);
uniform vec3 deep_color : source_color = vec3(0.05, 0.002, 0.002);

varying vec3 place;

void vertex() {
	place = VERTEX;
	// The same surface drawn again: a hair nearer, so it is over it.
	vec3 to_eye = CAMERA_POSITION_WORLD - VERTEX;
	VERTEX += normalize(to_eye) * 0.0015;
}

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1.0, 0.0, 0.0)), f.x), mix(hash(i + vec3(0.0, 1.0, 0.0)), hash(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(hash(i + vec3(0.0, 0.0, 1.0)), hash(i + vec3(1.0, 0.0, 1.0)), f.x), mix(hash(i + vec3(0.0, 1.0, 1.0)), hash(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}

void fragment() {
	float soaked = 0.0;
	for (int index = 0; index < 2; index++) {
		if (wound_age[index] < 0.0) continue;
		vec3 from = wound_frame[index] * (place - wound_at[index]);
		// Further down the body than up it or across it.
		from.y *= from.y < 0.0 ? 0.5 : 1.5;
		float grown = reach * (0.25 + 0.75 * pow(clamp(wound_age[index] / spread_time, 0.0, 1.0), 0.5));
		float ragged = (noise(from * 34.0) - 0.5) * 0.05 + (noise(from * 90.0) - 0.5) * 0.02;
		soaked = max(soaked, smoothstep(grown, grown * 0.55, length(from) + ragged));
	}
	if (soaked < 0.03) discard;
	ALBEDO = mix(film_color, deep_color, smoothstep(0.2, 0.9, soaked));
	ALPHA = soaked * 0.94;
	ROUGHNESS = mix(0.5, 0.22, soaked);
	SPECULAR = 0.45;
}
