// The archive, today: a desk in the dark, the game's own CRT set on it, a
// VCR, an angled lamp, shelves of tapes behind (FLOOR 1 full; FLOOR 2, 3 and 4
// empty). Four shots of the trailer happen here (timeline ids):
//   vcr       a gloved hand feeds in the tape labelled by hand; clack; motor.
//   crt       the set comes on: snow, two frames of the mask, the signal holds:
//             blue, PLAY, the tape's card; the lens goes in until the phosphor
//             is all there is.
//   database  the archive's list: FLOOR 1 recovered; 2, 3, 4 not, each with
//             two frames of something that could not be read.
//   endtape   End of tape. Snow. Then the mask in the snow, coming up to the
//             glass from inside; a blow, the glass cracks under it; another. Black.
import * as THREE from "three";
import { Kit } from "../engine/kit.js";
import { hotelRoom, corridor } from "../engine/sets.js";
import * as P from "../engine/props.js";
import { polyhaven, shadows, texture } from "../engine/assets.js";
import { Locust } from "../engine/locust.js";
import { Survivor } from "../engine/survivor.js";
import { crtMaterial } from "../engine/screens.js";
import { makeCracks } from "../engine/cracks.js";
import { VCR_BLUE, INK, ALERT, css, FONT } from "../engine/osd.js";
import { clamp, smooth, smoothstep, lerp, easeIn, easeOut, fbm1, keys } from "../engine/util.js";
import { V, aimCamera } from "./common.js";

// Timings inside each shot.
export const VCR = { IN: [0.25, 0.72], CLACK: 0.74, OUT: [0.8, 1.3] };
export const CRT = { ON: 0.12, MASK: [0.44, 0.507], HOLD: 0.62, TEXT: 0.72, PUSH: [0.4, 2.55], DIVE: 1.75 };
export const DB = { ROWS: [0.15, 0.55, 1.05, 1.55], FLASH: [0.72, 1.22, 1.72] };
export const END = { SNOW: 0.0, EMERGE: [1.05, 2.1], NEAR: [1.9, 2.45], HITS: [2.62, 2.98], BLACK: 3.1 };

const LABEL = ["HOTEL", "FLOOR 1", "TAPE 81"];

function tapeLabel() {
	const c = document.createElement("canvas");
	c.width = 512;
	c.height = 300;
	const g = c.getContext("2d");
	g.fillStyle = "#e9e3cf";
	g.fillRect(0, 0, 512, 300);
	g.strokeStyle = "rgba(120,110,90,0.35)";
	g.lineWidth = 2;
	for (let y = 70; y < 300; y += 62) {
		g.beginPath();
		g.moveTo(16, y);
		g.lineTo(496, y);
		g.stroke();
	}
	g.fillStyle = "#1c1a2a";
	g.font = "600 64px 'Ink Free', 'Segoe Print', cursive";
	g.textBaseline = "alphabetic";
	LABEL.forEach((l, i) => {
		g.save();
		g.translate(34 + i * 6, 64 + i * 62 + 4);
		g.rotate(-0.02 + i * 0.012);
		g.fillText(l, 0, 0);
		g.restore();
	});
	const t = new THREE.CanvasTexture(c);
	t.colorSpace = THREE.SRGBColorSpace;
	t.anisotropy = 8;
	return t;
}

// The screen's picture as a canvas (the tape's blue page, the list).
function screenCanvas() {
	const c = document.createElement("canvas");
	c.width = 640;
	c.height = 480;
	const tex = new THREE.CanvasTexture(c);
	tex.colorSpace = THREE.SRGBColorSpace;
	return { c, g: c.getContext("2d"), tex };
}

function osdLine(g, words, x, y, size, color = INK, alpha = 1, align = "left") {
	g.save();
	g.font = `600 ${size}px ${FONT}`;
	g.textAlign = align;
	g.fillStyle = `rgba(0,0,0,${0.85 * alpha})`;
	g.fillText(words, x + 2, y + 2);
	g.fillStyle = css(color, alpha);
	g.fillText(words, x, y);
	g.restore();
}

