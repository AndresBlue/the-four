extends SceneTree
## Loudness of the opening scene through the real mixer (sliders at 50%):
## peak and RMS on the Master bus per stretch of the timeline. Real time.
const WINDOWS := [[1.0, 6.0, "waking, static"], [8.0, 12.8, "sitting up on the bed"], [12.9, 18.0, "leaning in, staring at the static"], [21.0, 25.0, "figure peeks, drone, heartbeat"], [26.3, 30.4, "knocks on the glass"], [31.1, 34.0, "running out, door"], [34.0, 34.9, "slam and shatter behind"], [35.0, 38.0, "corridor: bangs, steps"]]
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
		while intro.time < window[1]:
			await process_frame
			for frame in capture.get_buffer(capture.get_frames_available()):
				peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
				sum += frame.length_squared() * 0.5
				count += 1
		print("%-34s peak %6.1f  RMS %6.1f dBFS" % [window[2], linear_to_db(maxf(peak, 1e-6)), linear_to_db(maxf(sqrt(sum / maxi(count, 1)), 1e-6))])
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	level.queue_free()
	await process_frame
	quit()
