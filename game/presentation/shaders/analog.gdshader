shader_type canvas_item;
// Consumer camcorder / VHS playback look. Applied to the 3D image and the
// in-world camcorder overlay; menus, subtitles and hints are drawn above it.
// Every term scales with the user's sliders, and reduced effects set them to 0.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float vhs : hint_range(0.0, 1.0) = 0.18;
uniform float grain : hint_range(0.0, 1.0) = 0.12;
uniform float chromatic : hint_range(0.0, 1.0) = 0.08;
uniform float scanlines : hint_range(0.0, 1.0) = 0.35;
// Stable colour treatment of old tape: lifted blacks, soft highlights, warm cast.
uniform vec3 tint = vec3(1.02, 1.0, 0.9);
uniform float vignette : hint_range(0.0, 1.0) = 0.45;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise1(float x) {
	float i = floor(x);
	float f = fract(x);
	return mix(hash(vec2(i, 1.7)), hash(vec2(i + 1.0, 1.7)), f * f * (3.0 - 2.0 * f));
}

vec3 rgb_to_yiq(vec3 c) {
	return vec3(dot(c, vec3(0.299, 0.587, 0.114)), dot(c, vec3(0.596, -0.274, -0.322)), dot(c, vec3(0.211, -0.523, 0.312)));
}

vec3 yiq_to_rgb(vec3 c) {
	return vec3(c.x + 0.956 * c.y + 0.621 * c.z, c.x - 0.272 * c.y - 0.647 * c.z, c.x - 1.106 * c.y + 1.703 * c.z);
}

vec3 tap(vec2 uv) {
	return texture(screen_texture, clamp(uv, vec2(0.0005), vec2(0.9995))).rgb;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	float t = TIME;
	// Tape transport: slow line wobble, a drifting tracking band and the
	// head-switching tear at the bottom of the frame.
	float line = floor(uv.y / px.y);
	float wobble = (noise1(uv.y * 38.0 + t * 1.3) - 0.5) * 0.0022 + sin(uv.y * 190.0 + t * 3.0) * 0.00035;
	float band_pos = fract(t * 0.043);
	float band = smoothstep(0.06, 0.0, abs(uv.y - band_pos)) * (0.6 + 0.4 * noise1(t * 4.0));
	float jitter = (hash(vec2(line, floor(t * 30.0))) - 0.5) * 0.004 * band;
	float head = smoothstep(0.035, 0.0, 1.0 - uv.y);
	float tear = head * (0.012 + (hash(vec2(floor(t * 24.0), line)) - 0.5) * 0.01);
	uv.x += (wobble + jitter) * vhs + tear * vhs;
	// Luma: slightly soft with edge ringing; chroma: much lower horizontal
	// resolution and a small delay, like composite video on tape.
	float soft = 1.0 + vhs * 2.5;
	vec3 center = tap(uv);
	vec3 blur_l = tap(uv - vec2(px.x * soft, 0.0));
	vec3 blur_r = tap(uv + vec2(px.x * soft, 0.0));
	float luma = rgb_to_yiq(center * 0.5 + (blur_l + blur_r) * 0.25).x;
	float far_luma = rgb_to_yiq(tap(uv - vec2(px.x * soft * 3.0, 0.0)) * 0.5 + tap(uv + vec2(px.x * soft * 3.0, 0.0)) * 0.5).x;
	luma += (luma - far_luma) * 0.35 * vhs;
	vec2 chroma = vec2(0.0);
	float chroma_width = px.x * (1.5 + vhs * 9.0);
	float chroma_delay = px.x * vhs * 3.0;
	for (int i = -3; i <= 3; i++) {
		vec3 sample_yiq = rgb_to_yiq(tap(uv + vec2(float(i) * chroma_width + chroma_delay, 0.0)));
		chroma += sample_yiq.yz;
	}
	chroma /= 7.0;
	chroma *= 1.0 - vhs * 0.25;
	vec3 color = yiq_to_rgb(vec3(luma, chroma));
	// Lens colour fringing, stronger towards the corners.
	vec2 from_center = SCREEN_UV - 0.5;
	vec2 fringe = from_center * dot(from_center, from_center) * chromatic * 0.045 + vec2(chromatic * px.x * 2.0, 0.0);
	color.r = mix(color.r, tap(uv + fringe).r, clamp(chromatic * 3.0, 0.0, 1.0));
	color.b = mix(color.b, tap(uv - fringe).b, clamp(chromatic * 3.0, 0.0, 1.0));
	// Tape grade: lifted blacks, compressed highlights, slight warm/green cast.
	float grade = clamp(vhs * 2.2, 0.0, 1.0);
	color = mix(color, color * tint, grade);
	color = mix(color, vec3(0.035, 0.035, 0.03) + color * 0.93, grade);
	color = mix(color, 1.0 - exp(-color * 1.25), grade * 0.6);
	// Tracking band noise, dropouts and interference.
	float snow = hash(vec2(uv.x * 900.0 + t * 60.0, line));
	color += (snow - 0.5) * band * 0.25 * vhs;
	// Rare, short oxide dropouts: a few pixels tall, a small stretch wide.
	float dropout_row = floor(line / 2.0);
	float dropout_frame = floor(t * 12.0);
	float dropout_line = step(0.9993, hash(vec2(dropout_frame, dropout_row)));
	float start = hash(vec2(dropout_row, dropout_frame + 3.0));
	float dropout = dropout_line * smoothstep(0.0, 0.01, uv.x - start) * smoothstep(0.0, 0.01, start + 0.04 + start * 0.08 - uv.x);
	color = mix(color, vec3(0.75), dropout * vhs * 0.6);
	color = mix(color, vec3(snow * 0.8), head * vhs * 0.55);
	// Grain: stronger in the shadows, as with auto-gain in the dark.
	float g = hash(uv * vec2(1731.0, 977.0) + fract(t * 23.0)) - 0.5;
	float dark = 1.0 - clamp(dot(color, vec3(0.333)) * 1.6, 0.0, 1.0);
	color += g * grain * (0.08 + dark * 0.14);
	// Static 240-line field structure (no temporal alternation, to avoid flicker).
	float scan = 0.5 + 0.5 * cos(SCREEN_UV.y * 240.0 * 6.28318);
	color *= 1.0 - scanlines * 0.28 * scan;
	color *= 1.0 + scanlines * 0.06;
	// Vignette and slight flicker of the whole frame.
	float edge = dot(from_center * vec2(1.1, 1.0), from_center * vec2(1.1, 1.0));
	color *= 1.0 - smoothstep(0.12, 0.6, edge) * vignette * clamp(vhs * 3.0, 0.3, 1.0);
	color *= 1.0 - (noise1(t * 11.0) - 0.5) * 0.03 * vhs;
	COLOR = vec4(max(color, vec3(0.0)), 1.0);
}
