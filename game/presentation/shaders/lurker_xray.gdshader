shader_type spatial;
// The Lurker's view from the plenum in Versus (.claude/specs/lurker_versus.md
// 13.2), on a quad over her camera (game/enemies/lurker/lurker_view.gd): the
// false ceiling under her as if it were not there. Nothing the scene drew is
// used. Each pixel's ray is followed down through her planta, worked out from
// a plan of it (lurker_view.plan_of()): the ceiling's grid faint round her
// where she has a false ceiling; the walls of the rooms as faint contours
// where they meet the floor and, fainter, the ceiling; the fire walls and
// cores that stop her as a line along her ceiling; the floor nearly black, a
// lit room a dark purple. Over that what the script lists:
// the ducts as thin lines, the fittings as low dots, the survivors within
// reach as warm figures, and their torches the hottest of all.
//
// Out goes the reading, as lurker_sight.gdshader's (lurker_thermal_sensor
// makes the recording of it): red, from FOOT to RANGE.
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;

const float RANGE = 1.6;
const float FOOT = -0.4;

// The plan: red the walls, green inside the building, blue her fire walls,
// alpha her false ceilings. plan_box = (x, z of its corner, metres across x, z).
uniform sampler2D plan : filter_linear, repeat_disable;
uniform vec4 plan_box = vec4(0.0, 0.0, 1.0, 1.0);
uniform float floor_y = 0.0;
uniform float ceil_y = 2.95;
uniform float slab_y = 4.4;
// Lit rooms: (min x, min z, max x, max z) and how lit, 0..1.
uniform int lit_count = 0;
uniform vec4 lit_rect[48];
uniform float lit_heat[48];
// Survivors: feet (world) and how warm.
uniform int body_count = 0;
uniform vec4 body_at[16];
// Points: (world, heat) and (kind 0 a fitting, 1 a torch; radius; 0; 0).
uniform int dot_count = 0;
uniform vec4 dot_at[96];
uniform vec4 dot_kind[96];
// Duct runs: (from, heat) and (to, 0).
uniform int line_count = 0;
uniform vec4 line_a[48];
uniform vec4 line_b[48];
// The flash, as in her eyes.
uniform float flash = 0.0;
uniform vec2 flash_from = vec2(0.0);
uniform float flash_peak = 1.0;

// Nothing: past the building and far off.
const float VOID = -0.36;
const float FLOOR_DARK = -0.3;
const float LIT_RISE = 0.36;
const float WALL = 0.16;
const float WALL_TOP = 0.02;
const float FIRE_WALL = 0.3;
const float GRID = -0.08;
const float BODY = 0.78;
const float FADE_FROM = 15.0;
const float FADE_TO = 35.0;

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

vec4 plan_at(vec2 xz) {
	vec2 uv = (xz - plan_box.xy) / plan_box.zw;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) return vec4(0.0);
	return texture(plan, uv);
}

// Distance between the ray o + d t (t > 0) and the segment a..b; `t` the ray's.
float ray_segment(vec3 o, vec3 d, vec3 a, vec3 b, out float t) {
	vec3 u = b - a;
	vec3 w = o - a;
	float uu = dot(u, u);
	float ud = dot(u, d);
	float uw = dot(u, w);
	float dw = dot(d, w);
	float den = uu - ud * ud;
	float s = den > 1.0e-6 ? clamp((uw - ud * dw) / den, 0.0, 1.0) : 0.0;
	vec3 p = a + u * s;
	t = max(dot(p - o, d), 0.0);
	return length(o + d * t - p);
}

