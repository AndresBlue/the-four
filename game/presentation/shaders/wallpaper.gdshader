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

void vertex() { SURFACE_VERTEX; }

void fragment() {
	vec2 uv = face_uv();
	float u = uv.x;
	float y = wp.y;
	if (abs(wn.y) > 0.5) {
		// Wall tops and undersides: bare plaster.
		float n = fbm(wp.xz * 9.0);
		ALBEDO = edge_color.rgb * (0.9 + n * 0.15);
		ROUGHNESS = 0.9;
	} else {
		float roll = floor(u / roll_width);
		float in_roll = fract(u / roll_width);
		// Printed motif: alternating ogee drops with a thin stripe between rolls.
		vec2 cell = vec2(in_roll * 2.0, y / motif_height + mod(roll, 2.0) * 0.5);
		vec2 q = fract(cell) - 0.5;
		float ogee = smoothstep(0.23, 0.2, abs(abs(q.x) - 0.25 * cos(q.y * 6.2831)) );
		float dots = smoothstep(0.06, 0.04, length(q - vec2(0.0, 0.0)));
		float stripe = smoothstep(0.035, 0.02, abs(in_roll - 0.5)) * 0.6;
		float print_mask = clamp(ogee * 0.8 + dots + stripe, 0.0, 1.0) * print_strength;
		float fibre = vnoise(uv * vec2(160.0, 40.0));
		float mottling = fbm(uv * 1.7);
		vec3 base = mix(paper_color.rgb, print_color.rgb, print_mask);
		base *= 0.97 + hash12(vec2(roll, 3.0)) * 0.03 + (mottling - 0.5) * 0.12 + (fibre - 0.5) * 0.04;
		base = albedo_or(base);
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
		ALBEDO = base;
		ROUGHNESS = roughness_or(0.82 + fibre * 0.1 - print_mask * 0.12 + mask * 0.05);
		float height = fibre * 0.0015 + print_mask * 0.0008 - seam * 0.002 + mottling * 0.002;
		NORMAL = BUMPED_VIEW_NORMAL(normal_or(wn), height, 1.0);
	}
}
