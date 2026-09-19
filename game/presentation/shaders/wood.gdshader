shader_type spatial;
// Lacquered hotel wood: growth rings, pores, panel grooves and scuffed varnish.
// object_space keeps the grain fixed to moving pieces such as door leaves.
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

void vertex() {
	if (object_space) {
		wp = VERTEX;
		wn = NORMAL;
	} else {
		SURFACE_VERTEX;
	}
}

void fragment() {
	vec2 uv = face_uv();
	// Grain runs horizontally on vertical faces and along X on flat faces.
	vec2 g = vec2(uv.x, uv.y);
	float warp = fbm(g * vec2(0.6, 7.0) + plane_offset() * 17.0);
	float rings = fract((g.y + warp * 0.12) * ring_density);
	float ring_line = smoothstep(0.0, 0.55, rings) * smoothstep(1.0, 0.8, rings);
	float pores = smoothstep(0.62, 0.8, fine_noise(g * vec2(8.0, 420.0)));
	vec3 color = mix(dark_color.rgb, light_color.rgb, 0.35 + ring_line * 0.45 + (warp - 0.5) * 0.4);
	color *= 1.0 - pores * 0.25;
	color = albedo_or(color);
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
	ALBEDO = color;
	ROUGHNESS = roughness_or(mix(0.75, 0.28, varnish) + dull * 0.25 + scratch * 0.2);
	SPECULAR = 0.5;
	float height = ring_line * 0.0004 - pores * 0.0005 - groove * 0.004;
	vec3 n = bump_world(normal_or(wn), dFdx(wp), dFdy(wp), dFdx(height), dFdy(height), 1.0);
	if (object_space) n = normalize(mat3(MODEL_MATRIX) * n);
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
}