export function create(ctx) {
	const id = ctx.entry.id;
	const scene = new THREE.Scene();
	const camera = new THREE.PerspectiveCamera(36, 16 / 9, 0.01, 40);
	let crt;
	let screen;
	let broadcast;
	let cracks;
	let vcr;
	let cassette;
	let hand;
	let lamp;
	const glimpses = [];
	const shot = {
		scene, camera, frame: "wide", samples: 32, shutter: 0.5, aperture: 0, focus: 1,
		async setup() {
			const kit = await new Kit(scene).load();
			// The room: dark, bare plaster and a floor of old boards.
			await hotelRoom(kit, { x0: -3, x1: 3, z0: -3, z1: 3, height: 2.9, finish: "wallpaperDecrepit" });
			// The desk.
			kit.box(1.8, 0.05, 0.8, kit.m.panel, 0, 0.75, 0);
			for (const [x, z] of [[-0.85, -0.35], [0.85, -0.35], [-0.85, 0.35], [0.85, 0.35]]) kit.box(0.05, 0.75, 0.05, kit.m.trim, x, 0.375, z);
			// The set: the game's CRT, a little turned toward the chair.
			const tv = await P.tv(0.56);
			tv.group.position.set(0.1, 0.775, -0.12);
			tv.group.rotation.y = -0.06;
			scene.add(tv.group);
			crt = crtMaterial({ strength: 1.25 });
			crt.uniforms.power.value = 0;
			tv.screen.material = crt;
			scene.updateMatrixWorld(true);
			const sb = new THREE.Box3().setFromObject(tv.screen);
			shot.screenCentre = sb.getCenter(new THREE.Vector3());
			shot.screenSize = sb.getSize(new THREE.Vector3());
			// Its light on the desk and the wall.
			shot.crtLight = new THREE.PointLight(new THREE.Color().setRGB(0.6, 0.7, 1.0, THREE.SRGBColorSpace), 0, 4, 2);
			shot.crtLight.position.copy(shot.screenCentre).add(V(0, 0, 0.35));
			scene.add(shot.crtLight);
			// The VCR, beside it: a black box with its slot, flap, buttons and display.
			vcr = new THREE.Group();
			vcr.position.set(-0.5, 0.775, 0.02);
			scene.add(vcr);
			const body = new THREE.MeshStandardMaterial({ color: 0x2a2a2e, roughness: 0.42, metalness: 0.35 });
			const face = new THREE.MeshStandardMaterial({ color: 0x1a1a1d, roughness: 0.3, metalness: 0.4 });
			kit.box(0.43, 0.004, 0.012, new THREE.MeshStandardMaterial({ color: 0x9a9a9e, roughness: 0.25, metalness: 0.9 }), 0, 0.083, 0.166, { parent: vcr });
			kit.box(0.43, 0.09, 0.32, body, 0, 0.045, 0, { parent: vcr });
			kit.box(0.43, 0.08, 0.01, face, 0, 0.045, 0.16, { parent: vcr });
			kit.box(0.2, 0.034, 0.012, new THREE.MeshStandardMaterial({ color: 0x050505, roughness: 0.2 }), -0.07, 0.05, 0.164, { parent: vcr });
			const vfdCanvas = document.createElement("canvas");
			vfdCanvas.width = 256;
			vfdCanvas.height = 64;
			const vg = vfdCanvas.getContext("2d");
			vg.fillStyle = "#020605";
			vg.fillRect(0, 0, 256, 64);
			vg.fillStyle = "#5fffd2";
			vg.font = "600 40px Consolas, monospace";
			vg.textAlign = "center";
			vg.fillText("0:00:00", 128, 46);
			const vfdTex = new THREE.CanvasTexture(vfdCanvas);
			vfdTex.colorSpace = THREE.SRGBColorSpace;
			const vfd = new THREE.Mesh(new THREE.PlaneGeometry(0.09, 0.022), new THREE.MeshStandardMaterial({ color: 0x000000, emissive: 0xffffff, emissiveMap: vfdTex, emissiveIntensity: 0.55, roughness: 0.2 }));
			vfd.position.set(0.12, 0.052, 0.1662);
			vcr.add(vfd);
			for (let i = 0; i < 5; i++) kit.box(0.014, 0.008, 0.006, new THREE.MeshStandardMaterial({ color: 0x2a2a2c, roughness: 0.5 }), 0.08 + i * 0.022, 0.025, 0.167, { parent: vcr });
			// The cassette with its handwritten label (on its top face).
			cassette = new THREE.Group();
			const shell = new THREE.MeshStandardMaterial({ color: 0x0a0a0b, roughness: 0.35, metalness: 0.1 });
			kit.box(0.188, 0.025, 0.104, shell, 0, 0.0125, 0, { parent: cassette });
			const label = new THREE.Mesh(new THREE.PlaneGeometry(0.1, 0.058), new THREE.MeshStandardMaterial({ map: tapeLabel(), roughness: 0.8 }));
			label.rotation.x = -Math.PI / 2;
			label.position.set(0.0, 0.0252, 0.012);
			cassette.add(label);
			const window = new THREE.Mesh(new THREE.PlaneGeometry(0.07, 0.02), new THREE.MeshStandardMaterial({ color: 0x2a1c14, roughness: 0.1, metalness: 0.2, transparent: true, opacity: 0.8 }));
			window.rotation.x = -Math.PI / 2;
			window.position.set(0, 0.0253, -0.03);
			cassette.add(window);
			scene.add(cassette);
			// The lamp: an angled arm and a cone of warm light on the desk.
			const lampMat = new THREE.MeshStandardMaterial({ color: 0x1a1a18, roughness: 0.4, metalness: 0.6 });
			kit.box(0.16, 0.02, 0.16, lampMat, 0.72, 0.785, 0.12);
			const arm = new THREE.Mesh(new THREE.CylinderGeometry(0.008, 0.008, 0.62, 8), lampMat);
			arm.position.set(0.66, 1.08, 0.08);
			arm.rotation.z = 0.35;
			scene.add(arm);
			const shade = new THREE.Mesh(new THREE.ConeGeometry(0.09, 0.14, 24, 1, true), lampMat);
			shade.position.set(0.52, 1.36, 0.1);
			shade.rotation.z = -0.9;
			scene.add(shade);
			lamp = new THREE.SpotLight(new THREE.Color().setRGB(1, 0.78, 0.52, THREE.SRGBColorSpace), id === "vcr" ? 11 : 7, 4, 0.75, 0.6, 2);
			lamp.position.set(0.5, 1.33, 0.1);
			lamp.target.position.set(id === "vcr" ? -0.5 : -0.1, 0.78, id === "vcr" ? 0.3 : 0.15);
			lamp.castShadow = true;
			lamp.shadow.mapSize.set(2048, 2048);
			lamp.shadow.bias = -0.0005;
			scene.add(lamp, lamp.target);
			// The shelves behind: FLOOR 1 full of tapes; FLOOR 2, 3 and 4 empty.
			const shelfMat = kit.m.trim;
			const tapeGeo = new THREE.BoxGeometry(0.026, 0.19, 0.105);
			const tapeMat = new THREE.MeshStandardMaterial({ color: 0x111113, roughness: 0.4 });
			const tapes = new THREE.InstancedMesh(tapeGeo, tapeMat, 180);
			let n = 0;
			for (let bay = 0; bay < 4; bay++) {
				const x0 = -2.4 + bay * 1.25;
				for (let row = 0; row < 4; row++) {
					const y = 0.45 + row * 0.42;
					kit.box(1.18, 0.025, 0.3, shelfMat, x0 + 0.59, y, -2.6);
					if (bay === 0) {
						for (let k = 0; k < 40 && n < 180; k++) {
							if ((k * 7 + row * 3) % 11 === 0) continue;
							const m = new THREE.Matrix4().makeTranslation(x0 + 0.05 + k * 0.028, y + 0.108, -2.6);
							tapes.setMatrixAt(n++, m);
						}
					}
				}
				const tag = document.createElement("canvas");
				tag.width = 256;
				tag.height = 64;
				const tg = tag.getContext("2d");
				tg.fillStyle = "#d9d2bd";
				tg.fillRect(0, 0, 256, 64);
				tg.fillStyle = "#222";
				tg.font = "600 36px Consolas, monospace";
				tg.textAlign = "center";
				tg.fillText(`FLOOR ${bay + 1}`, 128, 45);
				const tt = new THREE.CanvasTexture(tag);
				tt.colorSpace = THREE.SRGBColorSpace;
				const plate = new THREE.Mesh(new THREE.PlaneGeometry(0.16, 0.04), new THREE.MeshStandardMaterial({ map: tt, roughness: 0.8 }));
				plate.position.set(x0 + 0.59, 2.2, -2.44);
				scene.add(plate);
			}
			tapes.count = n;
			tapes.castShadow = true;
			tapes.receiveShadow = true;
			scene.add(tapes);
			const chair = await polyhaven("dining_chair_02").catch(() => null);
			if (chair) {
				shadows(chair);
				chair.position.set(0.2, 0, 0.95);
				chair.rotation.y = Math.PI + 0.3;
				scene.add(chair);
			}
			// A faint cold light from the doorway behind the camera.
			const fill = new THREE.DirectionalLight(new THREE.Color().setRGB(0.5, 0.6, 0.8, THREE.SRGBColorSpace), 0.05);
			fill.position.set(-2, 2, 3);
			scene.add(fill);
			screen = screenCanvas();
			if (id === "vcr") {
				hand = await Survivor.create();
				scene.add(hand.root);
				// A low warm fill from the chair's side, for the deck's face.
				const fill2 = new THREE.PointLight(new THREE.Color().setRGB(1, 0.8, 0.6, THREE.SRGBColorSpace), 0.35, 2.5, 2);
				fill2.position.set(-0.2, 0.9, 0.75);
				scene.add(fill2);
			}
			if (id === "crt" || id === "endtape") broadcast = await makeBroadcast(ctx);
			if (id === "endtape") cracks = makeCracks();
			if (id === "database") for (const make of [glimpseWhite, glimpseSets, glimpseDoors]) glimpses.push(await make(ctx));
		},
		beforeRender() {
			// The picture on the tube, rendered for this subframe.
			if (broadcast && shot.drawBroadcast) {
				const r = ctx.renderer;
				// Its own lamp's shadow is drawn here too, not only the room's.
				r.shadowMap.needsUpdate = true;
				r.setRenderTarget(broadcast.rt);
				r.setClearColor(0x000000, 1);
				r.clear();
				r.render(broadcast.scene, broadcast.camera);
			}
		},
		update(t) {
			crt.uniforms.time.value = t;
			if (id === "vcr") updateVcr(t);
			if (id === "crt") updateCrt(t);
			if (id === "database") updateDatabase(t);
			if (id === "endtape") updateEnd(t);
		},
		look(t) {
			const base = { kind: "clean", exposure: 1.35, bloom: 0.06, halation: 0.25, contrast: 1.08, saturation: 0.95, grain: 0.04, vignette: 0.45, chromatic: 0.5 };
			if (id === "crt" && t > CRT.PUSH[1] - 0.3) base.exposure = 1.35 + smoothstep(CRT.PUSH[1] - 0.3, CRT.PUSH[1], t) * 1.5;
			if (id === "endtape" && t >= END.BLACK) base.fadeAll = 1;
			if (id === "database" && t > 2.95) base.fadeAll = smoothstep(2.95, 3.15, t);
			return base;
		},
	};

	// A picture shown on the tube: the canvas (2D) or the broadcast render.
	function showCanvas() {
		crt.uniforms.image.value = screen.tex;
		screen.tex.needsUpdate = true;
	}

	function updateVcr(t) {
		// Close on the VCR's slot; the tape slides in, the hand goes away.
		const inK = smooth((t - VCR.IN[0]) / (VCR.IN[1] - VCR.IN[0]));
		const drawn = t > VCR.CLACK ? smooth((t - VCR.CLACK) / 0.18) : 0;
		const slot = V(-0.57, 0.775 + 0.05, 0.184);
		// Label up, pushed in two thirds of the way; the deck takes the rest.
		cassette.position.set(slot.x, slot.y - 0.0125, lerp(slot.z + 0.052 + 0.1, slot.z + 0.052 - 0.06, inK) - drawn * 0.052);
		cassette.visible = drawn < 0.98;
		const out = smooth((t - VCR.OUT[0]) / (VCR.OUT[1] - VCR.OUT[0]));
		hand.root.visible = out < 0.99;
		hand.root.position.set(-1.0, -0.42, 0.72 + out * 0.3);
		hand.root.rotation.y = Math.PI * 0.72;
		hand.reset();
		const grip = cassette.position.clone().add(V(0.03, 0.02, 0.07 + out * 0.25));
		hand.reachWrist("R", grip, [0.5, -1, 0.2]);
		hand.fingers("R", 0.25, { thumb: 0.3 });
		const drift = V(fbm1(t * 0.5, 2) * 0.004, fbm1(t * 0.4, 5) * 0.003, 0);
		aimCamera(camera, V(-0.12, 0.96, 0.6).add(drift), V(-0.55, 0.83, 0.2));
		camera.fov = 34;
		shot.aperture = 0.002;
		shot.focus = 0.62;
		crt.uniforms.power.value = 0;
		shot.crtLight.intensity = 0;
	}

	function updateCrt(t) {
		const g = screen.g;
		const on = clamp((t - CRT.ON) / 0.22);
		crt.uniforms.power.value = t > CRT.ON ? on : 0;
		shot.drawBroadcast = false;
		if (t < CRT.HOLD) {
			// Snow; two frames of the mask in it.
			const masked = t >= CRT.MASK[0] && t < CRT.MASK[1];
			shot.drawBroadcast = masked;
			crt.uniforms.image.value = broadcast.rt.texture;
			crt.uniforms.image_amount.value = masked ? 0.9 : 0;
			crt.uniforms.static_amount.value = masked ? 0.55 : 1;
			crt.uniforms.unstable.value = 0.6;
		} else {
			// The signal holds: the VCR's blue, PLAY, the tape's card.
			g.fillStyle = css(VCR_BLUE);
			g.fillRect(0, 0, 640, 480);
			osdLine(g, "VIDEO 1", 36, 50, 26);
			osdLine(g, "▶ PLAY", 320, 150, 40, INK, 1, "center");
			const lines = ["RECOVERED TAPE 81", "THE HOTEL — FLOOR 1", "GUESTS: 4", "OCCUPANT: THE LOCUST"];
			const shown = Math.max(0, Math.floor((t - CRT.TEXT) * 72));
			let left = shown;
			lines.forEach((l, i) => {
				const n = Math.min(l.length, left);
				left -= l.length;
				if (n > 0) osdLine(g, l.slice(0, n), 70, 250 + i * 44, 28, i === 3 ? [0.96, 0.78, 0.4] : INK);
			});
			showCanvas();
			crt.uniforms.image_amount.value = 1;
			crt.uniforms.static_amount.value = t < CRT.HOLD + 0.15 ? 0.6 : 0.08;
			crt.uniforms.unstable.value = t < CRT.HOLD + 0.1 ? 0.8 : 0.05;
		}
		shot.crtLight.intensity = on * (t < CRT.HOLD ? 0.35 : 0.5);
		shot.crtLight.color.setRGB(t < CRT.HOLD ? 0.7 : 0.25, t < CRT.HOLD ? 0.75 : 0.35, 1.0, THREE.SRGBColorSpace);
		// A slow creep toward the set while the card is read, then the dive
		// through the glass into the phosphor.
		const creep = smooth((t - CRT.PUSH[0]) / (CRT.DIVE - CRT.PUSH[0])) * 0.45;
		const dive = easeIn((t - CRT.DIVE) / (CRT.PUSH[1] - CRT.DIVE));
		const k = t < CRT.DIVE ? creep : 0.45 + dive * 0.55;
		const c = shot.screenCentre;
		const from = V(0.25, 1.28, 1.35);
		const to = c.clone().add(V(0, 0, 0.035));
		const pos = from.clone().lerp(to, k);
		aimCamera(camera, pos, c.clone().add(V(0, 0.01, 0)));
		camera.fov = lerp(34, 22, k);
		shot.aperture = 0;
	}

	function updateDatabase(t) {
		const g = screen.g;
		g.fillStyle = "#050807";
		g.fillRect(0, 0, 640, 480);
		osdLine(g, "ARCHIVE — THE HOTEL", 40, 50, 22, [0.62, 0.66, 0.6]);
		const rows = [["FLOOR 1", "TAPE 81 — RECOVERED", INK], ["FLOOR 2", "NOT RECOVERED", ALERT], ["FLOOR 3", "NOT RECOVERED", ALERT], ["FLOOR 4", "NOT RECOVERED", ALERT]];
		rows.forEach(([a, b, color], i) => {
			if (t < DB.ROWS[i]) return;
			const n = Math.floor((t - DB.ROWS[i]) * 40);
			osdLine(g, a.slice(0, n), 50, 120 + i * 82, 30);
			if (n > a.length) osdLine(g, b.slice(0, n - a.length), 70, 155 + i * 82, 24, color);
		});
		showCanvas();
		crt.uniforms.image_amount.value = 1;
		crt.uniforms.static_amount.value = 0.12;
		crt.uniforms.unstable.value = 0.1;
		crt.uniforms.power.value = 1;
		// Two frames of something that could not be read, each floor.
		for (const [i, f] of DB.FLASH.entries()) {
			if (t >= f && t < f + 2 / 30) {
				crt.uniforms.image.value = glimpses[i].rt.texture;
				crt.uniforms.static_amount.value = 0.45;
				crt.uniforms.unstable.value = 1;
			}
		}
		shot.crtLight.intensity = 0.35;
		const drift = V(fbm1(t * 0.3, 7) * 0.01, fbm1(t * 0.25, 8) * 0.006, 0);
		const c = shot.screenCentre;
		aimCamera(camera, c.clone().add(V(0.08, 0.05, 0.7 - t * 0.05)).add(drift), c.clone().add(V(0, 0.005, 0)));
		camera.fov = 34;
	}

	function updateEnd(t) {
		crt.uniforms.power.value = 1;
		crt.uniforms.image.value = broadcast.rt.texture;
		shot.drawBroadcast = true;
		// The mask comes out of the snow; it was already there.
		const emerge = smoothstep(END.EMERGE[0], END.EMERGE[1], t);
		crt.uniforms.image_amount.value = emerge * 0.95;
		crt.uniforms.static_amount.value = 1 - emerge * 0.55;
		crt.uniforms.unstable.value = 0.2 + emerge * 0.3;
		broadcast.pose(t);
		// The blows: the glass cracks where they land.
		let level = 0;
		let flash = 0;
		for (const [i, h] of END.HITS.entries()) {
			if (t >= h) {
				level = i + 1;
				flash = Math.max(flash, Math.exp(-(t - h) * 16) * 0.22);
			}
		}
		crt.uniforms.cracks.value = cracks.texture;
		crt.uniforms.crack_level.value = level;
		crt.uniforms.flash.value = flash;
		shot.crtLight.intensity = 0.4 + flash * 2;
		const c = shot.screenCentre;
		const jolt = level > 0 ? Math.exp(-(t - END.HITS[level - 1]) * 18) * 0.004 : 0;
		aimCamera(camera, c.clone().add(V(0.02, 0.02 + jolt, 0.62)), c.clone().add(V(0, 0.005, 0)));
		camera.fov = 36;
	}

	return shot;
}

