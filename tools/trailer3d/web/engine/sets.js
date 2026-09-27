// Sets built from the kit: the hotel corridor (every guest runs down one),
// rooms behind its doors, the reception.
import * as THREE from "three";
import { DIM } from "./kit.js";
import * as P from "./props.js";
import { polyhaven, shadows } from "./assets.js";
import { crtMaterial, GLOW } from "./screens.js";

// A straight corridor along -Z from z0: inner faces at x = +-width/2.
// doors: [{ side: -1 | 1, at: metres from z0, number, open (rad), room: { depth, lit } }]
// art: [{ side, at }] paintings flanked by a pair of sconces at +-0.98 m.
// gaps: [{ side, from, to }] full-height openings (a side corridor joining).
export async function corridor(kit, { length = 44, width = 3.5, z0 = 0, doors = [], art = [], signs = [], fireDoors = [], gaps = [], lit = true, end = "wall", sconceShadows = 0, finish = null, lightsWithin = null } = {}) {
	const half = width / 2;
	const wallX = half + DIM.wall / 2;
	kit.floor(-half - 0.2, z0 - length - 0.2, half + 0.2, z0 + 0.2);
	kit.ceilingSlab(-half - 0.2, z0 - length - 0.2, half + 0.2, z0 + 0.2);
	for (const side of [-1, 1]) {
		const openings = doors.filter((d) => d.side === side).map((d) => [d.at - DIM.opening / 2, d.at + DIM.opening / 2]);
		for (const g of gaps.filter((q) => q.side === side)) openings.push([g.from, g.to, kit.ceiling]);
		// The wall runs from z0 toward -z: "at" is measured along it.
		kit.wall(side * wallX, z0, side * wallX, z0 - length, { openings, dress: [-side], finish });
	}
	if (end === "wall") kit.wall(-half - 0.2, z0 - length - DIM.wall / 2, half + 0.2, z0 - length - DIM.wall / 2, { dress: [1], finish });
	const made = { doors: [], lights: [], sconces: [], paintings: [], rooms: [] };
	for (const d of doors) {
		const z = z0 - d.at;
		const x = d.side * wallX;
		// The door's front faces the corridor; it opens into the room.
		const door = await kit.door(x, z, d.side > 0 ? -Math.PI / 2 : Math.PI / 2, { open: d.open ?? 0, number: d.number, flip: d.flip });
		made.doors.push({ ...d, door, x, z });
		if (d.room) made.rooms.push(await room(kit, { x: d.side * (half + DIM.wall), z, side: d.side, ...d.room, finish }));
	}
	let n = 0;
	for (const a of art) {
		const z = z0 - a.at;
		const x = a.side * half;
		made.paintings.push(await kit.painting(x, z, -a.side, 0, a.index ?? n));
		for (const s of [-1, 1]) {
			const sz = z + s * 0.98;
			const shadow = sconceShadows > 0 && made.sconces.length < sconceShadows;
			// Lamps outside lightsWithin [near, far] (metres along) glow but light nothing:
			// three.js lights every pixel with every lamp, and those are lost in the haze.
			const withLight = !lightsWithin || (a.at >= lightsWithin[0] && a.at <= lightsWithin[1]);
			const sc = await kit.sconce(x, 1.6, sz, -a.side, 0, { dark: !lit || a.dark, shadow: shadow && withLight, intensity: a.intensity ?? 2.2, light: withLight });
			made.sconces.push(sc);
			if (sc.light) made.lights.push(sc.light);
		}
		n++;
	}
	for (const s of signs) made.signs = [...(made.signs ?? []), await kit.exitSign(0, z0 - s.at, s.rotY ?? 0, s.kind ?? "way_ahead")];
	for (const f of fireDoors) kit.fireDoor(0, z0 - f.at, width, { open: f.open ?? 1 });
	return made;
}

// A room behind a doorway at (x, z) on the corridor's `side`: its walls,
// floor and ceiling, dark unless lit. Enough of a room to see into.
export async function room(kit, { x, z, side, depth = 6, width = 7, lit = false, finish = null, dress = true }) {
	const x0 = x;
	const x1 = x + side * depth;
	const lo = Math.min(x0, x1);
	const hi = Math.max(x0, x1);
	kit.floor(lo, z - width / 2, hi, z + width / 2);
	kit.ceilingSlab(lo, z - width / 2, hi, z + width / 2);
	const T = DIM.wall;
	kit.wall(lo, z - width / 2 - T / 2, hi, z - width / 2 - T / 2, { dress: dress ? [1] : [], finish });
	kit.wall(lo, z + width / 2 + T / 2, hi, z + width / 2 + T / 2, { dress: dress ? [-1] : [], finish });
	kit.wall(x1 + side * T / 2, z - width / 2, x1 + side * T / 2, z + width / 2, { dress: dress ? [-side] : [], finish });
	let light = null;
	if (lit) light = kit.dome((x0 + x1) / 2, z, { intensity: typeof lit === "number" ? lit : 5 });
	return { x0, x1, z, width, light };
}

