shader_type canvas_item;
// The camcorder's optics and sensor, drawn over the finished 3D image (after
// TAA and tonemapping, which would smear noise and break on a remapped
// picture) and under the OSD: a lens does not bend the date stamp, while the
// tape (analog.gdshader, above) records both. Every term follows the real
// order: lens (barrel distortion, lateral colour, vignetting), then sensor
// (noise that grows with gain, chroma noise in the dark), then the camera's
// own detail enhancement.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
// Barrel distortion: source radius = r * scale * (1 + barrel * r^2), with r in
// half-heights. scale keeps the corners on the rendered picture, which is
// drawn wider for it (camcorder_look.gd works out the field of view).
uniform float barrel = 0.05;
uniform float scale = 0.8;
// Lateral chromatic aberration: red drawn slightly larger, blue smaller.
uniform float chromatic : hint_range(0.0, 1.0) = 0.3;
// Natural (cos^4) and mechanical falloff towards the corners.
uniform float vignette : hint_range(0.0, 1.0) = 0.45;
// Sensor noise: shot noise (grows with the square root of the signal) and
// read noise, both scaled by the gain the automatic iris had to add.
uniform float noise : hint_range(0.0, 1.0) = 0.35;
uniform float gain = 1.0;
// Horizontal detail enhancement ("peaking"): the sharp, haloed edges of
// consumer video.
uniform float detail : hint_range(0.0, 1.0) = 0.35;

float hash(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

vec2 distort(vec2 uv, float aspect, float amount) {
	vec2 p = (uv - 0.5) * vec2(aspect, 1.0) * 2.0;
	float r2 = dot(p, p);
	p *= scale * (1.0 + barrel * r2) * amount;
	return p / vec2(aspect, 1.0) * 0.5 + 0.5;
}

vec3 tap(vec2 uv) {
	return texture(screen_texture, clamp(uv, vec2(0.0005), vec2(0.9995))).rgb;
}

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	float aspect = px.y / px.x;
	vec2 uv = SCREEN_UV;
	// Lens: each colour through its own magnification, the centre untouched.
	float spread = chromatic * 0.004;
	vec2 green_uv = distort(uv, aspect, 1.0);
	vec3 color;
	color.r = tap(distort(uv, aspect, 1.0 + spread)).r;
	color.g = tap(green_uv).g;
	color.b = tap(distort(uv, aspect, 1.0 - spread)).b;
	// Camera detail: luma minus its horizontal blur, added back.
	if (detail > 0.0) {
		vec3 side = (tap(green_uv - vec2(px.x * 1.5, 0.0)) + tap(green_uv + vec2(px.x * 1.5, 0.0))) * 0.5;
		float edge = dot(color - side, vec3(0.299, 0.587, 0.114));
		color += edge * detail * 0.9;
	}
	vec2 centred = (uv - 0.5) * vec2(aspect, 1.0) * 2.0;
	float r2 = dot(centred, centred) / (aspect * aspect + 1.0);
	// cos^4 falloff of a wide lens plus a touch of mechanical vignetting.
	float falloff = pow(1.0 / (1.0 + r2 * 0.55), 2.0);
	color *= mix(1.0, falloff * (1.0 - smoothstep(0.55, 1.0, r2) * 0.35), vignette);
	// Sensor noise in (roughly) linear light: shot noise with sqrt of the
	// signal, read noise flat; both with the gain. Chroma noise on its own,
	// strongest where the signal is weakest, as in a camcorder at night.
	if (noise > 0.0) {
		vec3 linear = color * color;
		float luma = dot(linear, vec3(0.299, 0.587, 0.114));
		float frame = floor(TIME * 30.0);
		vec2 cell = floor(FRAGCOORD.xy);
		float n = hash(vec3(cell, frame)) + hash(vec3(cell + 19.1, frame)) - 1.0;
		vec3 c = vec3(hash(vec3(cell, frame + 7.0)), hash(vec3(cell, frame + 13.0)), hash(vec3(cell, frame + 29.0))) - 0.5;
		float sigma = (sqrt(luma) * 0.06 + 0.012) * gain;
		float dark = 1.0 - smoothstep(0.0, 0.25, luma);
		linear += (n * sigma + c * sigma * 0.9 * dark) * noise * 2.0;
		color = sqrt(max(linear, vec3(0.0)));
	}
	COLOR = vec4(max(color, vec3(0.0)), 1.0);
}
