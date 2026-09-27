// GUEST 02 — every live screen is a door. A dark room; click, the set comes
// on and its snow lights the room blue. In the snow something comes up to
// the glass: the mask, filling the picture, the picture breaking up in hard
// flashes of static. The last one cuts to the side wall: no set, no bed,
// only the set's flicker on the paper, and across it the shadow of The Locust,
// stooped over the set, huge.
import * as THREE from "three";
import { Kit } from "../engine/kit.js";
import { hotelRoom, tvSet } from "../engine/sets.js";
import { Locust } from "../engine/locust.js";
import * as P from "../engine/props.js";
import { channelWave } from "../engine/screens.js";
import { Volumetrics } from "../engine/volumetric.js";
import { camcorder, burnIn, typed } from "../engine/osd.js";
import { clamp, smooth, smoothstep, lerp } from "../engine/util.js";
import { V, handheld, aimCamera, makeTorch, holdTorch, tape } from "./common.js";
import { makeBroadcast } from "./archive.js";

export const CLICK = 0.5;
// In the picture: it comes out of the snow and up to the glass.
export const INSIDE = [1.0, 1.95];
// The flashes of static; after each, it is further out.
export const FLASHES = [1.95, 2.3, 2.6, 2.85];
export const OUT = 2.85;
const PULL = 1.4;

