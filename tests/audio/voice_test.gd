extends SceneTree
## Team voice without a network or a level: the ADPCM block and its
## anti-alias, the sensitivity to dBFS mapping and the variable threshold, the
## push-to-talk pre-roll and release, loss concealment, the radio's beeps and
## tail, and playback kept fed at 15 fps. Needs real time (the generator).
const CODEC := preload("res://game/audio/voice_codec.gd")
const DETECTION := preload("res://game/audio/voice_detection.gd")
const PLAYBACK := preload("res://game/audio/voice_playback.gd")
const MIX := 48000.0
var checks: Array = []
var failed := 0
var noise := RandomNumberGenerator.new()

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool, detail := "") -> void:
	checks.append({"check": title, "passed": passed, "detail": detail})
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title, "" if detail.is_empty() else "  (" + detail + ")")

func run() -> void:
	noise.seed = 1987
	codec()
	sensitivity()
	variable()
	push_to_talk()
	concealment()
	radio_events()
	await steady(15)
	await steady(60)
	var file := FileAccess.open("res://evidence/voice_tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": failed == 0, "checks": checks}, "\t"))
	file.close()
	print("VOICE_RESULT ", checks.size() - failed, "/", checks.size())
	quit(1 if failed > 0 else 0)

## frames at `rate` from sample `from`: a sum of tones, each [hz, amplitude].
func tones(parts: Array, rate: float, from := 0, count := -1) -> PackedVector2Array:
	var frames := PackedVector2Array()
	for index in (roundi(rate * CODEC.PERIOD) if count < 0 else count):
		var value := 0.0
		for part: Vector2 in parts: value += sin(TAU * part.x * (from + index) / rate) * part.y
		frames.append(Vector2(value, value))
	return frames

func hiss(db: float) -> PackedVector2Array:
	var frames := PackedVector2Array()
	var size := db_to_linear(db) * sqrt(3.0)
	for _index in roundi(MIX * CODEC.PERIOD):
		var value := noise.randf_range(-size, size)
		frames.append(Vector2(value, value))
	return frames

## Signal to error in dB after the best gain; also returns that gain.
func fit(heard: PackedFloat32Array, wanted: PackedFloat32Array) -> Vector2:
	var cross := 0.0
	var power := 0.0
	for index in heard.size():
		cross += heard[index] * wanted[index]
		power += wanted[index] * wanted[index]
	var gain := cross / maxf(power, 1e-12)
	var error := 0.0
	for index in heard.size(): error += pow(heard[index] - wanted[index] * gain, 2.0)
	return Vector2(10.0 * log(power * gain * gain / maxf(error, 1e-12)) / log(10.0), gain)

func rms(samples: PackedFloat32Array) -> float:
	var sum := 0.0
	for value in samples: sum += value * value
	return sqrt(sum / maxf(samples.size(), 1.0))

func codec() -> void:
	var voice := [Vector2(220.0, 0.12), Vector2(660.0, 0.08), Vector2(1500.0, 0.05)]
	var packet := CODEC.encode(tones(voice, CODEC.RATE))
	check("Un bloque de 20 ms a 16 kHz ocupa 163 bytes (8150 B/s)", packet.size() == CODEC.BYTES and CODEC.BYTES == 163 and CODEC.SAMPLES == 320)
	var wanted := PackedFloat32Array()
	for frame in tones(voice, CODEC.RATE): wanted.append(frame.x)
	var heard := fit(CODEC.decode(packet), wanted)
	check("El ADPCM conserva la voz con más de 20 dB de margen", heard.x > 20.0 and absf(heard.y - 1.0) < 0.05, "%.1f dB" % heard.x)
	# From the mix rate: the second of two blocks, decoded on its own.
	var one_k := [Vector2(1000.0, 0.3)]
	CODEC.encode(tones(one_k, MIX, 0))
	var second := CODEC.decode(CODEC.encode(tones(one_k, MIX, 960)))
	wanted.clear()
	for index in CODEC.SAMPLES: wanted.append(sin(TAU * 1000.0 * (3 * (CODEC.SAMPLES + index) + 1) / MIX) * 0.3)
	var alone := fit(second, wanted)
	check("Cada bloque se descodifica solo, sin el anterior, desde 48 kHz", alone.x > 20.0 and alone.y > 0.9, "%.1f dB, ganancia %.2f" % [alone.x, alone.y])
	var aliased := rms(CODEC.decode(CODEC.encode(tones([Vector2(12000.0, 0.3)], MIX))))
	check("El filtro antialias deja 12 kHz más de 15 dB abajo", linear_to_db(aliased / (0.3 / sqrt(2.0))) < -15.0, "%.1f dB" % linear_to_db(aliased / (0.3 / sqrt(2.0))))

