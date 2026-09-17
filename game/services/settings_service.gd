extends Node
signal changed
signal display_pending(seconds: int)
const DEFAULTS := {"character": 0, "fullscreen": true, "resolution": 0, "scale": 1.0, "quality": 1, "shadows": true, "fps": 60, "vsync": true, "vhs": 0.45, "grain": 0.35, "chromatic": 0.3, "scanlines": 0.35, "osd": true, "bob": 0.1, "reduced": false, "sensitivity": 0.0022, "invert": false, "master": 0.5, "ambience": 0.5, "music": 0.5, "effects": 0.5, "threat": 0.5, "subtitles": false, "player_name": "", "join_address": "127.0.0.1"}
const KEYS := {"forward": KEY_W, "backward": KEY_S, "left": KEY_A, "right": KEY_D, "sprint": KEY_SHIFT, "jump": KEY_SPACE, "interact": KEY_E, "flashlight": KEY_F, "crouch": KEY_CTRL}
const AUDIO_KEYS := ["master", "ambience", "music", "effects", "threat"]
## Saved-settings revision of the volume curve. Older files kept sliders tuned
## for a quieter curve, so their volumes are reset once.
const AUDIO_CURVE := 2
## Saved-settings revision of the display defaults. Older files predate
## starting in fullscreen, so their window choice is reset once.
const DISPLAY_REVISION := 2
## Saved-settings revision of the subtitle default (now off); reset once.
const SUBTITLE_REVISION := 1
const DISPLAY_KEYS := ["fullscreen", "resolution"]
## Room left around a window for the title bar and taskbar.
const WINDOW_MARGIN := Vector2i(48, 96)
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
var values := DEFAULTS.duplicate()
var bindings := KEYS.duplicate()
var save_path := "user://hotel_settings.json"
var previous_display := {}
var countdown := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply()
	apply_display()

func load_settings() -> void:
	if not FileAccess.file_exists(save_path): return
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary: return
	var stored = data.get("values", {})
	var current_curve: bool = data.get("audio_curve", 0) == AUDIO_CURVE
	var current_display: bool = data.get("display_rev", 0) == DISPLAY_REVISION
	var current_subtitles: bool = data.get("subtitle_rev", 0) == SUBTITLE_REVISION
	if stored is Dictionary:
		for key in DEFAULTS:
			if key in AUDIO_KEYS and not current_curve: continue
			if key in DISPLAY_KEYS and not current_display: continue
			if key == "subtitles" and not current_subtitles: continue
			if stored.has(key): values[key] = sanitize(key, stored[key])
	var keys = data.get("bindings", {})
	if keys is Dictionary:
		var used := {}
		for action in KEYS:
			var code: int = int(keys.get(action, KEYS[action])) if keys.get(action, KEYS[action]) is float or keys.get(action, KEYS[action]) is int else KEYS[action]
			if code <= 0 or code in [KEY_ESCAPE, KEY_F9, KEY_F11] or used.has(code):
				bindings = KEYS.duplicate()
				break
			used[code] = true
			bindings[action] = code

func sanitize(key: String, value: Variant) -> Variant:
	if DEFAULTS[key] is bool: return value if value is bool else DEFAULTS[key]
	if DEFAULTS[key] is String: return str(value).strip_edges().left(40) if value is String else DEFAULTS[key]
	if not (value is float or value is int) or not is_finite(float(value)): return DEFAULTS[key]
	match key:
		"resolution": return clampi(int(value), 0, 3)
		"character": return clampi(int(value), 0, 2)
		"quality": return clampi(int(value), 0, 2)
		"fps": return int(value) if int(value) in [0, 30, 60, 120, 144] else 60
		"sensitivity": return clampf(value, 0.0005, 0.008)
		"scale": return clampf(value, 0.5, 1.0)
	return clampf(value, 0, 1)

func set_value(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key): return
	if key in ["resolution", "fullscreen"] and previous_display.is_empty():
		previous_display = {"resolution": values.resolution, "fullscreen": values.fullscreen}
	values[key] = sanitize(key, value)
	if key in DISPLAY_KEYS:
		countdown = 12.0
		display_pending.emit(12)
		apply_display()
	apply()
	if previous_display.is_empty(): save_settings()

func confirm_display() -> void:
	previous_display.clear()
	countdown = 0
	save_settings()
	display_pending.emit(0)

