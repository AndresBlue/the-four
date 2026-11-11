// The veil of fine dust under a fall (ceiling_dust.gd veil()), in the
// volumetric fog: lit by the torch and the tubes with their shadows, nothing
// in the dark. Not a smooth ball: wisps in tall curtains, from a noise
// stretched up and down in the world that drifts slowly downward, thinning to
// the volume's edge and to nothing within a metre of the eye (`eye`, set each
// frame), so it never fogs the lens.
shader_type fog;

uniform sampler3D noise_tex : repeat_enable, filter_linear;
uniform float density = 0.0;
uniform vec3 albedo = vec3(1.0);
uniform vec3 eye = vec3(0.0, -1000.0, 0.0);

void fog() {
	vec3 p = WORLD_POSITION * vec3(1.6, 0.5, 1.6) + vec3(0.0, TIME * 0.06, 0.0);
	float wisp = smoothstep(0.45, 0.85, texture(noise_tex, p).r);
	float edge = clamp(-SDF / (0.5 * min(SIZE.x, SIZE.z)), 0.0, 1.0);
	float near = smoothstep(0.5, 1.4, distance(WORLD_POSITION, eye));
	DENSITY = density * wisp * edge * edge * near;
	ALBEDO = albedo;
}
