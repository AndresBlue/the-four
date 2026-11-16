shader_type spatial;
// The Lurker's eyes in Versus (.claude/specs/lurker_versus.md 4 and 4.5), on
// a quad over her camera (game/enemies/lurker/lurker_view.gd): what a thermal
// camera would read, where the heat is electricity.
//
// What the scene drew is not shown, only the depth it left, turned back into
// the point of the world under each pixel. The bare surfaces read nearly even
// and low, blotched, their corners and joints a little apart, the ceiling a
// little over the walls and the walls over the floor. The heat comes from the
// floor's registers (the script's list) as shapes in the world: a pixel on a
// fitting's lens, a machine's body or a torch's head reads its heat, and its
// heat stains the surfaces round it; a source in view leaves the soft halo a
// hot point leaves on a sensor, one behind something a warm patch on the face
// of what hides it. The live wires run as faint lines over the ceiling and
// down to their switches. Then the camera's gain stretches all of it between
// gain_low and gain_high; her own lit room burns past a few metres, and a
// torch in her face saturates the camera.
//
// Out goes the reading, not a colour (lurker_thermal_sensor.gdshader makes the
// recording of it): red, the reading from FOOT to RANGE; green, a cold outline.
//
// Sources, four vec4 each:
//   heat_at     = (world point, heat)
//   heat_box    = (half extents, yaw); a body's capsule (radius, half height);
//                 an outline's (0, its height over its width)
//   heat_screen = (uv.x, uv.y, halo radius in screen heights, metres from her eye)
//   heat_kind   = (kind, 1 in view, reach in screen heights, 0)
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;

const float LAMP = 0.0;
const float TORCH = 1.0;
const float BODY = 2.0;
const float COLD = 3.0;
const float RANGE = 1.6;
const float FOOT = -0.4;

uniform sampler2D depth_map : hint_depth_texture, repeat_disable, filter_nearest;
uniform int count = 0;
uniform vec4 heat_at[96];
uniform vec4 heat_box[96];
uniform vec4 heat_screen[96];
uniform vec4 heat_kind[96];
// The live wires: (from, heat) and (to, 0), world.
uniform int wire_count = 0;
uniform vec4 wire_a[48];
uniform vec4 wire_b[48];
// The camera's gain: these readings go to the foot and the top of the map.
uniform float gain_low = 0.06;
uniform float gain_high = 0.36;
// Her planta's floor (world y), for the walls' warmth with height.
uniform float floor_y = 0.0;
// 0..1: how much her own lit room blinds her past DAZZLE_NEAR.
uniform float dazzle = 0.0;
// The flash: how far on (0..1), the side its torch is on (screen, y up), and
// how far it may go (half with reduced effects).
uniform float flash = 0.0;
uniform vec2 flash_from = vec2(0.0);
uniform float flash_peak = 1.0;
uniform float now = 0.0;

