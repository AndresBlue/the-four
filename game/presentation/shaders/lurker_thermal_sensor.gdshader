shader_type canvas_item;
// The Lurker's camera sensor in Versus (.claude/specs/lurker_versus.md 4.5 and
// 13.9), over the picture lurker_sight.gdshader and her marks
// (lurker_mark.gdshader) leave on the screen: there the red is how bright each
// point reads after the camera's gain (FOOT to RANGE), the green a pale mark
// (her way down, the survivors, her doubles, what her drink would reach),
// the blue a red one (why her prey is not hers). Here it becomes a
// recording: a sensor of few lines scaled up soft, its edges sharpened, its
// noise, the faint stripes of its columns, the fall of its lens to the corners,
// and its map last: the cold in a very dark navy, the heat (only the
// electricity) up an iron ramp to white. A pale mark inside a survivor's box
// on the screen (`tint_box`) takes the colour of its mind (`tint_colour`:
// green whole, red gone). The marks are read sharp, not through the sensor's
// few lines.
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
// The survivors' boxes on the screen (uv: min x, min y, max x, max y) and the
// colour of each one's mind.
uniform int tint_count = 0;
uniform vec4 tint_box[24];
uniform vec4 tint_colour[24];

// What lurker_sight.gdshader packs a reading into.
const float RANGE = 1.6;
const float FOOT = -0.4;
const vec3 MARK = vec3(0.86, 0.93, 1.0);
const vec3 RED = vec3(1.0, 0.16, 0.1);

// The cold in navy to the hot up an iron ramp to white.
vec3 ramp(float v) {
	vec3 c0 = vec3(0.002, 0.004, 0.014);
	vec3 c1 = vec3(0.07, 0.12, 0.28);
	vec3 c2 = vec3(0.28, 0.1, 0.46);
	vec3 c3 = vec3(0.86, 0.2, 0.4);
	vec3 c4 = vec3(1.0, 0.56, 0.12);
	vec3 c5 = vec3(1.0, 0.93, 0.52);
	if (v < 0.2) return mix(c0, c1, smoothstep(-0.38, 0.2, v));
	if (v < 0.45) return mix(c1, c2, (v - 0.2) / 0.25);
	if (v < 0.7) return mix(c2, c3, (v - 0.45) / 0.25);
	if (v < 0.88) return mix(c3, c4, (v - 0.7) / 0.18);
	if (v < 1.0) return mix(c4, c5, (v - 0.88) / 0.12);
	return mix(c5, vec3(1.0), clamp((v - 1.0) * 3.0, 0.0, 1.0));
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
	float here = textureLod(screen_texture, uv, lod).r;
	float wide = textureLod(screen_texture, uv, lod + 1.2).r;
	vec2 marks = textureLod(screen_texture, uv, 0.0).gb;
	float v = FOOT + here * (RANGE - FOOT);
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
	vec3 colour = ramp(v);
	vec3 pale = MARK;
	for (int i = 0; i < tint_count; i++) {
		vec4 b = tint_box[i];
		if (uv.x >= b.x && uv.x <= b.z && uv.y >= b.y && uv.y <= b.w) {
			pale = tint_colour[i].rgb;
			break;
		}
	}
	colour = mix(colour, pale, clamp(marks.x, 0.0, 1.0));
	colour = mix(colour, RED, clamp(marks.y, 0.0, 1.0));
	COLOR = vec4(colour, 1.0);
}
