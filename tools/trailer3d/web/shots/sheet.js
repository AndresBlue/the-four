// The shared sheet (game/ui/paper_sheet.gd, sheet_map.gd): worn cream paper,
// its rules and margin; the plan of what the guests have seen drawn in
// iron-gall ink, each wall blooming into the page as it is seen, with its
// faint plum afterimage; a ring where you are. The pencils of the four seats —
// black, navy, dark red, dark green — add an arrow, "TV", a ring round 214.
// The oldest ink pales, comes apart into blotches, and is gone.
import { wear, jitter, writePage, GRAPHITE, PAPER as NOTE_PAPER } from "../engine/handwork.js";
import { text, SOFT } from "../engine/osd.js";
import { clamp, smooth, smoothstep, lerp } from "../engine/util.js";
import { tape } from "./common.js";

const PAPER = [0.86, 0.82, 0.71];
const INKS = [[0.1, 0.1, 0.11], [0.11, 0.16, 0.38], [0.44, 0.09, 0.09], [0.09, 0.29, 0.13]];
const IRON = [0.32, 0.17, 0.09];
const GHOST = [0.48, 0.1, 0.24];
export const SUPER = 2.95;

const rgba = (c, a) => `rgba(${Math.round(c[0] * 255)},${Math.round(c[1] * 255)},${Math.round(c[2] * 255)},${a})`;

// A storey of the hotel as wall pieces of 0.7 m (floor_map.gd PIECE), in metres:
// a corridor with rooms both sides, a branch down, doorways as gaps.
function plan() {
	const walls = [];
	const seg = (x1, y1, x2, y2) => {
		const len = Math.hypot(x2 - x1, y2 - y1);
		const n = Math.max(1, Math.round(len / 0.7));
		for (let i = 0; i < n; i++) walls.push([x1 + ((x2 - x1) * i) / n, y1 + ((y2 - y1) * i) / n, x1 + ((x2 - x1) * (i + 1)) / n, y1 + ((y2 - y1) * (i + 1)) / n]);
	};
	const wallWithDoors = (x1, y, x2, doors) => {
		let x = x1;
		for (const d of doors) {
			seg(x, y, d - 0.65, y);
			x = d + 0.65;
		}
		seg(x, y, x2, y);
	};
	// The corridor: y 0..3.5, x 0..48.
	wallWithDoors(0, 0, 48, [6, 18, 30, 42]);
	wallWithDoors(0, 3.5, 20, [10]);
	wallWithDoors(23.5, 3.5, 48, [34, 44]);
	// Rooms above (y -12..0) every 12 m, below (y 3.5..15.5) every 12 m.
	for (let x = 0; x <= 48; x += 12) seg(x, -12, x, 0);
	seg(0, -12, 48, -12);
	for (const x of [0, 12, 36, 48]) seg(x, 3.5, x, 15.5);
	seg(0, 15.5, 20, 15.5);
	seg(23.5, 15.5, 48, 15.5);
	// The branch down between them.
	seg(20, 3.5, 20, 15.5);
	seg(23.5, 3.5, 23.5, 15.5);
	// Furniture outlines in a couple of rooms (alcove partitions).
	seg(3, -3, 3, -8);
	seg(40, 8, 45, 8);
	return walls;
}

