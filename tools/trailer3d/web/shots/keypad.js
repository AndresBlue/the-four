// The code: beep 7, beep 3, beep 9, beep 1, each on its own; the tone;
// UNLOCKED; the last door is pulled open, quick, on the lift's light.
import * as THREE from "three";
import { Kit } from "../engine/kit.js";
import { hotelRoom } from "../engine/sets.js";
import { Locust } from "../engine/locust.js";
import { Detective, detectiveTorch, detectiveRun } from "../engine/detective.js";
import { Volumetrics } from "../engine/volumetric.js";
import { camcorder } from "../engine/osd.js";
import { writePage, GRAPHITE, PAPER, wear } from "../engine/handwork.js";
import { clamp, smooth, smoothstep, lerp } from "../engine/util.js";
import { V, handheld, steps, aimCamera, makeTorch, holdTorch, tape } from "./common.js";

// Black; then the notes, flicked through fast as they are put away; then the code.
export const NOTES = [0.6, 1.5];
export const KEYS = [1.8, 2.12, 2.44, 2.76];
export const TONE = 3.08;
export const OPEN = 3.4;
const CODE = [7, 3, 9, 1];

function keypadFace(pressed) {
	const c = document.createElement("canvas");
	c.width = 256;
	c.height = 400;
	const g = c.getContext("2d");
	g.fillStyle = "#17171a";
	g.fillRect(0, 0, 256, 400);
	const labels = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "0", "#"];
	for (let i = 0; i < 12; i++) {
		const x = 38 + (i % 3) * 64;
		const y = 150 + Math.floor(i / 3) * 60;
		const on = pressed === labels[i];
		g.fillStyle = on ? "#c8e6b4" : "#3a3a3e";
		g.fillRect(x, y, 52, 46);
		g.fillStyle = on ? "#1a2a14" : "#c9c6b8";
		g.font = "600 30px Consolas, monospace";
		g.textAlign = "center";
		g.textBaseline = "middle";
		g.fillText(labels[i], x + 26, y + 24);
	}
	const t = new THREE.CanvasTexture(c);
	t.colorSpace = THREE.SRGBColorSpace;
	return t;
}

function displayTexture() {
	const c = document.createElement("canvas");
	c.width = 320;
	c.height = 140;
	const t = new THREE.CanvasTexture(c);
	t.colorSpace = THREE.SRGBColorSpace;
	return { c, t, g: c.getContext("2d") };
}

