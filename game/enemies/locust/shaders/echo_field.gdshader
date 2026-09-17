shader_type spatial;
// The Locust does not see light. This pass throws away the lit image and
// rebuilds it from the depth buffer: the wavefronts of its clicks sweeping the
// real geometry, the depth of every surface, and the sounds it is actually
// hearing, painted as rings on those same surfaces. Drawn from HunterCamera
// only, as a screen-covering quad, above every other transparent in the hotel.
//
// ALPHA is always 1: the lit image is replaced, but its depth survives, and
// that depth is the whole trick.
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;

const int SWEEPS = 6;
const int CONTACTS = 12;

// DEPTH_TEXTURE is not a built-in: it has to be asked for. Nearest filtering
// is not optional, interpolating raw depth gives nonsense world positions
// along every silhouette.
uniform sampler2D depth_map : hint_depth_texture, repeat_disable, filter_nearest;
// Echo clock in seconds since this view opened. Small numbers keep float
// precision, the image freezes with the tree, and the CPU side can reproduce
// any value this shader computes.
uniform float now = 0.0;
uniform float reach = 40.0;
uniform float wave_speed = 42.0;
uniform float band_step = 1.5;
// 0 grey, 1 the red flood of its own shriek.
uniform float shriek : hint_range(0.0, 1.0) = 0.0;
// Residual level between clicks. Low on purpose: raise it and the creature
// simply sees, and the whole acoustic conceit collapses. Every level in here
// is LINEAR light: the AgX tonemap and the sRGB encoding roughly double what
// reaches the screen, which is why these numbers look so small.
uniform float base_level : hint_range(0.0, 1.0) = 0.012;
uniform float front_level : hint_range(0.0, 2.0) = 1.0;
uniform float grain_amount : hint_range(0.0, 1.0) = 1.0;
uniform float jitter_amount : hint_range(0.0, 1.0) = 1.0;
// A survivor's torch is light, which it cannot see, but the beam disturbs the
// reading: xy is the direction on screen, z the strength.
uniform vec3 glare = vec3(0.0);
uniform int sweep_count = 0;
// xyz: its head where the click left it. w: when the click left.
uniform vec4 sweeps[SWEEPS];
// x: amplitude of that click, y: its reach.
uniform vec4 sweep_power[SWEEPS];
uniform int contact_count = 0;
// xyz: where the sound is heard from. w: when it arrived.
uniform vec4 contacts[CONTACTS];
// x: loudness, y: kind, z: how muffled, w: how wide it spreads.
uniform vec4 contact_power[CONTACTS];

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

// The projection matrix has to be handed in: built-ins only exist inside the
// shader's own entry functions.
vec3 view_at(mat4 unproject, vec2 uv, float raw) {
	vec4 view = unproject * vec4(uv * 2.0 - 1.0, raw, 1.0);
	return view.xyz / view.w;
}

