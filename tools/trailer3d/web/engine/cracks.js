// Cracked CRT glass, as the game's opening draws it (game/intro/crack_pattern.gd):
// each blow leaves a crushed frosted core, long radial cracks that run nearly
// straight with small kinks and forks, and ring cracks joining neighbouring
// radials. Blow n is written to channel n (R, G, B, A), so the screen shader
// reveals the damage one blow at a time.
import * as THREE from "three";
import { rng } from "./util.js";

const W = 1024;
const H = 768;

export function makeCracks(blows = [[[0.455, 0.47], 0.55], [[0.55, 0.555], 0.85]], seed = 4411) {
	const random = rng(seed);
	const rr = (a, b) => a + (b - a) * random();
	const layers = [];
	for (const [uv, severity] of blows) {
		const c = document.createElement("canvas");
		c.width = W;
		c.height = H;
		const g = c.getContext("2d");
		g.fillStyle = "#000";
		g.fillRect(0, 0, W, H);
		g.lineCap = "round";
		const stroke = (a, b, strength, width) => {
			g.strokeStyle = `rgba(255,255,255,${Math.min(1, strength)})`;
			g.lineWidth = width * 2;
			g.beginPath();
			g.moveTo(a[0], a[1]);
			g.lineTo(b[0], b[1]);
			g.stroke();
		};
		const centre = [uv[0] * W, uv[1] * H];
		const reach = 120 + (420 - 120) * severity;
		const core = 4 + 7 * severity;
		for (let i = 0; i < 14 + Math.floor(severity * 18); i++) {
			const a = random() * Math.PI * 2;
			const from = [centre[0] + Math.cos(a) * random() * core, centre[1] + Math.sin(a) * random() * core];
			const b = a + rr(-1.2, 1.2);
			const len = rr(3, core);
			stroke(from, [from[0] + Math.cos(b) * len, from[1] + Math.sin(b) * len], rr(0.4, 0.8), 0.45);
		}
		g.fillStyle = "rgba(255,255,255,0.45)";
		g.beginPath();
		g.arc(centre[0], centre[1], core * 0.5, 0, Math.PI * 2);
		g.fill();
		const radial = (from, angle, length, strength, depth) => {
			const pts = [from];
			let p = from;
			let travelled = 0;
			let heading = angle;
			while (travelled < length) {
				const step = rr(8, 18);
				heading += rr(-0.14, 0.14);
				const next = [p[0] + Math.cos(heading) * step, p[1] + Math.sin(heading) * step];
				const fade = 1 - travelled / length;
				stroke(p, next, strength * (0.3 + 0.7 * fade), 0.3 + 0.4 * fade);
				pts.push(next);
				if (depth > 0 && travelled > length * 0.25 && random() < 0.06) radial(next, heading + rr(0.35, 0.8) * (random() < 0.5 ? 1 : -1), (length - travelled) * rr(0.3, 0.6), strength * 0.75, depth - 1);
				p = next;
				travelled += step;
				if (p[0] < 0 || p[1] < 0 || p[0] > W || p[1] > H) break;
			}
			return pts;
		};
		const pointOn = (line, radius) => {
			let travelled = 0;
			for (let i = 1; i < line.length; i++) {
				const seg = Math.hypot(line[i][0] - line[i - 1][0], line[i][1] - line[i - 1][1]);
				if (travelled + seg >= radius) {
					const k = (radius - travelled) / seg;
					return [line[i - 1][0] + (line[i][0] - line[i - 1][0]) * k, line[i - 1][1] + (line[i][1] - line[i - 1][1]) * k];
				}
				travelled += seg;
			}
			return null;
		};
		const count = 6 + Math.floor(severity * 6);
		const rays = [];
		const offset = random() * Math.PI * 2;
		for (let i = 0; i < count; i++) rays.push(radial(centre, offset + (Math.PI * 2 * i) / count + rr(-0.25, 0.25), reach * rr(0.45, 1.0), 1, 2));
		for (let ring = 0; ring < 1 + (severity > 0.5 ? 1 : 0); ring++) {
			const radius = reach * (0.22 + 0.25 * ring) * rr(0.85, 1.15);
			for (let i = 0; i < count; i++) {
				if (random() < 0.3) continue;
				const p = pointOn(rays[i], radius);
				const q = pointOn(rays[(i + 1) % count], radius * rr(0.9, 1.1));
				if (!p || !q) continue;
				const d = Math.hypot(p[0] - centre[0], p[1] - centre[1]) || 1;
				const push = rr(-4, 6);
				const mid = [(p[0] + q[0]) / 2 + ((p[0] - centre[0]) / d) * push, (p[1] + q[1]) / 2 + ((p[1] - centre[1]) / d) * push];
				stroke(p, mid, 0.6, 0.45);
				stroke(mid, q, 0.6, 0.45);
			}
		}
		layers.push(g.getImageData(0, 0, W, H).data);
	}
	// Pack: blow n in channel n.
	const out = new Uint8Array(W * H * 4);
	for (let i = 0; i < W * H; i++) {
		for (let ch = 0; ch < 4; ch++) out[i * 4 + ch] = layers[ch] ? layers[ch][i * 4] : 0;
	}
	// Rows of the canvas run down, as the tube's UV does in the shader (it
	// flips its own y), so the data goes in as it is, without a flip.
	const tex = new THREE.DataTexture(out, W, H, THREE.RGBAFormat);
	tex.flipY = false;
	tex.minFilter = THREE.LinearFilter;
	tex.magFilter = THREE.LinearFilter;
	tex.needsUpdate = true;
	return { texture: tex };
}
