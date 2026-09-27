// A static file server for the trailer page: the page itself (web/), three.js
// (node_modules/three), the timeline and the game's assets straight from the
// repository, so nothing is copied. POST /save?path=<rel> writes the body under
// evidence/trailer3d/ (the rendered frames). Used by render.mjs.
import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../..");
export const OUT = path.join(root, "evidence/trailer3d");
const MOUNTS = [
	["/three/", path.join(here, "node_modules/three/")],
	["/repo/", root + path.sep],
	["/out/", OUT + path.sep],
	["/cfg/", here + path.sep],
	["/", path.join(here, "web") + path.sep],
];
const TYPES = { ".html": "text/html", ".js": "text/javascript", ".mjs": "text/javascript", ".json": "application/json", ".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".glb": "model/gltf-binary", ".gltf": "model/gltf+json", ".bin": "application/octet-stream", ".fbx": "application/octet-stream", ".obj": "text/plain", ".mtl": "text/plain", ".wav": "audio/wav", ".ttf": "font/ttf" };

function save(req, res, url) {
	const rel = url.searchParams.get("path") ?? "";
	const file = path.normalize(path.join(OUT, rel));
	if (!file.startsWith(OUT)) { res.writeHead(403); res.end(); return; }
	const chunks = [];
	req.on("data", (c) => chunks.push(c));
	req.on("end", () => {
		fs.mkdirSync(path.dirname(file), { recursive: true });
		fs.writeFile(file, Buffer.concat(chunks), (err) => {
			res.writeHead(err ? 500 : 200);
			res.end(err ? String(err) : "ok");
		});
	});
}

export function serve(port = 8081) {
	const server = http.createServer((req, res) => {
		const url = new URL(req.url, "http://x");
		if (req.method === "POST" && url.pathname === "/save") return save(req, res, url);
		const pathname = decodeURIComponent(url.pathname);
		for (const [prefix, dir] of MOUNTS) {
			if (!pathname.startsWith(prefix)) continue;
			const file = path.normalize(path.join(dir, pathname.slice(prefix.length)));
			if (!file.startsWith(dir)) break;
			fs.readFile(file, (err, data) => {
				if (err) { res.writeHead(404); res.end(); return; }
				res.writeHead(200, { "Content-Type": TYPES[path.extname(file).toLowerCase()] ?? "application/octet-stream", "Cache-Control": "no-store" });
				res.end(data);
			});
			return;
		}
		res.writeHead(404);
		res.end();
	});
	return new Promise((resolve) => server.listen(port, "127.0.0.1", () => resolve(server)));
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
	await serve(8081);
	console.log("http://127.0.0.1:8081/");
}
