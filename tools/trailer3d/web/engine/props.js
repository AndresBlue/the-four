// The game's supplied models, fitted the way the game bakes them
// (tools/props/build_model_props.gd, build_door.gd, build_wardrobe.gd): floor
// at y = 0, centred, front facing +Z, at the game's sizes, with their own PBR
// maps.
import * as THREE from "three";
import { fbxCopy, texture } from "./assets.js";

async function pbr(dir, names, extra = {}) {
	const m = new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 1, metalness: 0, ...extra });
	if (names.albedo) m.map = await texture(`${dir}/${names.albedo}`, { srgb: true, flipY: true });
	if (names.normal) m.normalMap = await texture(`${dir}/${names.normal}`, { flipY: true });
	if (names.roughness) m.roughnessMap = await texture(`${dir}/${names.roughness}`, { flipY: true });
	if (names.metallic) { m.metalnessMap = await texture(`${dir}/${names.metallic}`, { flipY: true }); m.metalness = 1; }
	if (names.ao) m.aoMap = await texture(`${dir}/${names.ao}`, { flipY: true });
	if (names.orm) {
		const t = await texture(`${dir}/${names.orm}`, { flipY: true });
		m.roughnessMap = t;
		m.metalnessMap = t;
		m.aoMap = t;
		m.metalness = 1;
	}
	return m;
}

// Bounds of the given meshes of `root` in root's parent space.
function boundsOf(root, meshes) {
	root.updateMatrixWorld(true);
	const box = new THREE.Box3();
	const v = new THREE.Vector3();
	for (const m of meshes) {
		const pos = m.geometry.attributes.position;
		for (let i = 0; i < pos.count; i++) {
			v.fromBufferAttribute(pos, i).applyMatrix4(m.matrixWorld);
			box.expandByPoint(v);
		}
	}
	return box;
}

// Bakes the chosen meshes of an FBX into world-free geometry in prop space.
function bake(root, meshes, fit) {
	root.updateMatrixWorld(true);
	const out = [];
	for (const m of meshes) {
		const g = m.geometry.clone();
		// FBX meshes come with empty morph-target lists, which break the shader.
		g.morphAttributes = {};
		g.morphTargetsRelative = false;
		g.applyMatrix4(new THREE.Matrix4().multiplyMatrices(fit, m.matrixWorld));
		if (!g.attributes.normal) g.computeVertexNormals();
		out.push({ name: m.name, geometry: g, material: m.material });
	}
	return out;
}

function fitMatrix(box, { yaw = 0, axis = "long", size = 1, anchor = "centre", scale3 = null }) {
	const s = box.getSize(new THREE.Vector3());
	const along = { x: s.x, y: s.y, z: s.z }[axis] ?? Math.max(s.x, s.z);
	const k = scale3 ? null : size / along;
	const scale = scale3 ? new THREE.Vector3(scale3.x / s.x, scale3.y / s.y, scale3.z / s.z) : new THREE.Vector3(k, k, k);
	const offset = new THREE.Vector3(-(box.min.x + s.x / 2), -box.min.y, anchor === "wall" ? -box.min.z : -(box.min.z + s.z / 2));
	return new THREE.Matrix4().makeScale(scale.x, scale.y, scale.z).multiply(new THREE.Matrix4().makeTranslation(offset.x, offset.y, offset.z));
}

async function load(path, names, yaw) {
	const root = await fbxCopy(path);
	const holder = new THREE.Group();
	holder.rotation.y = yaw;
	holder.add(root);
	const meshes = [];
	root.traverse((o) => { if (o.isMesh && (!names || names.includes(o.name))) meshes.push(o); });
	holder.updateMatrixWorld(true);
	return { holder, meshes };
}

function meshOf(parts, material) {
	const group = new THREE.Group();
	for (const p of parts) {
		const mesh = new THREE.Mesh(p.geometry, typeof material === "function" ? material(p) : material);
		mesh.castShadow = true;
		mesh.receiveShadow = true;
		mesh.name = p.name;
		group.add(mesh);
	}
	return group;
}

// Splits a multi-material geometry into one geometry per material group.
function byGroup(geometry) {
	if (!geometry.groups.length) return [{ geometry, index: 0 }];
	const out = [];
	const index = geometry.index;
	for (const grp of geometry.groups) {
		const g = new THREE.BufferGeometry();
		for (const [name, attr] of Object.entries(geometry.attributes)) g.setAttribute(name, attr);
		if (index) g.setIndex(Array.from(index.array.slice(grp.start, grp.start + grp.count)));
		else {
			const ids = [];
			for (let i = grp.start; i < grp.start + grp.count; i++) ids.push(i);
			g.setIndex(ids);
		}
		out.push({ geometry: g, index: grp.materialIndex });
	}
	return out;
}

