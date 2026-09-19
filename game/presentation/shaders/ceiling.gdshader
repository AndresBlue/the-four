shader_type spatial;
// Stippled "popcorn" ceiling, yellowed by smoke with damp patches.
#include "res://game/presentation/shaders/surface.gdshaderinc"
#include "res://game/presentation/shaders/image_maps.gdshaderinc"

uniform vec4 base_color : source_color = vec4(0.66, 0.63, 0.53, 1.0);
uniform vec4 stain_color : source_color = vec4(0.45, 0.37, 0.22, 1.0);
uniform float stains : hint_range(0.0, 1.0) = 0.6;

void vertex() { SURFACE_VERTEX; }

void fragment() {
	vec2 uv = face_uv();
	// The scanned stucco (Detail) takes the place of the procedural stipple.
	MapLookup l = map_lookup(map_uv());
	float stipple = use_maps ? 0.5 : fine_noise(uv * 70.0) * 0.6 + fine_noise(uv * 190.0) * 0.4;
	float blotch = fbm(uv * 0.45);
	vec3 color = base_color.rgb * (0.9 + stipple * 0.12);
	color = scan_albedo(l, color);
	float damp = smoothstep(0.6, 0.72, blotch) * stains;
	float edge = smoothstep(0.015, 0.0, abs(blotch - 0.66)) * stains;
	color = mix(color, stain_color.rgb, damp * 0.55);
	color *= 1.0 - edge * 0.25;
	float ao = scan_occlusion(l);
	ALBEDO = room_grime(color, wp, NODE_POSITION_WORLD, ao);
	AO = ao;
	ROUGHNESS = scan_roughness(l, 0.95);
	NORMAL = BUMPED_VIEW_NORMAL(scan_normal(l, wn), stipple * 0.004, 1.0);
}
