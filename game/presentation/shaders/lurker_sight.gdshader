shader_type spatial;
// The Lurker's eyes in Versus (.claude/specs/lurker_versus.md 4; phase 2),
// on a quad over her camera (game/enemies/lurker/lurker_view.gd).
//
// The colours are matplotlib's plasma map. What the scene drew is not shown,
// only the depth it left: the rooms come out of the dark in deep blue and
// purple from how near they are and how they face her, never from a lamp.
// What is hot is painted over that from the floor's registers, as halos with
// no depth test (a lamp is heat through a wall): rooms with their light,
// fittings and machines, and the torches, the hottest of all with a flare of
// their own. A lit room dazzles her past a few metres, noise rings out, and
// a torch in her face floods the picture white from its side.
//
// Halos are given in screen space by the script, two vec4 each:
//   a = (uv.x, uv.y, radius in screen heights, heat)
//   b = (kind, vertical stretch, ring thickness, metres from her eye)
// Heat is a place on the map: about 0.5 magenta, 0.75 orange, 1 yellow, over
// 1 on to white.
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;

const float GLOW = 0.0;
const float TORCH = 1.0;
const float BODY = 2.0;
const float COLD = 3.0;
const float RING = 4.0;

uniform sampler2D depth_map : hint_depth_texture, repeat_disable, filter_nearest;
uniform int count = 0;
uniform vec4 halo_a[128];
uniform vec4 halo_b[128];
// 0..1: how much her own lit room blinds her past DAZZLE_NEAR.
uniform float dazzle = 0.0;
// The flash: how far on (0..1), the side its torch is on (screen, y up), and
// how white it may go (half with reduced effects).
uniform float flash = 0.0;
uniform vec2 flash_from = vec2(0.0);
uniform float flash_peak = 1.0;
uniform float now = 0.0;

const float DAZZLE_NEAR = 4.0;
// How far the dark keeps the rooms legible: about as far as she sees in it.
const float SIGHT = 22.0;
// Metres over which the near light of the geometry falls by e.
const float NEAR_FALL = 5.0;
// A halo further than the surface drawn over it by this much is seen through
// that surface, at this share of its heat (a torch always whole).
const float OCCLUDED_SLACK = 0.6;
const float THROUGH = 0.55;

