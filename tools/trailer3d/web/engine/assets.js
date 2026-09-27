// Loading the game's own assets straight from the repository (/repo/...),
// each once.
import * as THREE from "three";
import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js";
import { FBXLoader } from "three/addons/loaders/FBXLoader.js";
import { OBJLoader } from "three/addons/loaders/OBJLoader.js";
import { clone as cloneSkinned } from "three/addons/utils/SkeletonUtils.js";

const cache = new Map();
const textureLoader = new THREE.TextureLoader();
let maxAnisotropy = 8;

export function setAnisotropy(n) {
	maxAnisotropy = n;
}

function once(key, make) {
	if (!cache.has(key)) cache.set(key, make());
	return cache.get(key);
}

export const repo = (p) => `/repo/${p}`;

// A texture from the repository. srgb for colour, not for data (normal, ORM).
export function texture(path, { srgb = false, repeat = true, flipY = true } = {}) {
	return once(`tex:${path}:${srgb}:${repeat}:${flipY}`, async () => {
		const t = await textureLoader.loadAsync(repo(path));
		t.colorSpace = srgb ? THREE.SRGBColorSpace : THREE.NoColorSpace;
		if (repeat) t.wrapS = t.wrapT = THREE.RepeatWrapping;
		t.anisotropy = maxAnisotropy;
		t.flipY = flipY;
		t.needsUpdate = true;
		return t;
	});
}

// A scanned set (assets/textures/<set>/): colour, normal (OpenGL) and ORM.
export function scan(set) {
	return once(`scan:${set}`, async () => {
		const [albedo, normal, orm] = await Promise.all([
			texture(`assets/textures/${set}/albedo.jpg`, { srgb: true }),
			texture(`assets/textures/${set}/normal.jpg`),
			texture(`assets/textures/${set}/orm.jpg`),
		]);
		return { albedo, normal, orm };
	});
}

export function gltf(path) {
	return once(`gltf:${path}`, () => new GLTFLoader().loadAsync(repo(path)));
}

// A fresh copy of a glTF scene (skinned meshes keep their own skeleton).
export async function gltfCopy(path) {
	const g = await gltf(path);
	return cloneSkinned(g.scene);
}

// ownTextures: let the file bring its own (embedded) textures; otherwise its
// maps are applied by hand and the loader is not let fetch guesses.
export function fbx(path, { ownTextures = false } = {}) {
	return once(`fbx:${path}:${ownTextures}`, async () => {
		const loader = new FBXLoader();
		if (!ownTextures) {
			loader.manager = new THREE.LoadingManager();
			loader.manager.setURLModifier((url) => (url.startsWith("data:") || url.startsWith("blob:") || url.toLowerCase().endsWith(".fbx") ? url : "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII="));
		}
		return loader.loadAsync(repo(path));
	});
}

export async function fbxCopy(path, options) {
	const f = await fbx(path, options);
	return cloneSkinned(f);
}

export function obj(path) {
	return once(`obj:${path}`, () => new OBJLoader().loadAsync(repo(path)));
}

// A Poly Haven prop (source_assets/props/<id>/<id>_<res>.gltf).
export async function polyhaven(id, res = "2k") {
	const tries = [`source_assets/props/${id}/${id}_${res}.gltf`, `source_assets/props/${id}/${id}_1k.gltf`, `source_assets/props/${id}/${id}_2k.gltf`, `source_assets/props/${id}/${id}_4k.gltf`];
	for (const p of tries) {
		try {
			const g = await gltf(p);
			return g.scene.clone(true);
		} catch (e) {
			cache.delete(`gltf:${p}`);
		}
	}
	throw new Error(`no Poly Haven prop ${id}`);
}

// Casts and receives shadows on every mesh of an object.
export function shadows(object, cast = true, receive = true) {
	object.traverse((o) => {
		if (o.isMesh) {
			o.castShadow = cast;
			o.receiveShadow = receive;
		}
	});
	return object;
}

// Size of an object's bounding box, for fitting models to the game's measures.
export function size(object) {
	const box = new THREE.Box3().setFromObject(object);
	return { box, size: box.getSize(new THREE.Vector3()), center: box.getCenter(new THREE.Vector3()) };
}
