// The title: four lamps light one after another on the four notes of the
// motif — the fourth for the first time — and under them THE FOUR. Lamps 2,
// 3 and 4 go out; only the first stays. FLOOR ONE: THE LOCUST. SOLO · ONLINE
// CO-OP · VERSUS. IN DEVELOPMENT. The lamp's hum goes on. Cut to black.
import * as THREE from "three";
import { hotelMaterial } from "../engine/materials.js";
import { text, INK, AMBER, SOFT } from "../engine/osd.js";
import { smoothstep, smooth, clamp } from "../engine/util.js";

export const LAMPS = [0.25, 0.63, 1.01, 1.62];
export const TITLE = 1.72;
export const OUT = 2.9;
export const FLOOR = 3.05;
export const MODES = 3.55;
export const CUT = 4.35;

export function create(ctx) {
	const scene = new THREE.Scene();
	const camera = new THREE.PerspectiveCamera(22, 16 / 9, 0.1, 20);
	const bulbs = [];
	const lights = [];
	const shot = {
		scene, camera, frame: "wide", samples: 24, shutter: 0.5,
		async setup() {
			// A brass indicator plate with four round lamps, as over a lift door.
			const brass = await hotelMaterial("brass");
			const plate = new THREE.Mesh(new THREE.BoxGeometry(1.34, 0.36, 0.03), brass);
			plate.position.set(0, 0.62, 0);
			scene.add(plate);
			for (let i = 0; i < 4; i++) {
				const x = -0.495 + i * 0.33;
				const rim = new THREE.Mesh(new THREE.TorusGeometry(0.075, 0.014, 12, 36), brass);
				rim.position.set(x, 0.62, 0.02);
				scene.add(rim);
				const glass = new THREE.MeshStandardMaterial({ color: 0x2a1a0a, emissive: new THREE.Color().setRGB(1.0, 0.62, 0.22, THREE.SRGBColorSpace), emissiveIntensity: 0, roughness: 0.25 });
				const bulb = new THREE.Mesh(new THREE.SphereGeometry(0.068, 32, 16, 0, Math.PI * 2, 0, Math.PI / 2), glass);
				bulb.rotation.x = Math.PI / 2;
				bulb.position.set(x, 0.62, 0.02);
				scene.add(bulb);
				bulbs.push(glass);
				const l = new THREE.PointLight(new THREE.Color().setRGB(1.0, 0.62, 0.22, THREE.SRGBColorSpace), 0, 1.5, 2);
				l.position.set(x, 0.62, 0.15);
				scene.add(l);
				lights.push(l);
			}
			camera.position.set(0, 0.62, 4.2);
			camera.lookAt(0, 0.62 - 0.35, 0);
		},
		update(t) {
			for (let i = 0; i < 4; i++) {
				let on = t >= LAMPS[i] ? smoothstep(LAMPS[i], LAMPS[i] + 0.06, t) : 0;
				if (i > 0 && t >= OUT) on *= 1 - smoothstep(OUT, OUT + 0.08, t);
				// The first one hums: a faint flicker.
				if (i === 0) on *= 0.94 + 0.06 * Math.sin(t * 120 * Math.PI) * 0.5;
				bulbs[i].emissiveIntensity = on * 7;
				lights[i].intensity = on * 0.6;
			}
		},
		look(t) {
			return { kind: "clean", exposure: 1.2, bloom: 0.12, halation: 0.5, grain: 0.035, vignette: 0.5, chromatic: 0.3, fadeAll: t >= CUT ? 1 : 0 };
		},
		overlay(g, t, { w, h }) {
			const u = h / 720;
			const a = smoothstep(TITLE, TITLE + 0.35, t);
			if (a > 0) {
				g.save();
				g.font = `400 ${92 * u}px 'Perpetua Titling MT', 'Copperplate Gothic Light', Georgia, serif`;
				g.textAlign = "center";
				g.letterSpacing = `${22 * u}px`;
				g.fillStyle = `rgba(236,230,214,${a})`;
				g.fillText("THE FOUR", w / 2 + 11 * u, h * 0.62);
				g.restore();
			}
			if (t >= FLOOR) text(g, "FLOOR ONE: THE LOCUST", w / 2, h * 0.72, { size: 22, align: "center", color: AMBER, u, alpha: smoothstep(FLOOR, FLOOR + 0.25, t), spacing: 3 });
			if (t >= MODES) {
				const m = smoothstep(MODES, MODES + 0.25, t);
				text(g, "SOLO · ONLINE CO-OP · VERSUS", w / 2, h * 0.8, { size: 18, align: "center", color: SOFT, u, alpha: m, spacing: 2 });
				text(g, "IN DEVELOPMENT", w / 2, h * 0.85, { size: 14, align: "center", color: [0.94, 0.94, 0.9, 0.42], u, alpha: m, spacing: 3 });
			}
		},
	};
	return shot;
}
