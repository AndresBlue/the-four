shader_type canvas_item;
// The Lurker's camera sensor in Versus (.claude/specs/lurker_versus.md 4.5),
// over the picture lurker_sight.gdshader leaves on the screen: there the red
// is how bright each point reads after the camera's gain (FOOT to RANGE), the
// green how much of a cold outline is on it. Here it becomes a recording: a
// sensor of few lines scaled up soft, its edges sharpened, its noise, the
// faint stripes of its columns, the fall of its lens to the corners, and the
// plasma map last, as a camera colours its picture.
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
// The sensor's lines (its columns follow the screen's shape).
uniform float rows = 360.0;
// Noise, in reading units (the gain stretches it), and the columns' stripes.
uniform float noise = 0.02;
uniform float stripes = 0.012;
uniform float sharpen = 1.0;
uniform float vignette = 0.35;
uniform float now = 0.0;

// What lurker_sight.gdshader packs a reading into.
const float RANGE = 1.6;
const float FOOT = -0.4;

// matplotlib's plasma, a degree-6 fit to its table (lurker_view.plasma()).
vec3 plasma(float t) {
	t = clamp(t, 0.0, 1.0);
	const vec3 c0 = vec3(0.05873234392399702, 0.02333670892565664, 0.5433401826748754);
	const vec3 c1 = vec3(2.176514634195958, 0.2383834171260182, 0.7539604599784036);
	const vec3 c2 = vec3(-2.689460476458034, -7.455851135738909, 3.110799939717086);
	const vec3 c3 = vec3(6.130348345893603, 42.3461881477227, -28.51885465332158);
	const vec3 c4 = vec3(-11.10743619062271, -82.66631109428045, 60.13984767418263);
	const vec3 c5 = vec3(10.02306557647065, 71.41361770095349, -54.07218655560067);
	const vec3 c6 = vec3(-3.658713842777788, -22.93153465461149, 18.19190778539828);
	return clamp(c0 + t * (c1 + t * (c2 + t * (c3 + t * (c4 + t * (c5 + t * c6))))), 0.0, 1.0);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 screen = 1.0 / SCREEN_PIXEL_SIZE;
	// Few lines, scaled up with the blur of a cheap lens: soft pixels.
	float lod = max(log2(screen.y / rows), 0.0);
	vec2 here = textureLod(screen_texture, uv, lod).rg;
	float wide = textureLod(screen_texture, uv, lod + 1.2).r;
	float v = FOOT + here.r * (RANGE - FOOT);
	// The camera's own edge enhancement.
	v += (v - FOOT - wide * (RANGE - FOOT)) * sharpen;
	// Its noise: a fresh value per cell thirty times a second, soft between cells.
	vec2 cells = vec2(rows * screen.x / screen.y, rows);
	vec2 cell = uv * cells - 0.5;
	vec2 i = floor(cell);
	vec2 f = fract(cell);
	float frame = floor(now * 30.0);
	float n00 = hash12(i + frame * 17.0);
	float n10 = hash12(i + vec2(1.0, 0.0) + frame * 17.0);
	float n01 = hash12(i + vec2(0.0, 1.0) + frame * 17.0);
	float n11 = hash12(i + vec2(1.0, 1.0) + frame * 17.0);
	v += (mix(mix(n00, n10, f.x), mix(n01, n11, f.x), f.y) - 0.5) * noise * 2.0;
	// Faint stripes down its columns, drifting a little.
	float column = floor(uv.x * cells.x);
	v += (hash12(vec2(column, 3.0)) - 0.5) * stripes + (hash12(vec2(column, floor(now * 0.3))) - 0.5) * stripes * 0.6;
	// The lens falls off to the corners.
	vec2 q = (uv - 0.5) * vec2(screen.x / screen.y, 1.0);
	v -= vignette * dot(q, q) * 0.5;
	vec3 colour = plasma(v);
	// Past the top of the map it burns to white; under its foot, to black.
	colour = mix(colour, vec3(1.0), clamp((v - 1.0) * 3.0, 0.0, 1.0));
	colour *= clamp(1.0 + v * 2.5, 0.0, 1.0);
	colour = mix(colour, vec3(0.62, 0.74, 1.0), here.g * 0.85);
	COLOR = vec4(colour, 1.0);
}
