// The game's first screen: its own drawn headphones and HEADPHONES RECOMMENDED
// out of the black (hotel_ui.gd boot notice), in the menu's muted grey.
import { headphones, text, MUTED } from "../engine/osd.js";
import { smoothstep } from "../engine/util.js";

export function create(ctx) {
	return {
		frame: "wide",
		look() {
			return { kind: "clean", exposure: 1, grain: 0.03, vignette: 0.2, chromatic: 0 };
		},
		overlay(g, t, { w, h }) {
			const a = smoothstep(0.15, 0.45, t) * (1 - smoothstep(1.05, 1.35, t));
			if (a <= 0) return;
			const u = h / 720;
			const size = 104 * u;
			const iconH = size * 0.62;
			const gap = 30 * u;
			const textH = 34 * u;
			const top = h / 2 - (iconH + gap + textH) / 2;
			headphones(g, w / 2 - size / 2, top, size, MUTED, a);
			text(g, "HEADPHONES RECOMMENDED", w / 2, top + iconH + gap + 24 * u, { size: 30, align: "center", color: MUTED, alpha: a, u });
		},
	};
}
