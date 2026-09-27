// The three sectors of a floor, three hits on three notes of the motif, each
// with the game's own card (lifts.gd / hotel_ui.gd show_transit):
//   a green way-out sign lighting a dark corridor — SECTOR 1, FIND THE EXIT
//   a set jumping from black to snow — SECTOR 2, TURN ON THE TELEVISIONS
//   a page hanging out of a drawer, "– 3 –" in its corner — SECTOR 3, FIND THE CODE
// After the third note a fourth is expected; it does not come.
import * as THREE from "three";
import { Kit } from "../engine/kit.js";
import { corridor, tvSet } from "../engine/sets.js";
import { polyhaven, shadows } from "../engine/assets.js";
import { channelWave } from "../engine/screens.js";
import { Volumetrics } from "../engine/volumetric.js";
import { writeDigit, writePage, wear, PAPER, GRAPHITE } from "../engine/handwork.js";
import { camcorder, sectorCard } from "../engine/osd.js";
import { clamp, smooth, smoothstep } from "../engine/util.js";
import { V, handheld, aimCamera, makeTorch, holdTorch, tape } from "./common.js";

// The first comes out of black, after the voice has finished.
export const HITS = [0.9, 1.65, 2.4];
const CARDS = [["SECTOR 1", "FIND THE EXIT"], ["SECTOR 2", "TURN ON THE TELEVISIONS"], ["SECTOR 3", "FIND THE CODE"]];

function notePage() {
	const c = document.createElement("canvas");
	c.width = 512;
	c.height = 640;
	const g = c.getContext("2d");
	g.fillStyle = PAPER;
	g.fillRect(0, 0, 512, 640);
	wear(g, 512, 640, 311 + 3 * 97, { marked: true });
	writeDigit(g, 7, [512 * 0.24, 640 * 0.12, 512 * 0.52, 640 * 0.5], GRAPHITE, 512 * 0.07, 3 * 13 + 7);
	writePage(g, 3, 512 * 0.84, 640 * 0.09, 40, GRAPHITE, 21);
	const tex = new THREE.CanvasTexture(c);
	tex.colorSpace = THREE.SRGBColorSpace;
	tex.anisotropy = 8;
	return tex;
}

