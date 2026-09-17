// Optional photographic maps. Include after surface.gdshaderinc.
// Assign images in the material Inspector and enable the matching flag;
// map_metres is the real-world width covered by one repetition of the image.

group_uniforms image_maps;
uniform bool use_albedo_map = false;
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 map_tint : source_color = vec4(1.0);
uniform bool use_normal_map = false;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float normal_strength = 1.0;
uniform bool use_roughness_map = false;
uniform sampler2D roughness_map : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float map_metres = 1.0;
group_uniforms;

vec2 map_uv() { return face_uv() / max(map_metres, 0.01); }

vec3 albedo_or(vec3 procedural) {
	return use_albedo_map ? texture(albedo_map, map_uv()).rgb * map_tint.rgb : procedural;
}

float roughness_or(float procedural) {
	return use_roughness_map ? texture(roughness_map, map_uv()).g : procedural;
}

vec3 normal_or(vec3 world_normal) {
	return use_normal_map ? map_normal_world(texture(normal_map, map_uv()), normal_strength) : world_normal;
}
