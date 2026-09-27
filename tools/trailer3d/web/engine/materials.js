// The hotel's surfaces, ported from the game's shaders
// (game/presentation/shaders/*.gdshader) onto three.js' standard material, so
// light, shadow and reflection stay physically based. Same world-space
// mapping (every surface is an axis-aligned box face), same patterns, same
// scanned sets and parameters as game/presentation/materials/*.tres.
import * as THREE from "three";
import { scan } from "./assets.js";

const srgb = (r, g, b) => new THREE.Color().setRGB(r, g, b, THREE.SRGBColorSpace);

const COMMON = /* glsl */ `
varying vec3 vWp;
varying vec3 vWn;
uniform sampler2D uAlbedo;
uniform sampler2D uNormal;
uniform sampler2D uOrm;
uniform float uUseMaps;
uniform int uMapMode;
uniform vec3 uMapTint;
uniform float uMapDetail;
uniform float uNormalStrength;
uniform float uMapRoughness;
uniform float uMapMetallic;
uniform float uMapMetres;
uniform float uNoTile;
vec3 S_albedo;
float S_rough;
float S_metal;
float S_ao;
vec3 S_nw;
const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);
float hash12(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float hash13(vec3 p) { p = fract(p * 0.1031); p += dot(p, p.zyx + 31.32); return fract((p.x + p.y) * p.z); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float value = 0.0; float amplitude = 0.5;
	for (int i = 0; i < 4; i++) { value += vnoise(p) * amplitude; p = p * 2.03 + vec2(17.1, 9.2); amplitude *= 0.5; }
	return value;
}
float fine_noise(vec2 p) { return vnoise(p); }
vec2 face_uv() {
	vec3 a = abs(vWn);
	if (a.y > a.x && a.y > a.z) return vec2(vWp.x, vWp.z * sign(vWn.y));
	if (a.x > a.z) return vec2(-vWp.z * sign(vWn.x), -vWp.y);
	return vec2(vWp.x * sign(vWn.z), -vWp.y);
}
vec3 face_tangent() {
	vec3 a = abs(vWn);
	if (a.y > a.x && a.y > a.z) return vec3(1.0, 0.0, 0.0);
	if (a.x > a.z) return vec3(0.0, 0.0, -sign(vWn.x));
	return vec3(sign(vWn.z), 0.0, 0.0);
}
vec3 face_bitangent() {
	vec3 a = abs(vWn);
	if (a.y > a.x && a.y > a.z) return vec3(0.0, 0.0, -sign(vWn.y));
	return vec3(0.0, 1.0, 0.0);
}
float plane_offset() { return dot(sign(vWn) * step(0.5, abs(vWn)), vec3(0.37, 0.71, 0.13)); }
struct MapLookup { vec2 a; vec2 b; float blend; vec2 dx; vec2 dy; };
vec2 map_uv() { return face_uv() / max(uMapMetres, 0.01); }
MapLookup map_lookup(vec2 uv) {
	MapLookup l; l.dx = dFdx(uv); l.dy = dFdy(uv); l.a = uv; l.b = uv; l.blend = 0.0;
	if (uNoTile > 0.5) {
		float k = vnoise(uv * 0.7) * 8.0; float i = floor(k);
		l.a = uv + sin(vec2(3.0, 7.0) * i); l.b = uv + sin(vec2(3.0, 7.0) * (i + 1.0));
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
	if (uUseMaps < 0.5) return procedural;
	vec3 s = map_sample(uAlbedo, l).rgb;
	if (uMapMode == 0) return s * uMapTint;
	vec3 mean = textureLod(uAlbedo, vec2(0.5), 12.0).rgb;
	float ratio = dot(s, LUMA) / max(dot(mean, LUMA), 0.005);
	if (uMapMode == 1) return ratio * uMapTint;
	return procedural * max(mix(1.0, ratio, uMapDetail), 0.0);
}
float scan_roughness(MapLookup l, float procedural) { if (uUseMaps < 0.5) return procedural; return clamp(map_sample(uOrm, l).g + uMapRoughness, 0.02, 1.0); }
float scan_metallic(MapLookup l, float procedural) { if (uUseMaps < 0.5) return procedural; return map_sample(uOrm, l).b * uMapMetallic; }
float scan_occlusion(MapLookup l) { if (uUseMaps < 0.5) return 1.0; return map_sample(uOrm, l).r; }
vec3 map_normal_world(vec4 encoded, float strength, vec3 t, vec3 b) {
	vec2 xy = encoded.xy * 2.0 - 1.0; float z = sqrt(clamp(1.0 - dot(xy, xy), 0.0, 1.0)); xy *= strength;
	return normalize(t * xy.x + b * xy.y + vWn * max(z, 0.05));
}
vec3 scan_normal(MapLookup l, vec3 wn) { if (uUseMaps < 0.5) return wn; return map_normal_world(map_sample(uNormal, l), uNormalStrength, face_tangent(), face_bitangent()); }
vec3 bump_world(vec3 base, float h, float strength) {
	vec3 dpdx = dFdx(vWp); vec3 dpdy = dFdy(vWp); float dhdx = dFdx(h); float dhdy = dFdy(h);
	vec3 r1 = cross(dpdy, base); vec3 r2 = cross(base, dpdx); float det = dot(dpdx, r1);
	if (abs(det) < 1e-8) return base;
	vec3 grad = sign(det) * (dhdx * r1 + dhdy * r2) * strength;
	return normalize(abs(det) * base - grad);
}
// Dust along the skirting and old damp under the ceiling (surface.gdshaderinc's
// room_grime without the per-room data: by height in the room).
uniform float uCeiling;
vec3 room_grime(vec3 color, inout float ao) {
	float h = max(vWp.y, 0.0);
	float t = max(uCeiling - vWp.y, 0.0);
	float patchy = 0.6 + 0.8 * vnoise(vWp.xz * 3.1 + vWp.y * 2.3);
	float by_floor = exp(-h * 6.0) * (abs(vWn.y) < 0.5 ? 1.0 : 0.0);
	float by_ceiling = exp(-t * 2.5) * (abs(vWn.y) < 0.5 ? 1.0 : 0.0);
	color = mix(color, color * vec3(0.72, 0.62, 0.5), clamp(by_floor * patchy, 0.0, 1.0) * 0.5);
	color = mix(color, color * vec3(0.86, 0.78, 0.6), clamp(by_ceiling * patchy, 0.0, 1.0) * 0.45);
	ao *= 1.0 - (by_floor + by_ceiling) * 0.25;
	return color;
}
`;

