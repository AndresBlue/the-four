// What is written on the tape, drawn as the game draws it
// (game/presentation/camcorder_osd.gd, game/ui/osd_style.gd): Consolas at
// weight 600 (the game's fallback for its VCR font), INK with a hard black
// shadow 2 px off, laid out on a 1280x720 canvas and scaled to the frame's
// height. Plus the archive's own marks, the sector card and SIGNAL LOST.
import { clamp, smooth } from "./util.js";

export const INK = [0.94, 0.94, 0.9];
export const SOFT = [0.94, 0.94, 0.9, 0.62];
export const FAINT = [0.94, 0.94, 0.9, 0.22];
export const ALERT = [0.93, 0.22, 0.14];
export const AMBER = [0.96, 0.78, 0.4];
export const MUTED = [0.58, 0.58, 0.56];
export const VCR_BLUE = [0.09, 0.16, 0.62];
export const FONT = "Consolas, 'Lucida Console', monospace";

export const css = (c, a = 1) => `rgba(${Math.round(c[0] * 255)},${Math.round(c[1] * 255)},${Math.round(c[2] * 255)},${(c[3] ?? 1) * a})`;

// Scale from the game's 720-line canvas to this frame.
export const unit = (h) => h / 720;

export function text(g, words, x, y, { size = 30, color = INK, alpha = 1, align = "left", baseline = "alphabetic", shadow = true, weight = 600, font = FONT, u = 1.5, spacing = 0 } = {}) {
	g.save();
	g.font = `${weight} ${size * u}px ${font}`;
	g.textAlign = align;
	g.textBaseline = baseline;
	if (spacing) g.letterSpacing = `${spacing * u}px`;
	if (shadow) {
		g.fillStyle = `rgba(0,0,0,${0.85 * alpha})`;
		g.fillText(words, x + 2 * u, y + 2 * u);
	}
	g.fillStyle = css(color, alpha);
	g.fillText(words, x, y);
	g.restore();
}

// The camcorder OSD of a survivor: REC and SP top right with the blinking
// dot, the clock and date bottom left, the stamina cells bottom right, the
// focus brackets in the middle. t: seconds of tape; opts.clock: seconds since
// midnight at t = 0.
export function camcorder(g, t, { w, h }, { clock = 2 * 3600 + 51 * 60 + 25, date = "AUG. 3 1990", rec = true, stamina = null, exhausted = false, focus = 0, word = "", alpha = 1, code = "" } = {}) {
	const u = unit(h);
	const blink = ((t % 1) + 1) % 1;
	if (rec) {
		text(g, "REC", w - 44 * u, 55 * u, { align: "right", u, alpha });
		text(g, "SP", w - 44 * u, 89 * u, { align: "right", u, alpha });
		if (blink < 0.6) {
			g.fillStyle = css(ALERT, alpha);
			g.beginPath();
			g.arc(w - 129 * u, 53 * u, 9 * u, 0, Math.PI * 2);
			g.fill();
		}
		const total = Math.floor(clock + t);
		const hours = Math.floor(total / 3600);
		const h12 = hours % 12 === 0 ? 12 : hours % 12;
		const mm = String(Math.floor(total / 60) % 60).padStart(2, "0");
		const ss = String(total % 60).padStart(2, "0");
		text(g, `AM ${h12}:${mm}:${ss}`, 48 * u, h - 95 * u, { u, alpha });
		text(g, date, 48 * u, h - 61 * u, { u, alpha });
		if (code) text(g, `CODE  ${code}`, 48 * u, h - 132 * u, { u, alpha, size: 26 });
	}
	if (stamina !== null) {
		const right = w - 48 * u;
		const bottom = h - 60 * u;
		const cw = 14 * u;
		const ch = 22 * u;
		const gap = 5 * u;
		const width = 14 * (cw + gap) - gap;
		const lit = Math.ceil(clamp(stamina) * 14);
		const flash = exhausted && blink > 0.5;
		for (let i = 0; i < 14; i++) {
			const x = right - width + i * (cw + gap);
			g.fillStyle = `rgba(0,0,0,${0.6 * alpha})`;
			g.fillRect(x + 2 * u, bottom - ch + 2 * u, cw, ch);
			g.fillStyle = css(exhausted ? ALERT : INK, alpha * (i < lit && !flash ? 0.9 : 0.18));
			g.fillRect(x, bottom - ch, cw, ch);
		}
	}
	if (focus > 0.01) {
		const cx = w / 2;
		const cy = h / 2;
		const hx = 46 * u * (1 + (1 - focus) * 0.35);
		const hy = 32 * u * (1 + (1 - focus) * 0.35);
		const arm = 14 * u;
		for (const pass of [0, 1]) {
			const shift = pass === 0 ? 2 * u : 0;
			g.strokeStyle = pass === 0 ? `rgba(0,0,0,${0.6 * focus * alpha})` : css(INK, 0.9 * focus * alpha);
			g.lineWidth = 3 * u;
			g.beginPath();
			for (const sx of [-1, 1]) {
				for (const sy of [-1, 1]) {
					const x = cx + sx * hx + shift;
					const y = cy + sy * hy + shift;
					g.moveTo(x - sx * arm, y);
					g.lineTo(x, y);
					g.lineTo(x, y - sy * arm);
				}
			}
			g.stroke();
		}
		if (word) text(g, word, cx, cy + 44 * u + 22 * u, { size: 20, align: "center", u, alpha: alpha * focus });
	}
}

