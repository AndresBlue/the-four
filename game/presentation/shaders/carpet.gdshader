shader_type spatial;
// Patterned hotel carpet: interlocking medallions, pile fibre, wear and stains.
#include "res://game/presentation/shaders/surface.gdshaderinc"
#include "res://game/presentation/shaders/image_maps.gdshaderinc"

uniform vec4 base_color : source_color = vec4(0.32, 0.27, 0.20, 1.0);
uniform vec4 field_color : source_color = vec4(0.19, 0.075, 0.055, 1.0);
uniform vec4 line_color : source_color = vec4(0.33, 0.22, 0.11, 1.0);
uniform vec4 accent_color : source_color = vec4(0.13, 0.075, 0.05, 1.0);
uniform float tile_size = 0.62;
uniform float pattern : hint_range(0.0, 1.0) = 1.0;
uniform float wear : hint_range(0.0, 1.0) = 0.6;
// How far the pile's tufts push the pattern's edges about, in metres.
uniform float fibre_bleed = 0.035;

void vertex() { SURFACE_VERTEX; }

void fragment() {
	if (baked_surface()) {
		ALBEDO = baked_albedo(wp.xz, NODE_POSITION_WORLD, is_floor_face());
		ROUGHNESS = 0.97;
	} else {
		vec2 uv = wp.xz;
		vec3 color;
		float motif = 0.0;
		MapLookup l = map_lookup(map_uv());
		if (is_floor_face()) {
			// Woven, not printed: the pile's tufts lean the medallions' edges
			// about, so no line of the pattern is clean.
			vec2 tufts = use_maps ? (map_sample(normal_map, l).xy * 2.0 - 1.0) * fibre_bleed : vec2(0.0);
			vec2 cell = (uv + tufts) / tile_size;
			vec2 q = fract(cell) - 0.5;
			vec2 id = floor(cell);
			// Octagon medallion joined by a diagonal lattice.
			vec2 a = abs(q);
			float octagon = max(max(a.x, a.y), (a.x + a.y) * 0.72);
			float ring = smoothstep(0.022, 0.01, abs(octagon - 0.32));
			float inner = smoothstep(0.17, 0.15, octagon);
			float cross_mark = smoothstep(0.03, 0.015, min(a.x, a.y)) * step(octagon, 0.14);
			float lattice = smoothstep(0.02, 0.008, abs(abs(q.x) + abs(q.y) - 0.9) * 0.7);
			float corner = smoothstep(0.1, 0.08, length(a - 0.5));
			color = field_color.rgb;
			color = mix(color, line_color.rgb, clamp(ring + lattice, 0.0, 1.0));
			color = mix(color, accent_color.rgb, clamp(inner * (1.0 - cross_mark) + corner, 0.0, 1.0) * 0.85);
			color = mix(color, line_color.rgb * 0.8, cross_mark);
			motif = ring + lattice;
			color = mix(base_color.rgb, color, pattern);
			// Soften the print so it reads as woven pile rather than paint.
			color = mix(color, field_color.rgb, 0.25 + 0.2 * vnoise(uv * 6.0));
			color *= 0.94 + hash12(id) * 0.06;
		} else {
			color = base_color.rgb * 0.6;
		}
		// The scanned pile (Detail) under the woven medallions.
		color = scan_albedo(l, color);
		// Pile: fine directional fibres and shading patches from brushing (the
		// scan has its own fibres).
		float pile = use_maps ? 0.5 : fine_noise(uv * 260.0) * 0.6 + fine_noise(uv * 90.0 + 3.0) * 0.4;
		float brush = fbm(uv * 0.9 + vec2(4.0, 1.0));
		color *= 0.84 + pile * 0.22 + (brush - 0.5) * 0.14;
		// Wear: lighter, flattened paths and scattered dark stains.
		float traffic = smoothstep(0.45, 0.8, fbm(uv * 0.22)) * wear;
		color = mix(color, vec3(dot(color, vec3(0.33))) * 1.15, traffic * 0.35);
		float stain = smoothstep(0.7, 0.76, fbm(uv * 0.8 + 11.0)) * wear;
		color *= 1.0 - stain * 0.35;
		float ao = scan_occlusion(l);
		ALBEDO = room_grime(color, wp, NODE_POSITION_WORLD, ao);
		AO = ao;
		// Traffic flattens the pile: less relief, a touch less rough.
		ROUGHNESS = scan_roughness(l, 0.97) - traffic * 0.05;
		float height = pile * 0.002 - motif * 0.0006 * pattern;
		NORMAL = BUMPED_VIEW_NORMAL(normalize(mix(scan_normal(l, wn), wn, traffic * 0.5)), height, 1.0);
	}
}
