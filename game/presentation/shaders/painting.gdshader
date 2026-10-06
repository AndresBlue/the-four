shader_type spatial;
// Faded hotel art: an indistinct landscape under yellowed varnish. Each
// frame gets its own composition from its position; nothing is legible.
#include "res://game/presentation/shaders/surface.gdshaderinc"

uniform vec4 sky : source_color = vec4(0.42, 0.44, 0.38, 1.0);
uniform vec4 land : source_color = vec4(0.22, 0.24, 0.14, 1.0);
uniform vec4 accent : source_color = vec4(0.45, 0.30, 0.16, 1.0);
uniform vec4 varnish : source_color = vec4(0.86, 0.74, 0.50, 1.0);

void vertex() { SURFACE_VERTEX; }

void fragment() {
	if (plasticine()) {
		ALBEDO = plasticine_albedo(NODE_POSITION_WORLD);
		ROUGHNESS = 0.6;
	} else {
		vec2 uv = face_uv();
		float seed = hash13(floor(wp * 0.8)) * 50.0;
		vec2 p = vec2(uv.x * 1.6, -uv.y * 1.6) + seed;
		float horizon = fract(-uv.y * 1.28 + seed) ;
		float hills = fbm(vec2(p.x * 2.0, seed)) * 0.35 + 0.35;
		float ground = smoothstep(hills + 0.03, hills - 0.03, fract(horizon));
		float strokes = fbm(p * vec2(9.0, 4.0));
		vec3 color = mix(sky.rgb * (0.8 + strokes * 0.4), land.rgb * (0.7 + strokes * 0.5), ground);
		float figure = smoothstep(0.72, 0.8, fbm(p * 3.0 + 4.0)) * ground;
		color = mix(color, accent.rgb, figure * 0.6);
		color *= varnish.rgb * 1.1;
		float craquelure = smoothstep(0.02, 0.0, abs(vnoise(uv * 60.0) - 0.5));
		color *= 1.0 - craquelure * 0.15;
		ALBEDO = color;
		ROUGHNESS = 0.45 + strokes * 0.2;
		NORMAL = BUMPED_VIEW_NORMAL(wn, strokes * 0.001 - craquelure * 0.0003, 1.0);
	}
}
