// Renders frames of the trailer with headless Chromium on the GPU.
//   node render.mjs                        every frame, full quality -> evidence/trailer3d/frames/
//   node render.mjs --from 16 --to 21      a stretch (seconds)
//   node render.mjs --shots guest1,guest2  whole shots
//   node render.mjs --at 12.5,30           single frames (seconds) -> stills/
//   --scale 0.5 --samples 8 --step 3       quick previews (-> preview/)
//   --timeline test.json                   another timeline in this folder (a test shot)
import { serve } from "./server.mjs";
import { createRequire } from "node:module";
import { execSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);
let playwright;
try { playwright = require("playwright"); } catch { playwright = require(execSync("npm root -g").toString().trim() + "/playwright"); }

const args = process.argv.slice(2);
const opt = (name, fallback) => { const i = args.indexOf(`--${name}`); return i >= 0 ? args[i + 1] : fallback; };
const timelineFile = opt("timeline", "timeline.json");
const timeline = JSON.parse(fs.readFileSync(path.join(here, timelineFile), "utf8"));
const FPS = timeline.fps;
const scale = Number(opt("scale", 1));
const samples = opt("samples", null);
const step = Number(opt("step", 1));
const preview = scale < 1 || samples !== null || step > 1;
let frames = [];
const length = timeline.shots[timeline.shots.length - 1].end;
const labels = new Map();
if (opt("at")) {
	frames = opt("at").split(",").map((s) => {
		const f = Math.round(Number(s) * FPS);
		labels.set(f, `${Number(s).toFixed(2)}s.png`);
		return f;
	});
} else if (opt("shots")) {
	for (const id of opt("shots").split(",")) {
		const e = timeline.shots.find((s) => s.id === id);
		if (!e) throw new Error(`no shot ${id}`);
		for (let f = Math.round(e.start * FPS); f < Math.round(e.end * FPS); f += step) frames.push(f);
	}
} else {
	const from = Math.round(Number(opt("from", 0)) * FPS);
	const to = Math.round(Number(opt("to", length)) * FPS);
	for (let f = from; f < to; f += step) frames.push(f);
}
const dir = opt("out", opt("at") ? "stills" : preview ? "preview" : "frames");
const port = 8090 + Math.floor(Math.random() * 500);
const server = await serve(port);
const browser = await playwright.chromium.launch({ headless: true, args: ["--use-angle=d3d11", "--enable-gpu", "--ignore-gpu-blocklist", "--disable-gpu-watchdog", "--disable-renderer-backgrounding", "--js-flags=--max-old-space-size=8192"] });
const page = await browser.newPage({ viewport: { width: Math.round(1920 * scale), height: Math.round(1080 * scale) }, deviceScaleFactor: 1 });
page.setDefaultTimeout(0);
page.on("console", (m) => { if (m.type() === "error" || m.type() === "warning") console.log(`page ${m.type()}: ${m.text()}`); });
page.on("pageerror", (e) => console.log("page error:", e.message));
page.on("response", (r) => { if (r.status() >= 400) console.log(`page ${r.status()}: ${r.url()}`); });
const query = new URLSearchParams({ scale: String(scale) });
if (samples !== null) query.set("samples", samples);
if (timelineFile !== "timeline.json") query.set("timeline", timelineFile);
if (args.includes("--debug")) query.set("debug", "1");
await page.goto(`http://127.0.0.1:${port}/index.html?${query}`);
await page.waitForFunction(() => window.ready === true);
const started = Date.now();
let done = 0;
for (const f of frames) {
	const name = opt("at") ? labels.get(f) : `${String(f).padStart(5, "0")}.png`;
	const info = await page.evaluate(async ([frame, p]) => window.api.render(frame, p), [f, `${dir}/${name}`]);
	done++;
	if (done % 10 === 0 || done === frames.length || opt("at")) {
		const rate = (Date.now() - started) / done / 1000;
		console.log(`${dir}/${name}  ${info.shot} t=${info.t.toFixed(2)}  ${info.ms.toFixed(0)} ms  [${done}/${frames.length}, ~${Math.round(rate * (frames.length - done))} s left]`);
	}
}
await browser.close();
server.close();