const SURFACES = {
	wallpaper: /* glsl */ `
	uniform vec3 paper_color; uniform vec3 print_color; uniform vec3 stain_color; uniform vec3 edge_color;
	uniform float roll_width; uniform float motif_height; uniform float print_strength; uniform float stains; uniform float grime; uniform float ink_bleed;
	void surface() {
		vec2 uv = face_uv();
		float u = uv.x; float y = vWp.y;
		S_metal = 0.0; S_ao = 1.0;
		if (abs(vWn.y) > 0.5) {
			float n = fbm(vWp.xz * 9.0);
			S_albedo = edge_color * (0.9 + n * 0.15); S_rough = 0.9; S_nw = vWn; return;
		}
		MapLookup l = map_lookup(map_uv());
		vec2 bleed = uUseMaps > 0.5 ? (map_sample(uNormal, l).xy * 2.0 - 1.0) * ink_bleed : vec2(0.0);
		u += bleed.x; y += bleed.y;
		float roll = floor(u / roll_width);
		float in_roll = fract(u / roll_width);
		vec2 cell = vec2(in_roll * 2.0, y / motif_height + mod(roll, 2.0) * 0.5);
		vec2 q = fract(cell) - 0.5;
		float ogee = smoothstep(0.23, 0.2, abs(abs(q.x) - 0.25 * cos(q.y * 6.2831)));
		float dots = smoothstep(0.06, 0.04, length(q));
		float stripe = smoothstep(0.035, 0.02, abs(in_roll - 0.5)) * 0.6;
		float print_mask = clamp(ogee * 0.8 + dots + stripe, 0.0, 1.0) * print_strength;
		float fibre = uUseMaps > 0.5 ? 0.5 : fine_noise(uv * vec2(160.0, 40.0));
		float mottling = fbm(uv * 1.7);
		vec3 base = mix(paper_color, print_color, print_mask);
		base *= 0.97 + hash12(vec2(roll, 3.0)) * 0.03 + (mottling - 0.5) * 0.12 + (fibre - 0.5) * 0.04;
		if (uUseMaps > 0.5 && uMapMode != 2) { vec3 s = scan_albedo(l, base); base = mix(s, s * base / paper_color, print_strength); }
		else base = scan_albedo(l, base);
		float seam = smoothstep(0.012, 0.0, min(in_roll, 1.0 - in_roll) * roll_width);
		float lifted = smoothstep(0.55, 0.8, vnoise(vec2(roll * 3.1, y * 1.7))) * seam;
		base = mix(base, base * 0.7, seam * 0.4) + lifted * 0.03;
		float stain_field = fbm(vec2(u * 0.55, y * 0.9) + plane_offset() * 13.0);
		float top = smoothstep(1.6, 3.2, y);
		float mask = smoothstep(0.62 - top * 0.12, 0.7, stain_field) * stains * (0.35 + top);
		float ring = smoothstep(0.02, 0.0, abs(stain_field - (0.66 - top * 0.12))) * stains * top;
		base = mix(base, base * stain_color * 1.6, clamp(mask * 0.7, 0.0, 0.8));
		base *= 1.0 - ring * 0.35;
		float low = smoothstep(1.4, 0.9, y) * grime;
		float hand = smoothstep(0.25, 0.0, abs(y - 1.15)) * fbm(vec2(u * 3.0, 1.0)) * grime * 0.4;
		base *= 1.0 - (low * 0.18 + hand * 0.2) * fbm(uv * vec2(4.0, 9.0));
		float ao = scan_occlusion(l);
		S_albedo = room_grime(base, ao);
		S_ao = ao;
		S_rough = scan_roughness(l, 0.82 + fibre * 0.1) - print_mask * 0.12 + mask * 0.05;
		float height = fibre * 0.0015 + print_mask * 0.0008 - seam * 0.002 + (uUseMaps > 0.5 ? 0.0 : mottling * 0.002);
		S_nw = bump_world(scan_normal(l, vWn), height, 1.0);
	}`,
	carpet: /* glsl */ `
	uniform vec3 base_color; uniform vec3 field_color; uniform vec3 line_color; uniform vec3 accent_color;
	uniform float tile_size; uniform float pattern; uniform float wear; uniform float fibre_bleed;
	void surface() {
		vec2 uv = vWp.xz;
		vec3 color; float motif = 0.0;
		MapLookup l = map_lookup(map_uv());
		if (vWn.y > 0.5) {
			vec2 tufts = uUseMaps > 0.5 ? (map_sample(uNormal, l).xy * 2.0 - 1.0) * fibre_bleed : vec2(0.0);
			vec2 cell = (uv + tufts) / tile_size;
			vec2 q = fract(cell) - 0.5; vec2 id = floor(cell); vec2 a = abs(q);
			float octagon = max(max(a.x, a.y), (a.x + a.y) * 0.72);
			float ring = smoothstep(0.022, 0.01, abs(octagon - 0.32));
			float inner = smoothstep(0.17, 0.15, octagon);
			float cross_mark = smoothstep(0.03, 0.015, min(a.x, a.y)) * step(octagon, 0.14);
			float lattice = smoothstep(0.02, 0.008, abs(abs(q.x) + abs(q.y) - 0.9) * 0.7);
			float corner = smoothstep(0.1, 0.08, length(a - 0.5));
			color = field_color;
			color = mix(color, line_color, clamp(ring + lattice, 0.0, 1.0));
			color = mix(color, accent_color, clamp(inner * (1.0 - cross_mark) + corner, 0.0, 1.0) * 0.85);
			color = mix(color, line_color * 0.8, cross_mark);
			motif = ring + lattice;
			color = mix(base_color, color, pattern);
			color = mix(color, field_color, 0.25 + 0.2 * vnoise(uv * 6.0));
			color *= 0.94 + hash12(id) * 0.06;
		} else color = base_color * 0.6;
		color = scan_albedo(l, color);
		float pile = uUseMaps > 0.5 ? 0.5 : fine_noise(uv * 260.0) * 0.6 + fine_noise(uv * 90.0 + 3.0) * 0.4;
		float brush = fbm(uv * 0.9 + vec2(4.0, 1.0));
		color *= 0.84 + pile * 0.22 + (brush - 0.5) * 0.14;
		float traffic = smoothstep(0.45, 0.8, fbm(uv * 0.22)) * wear;
		color = mix(color, vec3(dot(color, vec3(0.33))) * 1.15, traffic * 0.35);
		float stain = smoothstep(0.7, 0.76, fbm(uv * 0.8 + 11.0)) * wear;
		color *= 1.0 - stain * 0.35;
		float ao = scan_occlusion(l);
		S_albedo = color; S_ao = ao; S_metal = 0.0;
		S_rough = scan_roughness(l, 0.97) - traffic * 0.05;
		float height = pile * 0.002 - motif * 0.0006 * pattern;
		S_nw = bump_world(normalize(mix(scan_normal(l, vWn), vWn, traffic * 0.5)), height, 1.0);
	}`,
	wood: /* glsl */ `
	uniform vec3 light_color; uniform vec3 dark_color; uniform float ring_density; uniform float varnish; uniform float scuffs;
	uniform float panel_spacing; uniform float grain_vertical;
	void surface() {
		vec2 uv = face_uv();
		vec3 t = grain_vertical > 0.5 ? face_bitangent() : face_tangent();
		vec3 b = cross(vWn, t);
		vec2 g = grain_vertical > 0.5 ? vec2(-uv.y, uv.x) : uv;
		g += vec2(hash13(floor(vWp * 0.5)) * 5.0, 0.0);
		float warp = fbm(g * vec2(0.6, 7.0) + plane_offset() * 17.0);
		float rings = fract((g.y + warp * 0.12) * ring_density);
		float ring_line = smoothstep(0.0, 0.55, rings) * smoothstep(1.0, 0.8, rings);
		float pores = smoothstep(0.62, 0.8, fine_noise(g * vec2(8.0, 420.0)));
		vec3 color = mix(dark_color, light_color, 0.35 + ring_line * 0.45 + (warp - 0.5) * 0.4);
		color *= 1.0 - pores * 0.25;
		MapLookup l = map_lookup(g / max(uMapMetres, 0.01));
		color = scan_albedo(l, color);
		float groove = 0.0;
		if (panel_spacing > 0.0 && abs(vWn.y) < 0.5) {
			float p = fract(uv.x / panel_spacing);
			groove = smoothstep(0.012, 0.0, min(p, 1.0 - p) * panel_spacing);
		}
		color *= 1.0 - groove * 0.5;
		float scratch = smoothstep(0.93, 1.0, vnoise(g * vec2(3.0, 90.0) + 7.0)) * scuffs;
		float dull = fbm(g * 2.2) * scuffs;
		color = mix(color, color * 1.35 + 0.02, scratch * 0.5);
		float ao = scan_occlusion(l);
		S_albedo = room_grime(color, ao); S_ao = ao; S_metal = 0.0;
		float lacquer = mix(0.75, 0.28, varnish);
		S_rough = (uUseMaps > 0.5 ? mix(scan_roughness(l, lacquer), lacquer, 0.5) : lacquer) + dull * 0.25 + scratch * 0.2;
		float height = (uUseMaps > 0.5 ? 0.0 : ring_line * 0.0004 - pores * 0.0005) - groove * 0.004;
		vec3 n = vWn;
		if (uUseMaps > 0.5) { vec2 xy = map_sample(uNormal, l).xy * 2.0 - 1.0; float z = sqrt(clamp(1.0 - dot(xy, xy), 0.0, 1.0)); xy *= uNormalStrength; n = normalize(t * xy.x + b * xy.y + vWn * max(z, 0.05)); }
		S_nw = bump_world(n, height, 1.0);
	}`,
	finish: /* glsl */ `
	uniform vec3 f_albedo; uniform vec3 f_variation; uniform float f_roughness; uniform float f_metallic;
	uniform int finish; uniform float detail_scale; uniform float relief; uniform float grime;
	void surface() {
		vec2 uv = face_uv() * detail_scale;
		float large = fbm(uv * 1.3 + plane_offset() * 9.0);
		float height = 0.0; float rough = f_roughness;
		vec3 color = mix(f_variation, f_albedo, 0.55 + large * 0.45);
		if (finish == 1) {
			float streak = fine_noise(uv * vec2(3.0, 600.0)) * 0.7 + vnoise(uv * vec2(1.0, 150.0)) * 0.3;
			color *= 0.9 + streak * 0.15;
			rough = clamp(f_roughness + (streak - 0.5) * 0.18 + large * 0.1, 0.05, 1.0);
			height = streak * 0.0002;
		} else if (finish == 3) {
			float crumple = fbm(uv * 5.0) * 0.7 + fbm(uv * 14.0 + 3.0) * 0.3;
			color *= 0.9 + crumple * 0.14;
			height = crumple * 0.012;
		} else {
			float speck = fine_noise(uv * 220.0);
			color *= 0.95 + speck * 0.08;
			height = speck * 0.0002;
		}
		MapLookup l = map_lookup(map_uv());
		color = scan_albedo(l, color);
		if (uUseMaps > 0.5) height *= 0.2;
		float dirt = smoothstep(0.6, 0.9, fbm(uv * 1.7 + 5.0)) * grime * 0.6;
		dirt += smoothstep(0.35, 0.0, vWp.y) * grime * 0.4;
		color *= 1.0 - clamp(dirt, 0.0, 1.0) * 0.35;
		float ao = scan_occlusion(l);
		S_albedo = color; S_ao = ao;
		S_metal = scan_metallic(l, f_metallic);
		S_rough = clamp((uUseMaps > 0.5 ? scan_roughness(l, rough) : rough) + dirt * 0.25, 0.02, 1.0);
		S_nw = bump_world(scan_normal(l, vWn), height, relief);
	}`,
	stucco: /* glsl */ `
	uniform vec3 base_color; uniform float stains;
	void surface() {
		vec2 uv = face_uv();
		MapLookup l = map_lookup(map_uv());
		float n = fbm(uv * 1.3);
		vec3 color = base_color * (0.92 + n * 0.12);
		color = scan_albedo(l, color);
		float stain_field = fbm(uv * 0.35 + 7.0);
		float mask = smoothstep(0.62, 0.72, stain_field) * stains;
		float ring = smoothstep(0.015, 0.0, abs(stain_field - 0.665)) * stains;
		color = mix(color, color * vec3(0.72, 0.6, 0.42), mask * 0.55);
		color *= 1.0 - ring * 0.3;
		float ao = scan_occlusion(l);
		S_albedo = color; S_ao = ao; S_metal = 0.0;
		S_rough = scan_roughness(l, 0.92);
		S_nw = scan_normal(l, vWn);
	}`,
	tile: /* glsl */ `
	uniform vec3 base_color; uniform vec3 grout_color; uniform float tile_count; uniform float stains;
	void surface() {
		vec2 uv = face_uv();
		MapLookup l = map_lookup(map_uv());
		float size = uMapMetres / tile_count;
		vec2 cell = uv / size; vec2 f = fract(cell); vec2 id = floor(cell);
		float grout = 1.0 - smoothstep(0.0, 0.035, min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)));
		vec3 color = scan_albedo(l, base_color) * (0.94 + hash12(id) * 0.1);
		float dirt = fbm(uv * 0.8 + 3.0);
		color = mix(color, grout_color * (0.7 + dirt * 0.4), grout);
		float stain = smoothstep(0.66, 0.74, fbm(uv * 0.5 + 9.0)) * stains;
		color *= 1.0 - stain * 0.3;
		float ao = scan_occlusion(l);
		S_albedo = room_grime(color, ao); S_ao = ao; S_metal = 0.0;
		S_rough = mix(scan_roughness(l, 0.2), 0.9, grout);
		S_nw = bump_world(scan_normal(l, vWn), -grout * 0.002, 1.0);
	}`,
};

