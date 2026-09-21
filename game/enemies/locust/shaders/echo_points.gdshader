shader_type spatial;
// Everything the creature reads as grains in the world. Each click fires rays
// from its head and every hit becomes a point in a world-space ring buffer, so
// the shape of a room stays registered where it really is and is drawn at
// whatever framerate the machine manages: the reading refreshes on the pulse,
// the picture never stutters.
//
// One shader serves five clouds, which differ only by uniforms and priority:
// architecture, the surface of a body, the puff of grains a heard noise leaves
// hanging where it was heard, what the shriek found, and the landmarks it
// simply knows. A puff is the same machinery with a slow wave and a long fade:
// its grains bloom outward from the noise instead of being swept by a click.
// depth_test_disabled on purpose: the depth test is done by hand in the
// fragment, softly, so remembered walls can whisper through a wall while a
// body (through = 0) is cut off by it completely.
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;

uniform float now = 0.0;
uniform float wave_speed = 42.0;
// Longest a point still shows. Pushed every frame from the measured write
// rate, so a point always finishes fading before the ring buffer reaches it.
uniform float age_limit = 5.0;
// View-space half-size per metre of distance, so a point keeps its size on
// screen; clamped so it never becomes a pixel or a blob.
uniform float point_scale = 0.004;
uniform float point_min = 0.010;
uniform float point_max = 0.085;
// How much of the reading survives behind a wall. Remembered architecture
// whispers through; a body never does.
uniform float through : hint_range(0.0, 1.0) = 0.35;
// 1 for the landmarks: doors and wardrobes it simply knows are there.
uniform float steady : hint_range(0.0, 1.0) = 0.0;
uniform float steady_fade_from = 12.0;
uniform float steady_fade_to = 20.0;
uniform float shriek : hint_range(0.0, 1.0) = 0.0;
uniform float gain : hint_range(0.0, 4.0) = 1.0;
// What the grains of this cloud are made of: kind 0 and kind 1 (see below).
uniform vec3 tone_cold : source_color = vec3(0.70, 0.75, 0.78);
uniform vec3 tone_hot : source_color = vec3(1.0, 0.94, 0.88);
uniform vec3 shriek_cold : source_color = vec3(1.3, 0.06, 0.03);
uniform vec3 shriek_hot : source_color = vec3(1.4, 0.34, 0.22);
// How much of a grain's light is there between fronts, and how much the front
// itself brings. A puff wants a body of its own; a remembered wall does not.
uniform float residue : hint_range(0.0, 2.0) = 0.11;
uniform float flare : hint_range(0.0, 4.0) = 1.8;
// Sound, unlike architecture, never holds still: each grain flickers on its
// own a dozen times a second by this much. In a picture made only of greys,
// that shimmer is what tells a noise from the doorway it hangs in.
uniform float twinkle : hint_range(0.0, 1.0) = 0.0;
// A faint phosphor halo round each grain (graphics preset echo_halo, Ultra):
// the quad grows to fit it and the core keeps its size. It only ever lies
// round a grain that is already there, so it shows nothing new.
uniform float halo : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D depth_map : hint_depth_texture, repeat_disable, filter_nearest;

// INSTANCE_CUSTOM only exists in vertex(): carried over uninterpolated.
// x: when the click left. y: metres from that click's origin to this point.
// z: what it is (0 architecture, 1 flesh), plus two for every tenth of a
// second of its own life when it carries one (a noise: doors outlast steps).
// w: how much came back.
varying flat vec4 echo;
varying flat float strength;
varying flat float from_eye;

void vertex() {
	echo = INSTANCE_CUSTOM;
	float age = now - echo.x;
	float front = age * wave_speed;
	// The front sweeping past is the flash; what it leaves behind is memory.
	float gap = front - echo.y;
	float flash = exp(-gap * gap / 2.5);
	float since = max(age - echo.y / wave_speed, 0.0);
	float tenths = floor(echo.z * 0.5 + 0.001);
	float life = tenths > 0.5 ? tenths * 0.1 : age_limit;
	float memory = clamp(1.0 - since / max(life, 0.05), 0.0, 1.0);
	// Almost all of a remembered point's light comes from the moment the front
	// passes it. That residue has to stay tiny: in a small room every point
	// lands on the same few square metres, and a generous residue adds up into
	// a flat lit panel instead of a stipple. A puff sets it high instead, so it
	// hangs in the air after its own little front has gone by.
	float live = (residue + flare * flash) * memory * echo.w;
	if (twinkle > 0.0) {
		float seed = fract(sin(float(INSTANCE_ID) * 12.9898 + floor(now * 12.0) * 78.233) * 43758.5453);
		live *= 1.0 - twinkle + twinkle * 2.0 * seed;
	}

	// Screen-constant billboard: take the instance origin into view space and
	// add the quad corners there, so nothing has to be turned to face anything.
	vec3 centre = (VIEW_MATRIX * MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	// Distance, not depth along Z: the same measure the soft depth test below
	// reconstructs from the buffer, so the two can be compared directly.
	from_eye = length(centre);
	float faded = mix(1.0, 1.0 - smoothstep(steady_fade_from, steady_fade_to, from_eye), steady);
	strength = mix(live, echo.w * faded, steady) * gain;
	float radius = clamp(from_eye * point_scale, point_min, point_max) * (1.0 + flash * 0.8 * (1.0 - steady));
	// A spent or never-written instance collapses to nothing, so the unused
	// tail of the ring buffer can never show up as a blob at the world origin.
	if (strength <= 0.002) radius = 0.0;
	radius *= 1.0 + halo * 2.0;
	POSITION = PROJECTION_MATRIX * vec4(centre + vec3(VERTEX.xy * radius, 0.0), 1.0);
}

void fragment() {
	// Distance from the centre in core radii (the quad is bigger with a halo).
	float r = length(UV - vec2(0.5)) * 2.0 * (1.0 + halo * 2.0);
	float disc = smoothstep(1.0, 0.15, r);
	if (halo > 0.0) disc += exp(-r * r * 0.35) * halo * 0.3;
	float weight = strength;
	if (through < 0.999) {
		// Soft depth test by hand. A hard depth_test_disabled would draw the
		// memory of three rooms away straight over the wall in front of you;
		// this way it only whispers through it.
		float raw = texture(depth_map, SCREEN_UV).x;
		// The same reading of the buffer as echo_field: reversed Z in 0..1 on
		// Forward+, OpenGL's range with the far plane at 1 on Compatibility.
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		bool drawn = raw < 0.9999999;
		vec4 ndc = vec4(vec3(SCREEN_UV, raw) * 2.0 - 1.0, 1.0);
#else
		bool drawn = raw > 0.0000001;
		vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, raw, 1.0);
#endif
		if (drawn) {
			vec4 probe = INV_PROJECTION_MATRIX * ndc;
			float wall = length(probe.xyz / probe.w);
			weight *= mix(1.0, through, smoothstep(0.15, 0.9, from_eye - wall));
		}
	}
	// echo.z picks between this cloud's two tones, and the shriek swaps both.
	float pick = echo.z - 2.0 * floor(echo.z * 0.5 + 0.001);
	vec3 tone = mix(tone_cold, tone_hot, pick);
	tone = mix(tone, mix(shriek_cold, shriek_hot, pick), shriek);
	ALBEDO = tone;
	ALPHA = clamp(disc * weight, 0.0, 1.0);
}
