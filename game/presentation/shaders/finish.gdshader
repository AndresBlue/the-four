shader_type spatial;
// Configurable finish for furniture materials: plain, brushed metal, woven
// fabric, crumpled linen or leaf. Adds micro relief and uneven grime.
#include "res://game/presentation/shaders/surface.gdshaderinc"
#include "res://game/presentation/shaders/image_maps.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 variation_color : source_color = vec4(0.4, 0.4, 0.4, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.7;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float specular : hint_range(0.0, 1.0) = 0.5;
uniform int finish : hint_enum("Plain", "Brushed", "Weave", "Crumpled", "Leaf") = 0;
uniform float detail_scale = 1.0;
uniform float relief = 1.0;
uniform float sheen : hint_range(0.0, 1.0) = 0.0;
uniform float grime : hint_range(0.0, 1.0) = 0.35;
uniform float backlight : hint_range(0.0, 1.0) = 0.0;

void vertex() { SURFACE_VERTEX; }

void fragment() {
	if (plasticine()) {
		ALBEDO = plasticine_albedo(NODE_POSITION_WORLD);
		ROUGHNESS = max(roughness, 0.5);
		SPECULAR = specular;
	} else {
		vec2 uv = face_uv() * detail_scale;
		float large = fbm(uv * 1.3 + plane_offset() * 9.0);
		float height = 0.0;
		float rough = roughness;
		vec3 color = mix(variation_color.rgb, albedo.rgb, 0.55 + large * 0.45);
		if (finish == 1) {
			float streak = fine_noise(uv * vec2(3.0, 600.0)) * 0.7 + vnoise(uv * vec2(1.0, 150.0)) * 0.3;
			color *= 0.9 + streak * 0.15;
			rough = clamp(roughness + (streak - 0.5) * 0.18 + large * 0.1, 0.05, 1.0);
			height = streak * 0.0002;
		} else if (finish == 2) {
			vec2 w = uv * 180.0;
			float weave = abs(sin(w.x)) * step(0.5, fract(w.y / 6.2831)) + abs(sin(w.y)) * step(fract(w.y / 6.2831), 0.5);
			float fuzz = fine_noise(uv * 400.0);
			color *= 0.86 + weave * 0.1 + fuzz * 0.08;
			height = weave * 0.0005 + fuzz * 0.0003;
		} else if (finish == 3) {
			float crumple = fbm(uv * 5.0) * 0.7 + fbm(uv * 14.0 + 3.0) * 0.3;
			float weave = fine_noise(uv * 300.0);
			color *= 0.9 + crumple * 0.14;
			height = crumple * 0.012 + weave * 0.0003;
		} else if (finish == 4) {
			float vein = smoothstep(0.03, 0.0, abs(fract(uv.x * 2.0) - 0.5)) + smoothstep(0.02, 0.0, abs(fract(uv.x * 9.0 + uv.y * 3.0) - 0.5)) * 0.4;
			color = mix(color, color * 1.5 + vec3(0.03, 0.05, 0.0), vein * 0.4);
			height = -vein * 0.0008 + large * 0.003;
		} else {
			float speck = fine_noise(uv * 220.0);
			color *= 0.95 + speck * 0.08;
			height = speck * 0.0002;
		}
		// A scanned cloth, leather or metal (Recolour or Replace) takes the place
		// of the procedural pattern; its relief stands for the procedural one.
		MapLookup l = map_lookup(map_uv());
		color = scan_albedo(l, color);
		if (use_maps) height *= 0.2;
		// Uneven dirt collects low on objects and in patches.
		float dirt = smoothstep(0.6, 0.9, fbm(uv * 1.7 + 5.0)) * grime * 0.6;
		dirt += smoothstep(0.35, 0.0, wp.y) * grime * 0.4;
		color *= 1.0 - clamp(dirt, 0.0, 1.0) * 0.35;
		float ao = scan_occlusion(l);
		ALBEDO = room_grime(color, wp, NODE_POSITION_WORLD, ao);
		AO = ao;
		METALLIC = scan_metallic(l, metallic);
		SPECULAR = specular;
		ROUGHNESS = clamp((use_maps ? scan_roughness(l, rough) : rough) + dirt * 0.25, 0.02, 1.0);
		if (sheen > 0.0) {
			RIM = sheen;
			RIM_TINT = 0.6;
		}
		if (backlight > 0.0) BACKLIGHT = color * backlight;
		NORMAL = BUMPED_VIEW_NORMAL(scan_normal(l, wn), height, relief);
	}
}