func revert_display() -> void:
	for key in previous_display: values[key] = previous_display[key]
	previous_display.clear()
	countdown = 0
	apply_display()
	apply()
	save_settings()
	display_pending.emit(0)

func bind(action: String, code: int) -> bool:
	if not KEYS.has(action) or code <= 0 or code in [KEY_ESCAPE, KEY_F9, KEY_F11]: return false
	for other in bindings:
		if other != action and bindings[other] == code: return false
	bindings[action] = code
	apply_bindings()
	save_settings()
	changed.emit()
	return true

func reset_controls() -> void:
	bindings = KEYS.duplicate()
	values.sensitivity = DEFAULTS.sensitivity
	values.invert = false
	apply()
	save_settings()

func key_name(action: String) -> String:
	return OS.get_keycode_string(bindings[action])

func apply_bindings() -> void:
	for action in bindings:
		if not InputMap.has_action(action): InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var key := InputEventKey.new()
		key.physical_keycode = bindings[action]
		InputMap.action_add_event(action, key)

func apply() -> void:
	apply_bindings()
	Engine.max_fps = values.fps
	# Window mode and size are only touched by display settings (apply_display),
	# so changing quality or shadows never resizes a maximised window.
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values.vsync else DisplayServer.VSYNC_DISABLED)
	get_viewport().scaling_3d_scale = values.scale
	# The player's own footsteps have their own drier bus, under the effects slider.
	for pair in [["Master", "master"], ["Ambience", "ambience"], ["Music", "music"], ["Effects", "effects"], ["Threat", "threat"], ["Steps", "effects"]]:
		var index := AudioServer.get_bus_index(pair[0])
		if index < 0:
			AudioServer.add_bus()
			index = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, pair[0])
		var volume: float = values[pair[1]]
		AudioServer.set_bus_volume_db(index, slider_db(volume))
		AudioServer.set_bus_mute(index, volume == 0.0)
	changed.emit()

## Tests and capture tools size their own window and must not go fullscreen.
static func manages_window() -> bool:
	var args := OS.get_cmdline_user_args()
	return DisplayServer.get_name() != "headless" and not args.has("--automation") and not args.has("--test-profile")

## Fullscreen on the current screen, or a window of the chosen size that
## fits the usable area (never under the taskbar) and is centred on it.
func apply_display() -> void:
	if DisplayServer.get_name() == "headless": return
	if not manages_window():
		if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		return
	if values.fullscreen:
		if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	place_window()
	# Leaving fullscreen can restore the old rectangle a frame later; place again.
	place_window.call_deferred()

func window_size_for(screen: int) -> Vector2i:
	var usable := DisplayServer.screen_get_usable_rect(screen).size - WINDOW_MARGIN
	var wanted: Vector2i = RESOLUTIONS[values.resolution]
	# Shrink keeping 16:9 when the chosen size does not fit this screen.
	var fit := minf(1.0, minf(float(usable.x) / wanted.x, float(usable.y) / wanted.y))
	return Vector2i(int(wanted.x * fit), int(wanted.y * fit))

func place_window() -> void:
	if values.fullscreen or DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED: return
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var size := window_size_for(screen)
	DisplayServer.window_set_size(size)
	# Centre the whole window, title bar included. The position set is the
	# client area's, so shift by the decoration offset.
	var decorated := DisplayServer.window_get_size_with_decorations()
	var border := DisplayServer.window_get_position() - DisplayServer.window_get_position_with_decorations()
	DisplayServer.window_set_position(usable.position + (usable.size - decorated) / 2 + border)

## Volume slider curve: 50% is the reference mix (0 dB), 100% adds +6 dB for
## extreme immersion (the Master limiter prevents clipping), 25% is -6 dB.
static func slider_db(volume: float) -> float:
	return linear_to_db(maxf(volume * 2.0, 0.0002))

func save_settings() -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"values": values, "bindings": bindings, "audio_curve": AUDIO_CURVE, "display_rev": DISPLAY_REVISION, "subtitle_rev": SUBTITLE_REVISION}))

func _process(delta: float) -> void:
	if countdown > 0:
		var before := int(ceil(countdown))
		countdown -= delta
		if countdown <= 0: revert_display()
		elif int(ceil(countdown)) != before: display_pending.emit(int(ceil(countdown)))