export function create(ctx) {
	const walls = plan();
	// When each piece was seen: the ring walks the corridor from x 2 to 30.
	const walk = (t) => lerp(2, 30, smooth(t / 3.2));
	const seenAt = walls.map(([x1, y1, x2, y2]) => {
		const cx = (x1 + x2) / 2;
		const cy = (y1 + y2) / 2;
		// First moment the walker is within sight of it (9 m in the lit corridor).
		for (let t = 0; t <= 3.6; t += 0.02) {
			const w = walk(t);
			if (Math.hypot(cx - w, cy - 1.75) < 12 + (Math.abs(cy - 1.75) < 2 ? 6 : 0)) return t;
		}
		return 99;
	});
	const chance = (i, part) => {
		const h = Math.sin(i * 91.3458 + part * 47.853) * 23421.631;
		return h - Math.floor(h);
	};
	const shot = {
		frame: "wide",
		look(t) {
			return tape({ exposure: 1, vhs: 0.4, grain: 0.18, bloom: 0.02, halation: 0.1, saturation: 0.95 });
		},
		overlay(g, t, { w, h }) {
			// The game behind, dimmed.
			g.fillStyle = "rgb(12,10,9)";
			g.fillRect(0, 0, w, h);
			const u = h / 1080;
			const PW = 1500 * u;
			const PH = 950 * u;
			// Your notes, as the game keeps them beside the sheet: the page a
			// drawer gave up, its number in pencil.
			const nx = w / 2 + 760 * u;
			const ny = 120 * u;
			text(g, "YOUR NOTES", nx, 96 * u, { size: 15, u, alpha: 0.75, spacing: 2 });
			g.save();
			g.translate(nx + 10 * u, ny);
			g.rotate(0.03);
			g.fillStyle = "rgba(0,0,0,0.55)";
			g.fillRect(8 * u, 10 * u, 150 * u, 190 * u);
			g.fillStyle = NOTE_PAPER;
			g.fillRect(0, 0, 150 * u, 190 * u);
			writePage(g, 3, 75 * u, 82 * u, 92 * u, GRAPHITE, 5);
			g.fillStyle = "rgba(60,52,40,0.55)";
			g.font = `600 ${11 * u}px Consolas, monospace`;
			g.textAlign = "center";
			g.fillText("ROOM 214 · DRAWER", 75 * u, 170 * u);
			g.restore();
			g.save();
			g.translate(w / 2 - 110 * u + Math.sin(t * 0.4) * 4 * u, h / 2 + Math.cos(t * 0.33) * 3 * u);
			g.rotate(-0.008 + Math.sin(t * 0.3) * 0.002);
			g.translate(-PW / 2, -PH / 2);
			// The page and its shadow.
			g.fillStyle = "rgba(0,0,0,0.6)";
			g.fillRect(14 * u, 18 * u, PW, PH);
			g.fillStyle = rgba(PAPER, 1);
			g.fillRect(0, 0, PW, PH);
			g.strokeStyle = "rgba(158,140,107,1)";
			g.lineWidth = 1.5 * u;
			g.strokeRect(0, 0, PW, PH);
			g.lineWidth = 1.4 * u;
			for (let y = 48 * u * 1.5; y < PH; y += 36 * u * 1.5) {
				g.strokeStyle = "rgba(82,107,168,0.2)";
				g.beginPath();
				g.moveTo(24 * u, y);
				g.lineTo(PW - 24 * u, y);
				g.stroke();
			}
			g.strokeStyle = "rgba(168,46,36,0.32)";
			g.beginPath();
			g.moveTo(108 * u, 12 * u);
			g.lineTo(108 * u, PH - 12 * u);
			g.stroke();
			if (!shot.wear) {
				const c = document.createElement("canvas");
				c.width = Math.round(PW);
				c.height = Math.round(PH);
				wear(c.getContext("2d"), c.width, c.height, 1187, { marked: false });
				shot.wear = c;
			}
			g.drawImage(shot.wear, 0, 0, PW, PH);
			// The plan, across the middle of the page.
			const mx = PW * 0.14;
			const my = PH * 0.12;
			const mw = PW * 0.8;
			const mh = PH * 0.8;
			const fit = Math.min(mw / 50, mh / 29) * 0.97;
			const ox = mx + (mw - 48 * fit) / 2;
			const oy = my + (mh - 27.5 * fit) / 2 + 12 * fit;
			const P = (x, y) => [ox + x * fit, oy + y * fit];
			g.save();
			g.font = `600 ${18 * u * 1.5}px Consolas, monospace`;
			g.fillStyle = rgba(IRON, 0.55);
			g.fillText("FLOOR 1", mx + mw * 0.02, my + mh * 0.06);
			g.restore();
			g.lineCap = "round";
			walls.forEach(([x1, y1, x2, y2], i) => {
				const since = t - seenAt[i];
				if (since < 0) return;
				// It fades from the moment it is seen: the oldest go first. (The game
				// takes three minutes; the page here keeps a few seconds.)
				const fresh = clamp(1 - since / 3.1);
				const own = chance(i, 0) * 0.35;
				const pale = smooth(fresh) * smoothstep(own - 0.1, own + 0.1, fresh);
				if (pale <= 0.01) return;
				const wob = (x, y, k) => [jitter(x * 4 + k, y * 4) * 0.9 * u, jitter(y * 4 + k, x * 4 + 3) * 0.9 * u];
				const [ax, ay] = P(x1, y1);
				const [bx, by] = P(x2, y2);
				const [wa, wb] = wob(x1, y1, 0);
				const [wc, wd] = wob(x2, y2, 0);
				const bloom = clamp(1 - since / 0.9);
				// Across the wall: its two faces, 0.18 m apart.
				const len = Math.hypot(bx - ax, by - ay) || 1;
				const nxw = (-(by - ay) / len) * 0.09 * fit;
				const nyw = ((bx - ax) / len) * 0.09 * fit;
				const face = (dx, dy, colour, width) => {
					g.strokeStyle = colour;
					g.lineWidth = width;
					g.beginPath();
					g.moveTo(ax + wa + dx, ay + wb + dy);
					g.lineTo(bx + wc + dx, by + wd + dy);
					g.stroke();
				};
				if (bloom > 0) face(0, 0, rgba(IRON, 0.22 * bloom), 2 * u * (3 + 2 * bloom));
				face(2.4 * u, -1.6 * u, rgba(GHOST, 0.12 * pale), 1.6 * u);
				face(nxw, nyw, rgba(IRON, pale), 1.7 * u);
				face(-nxw, -nyw, rgba(IRON, pale), 1.7 * u);
			});
			// Where these eyes are, faintly, as if the page knew.
			const [px, py] = P(walk(t), 1.75);
			const pulse = 0.5 + 0.5 * Math.sin(t * 2.2);
			g.strokeStyle = rgba(GHOST, 0.55 + 0.25 * pulse);
			g.lineWidth = 1.6 * u * 1.5;
			g.beginPath();
			g.arc(px, py, 4.5 * u * 1.5, 0, Math.PI * 2);
			g.stroke();
			g.beginPath();
			g.moveTo(px + 8 * u, py);
			g.lineTo(px + 17 * u, py);
			g.stroke();
			// The pencils: an arrow (black), "TV" (navy), a ring round 214 (dark red),
			// a line along the branch (dark green); each drawn as time goes.
			const pencil = (ink, from, to, draw) => {
				const k = clamp((t - from) / (to - from));
				if (k <= 0) return;
				g.save();
				g.strokeStyle = rgba(ink, 0.9);
				g.fillStyle = rgba(ink, 0.9);
				g.lineWidth = 3 * u * 1.5;
				g.lineCap = "round";
				g.lineJoin = "round";
				draw(k);
				g.restore();
			};
			const line = (pts, k) => {
				const n = Math.max(2, Math.ceil(pts.length * k));
				g.beginPath();
				pts.slice(0, n).forEach(([x, y], i) => (i ? g.lineTo(x, y) : g.moveTo(x, y)));
				g.stroke();
			};
			pencil(INKS[0], 0.9, 1.4, (k) => {
				const pts = [];
				for (let i = 0; i <= 20; i++) pts.push(P(6 + i * 0.7, 1.9 + Math.sin(i * 0.6) * 0.15 + jitter(i, 3) * 0.08));
				line(pts, k);
				if (k > 0.9) line([P(19, 1.2), P(20.2, 1.95), P(19, 2.7)], (k - 0.9) / 0.1);
			});
			pencil(INKS[1], 1.5, 1.9, (k) => {
				const [x, y] = P(30, -6.5);
				g.font = `600 ${40 * u * 1.5}px 'Segoe Print', 'Ink Free', cursive`;
				g.save();
				g.beginPath();
				g.rect(x - 20 * u, y - 60 * u, 110 * u * 1.5 * k, 90 * u);
				g.clip();
				g.fillText("TV", x, y);
				g.restore();
			});
			pencil(INKS[2], 2.05, 2.55, (k) => {
				const [x, y] = P(18.5, 9.0);
				g.font = `600 ${30 * u * 1.5}px 'Segoe Print', 'Ink Free', cursive`;
				g.fillText("214", x - 30 * u, y + 10 * u);
				g.beginPath();
				for (let i = 0; i <= 40 * k; i++) {
					const a = -0.6 + (i / 40) * Math.PI * 2.15;
					const r = 50 * u * (1 + jitter(i, 7) * 0.08);
					const X = x + Math.cos(a) * r * 1.3;
					const Y = y + Math.sin(a) * r * 0.85;
					i ? g.lineTo(X, Y) : g.moveTo(X, Y);
				}
				g.stroke();
			});
			pencil(INKS[3], 2.5, 3.0, (k) => {
				const pts = [];
				for (let i = 0; i <= 16; i++) pts.push(P(21.7 + jitter(i, 11) * 0.1, 4 + i * 0.7));
				line(pts, k);
			});
			g.restore();
			if (t >= SUPER) {
				const a = smoothstep(SUPER, SUPER + 0.25, t);
				g.fillStyle = `rgba(0,0,0,${0.55 * a})`;
				g.fillRect(w / 2 - 420 * u, h - 150 * u, 840 * u, 64 * u);
				text(g, "SOLO · 2–5 PLAYER CO-OP · VERSUS", w / 2, h - 106 * u, { size: 26, align: "center", u: u * 1.5, alpha: a, spacing: 2 });
			}
		},
	};
	return shot;
}