float ray_point(vec3 o, vec3 d, vec3 p, out float t) {
	t = max(dot(p - o, d), 0.0);
	return length(o + d * t - p);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float aspect = VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;
	vec4 far_point = INV_PROJECTION_MATRIX * vec4(uv * 2.0 - 1.0, 0.5, 1.0);
	vec3 o = INV_VIEW_MATRIX[3].xyz;
	vec3 d = normalize((INV_VIEW_MATRIX * vec4(normalize(far_point.xyz / far_point.w), 0.0)).xyz);
	float v = VOID;
	if (d.y < -1.0e-4) {
		// The floor, nearly black; a lit room a middling purple.
		float tf = (floor_y - o.y) / d.y;
		vec3 pf = o + d * tf;
		vec4 c = plan_at(pf.xz);
		float fade = 1.0 - smoothstep(FADE_FROM, FADE_TO, tf);
		if (c.g > 0.5) {
			float lit = 0.0;
			for (int i = 0; i < lit_count; i++) {
				vec4 r = lit_rect[i];
				if (pf.x >= r.x && pf.x <= r.z && pf.z >= r.y && pf.z <= r.w) lit = max(lit, lit_heat[i]);
			}
			v = mix(VOID, FLOOR_DARK + LIT_RISE * lit, fade);
		}
		// The walls where they meet the floor, and fainter at the ceiling: a plan
		// drawn twice, which the eye reads as walls standing between.
		v = max(v, mix(v, WALL, c.r * fade));
		float tc = (ceil_y - o.y) / d.y;
		if (tc > 0.0) {
			vec3 pc = o + d * tc;
			vec4 top = plan_at(pc.xz);
			float near = 1.0 - smoothstep(FADE_FROM, FADE_TO, tc);
			v = max(v, mix(v, WALL_TOP, top.r * near * 0.7));
			// The fire walls and cores that stop her, along her ceiling.
			v = max(v, mix(v, FIRE_WALL, top.b * near));
			// The ceiling's grid where it is hers, faint, only round her.
			if (top.a > 0.5) {
				vec2 cell = abs(fract(pc.xz / 0.6 + 0.5) - 0.5);
				float line = 1.0 - smoothstep(0.015, 0.035, min(cell.x, cell.y));
				v = max(v, mix(v, GRID, line * (1.0 - smoothstep(3.0, 9.0, tc))));
			}
		}
	}
	// The ducts, thin.
	for (int i = 0; i < line_count; i++) {
		float t;
		float dist = ray_segment(o, d, line_a[i].xyz, line_b[i].xyz, t);
		float width = 0.05 + 0.004 * t;
		v = max(v, line_a[i].w * (1.0 - smoothstep(width, width * 2.5, dist)));
	}
	// The survivors: a warm figure, a little warmer at its rim.
	for (int i = 0; i < body_count; i++) {
		vec3 feet = body_at[i].xyz;
		float t;
		float dist = ray_segment(o, d, feet + vec3(0.0, 0.3, 0.0), feet + vec3(0.0, 1.5, 0.0), t);
		float r = 0.26;
		float inside = 1.0 - smoothstep(r - 0.03, r + 0.02, dist);
		float rim = smoothstep(r * 0.4, r, dist) * inside;
		v = max(v, (BODY + 0.12 * rim) * body_at[i].w * inside);
	}
	// The fittings low, the torches burning with their halo.
	for (int i = 0; i < dot_count; i++) {
		float t;
		float dist = ray_point(o, d, dot_at[i].xyz, t);
		float r = dot_kind[i].y + 0.002 * t;
		if (dot_kind[i].x > 0.5) {
			v = max(v, dot_at[i].w * (1.0 - smoothstep(r * 0.5, r, dist)));
			v = max(v, dot_at[i].w * 0.55 * exp(-dist * dist / (r * r * 9.0)));
		} else v = max(v, dot_at[i].w * (1.0 - smoothstep(r * 0.4, r, dist)));
	}
	// The flash: as in her eyes, the camera saturated from the torch's side.
	vec2 q = (uv - 0.5) * vec2(aspect, 1.0);
	q.y = -q.y;
	float bloom = mix(0.2, 1.7, flash);
	float cover = 1.0 - smoothstep(bloom * 0.3, bloom, length(q - flash_from * 0.6));
	float crush = min(flash * 1.6, 1.0) * flash_peak;
	v = v * (1.0 - 0.9 * crush) - 0.35 * crush;
	v = mix(v, RANGE * flash_peak, cover * min(flash * 1.4, 1.0));
	vec3 packed = vec3(clamp((v - FOOT) / (RANGE - FOOT), 0.0, 1.0), 0.0, 0.0);
	ALBEDO = mix(pow((packed + 0.055) / 1.055, vec3(2.4)), packed / 12.92, lessThan(packed, vec3(0.04045)));
	ALPHA = 1.0;
}
