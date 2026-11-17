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
// Dust hanging in the air (`wrap` over 0, office_geometry.build_dust()): the
// plain instances of a MultiMesh, each speck's place, size and way taken from
// its number (a MultiMesh's own transforms reach VERTEX, not MODEL_MATRIX);
// it drifts slowly about its place and is wrapped into a box `wrap` metres
// wide round the eye, so a few hundred fill the air wherever one goes, fading
// at the box's edge so none pops in or out.
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
uniform float wrap = 0.0;
// How fast a hanging speck drifts (metres a second, at most), and how big it
// is (metres, least and most).
uniform float drift = 0.03;
uniform vec2 speck = vec2(0.003, 0.008);
// How wide (pixels of a 720-line picture) a speck right at the lens is drawn:
// out of the camcorder's focus it spreads into a soft disc, thinner for it,
// down to min_pixels at `focus` metres (0: never).
uniform float bokeh = 0.0;
uniform float focus = 1.2;
uniform sampler2D depth_map : hint_depth_texture, repeat_disable, filter_nearest;

varying float thin;
varying float spark;

void vertex() {
	vec3 centre = MODEL_MATRIX[3].xyz;
	float scale = 1.0;
	float edge = 1.0;
	if (wrap > 0.0) {
		// An integer hash: sin() of large numbers laid the specks out in columns.
		uvec3 h = uvec3(uint(INSTANCE_ID)) * uvec3(1664525u, 22695477u, 2891336453u) + uvec3(1013904223u, 1u, 12345u);
		h ^= h >> 16u;
		h *= 0x7feb352du;
		h ^= h >> 15u;
		h *= 0x846ca68bu;
		h ^= h >> 16u;
		vec3 seed = vec3(h & uvec3(0xffffffu)) / 16777216.0;
		vec3 way = fract(seed * 7.31 + seed.yzx * 3.17) - 0.5;
		vec3 sway = sin(TIME * (0.15 + 0.2 * seed.zxy) + seed * 40.0) * 0.12;
		centre += seed * wrap + way * 2.0 * drift * TIME + sway;
		scale = mix(speck.x, speck.y, fract(seed.x * 13.7 + seed.y * 5.3));
		vec3 eye = INV_VIEW_MATRIX[3].xyz;
		vec3 off = mod(centre - eye + wrap * 0.5, wrap) - wrap * 0.5;
		centre = eye + off;
		vec3 far = abs(off) / (wrap * 0.5);
		edge = 1.0 - smoothstep(0.7, 1.0, max(far.x, max(far.y, far.z)));
	}
	if (axial) {
		vec3 along = MODEL_MATRIX[1].xyz;
		vec3 side = cross(normalize(along), normalize(INV_VIEW_MATRIX[3].xyz - centre));
		side = length(side) > 1e-4 ? normalize(side) : normalize(MODEL_MATRIX[0].xyz);
		side *= length(MODEL_MATRIX[0].xyz);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(side, 0.0), vec4(along, 0.0), vec4(normalize(cross(side, along)), 0.0), vec4(centre, 1.0));
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	} else if (billboard) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], vec4(centre, 1.0));
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz) * scale, 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz) * scale, 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz) * scale, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
	// Grown to its least size on screen, thinned for it.
	float size = length(MODEL_MATRIX[0].xyz) * scale;
	float dist = max(length((MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz), 0.01);
	float least = dist * 2.0 / PROJECTION_MATRIX[1][1] * max(min_pixels, bokeh * (1.0 - smoothstep(0.2, focus, dist))) / 720.0;
	float grow = max(1.0, least / max(size, 1e-5));
	// A streak only widens: its length is how far it moved.
	VERTEX.x *= grow;
	if (!axial) VERTEX.y *= grow;
	// Hanging dust is thinned far less: at two pixels the falling dust's
	// inversesqrt left it too faint to see in a torch's beam.
	thin = (wrap > 0.0 ? pow(grow, -0.1) : inversesqrt(grow)) * edge;
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
