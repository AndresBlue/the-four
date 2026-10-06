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
// Tiles across one repetition of a scanned set.
uniform float tile_count = 8.0;

void vertex() { SURFACE_VERTEX; }

void fragment() {
	if (baked_surface()) {
		ALBEDO = baked_albedo(face_uv(), NODE_POSITION_WORLD, true);
		ROUGHNESS = 0.6;
		SPECULAR = 0.42;
	} else {
		vec2 uv = face_uv();
		// A scanned set brings its own tiles and grout: the procedural ones step
		// aside, and the cells (colour variation, cracks) follow the scan's.
		MapLookup l = map_lookup(map_uv());
		float size = use_maps ? map_metres / tile_count : tile_size;
		vec2 cell = uv / size;
		vec2 id = floor(cell);
		vec2 f = fract(cell);
		vec2 edge = min(f, 1.0 - f) * size;
		float grout = use_maps ? 0.0 : smoothstep(grout_width, grout_width * 0.4, min(edge.x, edge.y));
		float bevel = use_maps ? 0.0 : smoothstep(grout_width * 3.0, grout_width, min(edge.x, edge.y));
		float check = mod(id.x + id.y, 2.0);
		vec3 color = mix(tile_color.rgb, alternate_color.rgb, check * checker);
		color *= 0.94 + hash12(id) * 0.08 + (vnoise(uv * 12.0) - 0.5) * 0.05;
		color = scan_albedo(l, vec3(1.0)) * (use_maps ? color / tile_color.rgb : color);
		// The scan's grout is its darkest, roughest part.
		float scan_grout = use_maps ? smoothstep(0.55, 0.85, map_sample(orm_map, l).g) : 0.0;
		float dirt = smoothstep(0.3, 0.8, fbm(uv * 1.5)) * grime + (grout + scan_grout) * grime * 0.5;
		float crack = smoothstep(0.012, 0.0, abs(fbm(uv * 6.0 + id) - 0.5)) * step(0.86, hash12(id + 7.0));
		color = mix(color, grout_color.rgb, grout);
		color = mix(color, color * grout_color.rgb * 2.0, scan_grout * grime);
		color *= 1.0 - dirt * 0.3 - crack * 0.4;
		float ao = scan_occlusion(l);
		ALBEDO = room_grime(color, wp, NODE_POSITION_WORLD, ao);
		AO = ao;
		// Worn glaze: satin rather than mirror, so lamps do not paint hard glints.
		ROUGHNESS = use_maps ? scan_roughness(l, 0.0) + dirt * 0.25 : mix(0.34 + dirt * 0.3, 0.92, grout);
		SPECULAR = 0.42;
		float height = -grout * 0.003 - bevel * 0.0015 - crack * 0.0005;
		vec3 n = scan_normal(l, wn);
		if (finest_surface()) {
			// No tile is bedded quite level: each throws the lamp back a little
			// its own way, and the glare on a tiled floor breaks up tile by tile.
			vec2 tilt = (vec2(hash12(id + 3.0), hash12(id + 11.0)) - 0.5) * 0.045;
			n = normalize(n + face_tangent() * tilt.x + face_bitangent() * tilt.y);
		}
		NORMAL = BUMPED_VIEW_NORMAL(n, height, 1.0);
	}
}