// Parameters of game/presentation/materials/*.tres (colours in sRGB as there).
export const PRESETS = {
	wallpaper: { surface: "wallpaper", scan: "wallpaper001a", mapMetres: 1.2, mapMode: 2, mapDetail: 2.0, noTile: true, mapRoughness: 0.16, normalStrength: 1.5,
		u: { paper_color: srgb(0.62, 0.55, 0.40), print_color: srgb(0.47, 0.40, 0.27), stain_color: srgb(0.33, 0.25, 0.14), edge_color: srgb(0.55, 0.52, 0.46), roll_width: 0.53, motif_height: 0.46, print_strength: 0.55, stains: 0.55, grime: 0.5, ink_bleed: 0.03 } },
	wallpaperDecrepit: { surface: "wallpaper", scan: "decrepit_wallpaper", mapMetres: 2.5, mapMode: 1, mapDetail: 1.0, noTile: true, mapTint: srgb(0.55, 0.47, 0.34), mapRoughness: -0.1, normalStrength: 1,
		u: { paper_color: srgb(0.62, 0.55, 0.40), print_color: srgb(0.47, 0.40, 0.27), stain_color: srgb(0.33, 0.25, 0.14), edge_color: srgb(0.55, 0.52, 0.46), roll_width: 0.53, motif_height: 0.46, print_strength: 0.3, stains: 0.8, grime: 0.8, ink_bleed: 0.03 } },
	carpet: { surface: "carpet", scan: "carpet016", mapMetres: 0.9, mapMode: 2, mapDetail: 1.8, noTile: true, mapRoughness: 0.3, normalStrength: 1.4,
		u: { base_color: srgb(0.32, 0.27, 0.2), field_color: srgb(0.19, 0.075, 0.055), line_color: srgb(0.33, 0.22, 0.11), accent_color: srgb(0.13, 0.075, 0.05), tile_size: 0.62, pattern: 1.0, wear: 0.6, fibre_bleed: 0.035 } },
	panel: { surface: "wood", scan: "dark_wood", mapMetres: 2.0, mapMode: 1, mapTint: srgb(0.25, 0.14, 0.072), normalStrength: 1,
		u: { light_color: srgb(0.3, 0.17, 0.09), dark_color: srgb(0.13, 0.07, 0.04), ring_density: 22, varnish: 0.65, scuffs: 0.5, panel_spacing: 0.6, grain_vertical: 1 } },
	trim: { surface: "wood", scan: "dark_wood", mapMetres: 2.0, mapMode: 1, mapTint: srgb(0.22, 0.12, 0.065), normalStrength: 1,
		u: { light_color: srgb(0.3, 0.17, 0.09), dark_color: srgb(0.13, 0.07, 0.04), ring_density: 22, varnish: 0.7, scuffs: 0.5, panel_spacing: 0, grain_vertical: 0 } },
	cherry: { surface: "wood", scan: "lacquered_cherry_wood", mapMetres: 1.0, mapMode: 1, mapTint: srgb(0.27, 0.15, 0.08), normalStrength: 1,
		u: { light_color: srgb(0.33, 0.19, 0.1), dark_color: srgb(0.15, 0.08, 0.045), ring_density: 22, varnish: 0.65, scuffs: 0.5, panel_spacing: 0, grain_vertical: 1 } },
	brass: { surface: "finish", scan: "metal048b", mapMetres: 0.6, mapMode: 1, mapTint: srgb(0.72, 0.55, 0.27), mapRoughness: 0.15, normalStrength: 1,
		u: { f_albedo: srgb(0.72, 0.55, 0.27), f_variation: srgb(0.36, 0.28, 0.14), f_roughness: 0.32, f_metallic: 0.95, finish: 1, detail_scale: 1, relief: 1, grime: 0.5 } },
	metal: { surface: "finish", mapMetres: 0.5, normalStrength: 1,
		u: { f_albedo: srgb(0.52, 0.53, 0.52), f_variation: srgb(0.36, 0.35, 0.33), f_roughness: 0.38, f_metallic: 0.9, finish: 1, detail_scale: 1, relief: 1, grime: 0.45 } },
	black: { surface: "finish", u: { f_albedo: srgb(0.07, 0.07, 0.065), f_variation: srgb(0.05, 0.05, 0.045), f_roughness: 0.42, f_metallic: 0, finish: 0, detail_scale: 1, relief: 1, grime: 0.2 } },
	linen: { surface: "finish", u: { f_albedo: srgb(0.78, 0.75, 0.66), f_variation: srgb(0.66, 0.62, 0.52), f_roughness: 0.92, f_metallic: 0, finish: 3, detail_scale: 1, relief: 1, grime: 0.3 } },
	ceiling: { surface: "stucco", scan: "ceiling_interior", mapMetres: 1.0, mapMode: 2, mapDetail: 0.6, noTile: true, mapRoughness: 0.19, normalStrength: 0.35,
		u: { base_color: srgb(0.74, 0.71, 0.63), stains: 0.5 } },
	ceilingService: { surface: "stucco", scan: "officeceiling001", mapMetres: 3.6, mapMode: 1, mapTint: srgb(0.62, 0.6, 0.52), mapRoughness: 0.15, normalStrength: 1,
		u: { base_color: srgb(0.62, 0.6, 0.52), stains: 0.8 } },
	tile: { surface: "tile", scan: "tiles036", mapMetres: 1.6, mapMode: 1, mapTint: srgb(0.58, 0.58, 0.5), normalStrength: 1,
		u: { base_color: srgb(0.58, 0.58, 0.5), grout_color: srgb(0.3, 0.29, 0.26), tile_count: 8, stains: 0.4 } },
};

