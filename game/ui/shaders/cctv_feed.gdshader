shader_type canvas_item;
// The security post's camera on its monitor (security_cams.gd): a tube's curve
// and lines; `night`, a dark room by the camera's own lamp, coarse, grainy and
// pale green; `burst`, the static between two cameras; `flash`, a light coming
// on; `dim`, the picture put back for the plan drawn over it.
uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform float burst : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float dim : hint_range(0.0, 1.0) = 0.0;

#include "res://game/presentation/shaders/tape_snow.gdshaderinc"

void fragment() {
	vec2 c = UV - 0.5;
	vec2 uv = UV + c * dot(c, c) * 0.08;
	float frame = floor(TIME * 30.0);
	// Static: the lines torn sideways and the picture rolling.
	float torn = (hash(vec2(floor(uv.y * 180.0), frame)) - 0.5) * 0.16 * burst * burst;
	uv.x += torn;
	uv.y = mix(uv.y, fract(uv.y + burst * 0.3), step(0.001, burst));
	// At night, a coarser picture.
	vec2 cells = vec2(256.0, 144.0);
	uv = mix(uv, (floor(uv * cells) + 0.5) / cells, step(0.5, night));
	float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
	vec3 col = texture(TEXTURE, uv).rgb * inside;
	float grain = hash(floor(FRAGCOORD.xy / 3.0) + frame * 7.0);
	float seen = dot(col, vec3(0.3, 0.59, 0.11));
	// A cheap tube: few greys, and its grain over them.
	seen = pow(clamp(seen * 2.2, 0.0, 1.0), 0.9);
	seen = floor(seen * 12.0) / 12.0 + (grain - 0.5) * 0.2 + 0.04;
	vec3 green = vec3(0.55, 0.95, 0.62) * seen * (1.0 - dot(c, c) * 1.6) * inside;
	col = mix(col, green, night);
	col *= 1.0 - 0.12 * step(0.5, fract(FRAGCOORD.y / 3.0));
	col *= 1.0 - dot(c, c) * 0.7;
	col += flash * 0.8 * inside;
	// Between two cameras, the tape's own snow (tape_snow.gdshaderinc).
	col = mix(col, tape_snow(UV, floor(TIME * 60.0), true), clamp(burst * 1.4, 0.0, 1.0) * 0.9);
	col *= 1.0 - dim * 0.78;
	COLOR = vec4(col, 1.0);
}
