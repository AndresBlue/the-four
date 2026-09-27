// The archivist's lines, spoken by Kokoro-82M (onnx-community/Kokoro-82M-v1.0-ONNX,
// Apache-2.0), locally. Writes one WAV per line (24 kHz mono) to
// evidence/trailer3d/voice/<voice>/<id>.wav; audio/mix.py puts them on tape.
//   node voice.mjs                 the chosen voice (timeline.json voice.name)
//   node voice.mjs bf_emma am_michael ...   candidates, for comparing
import { KokoroTTS } from "kokoro-js";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../..");
const timeline = JSON.parse(fs.readFileSync(path.join(here, "timeline.json"), "utf8"));
const voices = process.argv.slice(2).length ? process.argv.slice(2) : [timeline.voice.name];
const tts = await KokoroTTS.from_pretrained("onnx-community/Kokoro-82M-v1.0-ONNX", { dtype: "fp32", device: "cpu" });
for (const voice of voices) {
	const out = path.join(root, "evidence/trailer3d/voice", voice);
	fs.mkdirSync(out, { recursive: true });
	for (const line of timeline.voice.lines) {
		const audio = await tts.generate(line.say ?? line.text, { voice, speed: line.speed ?? timeline.voice.speed });
		await audio.save(path.join(out, `${line.id}.wav`));
		process.stdout.write(`${voice} ${line.id} ${(audio.audio.length / audio.sampling_rate).toFixed(2)} s\n`);
	}
}