export function create(ctx) {
	const scene = new THREE.Scene();
	const camera = new THREE.PerspectiveCamera(50, 4 / 3, 0.02, 60);
	let sign;
	let tv;
	let torch;
	const shot = {
		scene, camera, frame: "tape", samples: 28, shutter: 0.5, aperture: 0, focus: 5,
		async setup() {
			// (a) A corridor with its lamps dead; only the sign.
			const kit = await new Kit(scene).load();
			await corridor(kit, { length: 16, width: 3.5, doors: [{ side: 1, at: 4, number: 111 }, { side: -1, at: 7, number: 112 }, { side: 1, at: 11, number: 113 }], art: [{ side: -1, at: 3.4 }, { side: 1, at: 8.2 }], lit: false });
			sign = await kit.exitSign(0, -9.0, 0, "way_ahead");
			sign.userData.spill.intensity = 2.4;
			sign.userData.spill.distance = 9;
			// (b) The set, somewhere else.
			const g2 = new THREE.Group();
			g2.position.set(40, 0, 0);
			scene.add(g2);
			const kb = await new Kit(g2).load();
			kb.floor(-3, -3, 3, 3);
			kb.wall(-3, -2.0, 3, -2.0, { dress: [1] });
			tv = await tvSet(scene, 40.3, -1.55, 0);
			// (c) The page hanging out of a drawer.
			const commode = await polyhaven("GothicCommode_01");
			shadows(commode);
			commode.position.set(80, 0, 0);
			scene.add(commode);
			const box = new THREE.Box3().setFromObject(commode);
			shot.drawer = { top: box.max.y, front: box.max.z };
			const page = new THREE.Mesh(new THREE.PlaneGeometry(0.16, 0.2, 8, 8), new THREE.MeshStandardMaterial({ map: notePage(), roughness: 0.9, side: THREE.DoubleSide }));
			// Caught in the top drawer, hanging over its front, its tip bent.
			const pos = page.geometry.attributes.position;
			for (let i = 0; i < pos.count; i++) {
				const y = pos.getY(i);
				const bend = Math.max(0, 0.1 - y);
				pos.setZ(i, bend * bend * 1.6 + Math.sin(pos.getX(i) * 20) * 0.002);
			}
			page.geometry.computeVertexNormals();
			page.position.set(80.05, box.max.y - 0.13, box.max.z + 0.012);
			page.rotation.set(-0.06, 0.08, 0.03);
			page.castShadow = true;
			scene.add(page);
			torch = makeTorch(scene, { intensity: 22, angle: 30 });
			shot.volumetrics = new Volumetrics(ctx.renderer, { density: 0.025, noise: 0.7, maxDist: 16, steps: 28 });
			shot.volumetrics.addPoint(sign.userData.spill, { radius: 1.6, strength: 0.8 });
		},
		update(t) {
			const hit = t < HITS[1] ? 0 : t < HITS[2] ? 1 : 2;
			const k = t - HITS[hit];
			const hh = handheld(t, { amp: 0.8, seed: 3 });
			const push = smooth(k / 1.1) * 0.35;
			torch.visible = hit === 2;
			shot.aperture = hit === 2 ? 0.004 : 0;
			if (hit === 0) {
				aimCamera(camera, V(-0.35, 1.45, -3.2 - push).add(hh.pos), V(0, 2.6, -9), { yaw: hh.yaw, pitch: hh.pitch, roll: hh.roll });
			} else if (hit === 1) {
				aimCamera(camera, V(40.2, 1.3, 0.75 - push).add(hh.pos), V(40.3, 1.12, -1.6), { yaw: hh.yaw, pitch: hh.pitch, roll: hh.roll });
				const on = clamp((k - 0.05) / 0.25);
				tv.mat.uniforms.power.value = k > 0.05 ? on : 0;
				tv.mat.uniforms.time.value = t;
				tv.glow.intensity = k > 0.05 ? 22 * smooth(on) * channelWave(t) : 0;
				tv.fill.intensity = k > 0.05 ? 3 * smooth(on) : 0;
			} else {
				const d = shot.drawer;
				const eye = V(80.0, d.top - 0.05, d.front + 0.5 - push * 0.25).add(hh.pos.multiplyScalar(0.3));
				aimCamera(camera, eye, V(80.07, d.top - 0.14, d.front), { yaw: hh.yaw * 0.3, pitch: hh.pitch * 0.3, roll: hh.roll * 0.3 });
				shot.focus = 0.5 - push * 0.25;
				holdTorch(torch, camera, { ahead: 0.6, sway: 0.05, offset: V(0.12, 0.08, 0.1) });
			}
		},
		look(t) {
			const hit = t < HITS[1] ? 0 : t < HITS[2] ? 1 : 2;
			const L = tape({ exposure: [2.2, 1.8, 1.6][hit] });
			for (const h of HITS) if (t >= h && t < h + 0.07) L.tracking = 0.7;
			if (t < HITS[0]) L.fadeAll = 1;
			return L;
		},
		overlay(g, t, size) {
			const hit = t < HITS[1] ? 0 : t < HITS[2] ? 1 : 2;
			const k = t - HITS[hit];
			camcorder(g, t, size, { clock: 2 * 3600 + 9 * 60 + 30 + hit * 11 * 60, date: "OCT. 27 1993" });
			const a = smoothstep(0.05, 0.2, k) * (1 - smoothstep(0.95, 1.08, k));
			sectorCard(g, size, { sector: CARDS[hit][0], errand: CARDS[hit][1], alpha: a, backdrop: 0.45 });
		},
	};
	return shot;
}