// matplotlib's plasma, a degree-6 fit to its table (sRGB out).
vec3 plasma(float t) {
	t = clamp(t, 0.0, 1.0);
	const vec3 c0 = vec3(0.05873234392399702, 0.02333670892565664, 0.5433401826748754);
	const vec3 c1 = vec3(2.176514634195958, 0.2383834171260182, 0.7539604599784036);
	const vec3 c2 = vec3(-2.689460476458034, -7.455851135738909, 3.110799939717086);
	const vec3 c3 = vec3(6.130348345893603, 42.3461881477227, -28.51885465332158);
	const vec3 c4 = vec3(-11.10743619062271, -82.66631109428045, 60.13984767418263);
	const vec3 c5 = vec3(10.02306557647065, 71.41361770095349, -54.07218655560067);
	const vec3 c6 = vec3(-3.658713842777788, -22.93153465461149, 18.19190778539828);
	return clamp(c0 + t * (c1 + t * (c2 + t * (c3 + t * (c4 + t * (c5 + t * c6))))), 0.0, 1.0);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	// The 1x1 QuadMesh doubled covers the frame (echo_field.gdshader).
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

// The view-space point drawn at a pixel, and whether anything was.
vec3 view_at(vec2 uv, mat4 inv_projection, out bool drawn) {
	float raw = texture(depth_map, uv).x;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	drawn = raw < 0.9999999;
	vec4 ndc = vec4(vec3(uv, raw) * 2.0 - 1.0, 1.0);
#else
	drawn = raw > 0.0000001;
	vec4 ndc = vec4(uv * 2.0 - 1.0, raw, 1.0);
#endif
	vec4 view = inv_projection * ndc;
	return view.xyz / view.w;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 texel = 1.0 / VIEWPORT_SIZE;
	float aspect = VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;
	bool drawn;
	vec3 here = view_at(uv, INV_PROJECTION_MATRIX, drawn);
	float dist = drawn ? length(here) : 1.0e5;
	// The geometry: near and facing her, brighter; edges where the depth
	// breaks, a little more; walls a touch over floors and ceilings.
	float t = 0.0;
	float lift = 0.05;
	if (drawn) {
		bool d1; bool d2; bool d3; bool d4;
		vec3 right = view_at(uv + vec2(texel.x, 0.0), INV_PROJECTION_MATRIX, d1);
		vec3 up = view_at(uv + vec2(0.0, texel.y), INV_PROJECTION_MATRIX, d2);
		vec3 left = view_at(uv - vec2(texel.x, 0.0), INV_PROJECTION_MATRIX, d3);
		vec3 down = view_at(uv - vec2(0.0, texel.y), INV_PROJECTION_MATRIX, d4);
		vec3 normal = normalize(cross(right - here, up - here));
		if (dot(normal, here) > 0.0) normal = -normal;
		float facing = clamp(dot(normal, normalize(-here)), 0.0, 1.0);
		vec3 world_normal = (INV_VIEW_MATRIX * vec4(normal, 0.0)).xyz;
		float wall = 1.0 - abs(world_normal.y);
		float lap = abs(length(right) + length(left) + length(up) + length(down) - 4.0 * dist) / max(dist, 0.1);
		float edge = smoothstep(0.03, 0.15, lap);
		// The bottom of the map: deep blue to purple, dark; brighter only near
		// and facing her, sunk to almost black far off.
		float near = exp(-dist / NEAR_FALL) * (1.0 - smoothstep(SIGHT * 0.6, SIGHT, dist));
		t = near * (0.03 + 0.09 * facing + 0.02 * wall) + 0.1 * edge * (0.25 + 0.75 * near);
		lift = 0.08 + near * (0.24 + 0.46 * facing) + 0.25 * edge * (0.3 + 0.7 * near);
	}
	// Her own lit room: past a few metres it burns out to magenta.
	float burn = dazzle * smoothstep(DAZZLE_NEAR - 1.0, DAZZLE_NEAR + 1.5, dist);
	t = mix(t, 0.52 + 0.03 * sin(now * 7.0 + uv.y * 9.0), burn);
	lift = mix(lift, 0.9, burn);
	// The heat: the hottest halo over a pixel sets its colour, the rest glows.
	float heat = 0.0;
	float bloom = 0.0;
	float cold = 0.0;
	for (int i = 0; i < count; i++) {
		vec4 a = halo_a[i];
		vec4 b = halo_b[i];
		vec2 p = (uv - a.xy) * vec2(aspect, 1.0) / a.z;
		p.y /= b.y;
		float r2 = dot(p, p);
		if (b.x == RING) {
			float f = max(0.0, 1.0 - abs(sqrt(r2) - 1.0) / b.z);
			heat = max(heat, a.w * f);
			continue;
		}
		if (r2 > 16.0) continue;
		float f = max(0.0, 1.0 - r2);
		f *= f;
		if (b.x == COLD) {
			// An outline, cold: a mind gone, seen through the walls.
			cold = max(cold, max(max(0.0, 1.0 - abs(sqrt(r2) - 0.8) / 0.3), 0.35 * f));
			continue;
		}
		if (b.x == TORCH) {
			// Its own shape, not only its heat: a cross of light and a wide halo.
			float flare = max(0.0, 1.0 - abs(p.y) * 5.0) * max(0.0, 1.0 - abs(p.x) / 4.0) + max(0.0, 1.0 - abs(p.x) * 5.0) * max(0.0, 1.0 - abs(p.y) / 2.5);
			float wide = max(0.0, 1.0 - r2 / 9.0);
			heat = max(heat, max(a.w * f, max(0.82 * flare, 0.6 * wide * wide)));
			bloom += 0.25 * wide * wide;
			continue;
		}
		// Behind what is drawn there, a lamp is heat through a wall: dimmer.
		if (dist < b.w - OCCLUDED_SLACK) f *= THROUGH;
		heat = max(heat, a.w * f);
		bloom += 0.04 * a.w * f;
	}
	float hot = max(t, heat + bloom * 0.25);
	vec3 colour = plasma(hot) * mix(lift, 1.0, smoothstep(0.0, 0.35, heat));
	// Past the top of the map, white.
	colour = mix(colour, vec3(1.0), clamp((hot - 1.0) * 4.0, 0.0, 1.0));
	colour = mix(colour, vec3(0.62, 0.74, 1.0), cold * 0.85);
	// The flash: white from its torch's side, then all of it.
	vec2 q = (uv - 0.5) * vec2(aspect, 1.0);
	q.y = -q.y;
	float side = dot(q, flash_from);
	float cover = clamp(flash * 2.2 - (0.7 - side) * (1.0 - flash) * 2.0, 0.0, 1.0);
	colour = mix(colour, vec3(1.0, 0.96, 0.78), cover * min(flash * 1.4, 1.0) * flash_peak);
	// A breath of sensor noise, so the flat blues do not band.
	colour += (hash12(FRAGCOORD.xy + fract(now) * 91.0) - 0.5) * 0.012;
	ALBEDO = pow(max(colour, vec3(0.0)), vec3(2.2));
	ALPHA = 1.0;
}
