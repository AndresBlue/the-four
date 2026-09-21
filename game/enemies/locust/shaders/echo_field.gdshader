shader_type spatial;
// The dark the reading hangs in.
//
// This pass used to draw the room: depth bands, edges and a wavefront, all
// derived from the depth buffer every frame. That was the whole problem. A
// picture computed from the live depth buffer is a render of the geometry with
// its textures taken off, and it updates whenever anything moves, so a
// survivor walking across the room was visible continuously instead of being
// read once per click. Nothing here describes shape any more.
//
// What is left is the black it all sits on, plus the two things that are not
// geometry: the grain of its own hearing, and the interference a lit torch
// makes. Everything with a shape is grains in the world (echo_points.gdshader),
// stamped when a click reaches it and frozen until the next one.
//
// ALPHA is still 1 so the lit hotel is replaced, and the depth the hotel wrote
// is still there for the grains to test themselves against.
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;

// DEPTH_TEXTURE is not a built-in: it has to be asked for. Nearest filtering
// is not optional, interpolating raw depth gives nonsense distances.
uniform sampler2D depth_map : hint_depth_texture, repeat_disable, filter_nearest;
// Echo clock in seconds since this view opened, shared with the grains.
uniform float now = 0.0;
// 0 grey, 1 the red flood of its own shriek.
uniform float shriek : hint_range(0.0, 1.0) = 0.0;
// The faintest suggestion that something solid is out there, so a wall it has
// never clicked at is not quite the same black as an open doorway. Keep this
// near nothing: it is the one term that could start describing shape again.
uniform float presence : hint_range(0.0, 0.05) = 0.006;
uniform float grain_amount : hint_range(0.0, 1.0) = 1.0;
uniform float jitter_amount : hint_range(0.0, 1.0) = 1.0;
// A survivor's torch is light, which it cannot see, but the beam disturbs the
// reading. It is the beam as it really is, in the view's own space: where the
// torch is (xyz) and how strongly it disturbs (w), which way it points (xyz)
// and the cosine of its half-angle (w), and how far it reaches. It used to be
// a fan drawn out from the middle of the screen towards the torch, which had
// nothing to do with where the light actually went.
uniform vec4 beam_origin = vec4(0.0);
uniform vec4 beam_axis = vec4(0.0, 0.0, -1.0, 0.9);
uniform float beam_range = 20.0;
const int BEAM_STEPS = 24;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	// The default QuadMesh is 1x1, so VERTEX.xy spans -0.5..0.5 and doubling it
	// covers the frame exactly. Do not resize the mesh.
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	// Tape-style horizontal unsteadiness, so the reading never looks digital.
	uv.x += (hash12(vec2(floor(uv.y * 240.0), floor(now * 24.0))) - 0.5) * 0.0016 * jitter_amount;
	float raw = texture(depth_map, uv).x;
	vec3 colour = vec3(0.0);
	float wall_distance = 1.0e6;
	// Forward+ has reversed Z in 0..1: 0.0 is the far plane, so nothing was
	// drawn on that pixel. Compatibility is OpenGL's: 1.0 is the far plane,
	// and the buffer holds 0..1 of a -1..1 range. Read as Forward+'s, every
	// wall came out in the wrong place and the reading went almost black.
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	bool drawn = raw < 0.9999999;
	vec4 ndc = vec4(vec3(uv, raw) * 2.0 - 1.0, 1.0);
#else
	bool drawn = raw > 0.0000001;
	vec4 ndc = vec4(uv * 2.0 - 1.0, raw, 1.0);
#endif
	if (drawn) {
		vec4 view = INV_PROJECTION_MATRIX * ndc;
		float eye_distance = length(view.xyz / view.w);
		wall_distance = eye_distance;
		// Falls away with distance and never varies across a surface, so it can
		// suggest "solid" without ever drawing an edge or a shape.
		colour = mix(vec3(0.74, 0.79, 0.82), vec3(1.35, 0.05, 0.02), shriek)
			* presence / (1.0 + eye_distance * 0.35);
	}

	// A lit torch pointed this way is interference, not an image: the cone of
	// its beam, walked along this pixel's line of sight up to the first thing
	// in the way, so it has the shape and place the light really has, is cut
	// by walls like anything else, and is thickest looking into the lamp.
	if (beam_origin.w > 0.001) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		vec4 far_point = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, 0.0, 1.0);
#else
		vec4 far_point = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, 0.5, 1.0);
#endif
		vec3 ray = normalize(far_point.xyz / far_point.w);
		float reach = min(wall_distance, length(beam_origin.xyz) + beam_range);
		float step_length = reach / float(BEAM_STEPS);
		float jitter = hash12(SCREEN_UV * 311.0 + now * 7.0);
		float through_beam = 0.0;
		for (int i = 0; i < BEAM_STEPS; i++) {
			vec3 point = ray * (float(i) + jitter) * step_length;
			vec3 from_lamp = point - beam_origin.xyz;
			float along = dot(from_lamp, beam_axis.xyz);
			if (along <= 0.0 || along > beam_range) continue;
			float cosine = along / max(length(from_lamp), 0.0001);
			// Brightest along the axis and soft at the rim, and thinning out
			// with distance from the lamp, the way a torch's light does.
			float inside = smoothstep(beam_axis.w, mix(beam_axis.w, 1.0, 0.7), cosine);
			through_beam += inside * inside / (1.0 + along * along * 0.08) * step_length;
		}
		float bloom = beam_origin.w * through_beam * (0.45 + 0.55 * hash12(SCREEN_UV * 260.0 + now * 31.0)) * 0.03;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		// Compatibility does not brighten faint values on the way to the
		// screen the way Forward+'s linear output does, so a beam this faint
		// vanished there: it is brought up by hand.
		bloom = pow(clamp(bloom, 0.0, 1.0), 0.4545);
#endif
		colour += mix(vec3(0.9, 0.93, 1.0), vec3(1.2, 0.08, 0.05), shriek) * bloom;
	}

	// Auto-gain grain: the noise floor of its own hearing.
	float speck = hash12(SCREEN_UV * VIEWPORT_SIZE + vec2(now * 1000.0));
	colour += (speck - 0.5) * 0.010 * grain_amount;

	ALBEDO = max(colour, vec3(0.0));
	ALPHA = 1.0;
}
