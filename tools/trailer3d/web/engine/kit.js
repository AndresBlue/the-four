// The hotel's architecture at the game's measures (hotel_geometry.gd,
// floor_definition.gd): 0.18 m papered walls over a 0.96 m dark wooden dado,
// chair rail, skirting and crown; carpet; stucco ceilings at 3.15 m;
// 1.30 x 2.65 m doorways with the supplied door and its brass plate on the
// leaf at 1.94 m; paintings at 2.02 m flanked by sconces at 1.6 m; the green
// way-out signs. Metres, y up, axis-aligned boxes so the ported surfaces map
// as in the game.
import * as THREE from "three";
import { hotelMaterial } from "./materials.js";
import * as P from "./props.js";
import { texture } from "./assets.js";

export const DIM = { ceiling: 3.15, wall: 0.18, dado: 0.96, opening: 1.3, openingHigh: 2.65 };
export const PAINTINGS = ["238272", "869", "495", "111632", "15708", "79765", "75409", "146701", "72801", "890", "874", "152747", "69041", "64029"];
const srgb = (hex) => new THREE.Color(hex);

export class Kit {
	constructor(scene, options = {}) {
		this.scene = scene;
		this.root = new THREE.Group();
		scene.add(this.root);
		this.ceiling = options.ceiling ?? DIM.ceiling;
		this.wallFinish = options.wallpaper ?? "wallpaper";
		this.lights = [];
		this.emissive = [];
	}

	async load() {
		const c = { ceiling: this.ceiling };
		this.m = {
			wallpaper: await hotelMaterial("wallpaper", c),
			wallpaperDecrepit: await hotelMaterial("wallpaperDecrepit", c),
			panel: await hotelMaterial("panel", c),
			trim: await hotelMaterial("trim", c),
			carpet: await hotelMaterial("carpet", c),
			ceiling: await hotelMaterial("ceiling", c),
			ceilingService: await hotelMaterial("ceilingService", c),
			brass: await hotelMaterial("brass", c),
			tile: await hotelMaterial("tile", c),
			metal: await hotelMaterial("metal", c),
			black: await hotelMaterial("black", c),
			linen: await hotelMaterial("linen", c),
		};
		return this;
	}

