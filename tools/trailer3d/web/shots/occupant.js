// The archive's card, for a moment: three guests lost, one degraded, and below
// them the occupant. "And the occupant..." The picture starts to fail.
// "...wasn't one of them." The 4:3 frame tears apart sideways; the human
// picture is gone.
import { text, burnIn, INK, ALERT, AMBER } from "../engine/osd.js";
import { smoothstep, clamp } from "../engine/util.js";
import { tape } from "./common.js";

export const FAIL = 0.95;
export const TEAR = [1.75, 2.35];

export function create(ctx) {
	return {
		frame: "tape",
		look(t) {
			const L = tape({ exposure: 1 });
			const f = smoothstep(FAIL, TEAR[0], t);
			L.tracking = f * 0.8;
			L.drag = f * 0.6;
			L.roll = t > TEAR[0] ? (t - TEAR[0]) * 0.1 : 0;
			L.frameTear = smoothstep(TEAR[0], TEAR[1], t);
			return L;
		},
		overlay(g, t, { w, h }) {
			const u = h / 720;
			const rows = [["GUEST 01", "LOST", ALERT], ["GUEST 02", "LOST", ALERT], ["GUEST 03", "LOST", ALERT], ["GUEST 04", "SIGNAL DEGRADED", AMBER]];
			const x = 250 * u;
			rows.forEach(([a, b, c], i) => {
				if (t < i * 0.05) return;
				text(g, a, x, 250 * u + i * 52 * u, { size: 30, u });
				text(g, "— " + b, x + 190 * u, 250 * u + i * 52 * u, { size: 30, color: c, u });
			});
			g.fillStyle = "rgba(240,240,230,0.22)";
			g.fillRect(x, 470 * u, 560 * u, 2 * u);
			if (t > 0.25) text(g, "OCCUPANT: THE LOCUST", x, 520 * u, { size: 34, u });
		},
	};
}