// The creature on the other side of the glass, as the game's opening shows
// it (game/intro/tv_broadcast.gd): a dim papered corner, The Locust with its
// reference look, a hard key light from the camera side.
async function makeBroadcast(ctx) {
	const scene = new THREE.Scene();
	const kit = await new Kit(scene).load();
	kit.box(5.0, 4.0, 0.1, kit.m.wallpaper, -0.2, 2.0, -1.6);
	kit.box(0.1, 4.0, 3.6, kit.m.wallpaper, -1.7, 2.0, 0.2);
	kit.floor(-3, -2.5, 3, 3.5);
	const key = new THREE.SpotLight(new THREE.Color().setRGB(1, 0.88, 0.72, THREE.SRGBColorSpace), 16, 5, THREE.MathUtils.degToRad(26), 0.6, 1.6);
	key.position.set(0.35, 3.1, 1.5);
	key.target.position.set(0, 2.45, 0.2);
	key.castShadow = true;
	scene.add(key, key.target);
	const fill = new THREE.PointLight(new THREE.Color().setRGB(0.7, 0.25, 0.2, THREE.SRGBColorSpace), 0.6, 4, 2);
	fill.position.set(-1.2, 1.4, 1.2);
	scene.add(fill);
	const locust = await Locust.create();
	scene.add(locust.root);
	const camera = new THREE.PerspectiveCamera(50, 4 / 3, 0.02, 20);
	camera.position.set(0.04, 2.5, 1.1);
	camera.lookAt(0.06, 2.46, 0);
	const rt = new THREE.WebGLRenderTarget(640, 480, { type: THREE.HalfFloatType });
	rt.texture.colorSpace = THREE.LinearSRGBColorSpace;
	const b = {
		scene, camera, rt, locust,
		// endtape: standing in the dark facing the lens, it comes up to the
		// glass; the right arm winds up and stabs at the tube, twice.
		pose(t) {
			const near = smoothstep(END.NEAR[0], END.NEAR[1], t);
			locust.root.position.set(0.06, 0, lerp(-0.6, 0.5, near));
			locust.reset();
			locust.aim("L_UpperArm", "L_Forearm", [0.25, -1.0, 0.15]);
			locust.aim("R_UpperArm", "R_Forearm", [-0.25, -1.0, 0.15]);
			locust.turn("Neck1", [0, 0, 1], Math.sin(t * 1.7) * 0.03);
			locust.turn("Head1", [0, 0, 1], -0.18 + Math.sin(t * 23) * 0.02 * near);
			locust.turn("Head1", [1, 0, 0], 0.12 + near * 0.1);
			// The picture is framed on its face, as the opening's broadcast is
			// (the mask sits a hand above the head's joint).
			const head = locust.point("Head1");
			camera.lookAt(head.x, head.y + 0.22, head.z);
			// The blows: the hand itself onto the glass (not the game's blade
			// reach), so it is the hand that fills the tube as it lands. Each
			// wind-up starts from where the last blow left the arm.
			const shoulder = locust.point("R_UpperArm");
			// Wound up in front of the mask: a black hand against the pale face,
			// the one thing in the picture it can be seen against.
			const face = new THREE.Vector3(head.x, head.y + 0.22, head.z);
			const cocked = camera.position.clone().lerp(face, 0.62).add(new THREE.Vector3(-0.03, 0.04, 0));
			// Where each blow lands: under its crack on the tube (makeCracks' uv).
			const glassAt = (i) => camera.position.clone().add(new THREE.Vector3(i ? 0.0156 : -0.014, i ? -0.0128 : 0.007, -0.25).applyQuaternion(camera.quaternion));
			const starts = END.HITS.map((h, i) => (i === 0 ? h - 0.3 : Math.max(h - 0.24, END.HITS[i - 1] + 0.1)));
			let active = -1;
			for (let i = 0; i < END.HITS.length; i++) if (t >= starts[i]) active = i;
			if (active >= 0) {
				const h = END.HITS[active];
				const start = starts[active];
				const from = active === 0 ? shoulder : glassAt(active - 1);
				const glass = glassAt(active);
				const last = active === END.HITS.length - 1;
				let target;
				if (t < h - 0.1) target = from.clone().lerp(cocked, easeOut((t - start) / (h - 0.1 - start)));
				else if (t < h) target = cocked.clone().lerp(glass, Math.pow((t - (h - 0.1)) / 0.1, 2.5));
				else if (t < h + 0.1 || !last) target = glass;
				else target = glass.clone().lerp(shoulder.clone().add(new THREE.Vector3(-0.2, -0.35, 0.15)), easeOut((t - h - 0.1) / 0.28));
				locust.reach("R", target, [-1.0, -0.6, -0.3], 0.06);
			}
		},
	};
	// crt: a mask in the snow for two frames.
	locust.root.position.set(0.06, 0, 0.0);
	locust.posePeek(0.1, 0, 1);
	return b;
}