export function create(ctx) {
	const scene = new THREE.Scene();
	const camera = new THREE.PerspectiveCamera(50, 4 / 3, 0.05, 60);
	let locust;
	let a;
	let face;
	let torch;
	let broadcast;
	const shot = {
		scene, camera, frame: "tape", samples: 32, shutter: 0.5,
		async setup() {
			ctx.renderer.localClippingEnabled = true;
			const kit = await new Kit(scene).load();
			await hotelRoom(kit, { x0: -3, x1: 3, z0: -4, z1: 3, doors: [{ wall: "s", at: 4.6, open: 0 }] });
			a = await tvSet(scene, 0.35, -3.55, 0);
			const bed = await P.bed();
			bed.position.set(2.0, 0, 0.4);
			bed.rotation.y = -Math.PI / 2;
			scene.add(bed);
			shot.bed = bed;
			const w = await P.wardrobe();
			w.group.position.set(-2.55, 0, -1.2);
			w.group.rotation.y = Math.PI / 2;
			scene.add(w.group);
			a.group.updateMatrixWorld(true);
			// For the reverse: the snow's light thrown wide across the room from
			// the glass, hard, so the shadow it casts is sharp on the far walls.
			shot.cast = new THREE.SpotLight(new THREE.Color(0.66, 0.76, 1.0), 0, 12, 1.15, 0.5, 1.4);
			shot.cast.castShadow = true;
			// The snow itself in the light it throws: a cookie of static, new
			// every frame, soft at the edge.
			shot.snow = document.createElement("canvas");
			shot.snow.width = shot.snow.height = 256;
			shot.snowTex = new THREE.CanvasTexture(shot.snow);
			shot.snowTex.colorSpace = THREE.SRGBColorSpace;
			shot.cast.map = shot.snowTex;
			shot.snowField = -1;
			shot.cast.shadow.mapSize.set(2048, 2048);
			shot.cast.shadow.bias = -0.0008;
			shot.cast.shadow.camera.near = 0.2;
			scene.add(shot.cast, shot.cast.target);
			shot.base = new Map([a.commode, a.group, a.glow, a.fill, a.glow.target].map((o) => [o, o.position.z]));
			const box = new THREE.Box3().setFromObject(a.screen);
			face = new THREE.Vector3((box.min.x + box.max.x) / 2, (box.min.y + box.max.y) / 2, box.max.z);
			shot.screenBox = box;
			locust = await Locust.create();
			// Never seen: it writes neither colour nor depth, and still casts
			// its shadow (the shadow pass draws with its own depth material).
			locust.root.traverse((o) => {
				if (!o.isMesh) return;
				for (const m of Array.isArray(o.material) ? o.material : [o.material]) {
					m.colorWrite = false;
					m.depthWrite = false;
				}
			});
			scene.add(locust.root);
			// What the set shows: the creature in its corner, coming to the glass.
			broadcast = await makeBroadcast(ctx);
			a.mat.uniforms.image.value = broadcast.rt.texture;
			// The guest's torch, low and shaking, on the set.
			torch = makeTorch(scene, { intensity: 22, angle: 24 });
			shot.volumetrics = new Volumetrics(ctx.renderer, { density: 0.012, noise: 0.5, maxDist: 12, steps: 24 });
			shot.volumetrics.addSpot(a.glow, { strength: 0.08 });
			shot.volumetrics.addSpot(torch, { strength: 0.12 });
		},
		beforeRender() {
			if (!shot.inPicture) return;
			const r = ctx.renderer;
			r.setRenderTarget(broadcast.rt);
			r.setClearColor(0x000000, 1);
			r.clear();
			r.render(broadcast.scene, broadcast.camera);
		},
		update(t) {
			const wave = channelWave(t);
			const hh = handheld(t, { amp: 1.2, seed: 21 });
			// Creeping in toward the set as it builds; backing off when it is out.
			const near = smoothstep(CLICK, FLASHES[0], t) * 0.35 - smoothstep(OUT, OUT + 0.4, t) * 0.5;
			const eye = V(0.2, 1.5, -1.0 - near).add(hh.pos);
			camera.position.copy(eye);
			const on = t >= CLICK;
			const k = clamp((t - CLICK) / 0.35);
			const flash = FLASHES.some((f) => t >= f && t < f + 0.1);
			const swell = smoothstep(CLICK + 0.3, FLASHES[0], t);
			const u = a.mat.uniforms;
			u.power.value = on ? k : 0;
			u.time.value = t;
			u.unstable.value = swell * 0.6 + (flash ? 1 : 0) + smoothstep(FLASHES[0], OUT, t) * 0.6;
			u.brightness.value = flash ? 2.4 : 0.85 + swell * 0.3;
			// The picture: snow, then the creature out of it and up to the glass;
			// once it is out, snow again.
			shot.inPicture = on && t < OUT;
			const seen = smoothstep(INSIDE[0], INSIDE[1], t);
			u.image_amount.value = shot.inPicture ? 0.25 + seen * 0.65 : 0;
			u.static_amount.value = shot.inPicture ? 1 - seen * 0.55 : 1;
			if (shot.inPicture) posePicture(broadcast, t);
			// Once it is out the set is all the light there is, and plenty.
			// Out, one light only, so there is one shadow (two would half-fill it).
			a.glow.intensity = on && t < OUT ? 14 * smooth(k) * wave * (flash ? 3 : 1) : 0;
			// Out, the set's beam alone (it casts the shadow; a fill would wash it).
			a.fill.intensity = on && t < OUT ? 2.2 * smooth(k) * wave * (flash ? 3 : 1) : 0;
			// Out: from right behind the set, its back filling the frame; the
			// creature out in the room is never seen, only its shadow, thrown by
			// the snow up the far wall.
			locust.root.visible = t >= OUT;
			shot.bed.visible = t < OUT;
			// For the reverse the set is brought out from the wall (the cut
			// hides it), so there is room behind it for the lens.
			const dz = t >= OUT ? PULL : 0;
			for (const o of [a.commode, a.group, a.glow, a.fill, a.glow.target]) o.position.z = shot.base.get(o) + dz;
			a.glow.target.updateMatrixWorld();
			// Dim, and never still: the snow's grain in the light, and now and then
			// the set flaring.
			const field = Math.floor(t * 30);
			const grain = 0.7 + 0.6 * (Math.sin(field * 12.9898) * 43758.5453 % 1 + 1) % 1;
			const flare = Math.sin(t * 7.3) * Math.sin(t * 3.1) > 0.6 ? 2.2 : 1;
			shot.cast.intensity = t >= OUT ? 9 * wave * grain * flare * (flash ? 2 : 1) : 0;
			if (t >= OUT && field !== shot.snowField) {
				shot.snowField = field;
				const g = shot.snow.getContext("2d");
				const img = g.createImageData(256, 256);
				let seed = field * 7919 + 17;
				for (let i = 0; i < 256 * 256; i++) {
					seed = (seed * 1103515245 + 12345) & 0x7fffffff;
					const x = i % 256 - 128;
					const y = Math.floor(i / 256) - 128;
					const edge = Math.max(0, 1 - Math.hypot(x, y) / 132);
					const v = (185 + (seed % 70)) * Math.min(1, edge * 1.6);
					img.data[i * 4] = img.data[i * 4 + 1] = img.data[i * 4 + 2] = v;
					img.data[i * 4 + 3] = 255;
				}
				g.putImageData(img, 0, 0);
				shot.snowTex.needsUpdate = true;
			}
			// The glass is a broad source: moved about it a little every
			// subframe, so the shadow's edge comes out soft.
			shot.cast.position.set(face.x + (Math.random() - 0.5) * 0.4, face.y + (Math.random() - 0.5) * 0.3, face.z + PULL + 0.05);
			shot.cast.target.position.set(3.0, face.y - 0.45, face.z + PULL + 2.4);
			shot.cast.target.updateMatrixWorld();
			if (t >= OUT) {
				poseOut(locust, t);
				// From the side, across the room at the east wall: the set out of
				// frame to the right, its light and the shadow on the paper.
				eye.set(-1.2 + hh.pos.x * 0.5, 1.45, 2.0);
				camera.position.copy(eye);
				aimCamera(camera, eye, V(3.0, 1.95, -0.3), { yaw: hh.yaw * 0.3, pitch: hh.pitch * 0.3, roll: hh.roll * 0.3 });
				camera.fov = 48;
			} else {
				aimCamera(camera, eye, V(0.35, 1.15, -3.6), { yaw: hh.yaw, pitch: hh.pitch, roll: hh.roll });
				camera.fov = 50;
			}
			holdTorch(torch, camera, { ahead: 2.2, swayT: t * 1.5, sway: 0.6, aimOffset: V(0, 0.1, 0) });
			// Behind the set there is no torch: the set is the only light.
			torch.intensity = t >= OUT ? 0 : 22;
		},
		look(t) {
			// Night gain, kept low: the room stays dark round the set.
			const L = tape({ exposure: 1.45, whiteBalance: [0.96, 1.0, 1.08], grain: 0.34, halation: 0.15, bloom: 0.035 });
			// The wall: darker, greyer, the grain up, the corners gone.
			if (t >= OUT) Object.assign(L, { exposure: 1.1, grain: 0.45, saturation: 0.7, vignette: 0.8 });
			// Each flash: a burst of white snow, the picture thrown sideways, a
			// frame too bright, and it drops back.
			for (const f of FLASHES) {
				const k = t - f;
				if (k >= -0.02 && k < 0.12) {
					L.snow = k < 0.07 ? 1 : 0.5;
					L.tracking = 1;
					L.jerk = 0.9;
					L.roll = 0.03;
					L.exposure = k < 0.04 ? 4.5 : 2.4;
					L.threat_glitch = 0.5;
				}
			}
			return L;
		},
		overlay(g, t, size) {
			camcorder(g, t, size, { clock: 2 * 3600 + 31 * 60 + 9, date: "OCT. 27 1993", focus: t < CLICK + 0.1 ? 1 - smoothstep(CLICK, CLICK + 0.1, t) : 0, word: "TURN ON" });
			if (t < 1.4) burnIn(g, [typed("TAPE 81 · GUEST 02", t, 0.05, 40)], size, { alpha: 1 - smoothstep(1.1, 1.4, t) });
		},
	};
	return shot;
}

