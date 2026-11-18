extends SceneTree
## Plays a real recording through the team voice chain as the game does: the
## automatic gate at the default sensitivity, the ADPCM codec and the receiving
## mixer's render, for four routes. Writes evidence/voz/voz_<ruta>.wav and the
## input as the microphone delivered it, plus the cost of each step.
##   godot --headless --path . --script res://tools/audio/voice_radio_demo.gd -- --test-profile [--input=<mp3>]
const CODEC := preload("res://game/audio/voice_codec.gd")
const DETECTION := preload("res://game/audio/voice_detection.gd")
const PLAYBACK := preload("res://game/audio/voice_playback.gd")
const VOICE := preload("res://game/net/voice_session.gd")
const INPUT := "res://evidence/voz/descargas/librivox_eagle/spc105_eagle_tennyson_lkp_64kb.mp3"
const SECONDS := 22.0

func _initialize() -> void:
	var source := INPUT
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--input="): source = argument.trim_prefix("--input=")
	var rate := AudioServer.get_mix_rate()
	var mic := decode_mp3(ProjectSettings.globalize_path(source), rate)
	print("input %d frames at %d Hz (%.1f s)" % [mic.size(), rate, mic.size() / rate])
	save(mic, rate, "res://evidence/voz/voz_entrada.wav")
	# What leaves the machine: gated blocks, timed by the block they left on.
	var block := roundi(rate * CODEC.PERIOD)
	var detector := DETECTION.new()
	detector.configure(rate)
	var threshold := DETECTION.threshold_db(0.2)
	var sent := {}
	var cost := Vector3.ZERO
	var ticks := mic.size() / block
	for tick in ticks:
		var started := Time.get_ticks_usec()
		var heard := detector.feed(mic.slice(tick * block, (tick + 1) * block), threshold)
		cost.x += Time.get_ticks_usec() - started
		# The pre-roll goes out on the tick it is released, as the game sends it.
		var at := tick - heard.size() + 1
		for frames in heard:
			started = Time.get_ticks_usec()
			sent[at] = CODEC.encode(frames)
			cost.y += Time.get_ticks_usec() - started
			at += 1
	print("gate: %d of %d blocks sent, %d bytes each, %d B/s while talking" % [sent.size(), ticks, CODEC.BYTES, CODEC.BYTES * 50])
	var routes := {
		"directa": VOICE.acoustic_route(1.5, -0.3, false, false),
		"medio": VOICE.acoustic_route(7.6, 0.2, false, false),
		"radio": VOICE.acoustic_route(15.0, 0.0, false, false),
		"radio_pared": VOICE.acoustic_route(6.0, 0.3, false, true),
	}
	for title: String in routes:
		var route: Vector4 = routes[title]
		var timing := receive(sent, ticks, route, "res://evidence/voz/voz_%s.wav" % title)
		print("%s route=%s render %.0f us/block, decode %.0f us/block" % [title, route, timing.x, timing.y])
	print("gate %.0f us/block, encode %.0f us/block" % [cost.x / ticks, cost.y / maxi(1, sent.size())])
	frequency_response()
	quit(0)

## The receiver's side of voice_playback.update, without a sound card: a block
## a tick, the carrier opened by the first block and closed HOLD_MS after the
## last, then the beep and the squelch tail rung out.
func receive(sent: Dictionary, ticks: int, route: Vector4, path: String) -> Vector2:
	var playback := PLAYBACK.new(null)
	playback.radio = route.x
	playback.direct = route.y
	playback.pan = route.z
	playback.obstruction = route.w
	var out := PackedVector2Array()
	var quiet := 0
	var open := false
	var cost := Vector2.ZERO
	for tick in ticks + 20:
		var voice := PackedFloat32Array()
		if sent.has(tick):
			var started := Time.get_ticks_usec()
			voice = CODEC.decode(sent[tick])
			cost.y += Time.get_ticks_usec() - started
			quiet = 0
			if not open: playback.open_carrier()
			open = true
		elif open:
			quiet += 1
			if quiet * CODEC.PERIOD * 1000.0 >= (PLAYBACK.OVER_MS if route.x > PLAYBACK.RADIO_EVENTS else PLAYBACK.HOLD_MS):
				playback.close_carrier()
				open = false
		var begun := Time.get_ticks_usec()
		out.append_array(playback.render(voice, route))
		cost.x += Time.get_ticks_usec() - begun
	save(out, CODEC.RATE, path)
	return Vector2(cost.x / (ticks + 20), cost.y / maxi(1, sent.size()))

## Quiet white noise straight into the radio path, carrier shut: the AGC sits
## at its ceiling and the limiter is linear, so this is the filters' response.
func frequency_response() -> void:
	var playback := PLAYBACK.new(null)
	playback.radio = 1.0
	var noise := RandomNumberGenerator.new()
	noise.seed = 7
	var out := PackedVector2Array()
	for _block in 150:
		var voice := PackedFloat32Array()
		for _sample in CODEC.SAMPLES: voice.append(noise.randf_range(-0.01, 0.01))
		out.append_array(playback.render(voice, Vector4(1.0, 0.0, 0.0, 0.0)))
	save(out, CODEC.RATE, "res://evidence/voz/respuesta_radio.wav")

## AudioStreamPlayback.mix_audio decodes the MP3 at the mix rate: the same
## rate AudioEffectCapture hands the game.
func decode_mp3(path: String, rate: float) -> PackedVector2Array:
	var stream := AudioStreamMP3.load_from_file(path)
	var playback := stream.instantiate_playback()
	playback.start(0.0)
	var frames := PackedVector2Array()
	var wanted := roundi(minf(stream.get_length(), SECONDS) * rate)
	while frames.size() < wanted:
		frames.append_array(playback.mix_audio(1.0, mini(4096, wanted - frames.size())))
	return frames

func save(frames: PackedVector2Array, rate: float, path: String) -> void:
	var data := PackedByteArray()
	data.resize(frames.size() * 4)
	for index in frames.size():
		data.encode_s16(index * 4, clampi(roundi(frames[index].x * 32767.0), -32768, 32767))
		data.encode_s16(index * 4 + 2, clampi(roundi(frames[index].y * 32767.0), -32768, 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = true
	wav.mix_rate = roundi(rate)
	wav.data = data
	wav.save_to_wav(ProjectSettings.globalize_path(path))
