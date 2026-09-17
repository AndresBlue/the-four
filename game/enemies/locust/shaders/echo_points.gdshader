shader_type spatial;
// What the creature remembers. Each click fires rays from its head and every
// hit becomes a point in a world-space ring buffer, so the shape of a room
// stays registered where it really is and is drawn at whatever framerate the
// machine manages: the reading refreshes on the pulse, the picture never
// stutters. One shader serves three clouds (architecture, bodies, landmarks)
// which differ only by uniforms and draw priority.
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
uniform sampler2D depth_map : hint_depth_texture, repeat_disable, filter_nearest;

// INSTANCE_CUSTOM only exists in vertex(): carried over uninterpolated.
// x: when the click left. y: metres from that click's origin to this point.
// z: what it is (0 architecture, 1 flesh). w: how much came back.
varying flat vec4 echo;
varying flat float strength;
varying flat float from_eye;

void vertex() {
	echo = INSTANCE_CUSTOM;
	float age = now - echo.x;
	float front = age * wave_speed;
	// The front sweeping past is the flash; what it leaves behind is memory.
	float gap = front - echo.y;
	float flash = exp(-gap * gap / 0.7);
	float since = max(age - echo.y / wave_speed, 0.0);
	float memory = clamp(1.0 - since / max(age_limit, 0.05), 0.0, 1.0);
	float live = (0.42 + 0.95 * flash) * memory * echo.w;

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
	POSITION = PROJECTION_MATRIX * vec4(centre + vec3(VERTEX.xy * radius, 0.0), 1.0);
}

void fragment() {
	float disc = smoothstep(1.0, 0.15, length(UV - vec2(0.5)) * 2.0);
	float weight = strength;
	if (through < 0.999) {
		// Soft depth test by hand. A hard depth_test_disabled would draw the
		// memory of three rooms away straight over the wall in front of you;
		// this way it only whispers through it.
		float raw = texture(depth_map, SCREEN_UV).x;
		if (raw > 0.0000001) {
			vec4 probe = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw, 1.0);
			float wall = length(probe.xyz / probe.w);
			weight *= mix(1.0, through, smoothstep(0.15, 0.9, from_eye - wall));
		}
	}
	// Flesh reads brighter and warmer than plaster, and its own shriek turns
	// the whole reading red with a hot core on anything alive.
	vec3 stone = vec3(0.70, 0.75, 0.78);
	vec3 flesh = vec3(1.0, 0.94, 0.88);
	vec3 tone = mix(stone, flesh, echo.z);
	tone = mix(tone, mix(vec3(1.3, 0.06, 0.03), vec3(1.4, 0.34, 0.22), echo.z), shriek);
	ALBEDO = tone;
	ALPHA = clamp(disc * weight, 0.0, 1.0);
}