// The glimpses of floors not recovered: rendered once, small, and corrupted
// on the tube. Places only — no creature is shown or named.
async function glimpseScene(build) {
	const scene = new THREE.Scene();
	const camera = new THREE.PerspectiveCamera(60, 4 / 3, 0.05, 200);
	await build(scene, camera);
	const rt = new THREE.WebGLRenderTarget(320, 240, { type: THREE.HalfFloatType });
	return { scene, camera, rt, rendered: false };
}

async function glimpseWhite(ctx) {
	// A white space too bright to read: a glass roof, a sun that is wrong.
	const g = await glimpseScene(async (scene, camera) => {
		const white = new THREE.MeshStandardMaterial({ color: 0xf2efe6, roughness: 0.9 });
		const floor = new THREE.Mesh(new THREE.PlaneGeometry(80, 80), white);
		floor.rotation.x = -Math.PI / 2;
		scene.add(floor);
		for (let i = 0; i < 12; i++) {
			const col = new THREE.Mesh(new THREE.CylinderGeometry(0.4, 0.4, 14, 16), white);
			col.position.set((i % 2 ? 1 : -1) * 6, 7, -6 - Math.floor(i / 2) * 7);
			col.castShadow = true;
			scene.add(col);
		}
		const sun = new THREE.DirectionalLight(0xffffff, 9);
		sun.position.set(8, 30, 6);
		sun.castShadow = true;
		sun.shadow.camera.left = -40; sun.shadow.camera.right = 40; sun.shadow.camera.top = 40; sun.shadow.camera.bottom = -40;
		scene.add(sun);
		scene.add(new THREE.HemisphereLight(0xffffff, 0xddd8cc, 2.5));
		scene.background = new THREE.Color(0xffffff);
		camera.position.set(0, 1.6, 4);
		camera.lookAt(0, 3, -30);
	});
	return render(ctx, g);
}

