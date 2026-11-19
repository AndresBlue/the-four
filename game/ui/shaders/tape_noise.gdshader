shader_type canvas_item;
// Tape static for menu transitions and signal loss. amount 0 is invisible.
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.85, 0.85, 0.82, 1.0);
// The snow of a blank tape, the same the camera's own filter shows.
#include "res://game/presentation/shaders/tape_snow.gdshaderinc"

void fragment() {
	vec3 snow = tape_snow(SCREEN_UV, floor(TIME * 60.0), true);
	COLOR = vec4(tint.rgb * snow, amount * (0.6 + 0.4 * min(1.0, dot(snow, vec3(0.6)))));
}
