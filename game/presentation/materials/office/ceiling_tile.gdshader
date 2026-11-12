shader_type spatial;
// The offices' acoustic ceiling tiles (spec_rediseno 2): cream gone yellow,
// no two tiles of the world's 0.6 m lattice quite alike (some yellower, a
// water ring on some, a hairline crack on a few), darker at each tile's edge
// where the grid holds it.
#include "res://game/presentation/shaders/surface.gdshaderinc"
#include "res://game/presentation/shaders/image_maps.gdshaderinc"

uniform vec4 base_color : source_color = vec4(0.70, 0.66, 0.55, 1.0);
uniform vec4 yellow_color : source_color = vec4(0.66, 0.58, 0.40, 1.0);
uniform vec4 stain_color : source_color = vec4(0.47, 0.39, 0.25, 1.0);
uniform float tile = 0.6;
uniform float yellowed : hint_range(0.0, 1.0) = 0.3;
uniform float ringed : hint_range(0.0, 1.0) = 0.12;
uniform float cracked : hint_range(0.0, 1.0) = 0.05;

void vertex() { SURFACE_VERTEX; }

void fragment() {
	vec2 cell = wp.xz / tile;
	vec2 id = floor(cell);
	vec2 f = fract(cell);
	// Only the face of a tile laid in the grid follows the lattice: a tile
	// hanging, fallen or turned up is plain.
	float laid = step(0.95, -wn.y);
	float yellow = step(1.0 - yellowed, hash12(id + 1.0)) * (0.5 + 0.5 * hash12(id + 13.0)) * laid;
	if (baked_surface()) {
		vec3 baked = baked_albedo(face_uv(), NODE_POSITION_WORLD, true);
		ALBEDO = mix(baked, baked * yellow_color.rgb / base_color.rgb, yellow * 0.6);
		ROUGHNESS = 0.95;
	} else {
		vec2 uv = face_uv();
		// The scanned stucco (Detail) over each tile's own colour.
		MapLookup l = map_lookup(map_uv());
		float stipple = use_maps ? 0.5 : fine_noise(uv * 70.0) * 0.6 + fine_noise(uv * 190.0) * 0.4;
		vec3 color = mix(base_color.rgb, yellow_color.rgb, yellow) * (0.9 + stipple * 0.12);
		color = scan_albedo(l, color);
		// A water ring: a stained patch with a tide mark, off the tile's middle.
		vec2 at = vec2(hash12(id + 17.0), hash12(id + 23.0)) * 0.5 + 0.25;
		// Its edge wanders (noise on the radius): a perfect circle read as a decal.
		float r = length(f - at) * tile * (0.75 + fbm((f - at) * 5.0 + id * 3.7) * 0.5);
		float size = 0.08 + hash12(id + 29.0) * 0.14;
		float ring = step(1.0 - ringed, hash12(id + 5.0)) * laid;
		float inside = smoothstep(size, size * 0.6, r) * ring;
		float tide = smoothstep(0.012, 0.0, abs(r - size)) * ring;
		color = mix(color, color * stain_color.rgb / base_color.rgb, inside * 0.35);
		color *= 1.0 - tide * 0.3;
		// A hairline crack across a few.
		float crack = smoothstep(0.01, 0.0, abs(fbm(f * 3.0 + id) - 0.5)) * step(1.0 - cracked, hash12(id + 9.0)) * laid;
		color *= 1.0 - crack * 0.5;
		// Darker where the grid holds the tile.
		vec2 edge = min(f, 1.0 - f) * tile;
		color *= 1.0 - smoothstep(0.02, 0.0, min(edge.x, edge.y)) * 0.12 * laid;
		float ao = scan_occlusion(l);
		ALBEDO = room_grime(color, wp, NODE_POSITION_WORLD, ao);
		AO = ao;
		ROUGHNESS = scan_roughness(l, 0.95);
		NORMAL = BUMPED_VIEW_NORMAL(scan_normal(l, wn), stipple * 0.004 - crack * 0.001 + plane_swell(uv), 1.0);
	}
}
