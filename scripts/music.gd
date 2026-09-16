extends AudioStreamPlayer

const MIN_VOLUME := -40.0
const MAX_VOLUME := -6.0
var target_volume := -22.0
var muted := false
var fade: Tween

func _ready() -> void:
	stream = stream.duplicate()
	stream.loop = true
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")
	bus = "Music"
	volume_db = -50.0
	if not OS.get_cmdline_user_args().has("--silent") and DisplayServer.get_name() != "headless":
		play()
		fade = create_tween()
		fade.tween_property(self, "volume_db", target_volume, 2.0)

func set_music_muted(value: bool) -> void:
	muted = value
	AudioServer.set_bus_mute(AudioServer.get_bus_index(bus), muted)

func adjust_volume(amount: float) -> void:
	if is_instance_valid(fade):
		fade.kill()
	target_volume = clampf(target_volume + amount, MIN_VOLUME, MAX_VOLUME)
	volume_db = target_volume

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		stream_paused = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		stream_paused = false
