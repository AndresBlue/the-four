shader_type spatial;
// Aged hotel wallpaper: roll seams, printed ogee motif, water stains and grime.
#include "res://game/presentation/shaders/surface.gdshaderinc"
#include "res://game/presentation/shaders/image_maps.gdshaderinc"

uniform vec4 paper_color : source_color = vec4(0.62, 0.55, 0.40, 1.0);
uniform vec4 print_color : source_color = vec4(0.47, 0.40, 0.27, 1.0);
uniform vec4 stain_color : source_color = vec4(0.33, 0.25, 0.14, 1.0);
uniform vec4 edge_color : source_color = vec4(0.55, 0.52, 0.46, 1.0);
uniform float roll_width = 0.53;
uniform float motif_height = 0.46;
uniform float print_strength : hint_range(0.0, 1.0) = 0.55;
uniform float stains : hint_range(0.0, 1.0) = 0.55;
uniform float grime : hint_range(0.0, 1.0) = 0.5;
// How far the ink bleeds along the paper's grain, in metres.
uniform float ink_bleed = 0.03;

void vertex() { SURFACE_VERTEX; }

void fragment() {
	if (plasticine()) {
		ALBEDO = plasticine_albedo(NODE_POSITION_WORLD);
		ROUGHNESS = 0.9;
	} else {
		vec2 uv = face_uv();
		float u = uv.x;
		float y = wp.y;
		if (abs(wn.y) > 0.5) {
			// Wall tops and undersides: bare plaster.
			float n = fbm(wp.xz * 9.0);
			ALBEDO = edge_color.rgb * (0.9 + n * 0.15);
			ROUGHNESS = 0.9;
		} else {
			// The scanned paper (Detail) under the printed motif, or a decrepit
			// scan (Replace) with the print faded into it. The ink bleeds into
			// the paper's grain: the print's edges follow it.
			MapLookup l = map_lookup(map_uv());
			vec2 bleed = use_maps ? (map_sample(normal_map, l).xy * 2.0 - 1.0) * ink_bleed : vec2(0.0);
			u += bleed.x;
			y += bleed.y;
			float roll = floor(u / roll_width);
			float in_roll = fract(u / roll_width);
			// Printed motif: alternating ogee drops with a thin stripe between rolls.
			vec2 cell = vec2(in_roll * 2.0, y / motif_height + mod(roll, 2.0) * 0.5);
			vec2 q = fract(cell) - 0.5;
			float ogee = smoothstep(0.23, 0.2, abs(abs(q.x) - 0.25 * cos(q.y * 6.2831)) );
			float dots = smoothstep(0.06, 0.04, length(q - vec2(0.0, 0.0)));
			float stripe = smoothstep(0.035, 0.02, abs(in_roll - 0.5)) * 0.6;
			float print_mask = clamp(ogee * 0.8 + dots + stripe, 0.0, 1.0) * print_strength;
			float fibre = use_maps ? 0.5 : fine_noise(uv * vec2(160.0, 40.0));
			float mottling = fbm(uv * 1.7);
			vec3 base = mix(paper_color.rgb, print_color.rgb, print_mask);
			base *= 0.97 + hash12(vec2(roll, 3.0)) * 0.03 + (mottling - 0.5) * 0.12 + (fibre - 0.5) * 0.04;
			if (use_maps && map_mode != 2) {
				vec3 scan = scan_albedo(l, base);
				base = mix(scan, scan * base / paper_color.rgb, print_strength);
			} else {
				base = scan_albedo(l, base);
			}
			// Seams: slightly lifted, lighter paper edge with a dark gap.
			float seam = smoothstep(0.012, 0.0, min(in_roll, 1.0 - in_roll) * roll_width);
			float lifted = smoothstep(0.55, 0.8, vnoise(vec2(roll * 3.1, y * 1.7))) * seam;
			base = mix(base, base * 0.7, seam * 0.4) + lifted * 0.03;
			// Water stains, heavier near the ceiling, and grime near skirting/hands.
			float stain_field = fbm(vec2(u * 0.55, y * 0.9) + plane_offset() * 13.0);
			float top = smoothstep(1.6, 3.2, y);
			float mask = smoothstep(0.62 - top * 0.12, 0.7, stain_field) * stains * (0.35 + top);
			float ring = smoothstep(0.02, 0.0, abs(stain_field - (0.66 - top * 0.12))) * stains * top;
			base = mix(base, base * stain_color.rgb * 1.6, clamp(mask * 0.7, 0.0, 0.8));
			base *= 1.0 - ring * 0.35;
			float low = smoothstep(1.4, 0.9, y) * grime;
			float hand = smoothstep(0.25, 0.0, abs(y - 1.15)) * fbm(vec2(u * 3.0, 1.0)) * grime * 0.4;
			base *= 1.0 - (low * 0.18 + hand * 0.2) * fbm(uv * vec2(4.0, 9.0));
			float ao = scan_occlusion(l);
			ALBEDO = room_grime(base, wp, NODE_POSITION_WORLD, ao);
			AO = ao;
			ROUGHNESS = scan_roughness(l, 0.82 + fibre * 0.1) - print_mask * 0.12 + mask * 0.05;
			float height = fibre * 0.0015 + print_mask * 0.0008 - seam * 0.002 + (use_maps ? 0.0 : mottling * 0.002);
			NORMAL = BUMPED_VIEW_NORMAL(scan_normal(l, wn), height, 1.0);
		}
	}
}
