// The darkness The Lurker carries: not a soft ball but ink in water, or a
// thick black vapour, wrapped round its body and always moving. Its edge is
// torn and sharp where it is dense, and thin wisps curl off it. Drawn on the
// back faces of a sphere and integrated along each view ray through it (cut
// short by whatever the ray meets first), so it is the same from inside as
// from outside. The face is kept clear of it, and so is the way from the face
// to the eye that looks at it: the face is what floats in front of the dark.
//
// Two of these go round it (lurker_visual.gd): the ink on the body, dense
// enough to be black, and the vapour, a wider and thinner one in rags.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_front, shadows_disabled;

// The mass lies along the body, from its front to the end of its abdomen.
uniform vec3 axis_a = vec3(0.0, -100.0, 0.0);
uniform vec3 axis_b = vec3(0.0, -100.0, 0.0);
// How far the mass reaches round that line, and the sphere it is drawn in.
uniform float thickness = 0.34;
uniform float radius = 0.8;
uniform float density = 40.0;
// 0: ink, dense with a torn edge. 1: vapour, all rags and holes.
uniform float vapour = 0.0;
// The face, in the world, and how wide a hole the dark leaves round it.
uniform vec3 face = vec3(0.0, -100.0, 0.0);
uniform float face_clear = 0.17;
// More of the mass (lurker_visual.gd): its shoulders, so the arms come out of
// the dark instead of off a ball, its neck, so the face comes out of it too,
// and the tail it drags when it dashes. Each
// a segment as wide as `thickness` times its share; a share of 0 is none.
uniform vec3 roots_a[9];
uniform vec3 roots_b[9];
uniform float roots_w[9];
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

float segment(vec3 p, vec3 a, vec3 b) {
	vec3 ab = b - a;
	float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-6), 0.0, 1.0);
	return length(p - (a + ab * t));
}

float dark(vec3 p, float t, vec3 eye, vec3 centre) {
	// the space itself is stirred, so the lumps curl instead of sliding
	vec3 q = p * 3.0;
	vec3 stir = vec3(noise(q + vec3(0.0, t * 0.3, 0.0)),
	                 noise(q + vec3(5.2, -t * 0.25, 1.3)),
	                 noise(q + vec3(2.1, 3.3, t * 0.35))) - 0.5;
	float n = noise(p * 6.0 + stir * 2.4 + vec3(0.0, -t * 0.45, 0.0)) * 0.6
	        + noise(p * 14.0 + stir * 3.2 - vec3(t * 0.3)) * 0.4;
	float r = segment(p, axis_a, axis_b) / thickness;
	for (int k = 0; k < 9; k++) {
		if (roots_w[k] > 0.0) r = min(r, segment(p, roots_a[k], roots_b[k]) / (thickness * roots_w[k]));
	}
	float ink = smoothstep(1.0, 0.84, r + (n - 0.5) * 1.15);
	float wisps = smoothstep(1.7, 1.15, r + (n - 0.5) * 1.8) * smoothstep(0.52, 0.72, n);
	// Rags with an edge, near the body: soft and wide they read as a vignette
	// round her, and through soft holes a torch's bright spot as a glowing
	// smoke. They only darken.
	float rags = smoothstep(1.9, 1.15, r + (n - 0.5) * 0.9) * smoothstep(0.48, 0.56, n);
	float d = mix(max(ink, wisps * 0.45), rags, vapour);
	float clear = face_clear > 0.0 ? smoothstep(face_clear * 0.55, face_clear, segment(p, face, eye)) : 1.0;
	// thinning out before the sphere it is drawn in, so its edge never shows
	float inside = smoothstep(radius, radius * 0.8, length(p - centre));
	return d * clear * inside;
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
	const int STEPS = 10;
	float dt = (t1 - t0) / float(STEPS);
	for (int i = 0; i < STEPS; i++) {
		vec3 p = eye + ray * (t0 + (float(i) + 0.5) * dt);
		sum += dark(p, TIME, eye, centre) * dt;
	}
	ALBEDO = vec3(0.0);
	ALPHA = clamp(1.0 - exp(-sum * density), 0.0, 1.0);
}