	box(w, h, d, material, x, y, z, { cast = true, receive = true, parent = this.root } = {}) {
		const mesh = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), material);
		mesh.position.set(x, y, z);
		mesh.castShadow = cast;
		mesh.receiveShadow = receive;
		parent.add(mesh);
		return mesh;
	}

	floor(x0, z0, x1, z1, material = this.m.carpet) {
		return this.box(x1 - x0, 0.3, z1 - z0, material, (x0 + x1) / 2, -0.15, (z0 + z1) / 2, { cast: false });
	}

	ceilingSlab(x0, z0, x1, z1, material = this.m.ceiling, height = this.ceiling) {
		return this.box(x1 - x0, 0.2, z1 - z0, material, (x0 + x1) / 2, height + 0.1, (z0 + z1) / 2);
	}

	// A wall from (x0, z0) to (x1, z1), one of the two axis-aligned. Openings
	// are [from, to] along it (metres from its start); dress lists the faces
	// that get the dado, rail, skirting and crown: +1 toward +z (or +x).
	wall(x0, z0, x1, z1, { openings = [], dress = [1, -1], finish = null, high = this.ceiling, dado = true, header = DIM.openingHigh } = {}) {
		const alongX = Math.abs(z1 - z0) < 1e-6;
		const len = alongX ? Math.abs(x1 - x0) : Math.abs(z1 - z0);
		const sx = alongX ? Math.sign(x1 - x0) || 1 : 0;
		const sz = alongX ? 0 : Math.sign(z1 - z0) || 1;
		const wallMat = finish ? this.m[finish] : this.m[this.wallFinish];
		const T = DIM.wall;
		const at = (s) => [x0 + sx * s, z0 + sz * s];
		const piece = (a, b, depth0, depth1, y0, y1, material, side) => {
			const [cx, cz] = at((a + b) / 2);
			const w = b - a;
			const d = depth1 - depth0;
			const off = (depth0 + depth1) / 2;
			const nx = alongX ? 0 : side;
			const nz = alongX ? side : 0;
			this.box(alongX ? w : d, y1 - y0, alongX ? d : w, material, cx + nx * off, (y0 + y1) / 2, cz + nz * off);
		};
		const run = (a, b) => {
			if (b - a < 1e-3) return;
			const [cx, cz] = at((a + b) / 2);
			const w = b - a;
			this.box(alongX ? w : T, high, alongX ? T : w, wallMat, cx, high / 2, cz);
			for (const side of dress) {
				if (dado) {
					piece(a, b, 0.075, 0.145, 0, 0.96, this.m.panel, side);
					piece(a, b, 0.1325, 0.1675, 0.955, 1.005, this.m.trim, side);
				}
				piece(a, b, 0.14, 0.17, 0, 0.14, this.m.trim, side);
				piece(a, b, 0.09, 0.15, high - 0.1, high, this.m.trim, side);
				piece(a, b, 0.085, 0.115, high - 0.16, high - 0.1, this.m.trim, side);
			}
		};
		const cuts = [...openings].sort((p, q) => p[0] - q[0]);
		let s = 0;
		for (const [a, b, top] of cuts) {
			run(s, a);
			const h0 = top ?? header;
			const [cx, cz] = at((a + b) / 2);
			if (high - h0 > 1e-3) this.box(alongX ? b - a : T, high - h0, alongX ? T : b - a, wallMat, cx, (high + h0) / 2, cz);
			for (const side of dress) piece(a, b, 0.09, 0.15, high - 0.1, high, this.m.trim, side);
			s = b;
		}
		run(s, len);
	}

	// A door centred at (x, z) in a wall; rotY 0: the wall runs along X and the
	// door's front faces +z. open: the leaf's swing (radians, the game opens
	// 1.48). number: the brass plate on both faces of the leaf at 1.94 m.
	async door(x, z, rotY = 0, { open = 0, number = null, flip = false } = {}) {
		const d = await P.door();
		d.group.position.set(x, 0, z);
		d.group.rotation.y = rotY;
		if (flip) d.group.scale.x = -1;
		d.leaf.rotation.y = open;
		this.root.add(d.group);
		if (number) {
			for (const side of [1, -1]) {
				const plate = this.plate(number);
				plate.position.set(0.65, 1.94, side * 0.07);
				plate.rotation.y = side > 0 ? 0 : Math.PI;
				d.leaf.add(plate);
			}
		}
		return d;
	}

	// The brass plate: 0.34 x 0.19 m, the number in dark brown (PLAQUE_INK).
	plate(number) {
		if (!this.plates) this.plates = new Map();
		if (!this.plates.has(number)) {
			const c = document.createElement("canvas");
			c.width = 512;
			c.height = 286;
			const g = c.getContext("2d");
			g.fillStyle = "#b8924e";
			g.fillRect(0, 0, 512, 286);
			const grad = g.createLinearGradient(0, 0, 512, 286);
			grad.addColorStop(0, "rgba(255,236,190,0.3)");
			grad.addColorStop(0.55, "rgba(0,0,0,0)");
			grad.addColorStop(1, "rgba(50,30,8,0.35)");
			g.fillStyle = grad;
			g.fillRect(0, 0, 512, 286);
			g.strokeStyle = "rgba(70,48,18,0.8)";
			g.lineWidth = 10;
			g.strokeRect(14, 14, 484, 258);
			g.fillStyle = "#120d08";
			g.font = "600 170px Georgia, serif";
			g.textAlign = "center";
			g.textBaseline = "middle";
			g.fillText(String(number), 256, 152);
			const tex = new THREE.CanvasTexture(c);
			tex.colorSpace = THREE.SRGBColorSpace;
			tex.anisotropy = 8;
			this.plates.set(number, new THREE.MeshStandardMaterial({ map: tex, metalness: 0.85, roughness: 0.36 }));
		}
		const face = this.plates.get(number);
		const mesh = new THREE.Mesh(new THREE.BoxGeometry(0.34, 0.19, 0.006), [this.m.brass, this.m.brass, this.m.brass, this.m.brass, face, this.m.brass]);
		mesh.castShadow = true;
		mesh.receiveShadow = true;
		return mesh;
	}

	// A sconce on a wall, facing (nx, nz): the supplied wall lamp and its light
	// (#ffe3a8, the game's 2600 K). The shade and bulb glow unless dark.
	async sconce(x, y, z, nx, nz, { intensity = 2.2, dark = false, shadow = false, light: withLight = true, range = 7 } = {}) {
		const lamp = await P.wallLamp();
		lamp.position.set(x, y, z);
		lamp.rotation.y = Math.atan2(nx, nz);
		this.root.add(lamp);
		let light = null;
		if (!dark && withLight) {
			light = new THREE.PointLight(srgb(0xffe3a8), intensity, range, 2);
			light.position.set(x + nx * 0.16, y + 0.22, z + nz * 0.16);
			light.castShadow = shadow;
			if (shadow) {
				light.shadow.mapSize.set(1024, 1024);
				light.shadow.bias = -0.0015;
				light.shadow.normalBias = 0.02;
				light.shadow.camera.near = 0.05;
				light.shadow.camera.far = 30;
			}
			this.root.add(light);
			this.lights.push(light);
		}
		lamp.traverse((o) => {
			if (!o.isMesh) return;
			if (o.material.emissive && (o.material.name?.includes?.("Cloth") || o.material === o.material)) {
				// Per-lamp copies so a dark room or a blackout can switch it.
				o.material = o.material.clone();
				if (o.material.emissiveIntensity !== undefined && o.material.emissive.getHex() !== 0) {
					o.material.userData.lit = o.material.emissiveIntensity || 0.35;
					o.material.emissiveIntensity = dark ? 0 : o.material.userData.lit;
					this.emissive.push(o.material);
				}
			}
		});
		return { lamp, light };
	}

	// A painting on a wall (1.14 x 0.78 m canvas at 2.02 m) in a wooden frame.
	async painting(x, z, nx, nz, index = 0, { y = 2.02, portrait = false } = {}) {
		const id = PAINTINGS[index % PAINTINGS.length];
		const tex = await texture(`assets/paintings/${id}.jpg`, { srgb: true, repeat: false });
		const w = portrait ? 0.78 : 1.14;
		const h = portrait ? 1.14 : 0.78;
		const group = new THREE.Group();
		group.position.set(x + nx * 0.012, y, z + nz * 0.012);
		group.rotation.y = Math.atan2(nx, nz);
		const canvas = new THREE.Mesh(new THREE.PlaneGeometry(w, h), new THREE.MeshStandardMaterial({ map: tex, roughness: 0.55 }));
		canvas.position.z = 0.025;
		canvas.receiveShadow = true;
		group.add(canvas);
		const b = 0.07;
		for (const [fw, fh, fx, fy] of [[w + 2 * b, b, 0, h / 2 + b / 2], [w + 2 * b, b, 0, -h / 2 - b / 2], [b, h, -w / 2 - b / 2, 0], [b, h, w / 2 + b / 2, 0]]) {
			this.box(fw, fh, 0.04, this.m.trim, fx, fy, 0.02, { parent: group });
		}
		this.root.add(group);
		return group;
	}

	// The green way-out sign across a corridor, as the game draws it
	// (exit_panel.gdshader): a sheet of clear acrylic lit by diodes in its top
	// edge; the engraving (R the flat, G the cut rim) scatters the light out.
	// 0.837 x 0.4185 m, hung at 2.65 m from two rods, with its green spill.
	async exitSign(x, z, rotY, kind = "way_ahead", { y = 2.65, level = 1 } = {}) {
		const group = new THREE.Group();
		group.position.set(x, y, z);
		group.rotation.y = rotY;
		const eng = await texture(`assets/props/exit_sign/${kind}.png`, { repeat: false });
		const back = await texture(`assets/props/exit_sign/${kind === "way_ahead" ? "way_back" : kind}.png`, { repeat: false });
		const lin = (r, g, b) => new THREE.Color().setRGB(r, g, b, THREE.SRGBColorSpace);
		const glow = lin(0.07, 1.0, 0.33);
		const core = lin(0.62, 1.0, 0.8);
		const mat = new THREE.ShaderMaterial({
			transparent: true, depthWrite: false, side: THREE.DoubleSide,
			uniforms: { engraving: { value: eng }, engravingBack: { value: back }, glow: { value: new THREE.Vector3(glow.r, glow.g, glow.b) }, core: { value: new THREE.Vector3(core.r, core.g, core.b) }, energy: { value: 5.0 }, level: { value: level } },
			vertexShader: `varying vec2 vUv; varying vec3 vN; varying vec3 vV;
				void main() { vUv = uv; vec4 wp = modelMatrix * vec4(position, 1.0); vN = normalize(mat3(modelMatrix) * normal); vV = normalize(cameraPosition - wp.xyz); gl_Position = projectionMatrix * viewMatrix * wp; }`,
			fragmentShader: `uniform sampler2D engraving; uniform sampler2D engravingBack; uniform vec3 glow; uniform vec3 core; uniform float energy; uniform float level;
				varying vec2 vUv; varying vec3 vN; varying vec3 vV;
				void main() {
					vec2 uv = vUv;
					if (!gl_FrontFacing) uv.x = 1.0 - uv.x;
					vec4 cut = gl_FrontFacing ? texture2D(engraving, uv) : texture2D(engravingBack, uv);
					float depth = 1.0 - uv.y;
					float cones = 0.0; float lamps = 0.0;
					for (int i = 0; i < 5; i++) {
						float at = (float(i) + 0.5) / 5.0; float across = abs(uv.x - at);
						cones += exp(-across * across / (0.0006 + depth * depth * 0.07));
						lamps += exp(-across * across / 0.00004) * exp(-depth * 90.0);
					}
					cones *= exp(-depth * 2.6) / 5.0;
					float guided = mix(0.62, 1.0, exp(-depth * 1.1));
					float letters = (cut.r * 0.7 + cut.g * 2.1) * guided;
					vec2 border = min(uv, 1.0 - uv);
					float edge = smoothstep(0.02, 0.0, min(border.x, border.y)) * mix(0.5, 1.6, smoothstep(0.7, 1.0, depth));
					float lit = (letters + edge * 0.8 + cones * 0.22 + lamps * 3.0 + guided * 0.05) * level;
					vec3 colour = mix(glow, core, clamp(lit * 0.55, 0.0, 1.0));
					float grazing = pow(1.0 - abs(dot(normalize(vN), normalize(vV))), 3.0);
					gl_FragColor = vec4(colour * lit * energy + vec3(0.35, 0.45, 0.4) * grazing * 0.45 * level, clamp(0.09 + grazing * 0.45 + lit * 1.4, 0.0, 1.0));
				}`,
		});
		const w = 0.837;
		const h = 0.4185;
		const sheet = new THREE.Mesh(new THREE.PlaneGeometry(w, h), mat);
		group.add(sheet);
		// The diode housing along the top edge, and the two rods to the ceiling.
		this.box(w + 0.02, 0.035, 0.03, this.m.metal, 0, h / 2 + 0.0175, 0, { parent: group });
		const rod = 3.15 - y - h / 2 - 0.035;
		for (const s2 of [1, -1]) this.box(0.01, rod, 0.01, this.m.metal, s2 * 0.3, h / 2 + 0.035 + rod / 2, 0, { parent: group });
		const spill = new THREE.PointLight(lin(0.25, 1.0, 0.45), 0.9 * level, 5, 2);
		spill.position.set(0, -0.3, 0);
		group.add(spill);
		group.userData.sheet = mat;
		group.userData.spill = spill;
		this.root.add(group);
		return group;
	}

	// The ceiling dome fitting (brass ring and frosted cone) and its light.
	dome(x, z, { intensity = 6, dark = false, color = 0xffe8b9, height = this.ceiling } = {}) {
		const glass = new THREE.MeshStandardMaterial({ color: srgb(0xefe2c6), emissive: srgb(0xffd599), emissiveIntensity: dark ? 0 : 2.5, roughness: 0.6 });
		this.box(0.52, 0.06, 0.52, this.m.brass, x, height - 0.03, z);
		const cone = new THREE.Mesh(new THREE.CylinderGeometry(0.23, 0.12, 0.16, 24), glass);
		cone.position.set(x, height - 0.13, z);
		this.root.add(cone);
		this.emissive.push(glass);
		glass.userData.lit = 2.5;
		let light = null;
		if (!dark) {
			light = new THREE.PointLight(srgb(color), intensity, 0, 2);
			light.position.set(x, height - 0.45, z);
			this.root.add(light);
			this.lights.push(light);
		}
		return light;
	}

	// A fire door across a corridor of width w at z: two metal-faced leaves
	// with wired-glass windows; open (0..1) swings them flat against the walls.
	fireDoor(x, z, w, { open = 1, rotY = 0 } = {}) {
		const group = new THREE.Group();
		group.position.set(x, 0, z);
		group.rotation.y = rotY;
		const leafW = (w - 0.2) / 2;
		const paint = new THREE.MeshStandardMaterial({ color: srgb(0x5b3a2a), roughness: 0.5, metalness: 0.2 });
		const glass = new THREE.MeshStandardMaterial({ color: 0x223028, roughness: 0.08, metalness: 0.1, transparent: true, opacity: 0.35 });
		for (const s of [-1, 1]) {
			const pivot = new THREE.Group();
			pivot.position.set(s * (w / 2 - 0.1), 0, 0);
			pivot.rotation.y = -s * open * 1.52;
			const leaf = new THREE.Group();
			leaf.position.x = -s * leafW / 2;
			this.box(leafW, 2.55, 0.06, paint, 0, 1.275, 0, { parent: leaf });
			const win = new THREE.Mesh(new THREE.BoxGeometry(0.28, 0.5, 0.065), glass);
			win.position.set(0, 1.55, 0);
			leaf.add(win);
			this.box(0.3, 0.035, 0.08, this.m.brass, -s * (leafW / 2 - 0.2), 1.05, 0.05, { parent: leaf });
			pivot.add(leaf);
			group.add(pivot);
		}
		this.root.add(group);
		return group;
	}

	// The reception's red emergency beacon: a metal box and a red dome.
	beacon(x, z, { height = this.ceiling } = {}) {
		const red = new THREE.MeshStandardMaterial({ color: 0x551010, emissive: new THREE.Color().setRGB(1.0, 0.1, 0.06, THREE.SRGBColorSpace), emissiveIntensity: 0, roughness: 0.3 });
		this.box(0.36, 0.12, 0.2, this.m.metal, x, height - 0.12 + 0.06, z);
		const dome = new THREE.Mesh(new THREE.SphereGeometry(0.11, 24, 12, 0, Math.PI * 2, 0, Math.PI / 2), red);
		dome.rotation.x = Math.PI;
		dome.position.set(x, height - 0.12, z);
		this.root.add(dome);
		const light = new THREE.PointLight(new THREE.Color().setRGB(1.0, 0.1, 0.06, THREE.SRGBColorSpace), 0, 0, 2);
		light.position.set(x, height - 0.3, z);
		this.root.add(light);
		// The game's blink: 1.6 s period, on 0.8 s, a stutter while on.
		return {
			light, glass: red,
			set(t) {
				const phase = (t % 1.6) / 1.6;
				const on = phase < 0.5 ? 1 : 0;
				const stutter = 0.75 + 0.25 * Math.sin(t * 5.9 * Math.PI * 2);
				const level = (0.08 + 0.92 * on) * (on ? stutter : 1);
				light.intensity = 9 * level;
				red.emissiveIntensity = 0.4 + 3.6 * on;
			},
		};
	}
}