let materialsCache = null;
async function mats() {
	if (materialsCache) return materialsCache;
	const d = "assets/props";
	materialsCache = {
		tvBody: await pbr(`${d}/tv`, { albedo: "body_albedo.png", normal: "body_normal.png", roughness: "body_roughness.png", metallic: "body_metallic.png", ao: "body_ao.png" }),
		lampMetal: await pbr(`${d}/wall_lamp`, { albedo: "metal_albedo.png", normal: "metal_normal.png", roughness: "metal_roughness.png", metallic: "metal_metallic.png" }),
		lampCloth: await pbr(`${d}/wall_lamp`, { albedo: "cloth_albedo.png", normal: "cloth_normal.png", roughness: "cloth_roughness.png" }, { side: THREE.DoubleSide }),
		bed: await pbr(`${d}/bedroom`, { albedo: "bed_albedo.jpg", normal: "bed_normal.png", orm: "bed_orm.jpg" }),
		sofa: await pbr(`${d}/sofa`, { albedo: "albedo.jpg", normal: "normal.jpg", roughness: "roughness.jpg", ao: "ao.jpg" }),
		// Two-sided: someone hides inside it, and its panels are single sheets.
		wardrobe: await pbr(`${d}/wardrobe`, { albedo: "albedo.jpg", normal: "normal.png", roughness: "roughness.jpg", metallic: "metallic.jpg", ao: "ao.jpg" }, { side: THREE.DoubleSide }),
		doorLeaf: await pbr(`${d}/door`, { albedo: "leaf_basecolor.png", normal: "leaf_normal.png", roughness: "leaf_roughness.png", metallic: "leaf_metallic.png" }),
		doorFrame: await pbr(`${d}/door`, { albedo: "frame_basecolor.png", normal: "frame_normal.png", roughness: "frame_roughness.png", metallic: "frame_metallic.png" }),
		monsteraLeaf: await pbr(`${d}/monstera`, { albedo: "leaf_albedo.png", normal: "leaf_normal.png", roughness: "leaf_roughness.png" }, { side: THREE.DoubleSide, alphaTest: 0.5 }),
		monsteraPot: await pbr(`${d}/monstera`, { albedo: "pot_albedo.png", normal: "pot_normal.png", roughness: "pot_roughness.png" }),
	};
	// The shade glows a little from the bulb behind it, as shade.tres does.
	materialsCache.lampCloth.emissive = new THREE.Color().setRGB(1, 0.72, 0.42, THREE.SRGBColorSpace);
	materialsCache.lampCloth.emissiveIntensity = 0.0;
	materialsCache.bulb = new THREE.MeshStandardMaterial({ color: 0xffffff, emissive: new THREE.Color().setRGB(1.0, 0.84, 0.6, THREE.SRGBColorSpace), emissiveIntensity: 6 });
	return materialsCache;
}

// A CRT television (tv/old_tv.fbx): 0.62 m along its longest side, front +Z.
// Returns { group, screen } — the screen mesh takes the caller's material.
export async function tv(size = 0.62) {
	const m = await mats();
	const { holder, meshes } = await load("assets/props/tv/old_tv.fbx", ["TV_body_low", "TV_screen_low"], 0);
	const fit = fitMatrix(boundsOf(holder, meshes), { axis: "long", size });
	const parts = bake(holder, meshes, fit);
	const group = new THREE.Group();
	let screen = null;
	for (const p of parts) {
		const mesh = new THREE.Mesh(p.geometry, p.name === "TV_screen_low" ? new THREE.MeshStandardMaterial({ color: 0x050706, roughness: 0.07 }) : m.tvBody);
		mesh.castShadow = true;
		mesh.receiveShadow = true;
		if (p.name === "TV_screen_low") screen = mesh;
		group.add(mesh);
	}
	return { group, screen };
}

// A wall sconce (wall_lamp.fbx): 0.42 m tall, back against the wall at z = 0.
export async function wallLamp() {
	const m = await mats();
	const { holder, meshes } = await load("assets/props/wall_lamp/wall_lamp.fbx", null, 0);
	const fit = fitMatrix(boundsOf(holder, meshes), { axis: "y", size: 0.42, anchor: "wall" });
	const parts = bake(holder, meshes, fit);
	const group = new THREE.Group();
	for (const p of parts) {
		if (p.name.includes("Bulb")) {
			const mesh = new THREE.Mesh(p.geometry, m.bulb);
			group.add(mesh);
			continue;
		}
		for (const piece of byGroup(p.geometry)) {
			const mat = Array.isArray(p.material) ? p.material[piece.index] : p.material;
			const cloth = mat && /Cloth/i.test(mat.name);
			const mesh = new THREE.Mesh(piece.geometry, cloth ? m.lampCloth : m.lampMetal);
			mesh.castShadow = !cloth;
			mesh.receiveShadow = true;
			group.add(mesh);
		}
	}
	return group;
}

