shader_type spatial;
// Glazed service-area tiles with dirty grout, uneven glaze and hairline cracks.
#include "res://game/presentation/shaders/surface.gdshaderinc"
#include "res://game/presentation/shaders/image_maps.gdshaderinc"

uniform vec4 tile_color : source_color = vec4(0.58, 0.58, 0.5, 1.0);
uniform vec4 alternate_color : source_color = vec4(0.5, 0.5, 0.43, 1.0);
uniform vec4 grout_color : source_color = vec4(0.36, 0.34, 0.28, 1.0);
uniform float tile_size = 0.3;
uniform float grout_width = 0.0035;
uniform float checker : hint_range(0.0, 1.0) = 0.35;
uniform float grime : hint_range(0.0, 1.0) = 0.6;

void vertex() { SURFACE_VERTEX; }

void fragment() {
	vec2 uv = face_uv();
	vec2 cell = uv / tile_size;
	vec2 id = floor(cell);
	vec2 f = fract(cell);
	vec2 edge = min(f, 1.0 - f) * tile_size;
	float grout = smoothstep(grout_width, grout_width * 0.4, min(edge.x, edge.y));
	float bevel = smoothstep(grout_width * 3.0, grout_width, min(edge.x, edge.y));
	float check = mod(id.x + id.y, 2.0);
	vec3 color = mix(tile_color.rgb, alternate_color.rgb, check * checker);
	color *= 0.94 + hash12(id) * 0.08 + (vnoise(uv * 12.0) - 0.5) * 0.05;
	color = albedo_or(color);
	float dirt = smoothstep(0.3, 0.8, fbm(uv * 1.5)) * grime + grout * grime * 0.5;
	float crack = smoothstep(0.012, 0.0, abs(fbm(uv * 6.0 + id) - 0.5)) * step(0.86, hash12(id + 7.0));
	color = mix(color, grout_color.rgb, grout);
	color *= 1.0 - dirt * 0.3 - crack * 0.4;
	ALBEDO = color;
	// Worn glaze: satin rather than mirror, so lamps do not paint hard glints.
	ROUGHNESS = roughness_or(mix(0.34 + dirt * 0.3, 0.92, grout));
	SPECULAR = 0.42;
	float height = -grout * 0.003 - bevel * 0.0015 - crack * 0.0005;
	NORMAL = BUMPED_VIEW_NORMAL(normal_or(wn), height, 1.0);
}