const float DAZZLE_NEAR = 4.0;
// Nothing drawn: the coldest there is.
const float VOID = 0.04;
// What a source warms round it (share of its heat, metres to fall by e): a
// lamp the ceiling round it, a torch the hand and body that hold it.
const float LAMP_STAIN = 0.3;
const float LAMP_STAIN_FALL = 0.45;
const float TORCH_STAIN = 0.35;
const float TORCH_STAIN_FALL = 0.5;
// Nothing past this (lurker_view.WARM_REACH: how far on the screen it looks).
const float STAIN_REACH = 1.6;
// A source in view: its halo on the sensor (share of its heat).
const float LAMP_HALO = 0.55;
const float TORCH_HALO = 0.85;
// A source behind something: the patch on its face (share of its heat), and
// the metres between over which it falls by e (a torch is a beacon).
const float LAMP_THROUGH = 0.3;
const float LAMP_THROUGH_FALL = 2.5;
const float TORCH_THROUGH = 0.62;
const float TORCH_THROUGH_FALL = 40.0;
// A wire with current: this much over its surface, this wide.
const float WIRE_NEAR = 0.04;
const float WIRE_FAR = 0.13;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
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
	vec3 world = (INV_VIEW_MATRIX * vec4(here, 1.0)).xyz;
	// The bare surface.
	float t = VOID;
	if (drawn) {
		bool d1; bool d2; bool d3; bool d4;
		vec3 right = view_at(uv + vec2(texel.x, 0.0), INV_PROJECTION_MATRIX, d1);
		vec3 up = view_at(uv + vec2(0.0, texel.y), INV_PROJECTION_MATRIX, d2);
		vec3 left = view_at(uv - vec2(texel.x, 0.0), INV_PROJECTION_MATRIX, d3);
		vec3 down = view_at(uv - vec2(0.0, texel.y), INV_PROJECTION_MATRIX, d4);
		vec3 normal = normalize(cross(right - here, up - here));
		if (dot(normal, here) > 0.0) normal = -normal;
		float facing = clamp(dot(normal, normalize(-here)), 0.0, 1.0);
		vec3 n = (INV_VIEW_MATRIX * vec4(normal, 0.0)).xyz;
		float lap = abs(length(right) + length(left) + length(up) + length(down) - 4.0 * dist) / max(dist, 0.1);
		float edge = smoothstep(0.02, 0.12, lap);
		// Floor, walls warmer as they rise, ceiling.
		float rise = clamp((world.y - floor_y) / 3.0, 0.0, 1.0);
		t = n.y > 0.6 ? 0.105 : (n.y < -0.6 ? 0.16 : 0.115 + 0.03 * rise);
		// Blotched: on the plane the surface lies in.
		vec2 plane = abs(n.y) > 0.6 ? world.xz : (abs(n.x) > abs(n.z) ? world.zy : world.xy);
		t += (value_noise(plane * 1.4) - 0.5) * 0.05 + (value_noise(plane * 0.33 + 17.0) - 0.5) * 0.05 + (value_noise(plane * 6.0) - 0.5) * 0.01;
		// Seen square on it reads a little warmer; corners and joints apart.
		t += 0.012 * facing + 0.025 * edge;
		// And a little cooler far off.
		t -= 0.03 * smoothstep(5.0, 25.0, dist);
	}
	// The heat.
	float hot = 0.0;
	float warm = 0.0;
	float halo = 0.0;
	float cold = 0.0;
	for (int i = 0; i < count; i++) {
		vec4 s = heat_screen[i];
		vec4 k = heat_kind[i];
		vec2 p = (uv - s.xy) * vec2(aspect, 1.0);
		float sd2 = dot(p, p);
		if (sd2 > k.z * k.z) continue;
		float r2 = sd2 / max(s.z * s.z, 1.0e-7);
		if (k.x == COLD) {
			// An outline, cold: a mind gone, seen through the walls (as tall as
			// heat_box.y says).
			float r = length(p / max(s.z, 1.0e-4) / vec2(1.0, max(heat_box[i].y, 0.01)));
			cold = max(cold, max(max(0.0, 1.0 - abs(r - 0.8) / 0.3), 0.35 * max(0.0, 1.0 - r2)));
			continue;
		}
		vec4 a = heat_at[i];
		if (drawn) {
			vec4 b = heat_box[i];
			vec3 o = world - a.xyz;
			float d;
			if (k.x == BODY) {
				o.y -= clamp(o.y, -b.y, b.y);
				d = length(o) - b.x;
			} else {
				float c = cos(b.w);
				float sn = sin(b.w);
				vec3 l = abs(vec3(c * o.x - sn * o.z, o.y, sn * o.x + c * o.z)) - b.xyz;
				d = length(max(l, 0.0)) + min(max(l.x, max(l.y, l.z)), 0.0);
			}
			// On it: its own heat.
			hot = max(hot, a.w * (1.0 - smoothstep(0.0, 0.05, d)));
			// Round it: the surfaces it warms.
			float near = 1.0 - smoothstep(STAIN_REACH * 0.5, STAIN_REACH, d);
			if (k.x == LAMP) warm += a.w * LAMP_STAIN * exp(-max(d, 0.0) / LAMP_STAIN_FALL) * near;
			else if (k.x == TORCH) warm += a.w * TORCH_STAIN * exp(-max(d, 0.0) / TORCH_STAIN_FALL) * near;
		}
		if (k.x == BODY) continue;
		if (k.y > 0.5) {
			// In view: the soft halo of a hot point on the sensor.
			halo = max(halo, a.w * (k.x == TORCH ? TORCH_HALO : LAMP_HALO) * exp(-r2 * 2.2));
		} else {
			// Behind something: a warm patch on its face, fainter the more lies between.
			float gap = max(s.w - dist, 0.0);
			float through = k.x == TORCH ? TORCH_THROUGH * exp(-gap / TORCH_THROUGH_FALL) : LAMP_THROUGH * exp(-gap / LAMP_THROUGH_FALL);
			warm += a.w * through * exp(-r2 * 1.6);
		}
	}
	// The wires with current, faint, where the surface is over them.
	float wire = 0.0;
	if (drawn) {
		for (int w = 0; w < wire_count; w++) {
			vec3 from = wire_a[w].xyz;
			vec3 along = wire_b[w].xyz - from;
			vec3 o = world - from;
			float d = length(o - along * clamp(dot(o, along) / max(dot(along, along), 1.0e-6), 0.0, 1.0));
			wire += wire_a[w].w * (1.0 - smoothstep(WIRE_NEAR, WIRE_FAR, d));
		}
	}
	// The camera's gain.
	float span = max(gain_high - gain_low, 0.01);
	float v = (t + warm + wire - gain_low) / span;
	// Her own lit room: past a few metres the surfaces drown in an even,
	// shimmering wash; what is hot still shows through it, and the wires
	// faintly.
	vec2 q = (uv - 0.5) * vec2(aspect, 1.0);
	float burn = dazzle * smoothstep(DAZZLE_NEAR - 1.0, DAZZLE_NEAR + 1.5, dist);
	v = mix(v, 0.36 + 0.12 * (value_noise(q * 5.0 + vec2(now * 0.6, now * 0.4)) - 0.5), burn);
	v = max(v + burn * wire / span, (max(hot, halo) - gain_low) / span);
	// The flash: the torch's bloom swells from its side and burns white, the
	// gain throws the rest to black; both give back as it passes.
	q.y = -q.y;
	float bloom = mix(0.2, 1.7, flash);
	float cover = 1.0 - smoothstep(bloom * 0.3, bloom, length(q - flash_from * 0.6));
	float crush = min(flash * 1.6, 1.0) * flash_peak;
	v = v * (1.0 - 0.9 * crush) - 0.35 * crush;
	v = mix(v, RANGE * flash_peak, cover * min(flash * 1.4, 1.0));
	vec3 packed = vec3(clamp((v - FOOT) / (RANGE - FOOT), 0.0, 1.0), clamp(cold, 0.0, 1.0), 0.0);
	// Into linear, so the screen holds the reading itself.
	ALBEDO = mix(pow((packed + 0.055) / 1.055, vec3(2.4)), packed / 12.92, lessThan(packed, vec3(0.04045)));
	ALPHA = 1.0;
}
