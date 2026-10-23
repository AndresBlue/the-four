shader_type spatial;
// The offices' wired glass (docs/OFICINAS.md 6.3): a faintly green pane with a
// square mesh of wire in it, laid out in the world's metres so a long pane
// and a short one carry the same mesh. The coordinate along the pane is x + z:
// panes stand along one axis or the other, never on a slant.
render_mode blend_mix, cull_disabled, depth_draw_opaque, specular_schlick_ggx;

uniform vec4 glass_color : source_color = vec4(0.72, 0.8, 0.78, 0.16);
uniform vec4 wire_color : source_color = vec4(0.22, 0.23, 0.22, 0.75);
uniform float pitch = 0.025;
uniform float wire = 0.06;

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 cell = vec2(world.x + world.z, world.y) / pitch;
	vec2 from_middle = abs(fract(cell) - 0.5);
	float on_wire = step(0.5 - wire * 0.5, max(from_middle.x, from_middle.y));
	ALBEDO = mix(glass_color.rgb, wire_color.rgb, on_wire);
	ALPHA = mix(glass_color.a, wire_color.a, on_wire);
	ROUGHNESS = mix(0.05, 0.6, on_wire);
	METALLIC = mix(0.0, 0.5, on_wire);
	SPECULAR = 0.8;
}
