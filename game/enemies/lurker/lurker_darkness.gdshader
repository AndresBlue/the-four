// The darkness The Lurker carries: a churning black fog round its body, so the
// body has no edge and runs into the dark behind it. Drawn on the back faces
// of a sphere and integrated along each view ray through it (cut short by
// whatever the ray meets first), so it is the same from inside as from
// outside. The face is kept clear of it: it is what floats in the dark.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_front, shadows_disabled;

uniform float radius = 0.62;
// How thick the fog is at the centre.
uniform float density = 7.0;
// The face, in the world, and how wide a hole the fog leaves round it.
uniform vec3 face = vec3(0.0, -100.0, 0.0);
uniform float face_clear = 0.17;
// How lumpy and restless it is: 1 for the fog round the body, 0 for the wide
// gloom, which only fades out smoothly.
uniform float churn = 1.0;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

varying vec3 world_vertex;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x),
	               mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
	           mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
	               mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fog(vec3 p, vec3 centre, float t) {
	float r = length(p - centre) / radius;
	// lumps that come and go, so the outline never settles
	float n = noise(p * 4.5 + vec3(0.0, t * 0.35, t * 0.2)) * 0.65 + noise(p * 11.0 - vec3(t * 0.5)) * 0.35;
	float body = smoothstep(1.0, 0.15 * churn, r + (n - 0.5) * 0.55 * churn);
	float clear = face_clear > 0.0 ? smoothstep(face_clear * 0.55, face_clear, length(p - face)) : 1.0;
	return body * clear;
}

void vertex() {
	world_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 centre = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 eye = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 ray = normalize(world_vertex - eye);
	vec3 oc = eye - centre;
	float b = dot(oc, ray);
	float c = dot(oc, oc) - radius * radius;
	float h = b * b - c;
	if (h <= 0.0) discard;
	h = sqrt(h);
	float t0 = max(-b - h, 0.0);
	float t1 = -b + h;
	// stop at the first opaque thing along the ray
	float depth = texture(depth_texture, SCREEN_UV).x;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
#endif
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	t1 = min(t1, length(view.xyz));
	if (t1 <= t0) discard;
	float sum = 0.0;
	const int STEPS = 7;
	float dt = (t1 - t0) / float(STEPS);
	for (int i = 0; i < STEPS; i++) {
		vec3 p = eye + ray * (t0 + (float(i) + 0.5) * dt);
		sum += fog(p, centre, TIME) * dt;
	}
	ALBEDO = vec3(0.0);
	ALPHA = clamp(1.0 - exp(-sum * density), 0.0, 0.985);
}
