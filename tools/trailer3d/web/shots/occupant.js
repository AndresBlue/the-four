// The screen goes black. Over nothing: "The occupant... wasn't one of them."
// Only the faintest grain of the tape is left, the picture gone.
import { tape } from "./common.js";

export function create(ctx) {
	return {
		frame: "tape",
		look(t) {
			const L = tape({ exposure: 1 });
			L.fadeAll = 0.97;
			return L;
		},
	};
}