const made = new Map();

// A hotel surface material; `over` changes preset uniforms (sRGB colours as arrays).
export async function hotelMaterial(name, over = {}) {
	const key = name + JSON.stringify(over);
	if (made.has(key)) return made.get(key);
	const p = PRESETS[name];
	const maps = p.scan ? await scan(p.scan) : null;
	const m = new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 1, metalness: 0 });
	const uniforms = {
		uAlbedo: { value: maps?.albedo ?? null }, uNormal: { value: maps?.normal ?? null }, uOrm: { value: maps?.orm ?? null },
		uUseMaps: { value: maps ? 1 : 0 }, uMapMode: { value: p.mapMode ?? 1 }, uMapTint: { value: p.mapTint ?? new THREE.Color(1, 1, 1) },
		uMapDetail: { value: p.mapDetail ?? 1 }, uNormalStrength: { value: p.normalStrength ?? 1 }, uMapRoughness: { value: p.mapRoughness ?? 0 },
		uMapMetallic: { value: p.mapMetallic ?? 1 }, uMapMetres: { value: p.mapMetres ?? 1 }, uNoTile: { value: p.noTile ? 1 : 0 },
		uCeiling: { value: over.ceiling ?? 3.15 },
	};
	for (const [k, v] of Object.entries(p.u ?? {})) uniforms[k] = { value: v };
	for (const [k, v] of Object.entries(over)) {
		if (k === "ceiling") continue;
		uniforms[k] = { value: Array.isArray(v) ? srgb(...v) : v };
	}
	m.userData.uniforms = uniforms;
	m.onBeforeCompile = (shader) => {
		Object.assign(shader.uniforms, uniforms);
		shader.vertexShader = shader.vertexShader
			.replace("#include <common>", "#include <common>\nvarying vec3 vWp;\nvarying vec3 vWn;")
			.replace("#include <worldpos_vertex>", "#include <worldpos_vertex>\nvWp = (modelMatrix * vec4(transformed, 1.0)).xyz;\nvWn = normalize(mat3(modelMatrix) * objectNormal);");
		shader.fragmentShader = shader.fragmentShader
			.replace("#include <common>", "#include <common>\n" + COMMON + SURFACES[p.surface])
			.replace("#include <map_fragment>", "#include <map_fragment>\nsurface();\ndiffuseColor.rgb = S_albedo;")
			.replace("#include <roughnessmap_fragment>", "#include <roughnessmap_fragment>\nroughnessFactor = clamp(S_rough, 0.04, 1.0);")
			.replace("#include <metalnessmap_fragment>", "#include <metalnessmap_fragment>\nmetalnessFactor = S_metal;")
			.replace("#include <normal_fragment_maps>", "#include <normal_fragment_maps>\nnormal = normalize((viewMatrix * vec4(S_nw, 0.0)).xyz);")
			.replace("#include <aomap_fragment>", "#include <aomap_fragment>\nreflectedLight.indirectDiffuse *= S_ao;\nreflectedLight.indirectSpecular *= S_ao;");
	};
	m.customProgramCacheKey = () => `hotel:${p.surface}`;
	made.set(key, m);
	return m;
}
