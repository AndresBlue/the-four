// The hotel's wood, for wood.gdshader and wood_lacquer.gdshader: the same
// surface, the second with the lacquer worked out as a coat of its own
// (LACQUER_COAT). Two shaders and not a switch in one, because a shader that
// writes CLEARCOAT at all pays for that second highlight under every lamp on
// every pixel, whatever it writes: a quarter of a millisecond of Alto's frame
// at 1080p, for a coat only the highest preset has.
#include "res://game/presentation/shaders/surface.gdshaderinc"
#include "res://game/presentation/shaders/image_maps.gdshaderinc"

uniform vec4 light_color : source_color = vec4(0.36, 0.21, 0.11, 1.0);
uniform vec4 dark_color : source_color = vec4(0.17, 0.09, 0.05, 1.0);
uniform float ring_density = 22.0;
uniform float varnish : hint_range(0.0, 1.0) = 0.65;
uniform float scuffs : hint_range(0.0, 1.0) = 0.5;
uniform float panel_spacing = 0.0;
uniform bool door_panels = false;
uniform bool object_space = false;

// Grain coordinates in metres, x along the grain, and the grain's direction
// in the world. On a batched box the grain runs along the longer side of each
// face, as a board is cut: along a plank, up a table leg, round a frame.
varying vec2 grain;
varying vec3 grain_t;

void vertex() {
	if (object_space) {
		wp = VERTEX;
		wn = NORMAL;
		room_data = vec4(0.0);
		grain = face_uv();
		grain_t = face_tangent();
	} else {
		SURFACE_VERTEX;
		vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
		vec3 a = abs(NORMAL);
		vec3 u = a.x > 0.5 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
		vec3 v = a.y > 0.5 ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
		if (dot(scale, v) > dot(scale, u)) {
			vec3 w = u;
			u = v;
			v = w;
		}
		grain_t = normalize((MODEL_MATRIX * vec4(u, 0.0)).xyz);
		// Its own length: on a face that leans (a bevel, a moulding's curve)
		// the normal is not square to the grain, and a shorter bitangent ran
		// the rings out of step with the flat faces either side of it.
		vec3 bitangent = normalize(cross(wn, grain_t));
		vec3 origin = MODEL_MATRIX[3].xyz;
		// Each piece is cut from its own place in the board.
		vec2 cut = vec2(hash13(floor(origin * 7.1)), hash13(floor(origin * 5.3) + 2.0)) * vec2(5.0, 3.0);
		grain = vec2(dot(wp - origin, grain_t), -dot(wp - origin, bitangent)) + cut;
	}
}

void fragment() {
	if (baked_surface()) {
		vec3 baked = baked_albedo(grain, NODE_POSITION_WORLD, true);
		vec2 across = face_uv();
		float cut = 0.0;
		if (panel_spacing > 0.0 && abs(wn.y) < 0.5) {
			float p = fract(across.x / panel_spacing);
			cut = smoothstep(0.012, 0.0, min(p, 1.0 - p) * panel_spacing);
		}
		if (door_panels && abs(wn.z) > 0.5) {
			vec2 cell = vec2(abs(wp.x) - 0.5, abs(wp.y) - 0.62);
			cut = max(cut, smoothstep(0.025, 0.0, abs(max(abs(cell.x) - 0.36, abs(cell.y) - 0.5))));
		}
		ALBEDO = baked * (1.0 - cut * 0.5);
		ROUGHNESS = 0.6;
	} else {
		vec2 uv = face_uv();
		vec2 g = grain;
		vec3 t = normalize(grain_t);
		vec3 b = cross(wn, t);
		float warp = fbm(g * vec2(0.6, 7.0) + plane_offset() * 17.0);
		float rings = fract((g.y + warp * 0.12) * ring_density);
		float ring_line = smoothstep(0.0, 0.55, rings) * smoothstep(1.0, 0.8, rings);
		float pores = smoothstep(0.62, 0.8, fine_noise(g * vec2(8.0, 420.0)));
		vec3 color = mix(dark_color.rgb, light_color.rgb, 0.35 + ring_line * 0.45 + (warp - 0.5) * 0.4);
		color *= 1.0 - pores * 0.25;
		// The scanned board (Recolour) takes the place of rings and pores.
		MapLookup l = map_lookup(g / max(map_metres, 0.01));
		color = scan_albedo(l, color);
		float groove = 0.0;
		if (panel_spacing > 0.0 && abs(wn.y) < 0.5) {
			float p = fract(uv.x / panel_spacing);
			groove = smoothstep(0.012, 0.0, min(p, 1.0 - p) * panel_spacing);
		}
		if (door_panels && abs(wn.z) > 0.5) {
			// Four raised panels on the 2.24 x 2.58 m leaf (local space).
			vec2 cell = vec2(abs(wp.x) - 0.5, abs(wp.y) - 0.62);
			float frame = max(abs(cell.x) - 0.36, abs(cell.y) - 0.5);
			groove = max(groove, smoothstep(0.025, 0.0, abs(frame)));
		}
		color *= 1.0 - groove * 0.5;
		float scratch = smoothstep(0.93, 1.0, vnoise(g * vec2(3.0, 90.0) + 7.0)) * scuffs;
		float dull = fbm(g * 2.2) * scuffs;
		color = mix(color, color * 1.35 + 0.02, scratch * 0.5);
		float ao = scan_occlusion(l);
		ALBEDO = object_space ? color : room_grime(color, wp, NODE_POSITION_WORLD, ao);
		AO = ao;
		// Varnish over the scan: its roughness, glossed by the lacquer, dulled by
		// wear and scratches.
		float lacquer = mix(0.75, 0.28, varnish);
		ROUGHNESS = (use_maps ? mix(scan_roughness(l, lacquer), lacquer, 0.5) : lacquer) + dull * 0.25 + scratch * 0.2;
		SPECULAR = 0.5;
#ifdef LACQUER_COAT
		// The lacquer as what it is, a clear coat over the wood: a second,
		// sharper highlight on top of the grain's own, gone where the varnish
		// has worn dull or been scratched through, and out of the grooves.
		CLEARCOAT = varnish * (1.0 - dull * 0.7) * (1.0 - scratch * 0.8) * (1.0 - groove);
		// (The engine's coat is polished even at 1: no sharper than this, or a
		// lamp is in the lacquer at many times its own brightness.)
		CLEARCOAT_ROUGHNESS = 0.6 + dull * 0.4;
#endif
		float height = (use_maps ? 0.0 : ring_line * 0.0004 - pores * 0.0005) - groove * 0.004;
		vec3 n = bump_world(scan_normal_frame(l, wn, t, b), dFdx(wp), dFdy(wp), dFdx(height), dFdy(height), 1.0);
		if (object_space) n = normalize(mat3(MODEL_MATRIX) * n);
		NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	}
}
