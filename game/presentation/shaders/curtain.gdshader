shader_type spatial;
// Heavy velvet curtain. The sway is presentation only and is disabled by
// reduced effects; it never moves collision.
#include "res://game/presentation/shaders/surface.gdshaderinc"

uniform float motion = 1.0;
uniform vec4 color : source_color = vec4(0.30, 0.08, 0.07, 1.0);
uniform vec4 fold_color : source_color = vec4(0.10, 0.03, 0.03, 1.0);

void vertex() {
	VERTEX.z += sin(TIME * 0.7 + VERTEX.x * 8.0) * 0.035 * motion * (1.0 - UV.y);
	SURFACE_VERTEX;
}

void fragment() {
	vec2 uv = face_uv();
	float folds = 0.5 + 0.5 * sin(uv.x * 31.0 + sin(uv.y * 1.3) * 0.8);
	float nap = fine_noise(uv * vec2(90.0, 30.0));
	float dust = fbm(uv * 2.0) * 0.2;
	vec3 base = mix(fold_color.rgb, color.rgb, 0.35 + folds * 0.65);
	base *= 0.9 + nap * 0.12 + dust * 0.3;
	ALBEDO = base;
	ROUGHNESS = 0.9;
	RIM = 0.7;
	RIM_TINT = 0.7;
	NORMAL = BUMPED_VIEW_NORMAL(wn, folds * 0.02 + nap * 0.0004, 1.0);
}