export function create(ctx) {
	const scene = new THREE.Scene();
	const camera = new THREE.PerspectiveCamera(46, 4 / 3, 0.02, 80);
	let face;
	let display;
	let lastPressed = null;
	let door;
	let carDoors;
	let other;
	let locust;
	let torch;
	let beam;
	const shot = {
		scene, camera, frame: "tape", samples: 28, shutter: 0.5,
		async setup() {
			// The refuge (x 0..6, z 0..6) with the last door on its west wall and the
			// keypad beside it; the lift vestibule behind that door (x -4..0), the car
			// against its far wall. The refuge's own door to the corridor on its east wall.
			const kit = await new Kit(scene).load();
			await hotelRoom(kit, { x0: 0, x1: 6, z0: 0, z1: 6, doors: [{ wall: "e", at: 3.0, open: 1.56 }, { wall: "w", at: 3.0, leaf: false }] });
			door = await kit.door(-0.09, 3.0, Math.PI / 2, { open: 0 });
			const lamp = kit.dome(3, 3, { intensity: 9, color: 0xb8d4b6 });
			// The refuge's light as it reaches its far door: a pool on the threshold,
			// the edge of where it is safe, and the mask leaning into it.
			const doorway = new THREE.SpotLight(new THREE.Color(0xc4dcc0), 14, 8, THREE.MathUtils.degToRad(24), 0.7, 2);
			doorway.position.set(4.3, 2.95, 3.05);
			doorway.target.position.set(6.4, 1.7, 3.0);
			scene.add(doorway, doorway.target);
			shot.doorway = doorway;
			// The corridor outside the refuge, dark.
			kit.floor(6.2, -2, 18, 8);
			kit.ceilingSlab(6.2, -2, 18, 8);
			kit.wall(6.18, 1.3, 18, 1.3, { dress: [1] });
			kit.wall(6.18, 4.7, 18, 4.7, { dress: [-1] });
			kit.wall(18, 1.3, 18, 4.7, { dress: [-1] });
			// A lamp further down the corridor, dim, behind where it will stand.
			const behind = await kit.sconce(12.5, 1.6, 1.3, 0, 1, { intensity: 1.2 });
			// Beyond the door, a tiled vestibule, lit, empty; its far wall.
			kit.floor(-4.4, 0, 0, 6, kit.m.tile);
			kit.ceilingSlab(-4.4, 0, 0, 6);
			kit.wall(-4.4, -0.09, 0, -0.09, { dress: [1], finish: "tile" });
			kit.wall(-4.4, 6.09, 0, 6.09, { dress: [-1], finish: "tile" });
			kit.wall(-4.49, 0, -4.49, 6, { dress: [1], finish: "tile" });
			const vest = kit.dome(-2.2, 3.0, { intensity: 3 });
			carDoors = [];
			// The keypad on the refuge's west wall, beside the door.
			face = new THREE.MeshStandardMaterial({ map: keypadFace(null), roughness: 0.5, metalness: 0.3 });
			const pad = new THREE.Mesh(new THREE.BoxGeometry(0.06, 0.34, 0.22), [kit.m.black, kit.m.black, kit.m.black, kit.m.black, kit.m.black, kit.m.black]);
			pad.position.set(0.03, 1.3, 1.9);
			scene.add(pad);
			const facePlane = new THREE.Mesh(new THREE.PlaneGeometry(0.2, 0.3125), face);
			facePlane.position.set(0.062, 1.27, 1.9);
			facePlane.rotation.y = Math.PI / 2;
			scene.add(facePlane);
			display = displayTexture();
			const lcd = new THREE.Mesh(new THREE.PlaneGeometry(0.16, 0.07), new THREE.MeshStandardMaterial({ color: 0x000000, emissive: 0xffffff, emissiveMap: display.t, emissiveIntensity: 1.6 }));
			lcd.position.set(0.064, 1.42, 1.9);
			lcd.rotation.y = Math.PI / 2;
			scene.add(lcd);
			shot.lcdLight = new THREE.PointLight(new THREE.Color().setRGB(0.3, 1.0, 0.45, THREE.SRGBColorSpace), 0.25, 1.2, 2);
			shot.lcdLight.position.set(0.2, 1.42, 1.9);
			scene.add(shot.lcdLight);
			other = await Detective.create();
			scene.add(other.root);
			locust = await Locust.create();
			scene.add(locust.root);
			torch = makeTorch(scene, { intensity: 60 });
			// The other one's torch, raised across the refuge onto the far door.
			beam = makeTorch(scene, { intensity: 160, angle: 13, penumbra: 0.5 });
			shot.volumetrics = new Volumetrics(ctx.renderer, { density: 0.012, noise: 0.6, maxDist: 20, steps: 28 });
			shot.volumetrics.addPoint(lamp, { radius: 1.2 });
			shot.volumetrics.addSpot(beam, { strength: 0.35 });
		},
		update(t) {
			// The display and the key that is down.
			const typedN = KEYS.filter((k) => t >= k).length;
			const down = KEYS.find((k) => t >= k && t < k + 0.09);
			const pressed = down !== undefined ? String(CODE[KEYS.indexOf(down)]) : null;
			if (pressed !== lastPressed) {
				face.map = keypadFace(pressed);
				face.needsUpdate = true;
				lastPressed = pressed;
			}
			const g = display.g;
			g.fillStyle = "#0c1f10";
			g.fillRect(0, 0, 320, 140);
			g.font = "600 64px Consolas, monospace";
			g.textAlign = "center";
			g.textBaseline = "middle";
			g.fillStyle = "#5dff86";
			const words = t >= TONE + 0.1 ? "UNLOCKED" : CODE.map((d, i) => (i < typedN ? String(d) : "_")).join(" ");
			g.font = t >= TONE + 0.1 ? "600 46px Consolas, monospace" : "600 64px Consolas, monospace";
			g.fillText(words, 160, 72);
			display.t.needsUpdate = true;
			// Wide open, flat to the wall, so the way back is in sight from the car.
		door.leaf.rotation.y = -smooth((t - OPEN) / 0.35) * 1.3;
			// Back from the wall: the keypad and the door beside it both in view.
			const hh = handheld(t, { amp: 0.8, seed: 71 });
			camera.fov = 50;
			// The moment it opens: running, through it, into the light, and gone.
			const run = smoothstep(OPEN + 0.12, OPEN + 1.0, t);
			const st = steps(t, { rate: 2.8, amp: 1.8 * run });
			// Round in front of the door first, then straight through it.
			const r = run;
			const pos = (r < 0.25 ? V(1.85, 1.55, 1.05).lerp(V(0.9, 1.58, 3.0), r / 0.25) : V(0.9, 1.58, 3.0).lerp(V(-2.4, 1.6, 3.0), (r - 0.25) / 0.75)).add(hh.pos).add(st.pos);
			const look = V(0.0, 1.3, 2.55).lerp(V(-4.5, 1.45, 3.0), smoothstep(OPEN + 0.05, OPEN + 0.3, t));
			aimCamera(camera, pos, look, { yaw: hh.yaw, pitch: hh.pitch + st.pitch, roll: hh.roll + st.roll });
			holdTorch(torch, camera, { ahead: 1.8, sway: 0.1, swayT: t });
			torch.intensity = 16;
			other.root.visible = false;
			locust.root.visible = false;
			beam.visible = false;
			for (const d of carDoors) d.leaf.position.z = 3.0 + d.s * 1.62;
		},
		look(t) {
			const L = tape({ exposure: 1.6 });
			// Snatched past: the tape smears and tears as each page goes by.
			if (t >= NOTES[0] && t < NOTES[1]) {
				L.drag = 0.6;
				L.tracking = (((t - NOTES[0]) * 4.4) % 1) < 0.15 ? 0.7 : 0.2;
			}
			if (t >= NOTES[1] && t < NOTES[1] + 0.06) L.tracking = 0.6;
			return L;
		},
		overlay(g, t, size) {
			// Before the code: black, then the notes from the drawers, one after
			// another, snatched past the lens as they are put away.
			if (t < NOTES[1]) {
				g.fillStyle = "#000";
				g.fillRect(0, 0, size.w, size.h);
				if (t >= NOTES[0]) notes(g, t, size);
				return;
			}
			camcorder(g, t, size, { clock: 3 * 3600 + 52 * 60 + 40, date: "OCT. 27 1993", focus: 1, word: "KEYPAD" });
		},
	};
	return shot;
}

