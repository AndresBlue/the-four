extends SceneTree
## Loudness of the opening scene through the real mixer (sliders at 50%):
## peak, RMS and the RMS of the loudest tenth of a second on the Master bus
## per stretch of the timeline (the last says how loud a blow is better than
## the RMS of a stretch that is mostly the room). Real time.
const WINDOWS := [[1.0, 6.0, "waking, static"], [8.0, 12.8, "sitting up on the bed"], [12.9, 18.0, "leaning in, staring at the static"], [21.0, 25.0, "figure peeks, drone, heartbeat"], [26.25, 26.8, "first blow on the glass"], [27.85, 28.4, "second blow"], [29.35, 29.85, "third blow, the glass cracks"], [31.1, 32.8, "up and to the door"], [32.8, 33.5, "the glass breaks behind"], [33.5, 34.9, "the door slammed"], [35.0, 38.0, "corridor: bangs, steps"]]
var level
var capture: AudioEffectCapture

func _initialize() -> void: run.call_deferred()

func run() -> void:
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await process_frame
	level.world_audio.enabled = true
	capture = AudioEffectCapture.new()
	capture.buffer_length = 6.0
	AudioServer.add_bus_effect(0, capture)
	level.start_intro(81)
	var intro = level.intro
	for window in WINDOWS:
		while intro.time < window[0]: await process_frame
		capture.clear_buffer()
		var peak := 0.0
		var sum := 0.0
		var count := 0
		# The loudest tenth of a second, sliding by hundredths.
		var hundredth := int(AudioServer.get_mix_rate() * 0.01)
		var block := 0.0
		var in_block := 0
		var last_ten: Array[float] = []
		var loudest := 0.0
		while intro.time < window[1]:
			await process_frame
			for frame in capture.get_buffer(capture.get_frames_available()):
				peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
				sum += frame.length_squared() * 0.5
				count += 1
				block += frame.length_squared() * 0.5
				in_block += 1
				if in_block == hundredth:
					last_ten.append(block / hundredth)
					if last_ten.size() > 10: last_ten.pop_front()
					if last_ten.size() == 10: loudest = maxf(loudest, last_ten.reduce(func(a, b): return a + b, 0.0) / 10.0)
					block = 0.0
					in_block = 0
		print("%-34s peak %6.1f  RMS %6.1f  loudest 0.1 s %6.1f dBFS" % [window[2], linear_to_db(maxf(peak, 1e-6)), linear_to_db(maxf(sqrt(sum / maxi(count, 1)), 1e-6)), linear_to_db(maxf(sqrt(loudest), 1e-6))])
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	level.queue_free()
	await process_frame
	quit()
