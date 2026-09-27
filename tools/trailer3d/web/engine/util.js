// Deterministic helpers: every frame of the trailer must come out the same on
// every render, so nothing here reads the clock or Math.random.

export const clamp = (x, a = 0, b = 1) => Math.min(Math.max(x, a), b);
export const lerp = (a, b, t) => a + (b - a) * t;
export const invLerp = (a, b, x) => clamp((x - a) / (b - a));
export const smooth = (t) => { t = clamp(t); return t * t * (3 - 2 * t); };
export const smoother = (t) => { t = clamp(t); return t * t * t * (t * (t * 6 - 15) + 10); };
export const smoothstep = (a, b, x) => smooth((x - a) / (b - a));
export const easeIn = (t) => { t = clamp(t); return t * t; };
export const easeOut = (t) => { t = clamp(t); return 1 - (1 - t) * (1 - t); };
export const easeInOut = (t) => { t = clamp(t); return t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2; };
export const deg = (d) => (d * Math.PI) / 180;

// 32-bit integer hash of any number of numbers, then a float in [0, 1).
export function hash(...values) {
	let h = 2166136261 >>> 0;
	for (const v of values) {
		let x = Math.floor(v * 1000003) | 0;
		x = Math.imul(x ^ (x >>> 16), 0x7feb352d);
		x = Math.imul(x ^ (x >>> 15), 0x846ca68b);
		x ^= x >>> 16;
		h = Math.imul(h ^ x, 16777619) >>> 0;
	}
	h ^= h >>> 13;
	h = Math.imul(h, 0x5bd1e995) >>> 0;
	h ^= h >>> 15;
	return (h >>> 0) / 4294967296;
}

export function rng(seed) {
	let s = seed >>> 0;
	return () => {
		s = (s + 0x6d2b79f5) >>> 0;
		let t = s;
		t = Math.imul(t ^ (t >>> 15), t | 1);
		t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
		return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
	};
}

export function halton(index, base) {
	let f = 1;
	let r = 0;
	let i = index;
	while (i > 0) {
		f /= base;
		r += f * (i % base);
		i = Math.floor(i / base);
	}
	return r;
}

// Smooth 1D value noise in [0, 1].
export function noise1(x, seed = 0) {
	const i = Math.floor(x);
	const f = x - i;
	const u = f * f * (3 - 2 * f);
	return lerp(hash(i, seed), hash(i + 1, seed), u);
}

// Fractal noise in [-1, 1], for hand-held drift and twitches.
export function fbm1(x, seed = 0, octaves = 3) {
	let v = 0;
	let a = 0.5;
	let norm = 0;
	for (let o = 0; o < octaves; o++) {
		v += (noise1(x, seed + o * 17) * 2 - 1) * a;
		norm += a;
		x *= 2.07;
		a *= 0.5;
	}
	return v / norm;
}

// Keyframes: [[time, value], ...] with numbers or arrays, eased between keys.
export function keys(t, frames, ease = smooth) {
	if (t <= frames[0][0]) return frames[0][1];
	for (let i = 1; i < frames.length; i++) {
		const [t1, v1, e] = frames[i];
		const [t0, v0] = frames[i - 1];
		if (t <= t1) {
			const k = (e ?? ease)((t - t0) / (t1 - t0));
			if (Array.isArray(v0)) return v0.map((a, j) => lerp(a, v1[j], k));
			return lerp(v0, v1, k);
		}
	}
	return frames[frames.length - 1][1];
}

// A step function over time: the value of the last key at or before t.
export function steps(t, frames) {
	let v = frames[0][1];
	for (const [k, value] of frames) if (t >= k) v = value;
	return v;
}

// Pulse that rises at `at`, holds, and falls: 0..1.
export function pulse(t, at, rise, hold, fall) {
	if (t < at) return 0;
	if (t < at + rise) return smooth((t - at) / rise);
	if (t < at + rise + hold) return 1;
	return 1 - smooth((t - at - rise - hold) / fall);
}