async function glimpseSets(ctx) {
	// Dozens of dead sets stacked to the ceiling.
	const g = await glimpseScene(async (scene, camera) => {
		const tvs = [];
		for (let r = 0; r < 5; r++) {
			for (let c = 0; c < 9; c++) {
				const t = await P.tv(0.5);
				t.group.position.set(-3.2 + c * 0.8 + (r % 2) * 0.1, r * 0.55, -3.0 - (c % 3) * 0.05);
				t.group.rotation.y = (c - 4) * -0.04;
				t.screen.material = new THREE.MeshStandardMaterial({ color: 0x0b0d0c, roughness: 0.08 });
				scene.add(t.group);
				tvs.push(t);
			}
		}
		const l = new THREE.SpotLight(0xbfd0ff, 30, 12, 0.7, 0.8, 2);
		l.position.set(0.5, 2.8, 2);
		l.target.position.set(0, 1, -3);
		scene.add(l, l.target);
		camera.position.set(0.2, 1.2, 1.4);
		camera.lookAt(0, 1.2, -3);
	});
	return render(ctx, g);
}

async function glimpseDoors(ctx) {
	// The same door, and the same, and the same, too far.
	const g = await glimpseScene(async (scene, camera) => {
		const kit = await new Kit(scene).load();
		const doors = [];
		for (let at = 2; at < 80; at += 2.6) {
			doors.push({ side: 1, at, number: 404 });
			doors.push({ side: -1, at: at + 1.3, number: 404 });
		}
		await corridor(kit, { length: 84, width: 3.0, doors, art: [], lit: false, end: "none" });
		for (let z = -4; z > -80; z -= 8) kit.dome(0, z, { intensity: 3 });
		scene.fog = new THREE.FogExp2(0x0a0806, 0.035);
		camera.position.set(0, 1.6, -0.5);
		camera.lookAt(0, 1.5, -40);
	});
	return render(ctx, g);
}

function render(ctx, g) {
	const r = ctx.renderer;
	g.camera.updateMatrixWorld();
	r.shadowMap.needsUpdate = true;
	r.setRenderTarget(g.rt);
	r.setClearColor(0x000000, 1);
	r.clear();
	r.render(g.scene, g.camera);
	r.setRenderTarget(null);
	return g;
}