// The four pages, 7, 3, 9, 1, in pencil on worn cream paper, each slid in
// under the last and gone, the hand shaking, the picture chasing them.
const pages = new Map();
function page(n, w, h) {
	if (pages.has(n)) return pages.get(n);
	const c = document.createElement("canvas");
	c.width = w;
	c.height = h;
	const g = c.getContext("2d");
	g.fillStyle = PAPER;
	g.fillRect(0, 0, w, h);
	wear(g, w, h, 300 + n, { marked: false });
	writePage(g, n, w / 2, h * 0.46, h * 0.5, GRAPHITE, n * 3.1);
	pages.set(n, c);
	return c;
}

function notes(g, t, size) {
	const k = (t - NOTES[0]) / (NOTES[1] - NOTES[0]);
	const i = Math.min(3, Math.floor(k * 4));
	const f = k * 4 - i;
	const w = size.h * 0.46;
	const h = size.h * 0.6;
	for (let j = Math.max(0, i - 1); j <= i; j++) {
		const slide = j === i ? 1 - Math.pow(1 - Math.min(1, f / 0.35), 3) : 1;
		const off = j < i ? -size.w * 0.9 * Math.min(1, f / 0.3) : 0;
		const x = size.w / 2 - w / 2 + (1 - slide) * size.w * 0.7 + off + Math.sin(t * 31 + j) * 6;
		const y = size.h / 2 - h / 2 + Math.sin(t * 23 + j * 2) * 5 + j * 4;
		g.save();
		g.translate(x + w / 2, y + h / 2);
		g.rotate(-0.06 + j * 0.035 + Math.sin(t * 17) * 0.01);
		g.fillStyle = "rgba(0,0,0,0.6)";
		g.fillRect(-w / 2 + 10, -h / 2 + 14, w, h);
		g.drawImage(page([7, 3, 9, 1][j], 360, 470), -w / 2, -h / 2, w, h);
		// The torch on it: a warm pool, falling off to the edges.
		const r = g.createRadialGradient(0, 0, w * 0.1, 0, 0, w * 0.9);
		r.addColorStop(0, "rgba(0,0,0,0)");
		r.addColorStop(1, "rgba(0,0,0,0.7)");
		g.fillStyle = r;
		g.fillRect(-w / 2, -h / 2, w, h);
		g.restore();
	}
}