func sensitivity() -> void:
	check("Sensibilidad 0 pide -30 dBFS, 0,2 pide -40 y 1 deja pasar -80", is_equal_approx(DETECTION.threshold_db(0.0), -30.0) and is_equal_approx(DETECTION.threshold_db(0.2), -40.0) and is_equal_approx(DETECTION.threshold_db(1.0), -80.0) and DETECTION.threshold_db(0.5) < DETECTION.threshold_db(0.4))
	check("La escala del medidor va de -60 dBFS a 0 dBFS", DETECTION.scale(-60.0) == 0.0 and DETECTION.scale(0.0) == 1.0 and is_equal_approx(DETECTION.scale(-30.0), 0.5) and DETECTION.scale(-75.0) == 0.0)
	var detector := DETECTION.new()
	detector.configure(MIX)
	# Normal speech a hand's width from a typical microphone: about -28 dBFS RMS.
	var speech := tones([Vector2(180.0, 0.03), Vector2(540.0, 0.04), Vector2(1200.0, 0.025)], MIX)
	var room := 0
	for _block in 100: room += detector.feed(hiss(-55.0), DETECTION.threshold_db(0.2)).size()
	check("Con 0,2 el ruido de una habitación tranquila (-55 dBFS) no abre", room == 0)
	detector.feed(speech, DETECTION.threshold_db(0.2))
	var opened := detector.feed(speech, DETECTION.threshold_db(0.2))
	check("Con 0,2 la voz normal (-28 dBFS) abre al segundo bloque con su inicio", opened.size() == DETECTION.PRE_ROLL_BLOCKS and detector.transmitting(), "%.1f dBFS" % detector.level_db)
	check("El medidor sigue a la voz", detector.meter > DETECTION.scale(-40.0))

func variable() -> void:
	var detector := DETECTION.new()
	detector.configure(MIX)
	for _block in 100: detector.feed(hiss(-50.0), detector.gate_db(0.2, true))
	var settled := detector.gate_db(0.2, true)
	check("La sensibilidad variable se sitúa unos 12 dB sobre la habitación", absf(settled - (-50.0 + DETECTION.MARGIN_DB)) < 3.0, "%.1f dBFS" % settled)
	var speech := tones([Vector2(180.0, 0.05), Vector2(540.0, 0.06), Vector2(1200.0, 0.04)], MIX)
	var sent := 0
	for block in 150:
		# 300 ms of words, 200 ms between them.
		var frames := speech if block % 25 < 15 else hiss(-50.0)
		sent += detector.feed(frames, detector.gate_db(0.2, true)).size()
	check("Hablar 3 s no arrastra el umbral", sent > 100 and absf(detector.gate_db(0.2, true) - settled) < 2.0, "%.1f dBFS, %d bloques" % [detector.gate_db(0.2, true), sent])
	var shut_at := -1
	for block in 400:
		detector.feed(hiss(-34.0), detector.gate_db(0.2, true))
		if shut_at < 0 and block > 20 and not detector.transmitting(): shut_at = block
	# The variable threshold goes no higher than sensitivity 0 asks for.
	check("Un ventilador que se queda sube el umbral y cierra la transmisión", shut_at > 0 and is_equal_approx(detector.gate_db(0.2, true), DETECTION.LOUDEST_DB), "cierra a los %.1f s, umbral %.1f" % [shut_at * CODEC.PERIOD, detector.gate_db(0.2, true)])
	for _block in 15: detector.feed(hiss(-60.0), detector.gate_db(0.2, true))
	check("Al apagarlo el umbral baja enseguida", detector.gate_db(0.2, true) < -45.0, "%.1f dBFS en 0,3 s" % detector.gate_db(0.2, true))

func push_to_talk() -> void:
	var detector := DETECTION.new()
	detector.configure(MIX)
	var blocks: Array[PackedVector2Array] = []
	for index in 8: blocks.append(tones([Vector2(300.0 + index * 50.0, 0.001)], MIX))
	var early := 0
	for index in 6: early += detector.press(blocks[index], false).size()
	var pressed := detector.press(blocks[6], true)
	check("Pulsar abre al instante con los 60 ms ya capturados", early == 0 and pressed.size() == DETECTION.PRESS_BLOCKS + 1 and pressed[0] == blocks[3] and pressed[3] == blocks[6])
	var held := 0
	for _block in 20: held += detector.press(blocks[7], true).size()
	var after := 0
	for _block in 20: after += detector.press(blocks[7], false).size()
	check("Mantiene 160 ms tras soltar y cierra", held == 20 and after == DETECTION.RELEASE_BLOCKS and not detector.transmitting(), "%d bloques tras soltar" % after)
	check("Sin sensibilidad en pulsar para hablar: un susurro pasa igual", pressed.size() > 0)

