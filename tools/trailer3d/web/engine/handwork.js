// Pencil by hand, as the game writes it (game/ui/handwork.gd): digits as a
// few strokes whose turns wander, drawn twice a hair apart; a page number
// between two dashes; and the wear of a worn sheet of paper.

const STROKES = {
	0: [[[0.5, 0.06], [0.74, 0.16], [0.84, 0.42], [0.8, 0.72], [0.62, 0.92], [0.4, 0.93], [0.2, 0.76], [0.16, 0.46], [0.24, 0.18], [0.46, 0.06], [0.58, 0.09]]],
	1: [[[0.3, 0.24], [0.56, 0.06], [0.54, 0.94]]],
	2: [[[0.18, 0.28], [0.3, 0.1], [0.52, 0.05], [0.74, 0.14], [0.8, 0.32], [0.68, 0.52], [0.18, 0.93], [0.84, 0.9]]],
	3: [[[0.18, 0.14], [0.44, 0.05], [0.72, 0.13], [0.76, 0.32], [0.46, 0.47], [0.78, 0.6], [0.8, 0.82], [0.52, 0.95], [0.18, 0.86]]],
	4: [[[0.62, 0.94], [0.62, 0.05], [0.14, 0.66], [0.86, 0.64]]],
	5: [[[0.8, 0.07], [0.28, 0.08], [0.22, 0.46], [0.5, 0.38], [0.78, 0.5], [0.8, 0.77], [0.56, 0.94], [0.2, 0.86]]],
	6: [[[0.74, 0.1], [0.46, 0.08], [0.26, 0.34], [0.2, 0.7], [0.36, 0.93], [0.64, 0.93], [0.8, 0.72], [0.68, 0.52], [0.4, 0.5], [0.22, 0.66]]],
	7: [[[0.16, 0.08], [0.84, 0.07], [0.4, 0.94]]],
	8: [[[0.5, 0.48], [0.28, 0.36], [0.28, 0.14], [0.5, 0.05], [0.72, 0.14], [0.7, 0.36], [0.5, 0.48], [0.22, 0.62], [0.24, 0.86], [0.5, 0.95], [0.78, 0.86], [0.78, 0.62], [0.5, 0.48]]],
	9: [[[0.78, 0.36], [0.64, 0.08], [0.36, 0.08], [0.2, 0.3], [0.32, 0.5], [0.62, 0.5], [0.78, 0.36], [0.74, 0.7], [0.56, 0.94], [0.28, 0.9]]],
};

export const PAPER = "rgb(219,209,181)";
export const GRAPHITE = [0.13, 0.12, 0.12];

// A number between -0.5 and 0.5 that only depends on its arguments.
export function jitter(a, b) {
	const v = Math.sin(a * 12.9898 + b * 78.233) * 43758.5453;
	return v - Math.floor(v) - 0.5;
}

function rgba(c, a) {
	return `rgba(${Math.round(c[0] * 255)},${Math.round(c[1] * 255)},${Math.round(c[2] * 255)},${a})`;
}

// Writes `value` into the box (x, y, w, h); `drawn` 0..1 reveals the strokes
// as a pencil would (for writing it on screen).
export function writeDigit(g, value, box, ink, weight, seed = 0, { drawn = 1, alpha = 1 } = {}) {
	const strokes = STROKES[Math.max(0, Math.min(9, value))] ?? [];
	for (const stroke of strokes) {
		for (let pass = 0; pass < 2; pass++) {
			const turns = stroke.map(([x, y], k) => [x + jitter(k, seed + pass * 3.1) * 0.07, y + jitter(k + 7.7, seed - pass * 1.9) * 0.07]);
			const pts = [];
			for (let k = 0; k < turns.length - 1; k++) {
				for (let st = 0; st < 4; st++) {
					const t = st / 4;
					const gx = jitter(k * 4 + st, seed + 11) * 0.012;
					const gy = jitter(k * 4 + st + 3.3, seed + 5) * 0.012;
					pts.push([box[0] + (turns[k][0] + (turns[k + 1][0] - turns[k][0]) * t + gx) * box[2], box[1] + (turns[k][1] + (turns[k + 1][1] - turns[k][1]) * t + gy) * box[3]]);
				}
			}
			const last = turns[turns.length - 1];
			pts.push([box[0] + last[0] * box[2], box[1] + last[1] * box[3]]);
			const n = Math.max(2, Math.ceil(pts.length * Math.max(0, Math.min(1, drawn))));
			g.save();
			g.strokeStyle = rgba(ink, alpha * (pass === 0 ? 1 : 0.55));
			g.lineWidth = weight * (pass === 0 ? 1 : 0.7);
			g.lineCap = "round";
			g.lineJoin = "round";
			g.beginPath();
			pts.slice(0, n).forEach(([x, y], i) => (i ? g.lineTo(x, y) : g.moveTo(x, y)));
			g.stroke();
			g.restore();
		}
	}
}

