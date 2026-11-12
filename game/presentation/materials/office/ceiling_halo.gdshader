shader_type spatial;
// The glow on the ceiling tiles round a lit troffer (office_geometry.ceiling_halo(),
// spec_rediseno 4): added to what is behind, unlit, with no shadow. UV is the offset
// from the troffer's centre in metres, its long side along u; inside the troffer
// (its own glowing lens) it adds nothing.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec3 glow : source_color = vec3(1.0);
uniform float energy = 0.0;
uniform vec2 inner = vec2(0.6, 0.3);
uniform float reach = 1.2;

void fragment() {
	vec2 outside = max(abs(UV) - inner, vec2(0.0));
	float d = length(outside);
	// Eased out to nothing at `reach`: no edge where it ends on a dark ceiling.
	float fall = 1.0 - smoothstep(0.0, reach, d);
	ALBEDO = glow * energy * fall * fall * step(0.0001, d);
}