// In the picture: out of the dark of its corner, up to the glass.
function posePicture(b, t) {
	const L = b.locust;
	const near = smoothstep(INSIDE[0], FLASHES[0] + 0.3, t);
	L.root.position.set(0.06, 0, lerp(-0.9, 0.45, near));
	L.root.rotation.set(0, 0, 0);
	L.reset();
	L.stand({ hunch: 0.2 + near * 0.2 });
	L.hangArms();
	L.turn("Head1", [0, 0, 1], -0.2 + Math.sin(t * 23) * 0.03 * near);
	L.turn("Head1", [1, 0, 0], 0.12 + near * 0.1);
	const head = L.point("Head1");
	b.camera.lookAt(head.x, head.y + 0.22, head.z);
}

// Out: between the set and the east wall, stooped over the set, the long
// arms hanging, the head on one side: all of it thrown up the wall.
function poseOut(L, t) {
	L.root.rotation.set(0, -Math.PI / 2 - 0.35, 0);
	L.root.position.set(1.9, 0, -3.55 + PULL + 1.0);
	L.reset();
	L.stand({ hunch: 0.55 });
	L.hangArms();
	L.turn("Head1", [1, 0, 0], 0.25);
	L.turn("Head1", [0, 0, 1], 0.4 + Math.sin(t * 29) * 0.05);
	L.root.updateMatrixWorld(true);
}
