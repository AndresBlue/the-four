shader_type canvas_item;
// The drops of presentation/shaders/lens_blood.gdshaderinc by themselves,
// over a plain ground (tools/dev/lens_blood_look.gd).
#include "res://game/presentation/shaders/lens_blood.gdshaderinc"

uniform vec3 ground = vec3(0.92, 0.92, 0.9);
uniform float wide = 1.7778;

void fragment() {
	COLOR = vec4(through_lens_blood(ground, blood_on_lens(UV * vec2(wide, 1.0), wide), ground), 1.0);
}
