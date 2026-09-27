// Page entry: builds the engine from the timeline and hands render.mjs an API.
//   /index.html?scale=0.5&samples=8&timeline=test.json
import { Engine } from "./engine/engine.js";

const query = new URLSearchParams(location.search);
const timeline = await (await fetch(`/cfg/${query.get("timeline") ?? "timeline.json"}`)).json();
const engine = new Engine(timeline, {
	scale: Number(query.get("scale") ?? 1),
	samples: query.has("samples") ? Number(query.get("samples")) : null,
});
window.engine = engine;
window.api = {
	length: engine.length,
	fps: 30,
	async render(frame, path) {
		const t0 = performance.now();
		const info = await engine.renderFrame(frame);
		if (path) await engine.save(path);
		return { ...info, ms: performance.now() - t0 };
	},
};
window.ready = true;
