shader_type spatial;
// Her marks in the world (.claude/specs/lurker_versus.md 13.9), drawn after
// her reading (lurker_sight.gdshader) and in its terms, so her sensor
// (lurker_thermal_sensor.gdshader) colours them with it: the vertex colour is
// what is packed (red a reading, green a pale mark, pink in the ducts; blue a
// red one); its alpha how much the pale mark darkens on faces turned away,
// so a tube reads as a tube. lurker_view.gd draws with it the outline of the
// tile she would go down by and of the way into the ducts at hand, the ducts'
// network and its ways out, and the lines of why her prey is not hers.
// Its copy with no depth test (lurker_view.through()) is seen through all.
render_mode unshaded, blend_mix, depth_draw_always, cull_disabled, fog_disabled, shadows_disabled;

void fragment() {
	vec3 packed = COLOR.rgb;
	float facing = abs(dot(NORMAL, VIEW));
	packed.g *= mix(1.0, 0.5 + 0.5 * facing, COLOR.a);
	// Into linear, so the screen holds what is packed itself.
	ALBEDO = mix(pow((packed + 0.055) / 1.055, vec3(2.4)), packed / 12.92, lessThan(packed, vec3(0.04045)));
	ALPHA = 1.0;
}
