shader_type canvas_item;
// Tape static for menu transitions and signal loss. amount 0 is invisible.
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.85, 0.85, 0.82, 1.0);

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 cell = floor(FRAGCOORD.xy / 2.0);
	float frame = floor(TIME * 30.0);
	float snow = hash(cell + frame * 17.0);
	float line = hash(vec2(floor(FRAGCOORD.y / 3.0), frame));
	float bands = smoothstep(0.82, 1.0, line);
	float value = snow * 0.75 + bands * 0.35;
	COLOR = vec4(tint.rgb * value, amount * (0.55 + 0.45 * snow));
}