// A short dash either side of a small number: how a page is numbered.
export function writePage(g, value, cx, cy, height, ink, seed = 0, alpha = 1) {
	const width = height * 0.62;
	writeDigit(g, value, [cx - width / 2, cy - height / 2, width, height], ink, Math.max(1.2, height * 0.12), seed, { alpha });
	g.save();
	g.strokeStyle = rgba(ink, alpha);
	g.lineWidth = Math.max(1, height * 0.1);
	g.lineCap = "round";
	for (const side of [-1, 1]) {
		g.beginPath();
		g.moveTo(cx + side * height * 0.62, cy);
		g.lineTo(cx + side * height * 1.25, cy + jitter(side, seed) * height * 0.15);
		g.stroke();
	}
	g.restore();
}

// Paper wear (handwork.gd wear()): pulp grain, yellowing from the edges,
// optionally a fold and coffee rings; brown over the page.
export function wear(g, w, h, seed, { marked = true } = {}) {
	let s = seed >>> 0;
	const rnd = () => {
		s = (s * 1664525 + 1013904223) >>> 0;
		return s / 4294967296;
	};
	const rings = [];
	if (marked) for (let n = 0, c = 1 + Math.floor(rnd() * 3); n < c; n++) rings.push([0.08 + rnd() * 0.84, 0.08 + rnd() * 0.84, 0.06 + rnd() * 0.07, 0.5 + rnd() * 0.5]);
	const blots = [];
	for (let n = 0, c = 2 + Math.floor(rnd() * 4); n < c; n++) blots.push([rnd(), rnd(), 0.05 + rnd() * 0.15, 0.2 + rnd() * 0.35]);
	const fold = 0.35 + rnd() * 0.3;
	const cw = Math.max(32, Math.round(w / 6));
	const ch = Math.max(20, Math.round(h / 6));
	const img = g.createImageData(cw, ch);
	const aspect = cw / ch;
	for (let y = 0; y < ch; y++) {
		for (let x = 0; x < cw; x++) {
			const u = (x + 0.5) / cw;
			const v = (y + 0.5) / ch;
			let amount = 0.05 + jitter(x, y + seed) * 0.06;
			const edge = Math.min(Math.min(u, 1 - u) * aspect, Math.min(v, 1 - v));
			amount += Math.pow(Math.max(0, Math.min(1, 1 - edge / 0.12)), 2) * 0.45;
			if (marked) amount += Math.exp(-Math.pow(((u - fold) * cw) / 2.2, 2)) * 0.22;
			for (const [rx, ry, rr, rs] of rings) {
				const d = Math.hypot((u - rx) * aspect, v - ry) / rr;
				amount += (Math.exp(-Math.pow((d - 1) * 9, 2)) * 0.34 + (d < 1 ? 0.07 : 0)) * rs;
			}
			for (const [bx, by, br, bs] of blots) {
				const d = Math.hypot((u - bx) * aspect, v - by) / br;
				amount += Math.exp(-d * d * 2) * bs * 0.35;
			}
			const i = (y * cw + x) * 4;
			img.data[i] = 0.42 * 255;
			img.data[i + 1] = 0.29 * 255;
			img.data[i + 2] = 0.14 * 255;
			img.data[i + 3] = Math.max(0, Math.min(0.85, amount)) * 255;
		}
	}
	const c = document.createElement("canvas");
	c.width = cw;
	c.height = ch;
	c.getContext("2d").putImageData(img, 0, 0);
	g.save();
	g.imageSmoothingEnabled = true;
	g.drawImage(c, 0, 0, w, h);
	g.restore();
}