export async function bed() {
	const m = await mats();
	const { holder, meshes } = await load("assets/props/bedroom/bedroom_set.fbx", ["SM_Bed_01"], 0);
	const fit = fitMatrix(boundsOf(holder, meshes), { axis: "z", size: 2.1 });
	return meshOf(bake(holder, meshes, fit), m.bed);
}

export async function sofa() {
	const m = await mats();
	const { holder, meshes } = await load("assets/props/sofa/sofa.fbx", ["Sofa"], 0);
	const fit = fitMatrix(boundsOf(holder, meshes), { axis: "x", size: 2.15 });
	return meshOf(bake(holder, meshes, fit), m.sofa);
}

const WARDROBE_DOORS = ["7_low", "17_low", "18_low", "6_low", "1_low", "20_low"];

// The hiding wardrobe (build_wardrobe.gd): 1.25 x 2.3 x 0.78 m, doors on +Z,
// split at the centre seam into two leaves hinged at their outer edges.
// Returns { group, left, right } — left/right are pivots: rotate .rotation.y
// (left opens with negative angles, right with positive ones).
export async function wardrobe() {
	const m = await mats();
	const { holder, meshes } = await load("assets/props/wardrobe/wardrobe.fbx", null, -Math.PI / 2);
	const box = boundsOf(holder, meshes);
	const fit = fitMatrix(box, { scale3: new THREE.Vector3(1.25, 2.3, 0.78) });
	const parts = bake(holder, meshes, fit);
	const group = new THREE.Group();
	const body = [];
	const leaves = { left: [], right: [] };
	for (const p of parts) {
		if (!WARDROBE_DOORS.includes(p.name)) { body.push(p.geometry); continue; }
		// Split the door parts triangle by triangle at the centre seam.
		const g = p.geometry.index ? p.geometry.toNonIndexed() : p.geometry;
		const pos = g.attributes.position;
		const sides = { left: [], right: [] };
		for (let t = 0; t < pos.count; t += 3) {
			const cx = (pos.getX(t) + pos.getX(t + 1) + pos.getX(t + 2)) / 3;
			sides[cx < 0 ? "left" : "right"].push(t);
		}
		for (const side of ["left", "right"]) {
			if (!sides[side].length) continue;
			const ng = new THREE.BufferGeometry();
			for (const [name, attr] of Object.entries(g.attributes)) {
				const arr = new attr.array.constructor(sides[side].length * 3 * attr.itemSize);
				let o = 0;
				for (const t of sides[side]) for (let k = 0; k < 3; k++) for (let c = 0; c < attr.itemSize; c++) arr[o++] = attr.array[(t + k) * attr.itemSize + c];
				ng.setAttribute(name, new THREE.BufferAttribute(arr, attr.itemSize));
			}
			leaves[side].push(ng);
		}
	}
	for (const geo of body) {
		const mesh = new THREE.Mesh(geo, m.wardrobe);
		mesh.castShadow = mesh.receiveShadow = true;
		group.add(mesh);
	}
	// Hinges at the outer front edges.
	const front = new THREE.Box3();
	for (const side of ["left", "right"]) for (const g of leaves[side]) { g.computeBoundingBox(); front.union(g.boundingBox); }
	const pivots = {};
	for (const side of ["left", "right"]) {
		const pivot = new THREE.Group();
		const hx = side === "left" ? front.min.x : front.max.x;
		const hz = front.max.z;
		pivot.position.set(hx, 0, hz);
		for (const g of leaves[side]) {
			g.translate(-hx, 0, -hz);
			const mesh = new THREE.Mesh(g, m.wardrobe);
			mesh.castShadow = mesh.receiveShadow = true;
			pivot.add(mesh);
		}
		group.add(pivot);
		pivots[side] = pivot;
	}
	return { group, left: pivots.left, right: pivots.right };
}

