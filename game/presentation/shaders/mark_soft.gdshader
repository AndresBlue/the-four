shader_type canvas_item;
render_mode unshaded;
// The camcorder's own lettering, softened along the lines as a piece before
// the tape has it (camcorder_osd.gd, soft_corner; a CanvasGroup's shader:
// what it reads is the group, its colour times its cover). The author wanted
// the old recording's blur on these words and not on the picture or the
// menus. `soft` is how wide, in pixels of the 1280 the interface is laid out
// on; 0 leaves the lettering as it was drawn.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float soft = 3.1;

void fragment() {
	vec2 step = vec2(soft * 0.5 / 1280.0, 0.0);
	vec4 drawn = textureLod(screen_texture, SCREEN_UV, 0.0) * 0.3
		+ (textureLod(screen_texture, SCREEN_UV - step, 0.0) + textureLod(screen_texture, SCREEN_UV + step, 0.0)) * 0.22
		+ (textureLod(screen_texture, SCREEN_UV - step * 2.0, 0.0) + textureLod(screen_texture, SCREEN_UV + step * 2.0, 0.0)) * 0.13;
	// Heavier than it was drawn: a character generator's strokes ran into
	// the dots beside them.
	drawn = min(drawn * 1.5, vec4(1.0));
	if (drawn.a > 0.0001) drawn.rgb /= drawn.a;
	COLOR *= drawn;
}
