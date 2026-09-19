// Scanned maps (assets/textures/<set>/, made by tools/textures/ingest_pbr.py).
// Include after surface.gdshaderinc. hotel_geometry.apply_scan() gives a
// material the set named in its "scan" metadata and turns use_maps on;
// without one the procedural surface stays as it was.
//
// A fragment looks its maps up once (MapLookup l = map_lookup(uv)) and passes
// that to scan_albedo(), scan_roughness(), scan_occlusion(), scan_normal().

group_uniforms image_maps;
uniform bool use_maps = false;
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// Occlusion, roughness, metalness.
uniform sampler2D orm_map : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
// Replace: the scan's colour times map_tint. Recolour: map_tint, lightened
// and darkened as the scan is (its mean becomes map_tint; by luminance, so a
// saturated scan's weak channels never blow up). Detail: the procedural
// colour, lightened and darkened as the scan is (map_detail of it).
uniform int map_mode : hint_enum("Replace", "Recolour", "Detail") = 1;
uniform vec4 map_tint : source_color = vec4(1.0);
uniform float map_detail : hint_range(0.0, 2.0) = 1.0;
uniform float normal_strength = 1.0;
// Added to the scan's roughness.
uniform float map_roughness : hint_range(-1.0, 1.0) = 0.0;
// How much of the scan's metalness is kept (none for cloth with a metal thread).
uniform float map_metallic : hint_range(0.0, 1.0) = 1.0;
// Real width of one repetition of the scan.
uniform float map_metres = 1.0;
// For random-looking scans (stucco, pile, plain paper): every repetition is
// shifted by a noise, so no stain or fleck repeats across a room. Never for
// laid or printed ones (tiles, boards): their joints would break. Only where
// the preset works the finest detail out (surface_detail).
uniform bool map_no_tile = false;
group_uniforms;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

struct MapLookup {
	vec2 a;
	vec2 b;
	float blend;
	vec2 dx;
	vec2 dy;
};

vec2 map_uv() { return face_uv() / max(map_metres, 0.01); }

// uv in repetitions. The derivatives are taken before the shift, so the
// jumps between shifted patches never pick a blurred mip.
MapLookup map_lookup(vec2 uv) {
	MapLookup l;
	l.dx = dFdx(uv);
	l.dy = dFdy(uv);
	l.a = uv;
	l.b = uv;
	l.blend = 0.0;
	if (map_no_tile && surface_detail >= 2.5) {
		float k = vnoise(uv * 0.7) * 8.0;
		float i = floor(k);
		l.a = uv + sin(vec2(3.0, 7.0) * i);
		l.b = uv + sin(vec2(3.0, 7.0) * (i + 1.0));
		l.blend = smoothstep(0.25, 0.75, fract(k));
	}
	return l;
}

vec4 map_sample(sampler2D map, MapLookup l) {
	vec4 a = textureGrad(map, l.a, l.dx, l.dy);
	if (l.blend <= 0.0) return a;
	return mix(a, textureGrad(map, l.b, l.dx, l.dy), l.blend);
}

vec3 scan_albedo(MapLookup l, vec3 procedural) {
	if (!use_maps) return procedural;
	vec3 scan = map_sample(albedo_map, l).rgb;
	if (map_mode == 0) return scan * map_tint.rgb;
	// The smallest mip is the scan's mean colour.
	vec3 mean = textureLod(albedo_map, vec2(0.5), 12.0).rgb;
	float ratio = dot(scan, LUMA) / max(dot(mean, LUMA), 0.005);
	if (map_mode == 1) return ratio * map_tint.rgb;
	return procedural * max(mix(1.0, ratio, map_detail), 0.0);
}

float scan_roughness(MapLookup l, float procedural) {
	if (!use_maps) return procedural;
	return clamp(map_sample(orm_map, l).g + map_roughness, 0.02, 1.0);
}

float scan_metallic(MapLookup l, float procedural) {
	if (!use_maps) return procedural;
	return map_sample(orm_map, l).b * map_metallic;
}

float scan_occlusion(MapLookup l) {
	if (!use_maps) return 1.0;
	return map_sample(orm_map, l).r;
}

// With the face's own tangent frame (face_uv()).
vec3 scan_normal(MapLookup l, vec3 world_normal) {
	if (!use_maps) return world_normal;
	return map_normal_world(map_sample(normal_map, l), normal_strength);
}

// With a frame of the shader's own (uv along tangent and bitangent).
vec3 scan_normal_frame(MapLookup l, vec3 world_normal, vec3 tangent, vec3 bitangent) {
	if (!use_maps) return world_normal;
	vec2 xy = map_sample(normal_map, l).xy * 2.0 - 1.0;
	float z = sqrt(clamp(1.0 - dot(xy, xy), 0.0, 1.0));
	xy *= normal_strength;
	return normalize(tangent * xy.x + bitangent * xy.y + world_normal * max(z, 0.05));
}