// A hotel room spanning x0..x1, z0..z1 (z0 < z1): floor, ceiling, four papered
// walls. doors: [{ wall: "n" (z0) | "s" (z1) | "w" (x0) | "e" (x1), at: metres
// along the wall from its x0 / z0 end, open (rad, + swings into the room),
// number }]. Returns the doors made.
export async function hotelRoom(kit, { x0, x1, z0, z1, doors = [], finish = null, height = kit.ceiling, floor = null, ceiling = true }) {
	const T = DIM.wall;
	kit.floor(x0 - T, z0 - T, x1 + T, z1 + T, floor ?? kit.m.carpet);
	if (ceiling) kit.ceilingSlab(x0 - T, z0 - T, x1 + T, z1 + T, kit.m.ceiling, height);
	const on = (w) => doors.filter((d) => d.wall === w).map((d) => [d.at - DIM.opening / 2, d.at + DIM.opening / 2]);
	kit.wall(x0 - T, z0 - T / 2, x1 + T, z0 - T / 2, { openings: on("n").map(([a, b]) => [a + T, b + T]), dress: [1], finish, high: height });
	kit.wall(x0 - T, z1 + T / 2, x1 + T, z1 + T / 2, { openings: on("s").map(([a, b]) => [a + T, b + T]), dress: [-1], finish, high: height });
	kit.wall(x0 - T / 2, z0, x0 - T / 2, z1, { openings: on("w"), dress: [1], finish, high: height });
	kit.wall(x1 + T / 2, z0, x1 + T / 2, z1, { openings: on("e"), dress: [-1], finish, high: height });
	const made = [];
	for (const d of doors) {
		let x;
		let z;
		let rot;
		if (d.wall === "n") { x = x0 + d.at; z = z0 - T / 2; rot = 0; }
		if (d.wall === "s") { x = x0 + d.at; z = z1 + T / 2; rot = Math.PI; }
		if (d.wall === "w") { x = x0 - T / 2; z = z0 + d.at; rot = Math.PI / 2; }
		if (d.wall === "e") { x = x1 + T / 2; z = z0 + d.at; rot = -Math.PI / 2; }
		// The leaf swings toward its back with positive angles: into the room
		// is toward its front, so the sign turns. leaf: false leaves a bare opening.
		if (d.leaf === false) continue;
		made.push({ ...d, x, z, ...(await kit.door(x, z, rot, { open: -(d.open ?? 0), number: d.number, flip: d.flip })) });
	}
	return { doors: made };
}

// A CRT on a gothic commode (the game's TV model on a Poly Haven piece),
// facing rotY, with the dead channel's light thrown forward and a faint fill.
export async function tvSet(scene, x, z, rotY, { strength = 1.4, size = 0.82 } = {}) {
	const commode = await polyhaven("GothicCommode_01");
	shadows(commode);
	commode.position.set(x, 0, z);
	commode.rotation.y = rotY;
	scene.add(commode);
	const top = new THREE.Box3().setFromObject(commode).max.y;
	const t = await P.tv(size);
	t.group.position.set(x, top, z);
	t.group.rotation.y = rotY;
	scene.add(t.group);
	const mat = crtMaterial({ strength });
	t.screen.material = mat;
	// The dead channel's light, thrown forward from the glass.
	const front = new THREE.Vector3(Math.sin(rotY), 0, Math.cos(rotY));
	const glow = new THREE.SpotLight(GLOW, 0, 9, THREE.MathUtils.degToRad(72), 1.0, 2);
	glow.position.set(x + front.x * 0.3, top + 0.3, z + front.z * 0.3);
	glow.target.position.set(x + front.x * 3, top + 0.1, z + front.z * 3);
	glow.castShadow = true;
	glow.shadow.mapSize.set(1024, 1024);
	glow.shadow.bias = -0.0015;
	glow.shadow.camera.near = 0.1;
	scene.add(glow, glow.target);
	// And what it gives the room all round, faintly.
	const fill = new THREE.PointLight(GLOW, 0, 7, 2);
	fill.position.copy(glow.position);
	scene.add(fill);
	return { mat, glow, fill, top };
}

