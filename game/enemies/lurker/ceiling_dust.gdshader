// Dust in the air (ceiling_dust.gd): it is seen because it scatters the light
// that reaches it every way, not because a face of it turns to the lamp. So
// light() adds what arrives (with its shadows) without N.L: a mote shines as it
// drifts into a torch's beam or under a tube and is black out of it. Each speck
// is kept at least min_pixels wide on screen (a millimetre of dust is less than
// a pixel at 720p), its alpha thinned as it is grown so it does not swell into
// a ball; soft where it meets a surface, faded near the lens. Facing the camera,
// flat and turning (`billboard` off: the flakes of tile), or a streak along the
// way it moves (`axial`: the particle's Y follows its velocity), turned about
// that line to the eye, so a falling thread reads as a line and not as beads.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_lambert, specular_disabled;

uniform sampler2D shape : source_color, filter_linear_mipmap;
uniform bool billboard = true;
uniform bool axial = false;
// How much of the light reaching it it sends to the eye.
uniform float scatter = 1.0;
// The least width it is drawn at, in pixels of a 720-line picture.
uniform float min_pixels = 2.5;
// Its brightness flickering as it turns in the air (0: steady).
uniform float twinkle = 0.0;
uniform sampler2D depth_map : hint_depth_texture, repeat_disable, filter_nearest;

varying float thin;
varying float spark;

void vertex() {
	if (axial) {
		vec3 centre = MODEL_MATRIX[3].xyz;
		vec3 along = MODEL_MATRIX[1].xyz;
		vec3 side = cross(normalize(along), normalize(INV_VIEW_MATRIX[3].xyz - centre));
		side = length(side) > 1e-4 ? normalize(side) : normalize(MODEL_MATRIX[0].xyz);
		side *= length(MODEL_MATRIX[0].xyz);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(side, 0.0), vec4(along, 0.0), vec4(normalize(cross(side, along)), 0.0), vec4(centre, 1.0));
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	} else if (billboard) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
	// Grown to its least size on screen, thinned for it.
	float size = length(MODEL_MATRIX[0].xyz);
	float dist = max(length((MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz), 0.01);
	float least = dist * 2.0 / PROJECTION_MATRIX[1][1] * min_pixels / 720.0;
	float grow = max(1.0, least / max(size, 1e-5));
	// A streak only widens: its length is how far it moved.
	VERTEX.x *= grow;
	if (!axial) VERTEX.y *= grow;
	thin = inversesqrt(grow);
	spark = fract(sin(float(INSTANCE_ID) * 12.9898) * 43758.5453);
}

void fragment() {
	vec4 tex = texture(shape, UV);
	ALBEDO = COLOR.rgb;
	float a = COLOR.a * tex.a * thin;
	if (twinkle > 0.0) a *= 1.0 - twinkle * (0.5 + 0.5 * sin(TIME * (6.0 + spark * 14.0) + spark * 40.0));
	// Soft against what it meets, faded near the lens.
	float depth = texture(depth_map, SCREEN_UV).x;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	behind.xyz /= behind.w;
	a *= clamp((VERTEX.z - behind.z) / 0.06, 0.0, 1.0);
	a *= smoothstep(0.12, 0.4, -VERTEX.z);
	ALPHA = clamp(a, 0.0, 1.0);
}

void light() {
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * scatter / PI;
}