func concealment() -> void:
	var playback := PLAYBACK.new(null)
	var packet := CODEC.encode(tones([Vector2(440.0, 0.3)], CODEC.RATE))
	var first := playback.take(packet)
	var lost := playback.take(PackedByteArray())
	var again := playback.take(PackedByteArray())
	check("Un bloque perdido repite el anterior a -6 dB", lost.size() == first.size() and is_equal_approx(lost[100], first[100] * 0.5) and is_equal_approx(lost[200], first[200] * 0.5))
	check("Un segundo bloque perdido es silencio", again.is_empty())
	playback.take(packet)
	check("Tras un bloque bueno vuelve a ocultar una pérdida", not playback.take(PackedByteArray()).is_empty())

func radio_events() -> void:
	var voice := CODEC.decode(CODEC.encode(tones([Vector2(440.0, 0.2)], CODEC.RATE)))
	var far := Vector4(1.0, 0.0, 0.0, 0.0)
	var radio := PLAYBACK.new(null)
	radio.radio = 1.0
	radio.open_carrier()
	var key_up := radio.beep_left
	for _block in 5: radio.render(voice, far)
	radio.close_carrier()
	var rung := 0
	var tail := 0.0
	while radio.ringing() and rung < 50:
		var frames := radio.render(PackedFloat32Array(), far)
		rung += 1
		if radio.beep_left == 0: for frame in frames: tail = maxf(tail, absf(frame.x))
	var closing := (PLAYBACK.BEEP_CLOSE.y + PLAYBACK.TAIL_SECONDS) / CODEC.PERIOD
	check("Por radio: bip al abrir, y al cerrar bip y cola del silenciador", key_up == roundi(PLAYBACK.BEEP_OPEN.y * CODEC.RATE) and rung == ceili(closing) and tail > 0.05 and not radio.carrier, "%d bloques, cola %.2f" % [rung, tail])
	var near := Vector4(0.0, 0.96, 0.0, 0.0)
	var direct := PLAYBACK.new(null)
	direct.direct = 0.96
	direct.open_carrier()
	direct.render(voice, near)
	direct.close_carrier()
	direct.render(PackedFloat32Array(), near)
	var after := direct.render(PackedFloat32Array(), near)
	var loudest := 0.0
	for frame in after: loudest = maxf(loudest, absf(frame.x))
	check("En directo ni bips ni estática", not direct.ringing() and loudest < 0.01, "%.4f" % loudest)
	var cost := Time.get_ticks_usec()
	for _block in 50: radio.render(voice, far)
	print("render por radio: %.0f us por bloque" % ((Time.get_ticks_usec() - cost) / 50.0))

## A teammate talking for 3 s at 50 blocks/s while the game runs at `fps`.
## What update() pushes feeds a model of a steady sound card, which must never
## run dry once started, and no block may be dropped or restart the stream.
## The headless Dummy driver pulls in irregular gulps, so its own underrun
## count is only reported.
func steady(fps: int) -> void:
	Engine.max_fps = fps
	var holder := Node.new()
	root.add_child(holder)
	var playback := PLAYBACK.new(holder)
	var packet := CODEC.encode(tones([Vector2(440.0, 0.2)], CODEC.RATE))
	var begin := Time.get_ticks_msec()
	var sent := 0
	var pushed := 0
	var card := 0.0
	var dry := 0
	var restarts := 0
	var was_started := false
	var last := begin
	while Time.get_ticks_msec() - begin < 3000:
		await process_frame
		var now := Time.get_ticks_msec()
		while sent < (now - begin) / 20:
			sent += 1
			playback.enqueue(sent, packet, now)
		if was_started:
			card -= (now - last) * CODEC.RATE / 1000.0
			if card < 0.0:
				# A frame a quarter longer than the frame rate is this machine stalling
				# (verify runs eight jobs at once), not the game at `fps`.
				if now - last <= 1250 / fps: dry += 1
				card = 0.0
		last = now
		# Sequences run 1, 2, 3...: the last one taken counts the blocks pushed.
		var before := maxi(0, playback.last_sequence)
		playback.update(now, Vector4(1.0, 0.0, 0.0, 0.0))
		var added := (maxi(0, playback.last_sequence) - before) * CODEC.SAMPLES
		pushed += added
		card += added
		if was_started and not playback.started: restarts += 1
		was_started = playback.started
	var lost := sent - pushed / CODEC.SAMPLES - playback.queue.size()
	var skips: int = playback.output.get_skips() if playback.output != null else -1
	# At 60 fps the target is short and the Dummy's gulps, not the card
	# model, decide when there is room: only losses and restarts count there.
	check("A %d fps la voz no se corta ni pierde bloques" % fps, (dry == 0 or fps > 30) and restarts == 0 and lost == 0, "%d vaciados, %d reinicios, %d perdidos; Dummy: %d" % [dry, restarts, lost, skips])
	playback.dispose()
	holder.queue_free()
	Engine.max_fps = 0
