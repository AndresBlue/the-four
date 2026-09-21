shader_type canvas_item;
// A picture going the way a weak analogue signal goes: the lines swell and roll
// like water, the picture runs sideways into a smear and the snow eats it.
// wash 0 is the clean picture, 1 is nothing left of it.
uniform float wash : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Off the edge of the little picture there is nothing, not its edge repeated.
float inside(vec2 uv) {
	return step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
}
#define PICTURE(at) (texture(TEXTURE, at) * inside(at))

void fragment() {
	float w = wash;
	float frame = floor(TIME * 24.0);
	vec2 uv = UV;
	// The swell: a slow roll down the height and a quicker shiver over it.
	float swell = sin(uv.y * 24.0 + TIME * 5.0) * 0.022 + sin(uv.y * 71.0 - TIME * 13.0) * 0.009;
	// Some rows jump sideways for a frame, more of them the weaker it gets.
	float row = floor(uv.y * 22.0);
	float tear = step(1.0 - w * 0.8, hash(vec2(row, frame))) * (hash(vec2(frame, row + 7.0)) - 0.5) * 0.14;
	uv.x += (swell + tear) * w;
	uv.y += sin(uv.x * 5.0 + TIME * 3.0) * 0.025 * w;
	// The smear: the picture runs, mostly sideways, and the colours slip.
	vec2 step_x = vec2(TEXTURE_PIXEL_SIZE.x * (1.0 + 9.0 * w), 0.0);
	vec2 step_y = vec2(0.0, TEXTURE_PIXEL_SIZE.y * 3.0 * w);
	vec4 col = PICTURE(uv) * 0.28;
	col += (PICTURE(uv + step_x) + PICTURE(uv - step_x)) * 0.18;
	col += (PICTURE(uv + step_x * 2.0) + PICTURE(uv - step_x * 2.0)) * 0.1;
	col += (PICTURE(uv + step_y) + PICTURE(uv - step_y)) * 0.08;
	col = mix(PICTURE(uv), col, clamp(w * 3.0, 0.0, 1.0));
	col.r = mix(col.r, PICTURE(uv + step_x * 1.5).r, w);
	// The snow: over what is left of the picture, and grains of it given up.
	float snow = hash(floor(FRAGCOORD.xy / 2.0) + frame * 17.0);
	float grain = hash(floor(FRAGCOORD.xy / 3.0) + frame * 3.1);
	col.rgb = mix(col.rgb, vec3(0.85, 0.85, 0.82) * snow, w * 0.75);
	col.a *= smoothstep(w * 1.2 - 0.2, w * 1.2, grain);
	col.a *= 1.0 - w * w * 0.6;
	// Snow in the space the notice held, where there was nothing written.
	// It thins out towards the edges, so there is no box to see.
	float edge = smoothstep(0.0, 0.08, UV.x) * smoothstep(0.0, 0.25, 1.0 - UV.x) * smoothstep(0.0, 0.3, UV.y) * smoothstep(0.0, 0.3, 1.0 - UV.y);
	float haze = snow * w * (1.0 - w) * 1.8 * edge * (0.6 + 0.4 * sin(uv.y * 12.0 + TIME * 6.0));
	col = vec4(mix(vec3(snow), col.rgb, col.a), max(col.a, haze));
	COLOR = col * COLOR;
}
