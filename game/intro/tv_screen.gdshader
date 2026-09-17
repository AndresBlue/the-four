shader_type spatial;
render_mode unshaded, cull_back;
// CRT screen of the opening scene: static, the creature peeking in, knocks
// flashing the tube and cracks spreading from inside. Driven by intro_sequence.gd.

// Part of the mesh UVs covered by the visible tube face (min, size).
uniform vec4 screen_rect = vec4(0.0128, 0.1364, 0.9745, 0.7213);
uniform float power : hint_range(0.0, 1.0) = 1.0;
uniform float static_amount : hint_range(0.0, 1.0) = 1.0;
// The creature: a supplied picture, or a drawn stand-in when there is none.
uniform sampler2D image : source_color, filter_linear;
uniform bool has_image = false;
uniform float image_amount : hint_range(0.0, 1.0) = 0.0;
// Picture centre offset (screen units) and zoom.
uniform vec2 image_offset = vec2(0.0);
uniform float image_scale = 1.0;
// Cracks: red channel holds the stage (0..1) at which each crack appears.
uniform sampler2D cracks : filter_linear;
uniform float crack_level : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float roll = 0.0;
uniform float brightness = 0.95;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float ellipse(vec2 p, vec2 centre, vec2 radius) {
	vec2 d = (p - centre) / radius;
	return 1.0 - smoothstep(0.85, 1.0, dot(d, d));
}

// Stand-in portrait: a black stilted body under ragged hair around a long,
// pale mask of a face with hollow eyes and a dark open mouth.
vec3 drawn_figure(vec2 p) {
	vec3 wall = mix(vec3(0.42, 0.36, 0.27), vec3(0.3, 0.25, 0.19), p.x);
	wall *= 0.85 + 0.15 * sin(p.x * 90.0) * sin(p.y * 70.0);
	float strands = hash(vec2(floor(p.x * 60.0), 3.0));
	float hair = ellipse(p, vec2(0.5, 0.3), vec2(0.15 + strands * 0.05, 0.19 + strands * 0.08));
	float body = ellipse(p, vec2(0.5, 1.05), vec2(0.3, 0.42));
	body = max(body, step(abs(p.x - 0.5), 0.035) * step(0.35, p.y));
	vec3 colour = mix(wall, vec3(0.015), max(hair, body));
	float face = ellipse(p, vec2(0.5, 0.3), vec2(0.058, 0.115));
	colour = mix(colour, vec3(0.8, 0.66, 0.56) * (1.0 - (p.y - 0.2) * 0.8), face);
	float eyes = ellipse(p, vec2(0.474, 0.265), vec2(0.011, 0.014)) + ellipse(p, vec2(0.526, 0.265), vec2(0.011, 0.014));
	float mouth = ellipse(p, vec2(0.5, 0.375), vec2(0.022, 0.028));
	colour = mix(colour, vec3(0.03, 0.005, 0.005), clamp(eyes + mouth, 0.0, 1.0));
	return colour;
}

void fragment() {
	vec2 uv = (UV - screen_rect.xy) / screen_rect.zw;
	float t = TIME;
	// Vertical roll and line jitter while the channel is unstable.
	uv.y = fract(uv.y + roll);
	uv.x += (hash(vec2(floor(uv.y * 240.0), floor(t * 30.0))) - 0.5) * 0.01 * static_amount;
	// A fresh crack refracts the picture slightly around it.
	float crack = texture(cracks, uv).r;
	float shown = step(0.001, crack) * step(crack, crack_level + 0.001);
	vec2 bent = uv + shown * 0.01 * vec2(hash(uv * 31.0) - 0.5, hash(uv * 17.0) - 0.5);
	vec2 picture = (bent - 0.5 - image_offset) / image_scale + 0.5;
	vec3 figure = vec3(0.0);
	if (all(greaterThanEqual(picture, vec2(0.0))) && all(lessThanEqual(picture, vec2(1.0)))) {
		figure = has_image ? texture(image, picture).rgb : drawn_figure(picture);
	}
	float snow = hash(floor(uv * vec2(320.0, 240.0)) + floor(t * 30.0));
	vec3 noise = vec3(snow) * (0.55 + 0.45 * sin(uv.y * 8.0 + t * 3.0));
	vec3 colour = mix(noise * 0.9, figure, image_amount);
	colour = mix(colour, noise, static_amount * image_amount * 0.6);
	// Scanlines, tube vignette and a soft glow.
	colour *= 0.82 + 0.18 * sin(uv.y * 480.0);
	vec2 centred = uv - 0.5;
	colour *= 1.0 - dot(centred, centred) * 1.6;
	colour += flash * vec3(0.85, 0.9, 1.0);
	colour += shown * vec3(0.9) * (0.4 + 0.6 * power);
	ALBEDO = colour * brightness * power + shown * vec3(0.05);
}