// The archive's burn-in: a small black window with its catalogue line, the
// way a transfer house stamps a tape it copies.
export function burnIn(g, lines, { w, h }, { alpha = 1, x = null, y = null, size = 20, typed = 1 } = {}) {
	const u = unit(h);
	const pad = 8 * u;
	g.save();
	g.font = `600 ${size * u}px ${FONT}`;
	const shown = lines.map((l) => l.slice(0, Math.ceil(l.length * clamp(typed))));
	const width = Math.max(...lines.map((l) => g.measureText(l).width)) + pad * 2;
	const lineH = size * 1.25 * u;
	const height = lineH * lines.length + pad * 1.2;
	const bx = x ?? 40 * u;
	const by = y ?? 34 * u;
	g.fillStyle = `rgba(0,0,0,${0.82 * alpha})`;
	g.fillRect(bx, by, width, height);
	g.fillStyle = css(INK, alpha);
	g.textBaseline = "top";
	shown.forEach((l, i) => g.fillText(l, bx + pad, by + pad * 0.8 + i * lineH));
	g.restore();
}

// The sector card as the game writes it after a lift ride: the heading, a
// faint rule, the errand in amber (hotel_ui.gd show_transit), centred.
export function sectorCard(g, { w, h }, { sector, errand, alpha = 1, backdrop = 0 }) {
	const u = unit(h);
	if (backdrop > 0) {
		g.fillStyle = `rgba(0,0,0,${backdrop * alpha})`;
		g.fillRect(0, 0, w, h);
	}
	const cy = h / 2;
	text(g, sector, w / 2, cy - 20 * u, { size: 54, align: "center", u, alpha });
	g.fillStyle = css(FAINT, alpha);
	g.fillRect(w / 2 - 140 * u, cy + 8 * u, 280 * u, 2 * u);
	text(g, errand, w / 2, cy + 50 * u, { size: 26, color: AMBER, align: "center", u, alpha });
}

// SIGNAL LOST: the failure title with its colour ghosts (hotel_ui.gd title()).
export function signalLost(g, { w, h }, { alpha = 1, size = 70, words = "SIGNAL LOST", y = null } = {}) {
	const u = unit(h);
	const cy = y ?? h / 2 + 20 * u;
	for (const [dx, c] of [[-3, [0.9, 0.15, 0.1, 0.55]], [3, [0.1, 0.75, 0.9, 0.45]]]) text(g, words, w / 2 + dx * u, cy, { size, color: c, align: "center", u, alpha, shadow: false });
	text(g, words, w / 2, cy, { size, color: ALERT, align: "center", u, alpha });
}

// The game's drawn headphones (osd_style.gd headphones()), `size` wide, top-left at (x, y).
export function headphones(g, x, y, size, color = MUTED, alpha = 1) {
	const stroke = Math.max(2, size * 0.07);
	const mx = x + size * 0.5;
	const my = y + size * 0.38;
	const reach = size * 0.35;
	g.save();
	g.strokeStyle = css(color, alpha);
	g.fillStyle = css(color, alpha);
	g.lineWidth = stroke;
	g.beginPath();
	g.arc(mx, my, reach, Math.PI, Math.PI * 2);
	g.stroke();
	for (const side of [-1, 1]) {
		const hx = mx + side * reach;
		g.lineWidth = stroke * 2.2;
		g.lineCap = "butt";
		g.beginPath();
		g.moveTo(hx, my);
		g.lineTo(hx, my + size * 0.2);
		g.stroke();
		g.beginPath();
		g.arc(hx, my + size * 0.2, stroke * 1.1, 0, Math.PI * 2);
		g.fill();
	}
	g.restore();
}

// Typewriter reveal: how many characters of `words` show at time t.
export function typed(words, t, start, cps = 28) {
	return words.slice(0, Math.max(0, Math.floor((t - start) * cps)));
}

export const fadeIn = (t, at, d) => smooth((t - at) / d);

// The zoom rocker's scale (camcorder_osd.gd): "W [---▮---] T" at the top,
// shown while zooming; zoom 0 is wide, 1 tele.
export function zoomBar(g, { w, h }, zoom, alpha = 1) {
	if (alpha <= 0.01) return;
	const u = unit(h);
	const cx = w / 2;
	const x0 = cx - 111.8 * u;
	const x1 = cx + 111.8 * u;
	const y0 = 56 * u;
	const y1 = 80 * u;
	const tx0 = cx - 85 * u;
	const tx1 = cx + 85 * u;
	const ty = 68 * u;
	for (const pass of [0, 1]) {
		const d = pass === 0 ? 2 * u : 0;
		const ink = pass === 0 ? (a) => `rgba(0,0,0,${0.6 * a})` : (a) => css(INK, a);
		g.strokeStyle = ink(0.45 * alpha);
		g.lineWidth = 4 * u;
		g.strokeRect(x0 + d, y0 + d, x1 - x0, y1 - y0);
		g.lineWidth = 5 * u;
		g.beginPath();
		g.moveTo(tx0 + d, ty + d);
		g.lineTo(tx1 + d, ty + d);
		for (const x of [tx0, tx1]) {
			g.moveTo(x + d, ty - 5 * u + d);
			g.lineTo(x + d, ty + 5 * u + d);
		}
		g.stroke();
		g.fillStyle = ink(0.9 * alpha);
		g.fillRect(tx0 + (tx1 - tx0) * zoom - 6 * u + d, 61 * u + d, 12 * u, 14 * u);
	}
	text(g, "W", x0 + 9 * u, 73.76 * u, { size: 16, u, alpha: alpha * 0.9 });
	text(g, "T", x1 - 17.8 * u, 73.76 * u, { size: 16, u, alpha: alpha * 0.9 });
}