void fragment() {
	vec2 texel = 1.0 / VIEWPORT_SIZE;
	vec2 uv = SCREEN_UV;
	// Tape-style horizontal unsteadiness, so the reading never looks digital.
	uv.x += (hash12(vec2(floor(uv.y * 240.0), floor(now * 24.0))) - 0.5) * 0.0016 * jitter_amount;
	float raw = texture(depth_map, uv).x;
	vec3 colour = vec3(0.0);
	// Reversed Z: 0.0 is the far plane, so nothing was drawn on that pixel and
	// there is nothing to reconstruct. ('return' is not allowed in fragment.)
	if (raw > 0.0000001) {
		vec3 here = view_at(INV_PROJECTION_MATRIX, uv, raw);
		vec3 world = (INV_VIEW_MATRIX * vec4(here, 1.0)).xyz;
		float eye_distance = length(here);

		// Surface normal from four depth taps, keeping the nearer neighbour on
		// each axis. dFdx/dFdy would give normals in 2x2 blocks and would
		// explode across silhouettes, which is where the best signal is.
		vec3 left = view_at(INV_PROJECTION_MATRIX, uv - vec2(texel.x, 0.0), texture(depth_map, uv - vec2(texel.x, 0.0)).x);
		vec3 right = view_at(INV_PROJECTION_MATRIX, uv + vec2(texel.x, 0.0), texture(depth_map, uv + vec2(texel.x, 0.0)).x);
		vec3 down = view_at(INV_PROJECTION_MATRIX, uv - vec2(0.0, texel.y), texture(depth_map, uv - vec2(0.0, texel.y)).x);
		vec3 up = view_at(INV_PROJECTION_MATRIX, uv + vec2(0.0, texel.y), texture(depth_map, uv + vec2(0.0, texel.y)).x);
		vec3 dx = abs(left.z - here.z) < abs(right.z - here.z) ? here - left : right - here;
		vec3 dy = abs(down.z - here.z) < abs(up.z - here.z) ? here - down : up - here;
		vec3 normal = normalize(cross(dy, dx));
		float facing = abs(dot(normal, normalize(-here)));
		// A surface square to the click throws the echo straight back; one seen
		// edge-on scatters it away. So what it is facing is what it reads, and
		// the floor and ceiling running away underfoot stay dim.
		float shape = 0.22 + 0.78 * pow(facing, 1.3);
		// A real depth discontinuity: the edge that draws the doorways.
		float edge = clamp((abs(left.z - right.z) + abs(down.z - up.z)) * 0.55, 0.0, 1.0);

		// Depth contour bands: distance read at a glance, and the residual level
		// that keeps the image from blinking to black between clicks.
		float ring = 1.0 - abs(fract(eye_distance / band_step) - 0.5) * 2.0;
		float bands = pow(clamp(ring, 0.0, 1.0), 7.0);
		float level = base_level * (bands * 3.0 + 0.12) * shape;
		// Edges answer on their own, so doorways and furniture stay readable
		// even in the gap between two clicks.
		level += base_level * edge * 8.0;

		// Every click in flight, as a shell expanding from where its head was.
		// The falloff is asymmetric: tight ahead of the front, long tail behind,
		// so what the wave already passed stays lit and decays. That asymmetry
		// is what makes this an echo instead of a depth camera.
		for (int i = 0; i < SWEEPS; i++) {
			if (i >= sweep_count) { break; }
			float travelled = (now - sweeps[i].w) * wave_speed;
			float away = distance(world, sweeps[i].xyz);
			if (travelled > 0.0 && away <= sweep_power[i].y) {
				float ahead = away - travelled;
				// Tight ahead of the front, a short tail behind it. The tail has
				// to die fast or a near wall is lit by every shell at once and
				// the whole near field blows out into white.
				float shell = ahead > 0.0 ? exp(-ahead * ahead / 0.45) : exp(ahead * 1.8);
				// The far side of the room answers later and quieter.
				// Nothing right against its head is allowed to blow out.
				float spread = smoothstep(0.0, 1.3, away) / (1.0 + away * away * 0.008);
				level += 1.5 * front_level * sweep_power[i].x * shell * spread * shape * (0.6 + edge * 1.6);
			}
		}

		// The sounds it hears, spreading over the surfaces around where they
		// arrived from. Here the noise and the geometry become one image.
		for (int i = 0; i < CONTACTS; i++) {
			if (i >= contact_count) { break; }
			float age = now - contacts[i].w;
			if (age >= 0.0) {
				float away = distance(world, contacts[i].xyz);
				float front = age * 9.0;
				float width = 0.5 + contact_power[i].w;
				float ripple = exp(-pow((away - front) / width, 2.0));
				// The ring carries the news; the glow only says "around here", so
				// it has to stay tight or a single slam washes the whole room.
				float halo = exp(-away * (1.7 - contact_power[i].w * 0.35)) * 0.22;
				float dulled = 1.0 - contact_power[i].z * 0.55;
				level += 0.45 * contact_power[i].x * (ripple * 1.25 + halo) * dulled * shape;
			}
		}

		// Beyond its hearing there is nothing to reconstruct.
		level *= 1.0 - smoothstep(reach * 0.55, reach, eye_distance);
		// A soft ceiling. A wall square-on and close is hit by every shell at
		// once; without this it burns to flat white and swallows the room.
		level = level / (1.0 + level * 0.8);

		// Grey with a cold cast; its own shriek floods the reading red.
		// AgX takes a lot of the chroma out of a saturated colour, so the red of
		// the shriek has to be pushed well past where it looks right on paper.
		vec3 grey = vec3(0.74, 0.79, 0.82);
		vec3 blood = vec3(1.35, 0.05, 0.02);
		colour = mix(grey, blood, shriek) * level;
		// Hot returns bleach towards white (red holds its hue a little longer).
		colour += mix(vec3(1.0), vec3(1.0, 0.55, 0.45), shriek) * pow(clamp(level - 0.75, 0.0, 1.0), 1.5) * 0.6;

		// A lit torch pointed this way is interference, not an image.
		if (glare.z > 0.001) {
			vec2 from_centre = SCREEN_UV - 0.5;
			float aim = clamp(dot(normalize(from_centre + vec2(0.0001)), normalize(glare.xy + vec2(0.0001))), 0.0, 1.0);
			float bloom = glare.z * pow(aim, 3.0) * (0.35 + 0.65 * hash12(SCREEN_UV * 260.0 + now * 31.0));
			colour += mix(vec3(0.9, 0.93, 1.0), blood, shriek) * bloom * 0.16;
		}

		// Auto-gain grain, heavier where the reading is weak.
		float speck = hash12(SCREEN_UV * VIEWPORT_SIZE + vec2(now * 1000.0));
		colour += (speck - 0.5) * 0.012 * grain_amount * (1.3 - clamp(level, 0.0, 1.0));
	}
	ALBEDO = max(colour, vec3(0.0));
	ALPHA = 1.0;
}
