shader_type spatial;
// Blood on a surface, and in the air on its way to one (game/app/blood.gd):
// one stain of the atlas tools/textures/bake_blood.py draws, on a quad laid
// on whatever it hit. Lit by the room's lamps like anything else in it: in
// a dark room it is dark, and under a lamp it is the wettest thing there.
//
// Each instance says of itself (INSTANCE_CUSTOM): which stain of the atlas
// (r), the second of the blood's clock it lands at (g: before that there is
// nothing), how long it takes to run its length if it is a run down a wall
// (b: 0, it does not run) and how much of it the surface drinks (a: 0 a
// hard, shut surface -- it lies on it, beaded and shining; 1 carpet -- it
// is in it, flat and dull).
render_mode blend_mix, depth_draw_never, cull_back, shadows_disabled, world_vertex_coords;

uniform sampler2D atlas : filter_linear_mipmap, repeat_disable;
// The blood's own clock (seconds since the capture it came from began).
uniform float clock = 1000.0;
// What it is where it lies thin, and where it lies deep.
uniform vec3 film_color : source_color = vec3(0.34, 0.012, 0.008);
uniform vec3 deep_color : source_color = vec3(0.045, 0.002, 0.002);

varying float cell;
varying float born;
varying float run;
varying float soak;

void vertex() {
	cell = INSTANCE_CUSTOM.r;
	born = INSTANCE_CUSTOM.g;
	run = INSTANCE_CUSTOM.b;
	soak = INSTANCE_CUSTOM.a;
	// It lies on the surface, and the surface is drawn there too: brought a
	// hair towards the eye, more the further off it is seen from (a camcorder
	// on the floor sees a floor at a grazing angle, where a hair is nothing).
	vec3 to_eye = CAMERA_POSITION_WORLD - VERTEX;
	VERTEX += normalize(to_eye) * (0.002 + 0.0025 * length(to_eye));
}

void fragment() {
	float age = clock - born;
	if (age < 0.0) discard;
	float index = floor(cell + 0.5);
	vec2 inside = clamp(UV, 0.004, 0.996);
	vec4 stain = texture(atlas, (vec2(mod(index, 4.0), floor(index / 4.0)) + inside) * 0.25);
	float cover = stain.a;
	// It is there at once and spreads to its edge in a few frames; a run is
	// let down its length, and what is ahead of it is not there yet.
	cover *= smoothstep(0.0, 0.05, age + 0.02);
	if (run > 0.0) cover *= smoothstep(0.03, -0.03, UV.y - clamp(age / run, 0.0, 1.0));
	if (cover < 0.03) discard;
	float thick = stain.b;
	vec3 color = mix(film_color, deep_color, smoothstep(0.0, 0.55, thick));
	// Drunk by the carpet it is the carpet, wet: all of it as dark as the
	// deepest of it (a red carpet with blood in it is not redder, it is
	// blacker), no bead, and the dull shine of a pile that is soaked.
	ALBEDO = mix(color, deep_color, soak);
	ALPHA = cover * mix(mix(0.7, 0.97, smoothstep(0.0, 0.5, thick)), 0.9, soak);
	ROUGHNESS = mix(mix(0.2, 0.09, thick), 0.46, soak);
	SPECULAR = mix(0.6, 0.28, soak);
	NORMAL_MAP = vec3(stain.rg, 1.0);
	NORMAL_MAP_DEPTH = mix(1.4, 0.2, soak);
}