// A hotel door (build_door.gd): casing round the 1.30 x 2.65 m opening,
// centred on the wall at x = 0; the leaf hinged at the opening's left edge
// (x = -0.65) swinging on .leaf.rotation.y. Copy "01" of the file.
export async function door() {
	const m = await mats();
	const root = await fbxCopy("assets/props/door/door.fbx");
	root.updateMatrixWorld(true);
	// The file has two copies side by side (shut and ajar): keep the first.
	const all = [];
	root.traverse((o) => { if (o.isMesh) all.push(o); });
	const first = all.filter((o) => !o.name.endsWith("_2"));
	const frameMeshes = first.filter((o) => o.name === "F");
	// The file's handle sits far off the leaf (a pivot three.js reads
	// differently): it is left out, and the leaf gets its own knobs.
	const leafMeshes = first.filter((o) => o.name === "door");
	const frameBox = boundsOf(root, frameMeshes);
	const leafBox = boundsOf(root, [...leafMeshes]);
	// The leaf's thin axis tells which way the door faces.
	const ls = leafBox.getSize(new THREE.Vector3());
	const facesX = ls.x < ls.z;
	const turn = new THREE.Matrix4().makeRotationY(facesX ? -Math.PI / 2 : 0);
	const tb = (b) => b.clone().applyMatrix4(turn);
	const fb = tb(frameBox);
	const lb = tb(leafBox);
	const OPEN_W = 1.3;
	const OPEN_H = 2.65;
	// Opening = the leaf's extent; scale x/y so the leaf fills 1.30 x 2.65.
	const lsz = lb.getSize(new THREE.Vector3());
	const sx = OPEN_W / lsz.x;
	const sy = OPEN_H / lsz.y;
	const sz = (sx + sy) / 2;
	const centre = new THREE.Vector3((lb.min.x + lb.max.x) / 2, lb.min.y, (fb.min.z + fb.max.z) / 2);
	const fit = new THREE.Matrix4().makeScale(sx, sy, sz).multiply(new THREE.Matrix4().makeTranslation(-centre.x, -centre.y, -centre.z)).multiply(turn);
	const group = new THREE.Group();
	for (const p of bake(root, frameMeshes, fit)) {
		for (const piece of byGroup(p.geometry)) {
			const mesh = new THREE.Mesh(piece.geometry, m.doorFrame);
			mesh.castShadow = mesh.receiveShadow = true;
			group.add(mesh);
		}
	}
	const leaf = new THREE.Group();
	// A hair off the floor, so its bottom edge never fights the carpet.
	leaf.position.set(-OPEN_W / 2, 0.012, 0);
	for (const p of bake(root, leafMeshes, fit)) {
		for (const piece of byGroup(p.geometry)) {
			const mat = Array.isArray(p.material) ? p.material[piece.index] : p.material;
			const isLeaf = mat && mat.name === "door";
			// Its own copy: the baked pieces are cached and shared between doors,
			// and moving them in place moved every other door's leaf too.
			const geometry = piece.geometry.clone();
			const mesh = new THREE.Mesh(geometry, isLeaf ? m.doorLeaf : m.doorFrame);
			mesh.castShadow = mesh.receiveShadow = true;
			leaf.add(mesh);
		}
	}
	// The leaf's hinge edge on the group's origin, its thickness on the
	// frame's middle.
	const span = new THREE.Box3();
	for (const mesh of leaf.children) {
		mesh.geometry.computeBoundingBox();
		span.union(mesh.geometry.boundingBox);
	}
	const middle = (span.min.z + span.max.z) / 2;
	for (const mesh of leaf.children) mesh.geometry.translate(-span.min.x, 0, -middle);
	// A brass knob each side, near the free edge.
	const leafDepth = span.max.z - span.min.z;
	const brass = new THREE.MeshStandardMaterial({ color: new THREE.Color().setRGB(0.62, 0.45, 0.2, THREE.SRGBColorSpace), metalness: 1, roughness: 0.35 });
	for (const side of [1, -1]) {
		const rose = new THREE.Mesh(new THREE.CylinderGeometry(0.03, 0.03, 0.012, 20), brass);
		rose.rotation.x = Math.PI / 2;
		rose.position.set(OPEN_W - 0.09, 1.0, side * (leafDepth / 2 + 0.006));
		const knob = new THREE.Mesh(new THREE.SphereGeometry(0.028, 16, 12), brass);
		knob.position.set(OPEN_W - 0.09, 1.0, side * (leafDepth / 2 + 0.05));
		const neck = new THREE.Mesh(new THREE.CylinderGeometry(0.009, 0.009, 0.045, 10), brass);
		neck.rotation.x = Math.PI / 2;
		neck.position.set(OPEN_W - 0.09, 1.0, side * (leafDepth / 2 + 0.025));
		for (const k of [rose, knob, neck]) {
			k.castShadow = true;
			leaf.add(k);
		}
	}
	group.add(leaf);
	return { group, leaf };
}

export async function monstera() {
	const m = await mats();
	const { holder, meshes } = await load("assets/props/monstera/monstera.fbx", null, 0);
	const fit = fitMatrix(boundsOf(holder, meshes), { axis: "y", size: 1.35 });
	return meshOf(bake(holder, meshes, fit), (p) => (/Leaves|root/i.test(p.name) ? m.monsteraLeaf : m.monsteraPot));
}
