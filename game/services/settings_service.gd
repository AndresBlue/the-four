extends Node
const PRESETS := preload("res://game/presentation/graphics_presets.gd")
signal changed
signal display_pending(seconds: int)
const DEFAULTS := {"character": 0, "pad_look": 2.6, "rumble": true, "window_mode": 0, "resolution": 0, "scale": 1.0, "upscaler": "auto", "sharpness": 0.9, "aa": "preset", "ao": -1, "fog": -1, "reflections": -1, "blur": -1, "quality": 1, "shadows": true, "fps": 60, "vsync": true, "vhs": 0.45, "grain": 0.35, "chromatic": 0.3, "scanlines": 0.35, "osd": true, "bob": 0.1, "reduced": false, "sensitivity": 0.0022, "invert": false, "master": 0.5, "ambience": 0.5, "music": 0.5, "effects": 0.5, "threat": 0.5, "subtitles": false, "player_name": "", "join_address": "127.0.0.1", "renderer": "forward_plus"}
const KEYS := {"forward": KEY_W, "backward": KEY_S, "left": KEY_A, "right": KEY_D, "sprint": KEY_SHIFT, "jump": KEY_SPACE, "interact": KEY_E, "flashlight": KEY_F, "crouch": KEY_CTRL, "sheet": KEY_TAB}
## The same actions on a pad. Moving and looking are the two sticks and are not
## rebound: what is bound is what a button does. The layout is the one every
## other game uses, so a hand that has played anything else already knows it:
## the bottom button acts, the right one crouches, the left one lights the
## torch, the top one jumps, the shoulders run and open the sheet.
const PAD_KEYS := {"interact": JOY_BUTTON_A, "crouch": JOY_BUTTON_B, "flashlight": JOY_BUTTON_X, "jump": JOY_BUTTON_Y, "sprint": JOY_BUTTON_LEFT_SHOULDER, "sheet": JOY_BUTTON_RIGHT_SHOULDER}
## Buttons the game keeps for itself, so nothing can be bound over them: the
## menu button pauses, and B is how a menu is left.
const PAD_RESERVED := [JOY_BUTTON_START, JOY_BUTTON_BACK]
## The menus' own actions and the pad buttons they answer to. Godot builds
## these actions itself, and in this project ui_accept came without any pad
## button: the cross moved the highlight and nothing could be chosen. Added
## only if the action does not have that button already, so the engine's
## defaults are kept.
const UI_PAD := {"ui_accept": JOY_BUTTON_A, "ui_cancel": JOY_BUTTON_B, "ui_up": JOY_BUTTON_DPAD_UP, "ui_down": JOY_BUTTON_DPAD_DOWN, "ui_left": JOY_BUTTON_DPAD_LEFT, "ui_right": JOY_BUTTON_DPAD_RIGHT}
## And on the left stick, so the menus are walked with the same hand that walks
## the hotel.
const UI_STICK := {"ui_up": [JOY_AXIS_LEFT_Y, -1.0], "ui_down": [JOY_AXIS_LEFT_Y, 1.0], "ui_left": [JOY_AXIS_LEFT_X, -1.0], "ui_right": [JOY_AXIS_LEFT_X, 1.0]}

## How far a stick has to leave its middle before it counts, and the actions
## the right stick looks with (built here, never saved: they are the stick).
const STICK_DEADZONE := 0.22
const LOOK_ACTIONS := {"look_left": [JOY_AXIS_RIGHT_X, -1.0], "look_right": [JOY_AXIS_RIGHT_X, 1.0], "look_up": [JOY_AXIS_RIGHT_Y, -1.0], "look_down": [JOY_AXIS_RIGHT_Y, 1.0]}
const MOVE_AXES := {"forward": [JOY_AXIS_LEFT_Y, -1.0], "backward": [JOY_AXIS_LEFT_Y, 1.0], "left": [JOY_AXIS_LEFT_X, -1.0], "right": [JOY_AXIS_LEFT_X, 1.0]}
var pad_bindings := PAD_KEYS.duplicate()
const AUDIO_KEYS := ["master", "ambience", "music", "effects", "threat"]
## Saved-settings revision of the volume curve. Older files kept sliders tuned
## for a quieter curve, so their volumes are reset once.
const AUDIO_CURVE := 2
## Saved-settings revision of the display defaults. Older files predate
## starting in fullscreen and the three window modes, so their window choice
## is reset once.
const DISPLAY_REVISION := 3
## How the window is shown. Exclusive fullscreen hands the screen to the game
## (the steadiest picture); borderless is the same size with the desktop still
## under it, which is what you want to alt-tab; windowed uses the size below.
const WINDOW_MODES := ["Pantalla completa", "Ventana sin bordes", "Ventana"]
const FULLSCREEN := 0
const BORDERLESS := 1
const WINDOWED := 2
## Saved-settings revision of the subtitle default (now off); reset once.
const SUBTITLE_REVISION := 1
const DISPLAY_KEYS := ["window_mode", "resolution"]
## Room left around a window for the title bar and taskbar.
const WINDOW_MARGIN := Vector2i(48, 96)
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
var values := DEFAULTS.duplicate()
var bindings := KEYS.duplicate()
var save_path := "user://hotel_settings.json"
var previous_display := {}
var countdown := 0.0
## First start on an integrated GPU (or none): the game starts on Bajo and
## the menu suggests the Compatibility renderer once.
var integrated_gpu := false
## The renderer is chosen before anything runs, so the choice lives in its own
## file, which project.godot names as its settings override
## (application/config/project_settings_override): the next start reads it.
## Forward+ is the project's own, so choosing it removes the file. The editor
## ignores the override, and tools pass --rendering-method, which wins.
const RENDERER_OVERRIDE := "user://renderer.cfg"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	# Keeps the override file in step with the saved choice (a deleted settings
	# file means Forward+ again). Tests never touch it.
	if manages_window(): write_renderer()
	apply()
	apply_display()

func load_settings() -> void:
	if not FileAccess.file_exists(save_path):
		first_run()
		return
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
	var pads = data.get("pad_bindings", {})
	if pads is Dictionary:
		var taken := {}
		for action in PAD_KEYS:
			var button: int = int(pads.get(action, PAD_KEYS[action])) if pads.get(action, PAD_KEYS[action]) is float or pads.get(action, PAD_KEYS[action]) is int else PAD_KEYS[action]
			if button < 0 or button in PAD_RESERVED or taken.has(button):
				pad_bindings = PAD_KEYS.duplicate()
				break
			taken[button] = true
			pad_bindings[action] = button
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

func write_renderer() -> void:
	if values.renderer == "forward_plus":
		if FileAccess.file_exists(RENDERER_OVERRIDE): DirAccess.remove_absolute(ProjectSettings.globalize_path(RENDERER_OVERRIDE))
		return
	var file := FileAccess.open(RENDERER_OVERRIDE, FileAccess.WRITE)
	if file: file.store_string("[rendering]\n\nrenderer/rendering_method=\"%s\"\n" % values.renderer)

## Whether the renderer running is the one chosen (a change waits for a restart).
func renderer_pending() -> bool:
	return values.renderer != RenderingServer.get_current_rendering_method()

## No settings saved yet: a preset for this machine, with its render scale.
## Tests and capture tools keep the plain defaults.
func first_run() -> void:
	if not manages_window(): return
	var adapter := RenderingServer.get_video_adapter_type()
	integrated_gpu = adapter in [RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU, RenderingDevice.DEVICE_TYPE_CPU]
	if integrated_gpu: values.quality = PRESETS.LOW
	values.scale = PRESETS.PRESETS[values.quality].scale

func sanitize(key: String, value: Variant) -> Variant:
	if key == "renderer": return value if value in ["forward_plus", "gl_compatibility"] else DEFAULTS[key]
	if key == "upscaler": return value if value in PRESETS.UPSCALERS else DEFAULTS[key]
	if key == "aa": return value if value in PRESETS.ANTIALIASING else DEFAULTS[key]
	if DEFAULTS[key] is bool: return value if value is bool else DEFAULTS[key]
	if DEFAULTS[key] is String: return str(value).strip_edges().left(40) if value is String else DEFAULTS[key]
	if not (value is float or value is int) or not is_finite(float(value)): return DEFAULTS[key]
	match key:
		"resolution": return clampi(int(value), 0, 3)
		"window_mode": return clampi(int(value), 0, WINDOW_MODES.size() - 1)
		"ao", "fog", "reflections", "blur": return clampi(int(value), -1, 1)
		"character": return clampi(int(value), 0, 2)
		"quality": return clampi(int(value), 0, PRESETS.count() - 1)
		"fps": return int(value) if int(value) in [0, 30, 60, 120, 144] else 60
		"sensitivity": return clampf(value, 0.0005, 0.008)
		"pad_look": return clampf(value, 0.6, 6.0)
		"scale": return clampf(value, PRESETS.SCALING_MODES[PRESETS.SCALING_MODES.size() - 1], 1.0)
	return clampf(value, 0, 1)

func set_value(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key): return
	if key in DISPLAY_KEYS and previous_display.is_empty():
		previous_display = {"resolution": values.resolution, "window_mode": values.window_mode}
	values[key] = sanitize(key, value)
	# A preset brings its own render scale; the slider can move it afterwards.
	if key == "quality": values.scale = PRESETS.PRESETS[values.quality].scale
	if key == "renderer": write_renderer()
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

## A button for an action. Refused if it is one the game keeps, or one already
## doing something else, the same as a key.
func bind_pad(action: String, button: int) -> bool:
	if not PAD_KEYS.has(action) or button < 0 or button in PAD_RESERVED: return false
	for other in pad_bindings:
		if other != action and pad_bindings[other] == button: return false
	pad_bindings[action] = button
	apply_bindings()
	save_settings()
	changed.emit()
	return true

## What a pad button is called on screen, in the letters printed on it.
const PAD_NAMES := {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y", JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3", JOY_BUTTON_DPAD_UP: "CRUZ ↑", JOY_BUTTON_DPAD_DOWN: "CRUZ ↓", JOY_BUTTON_DPAD_LEFT: "CRUZ ←", JOY_BUTTON_DPAD_RIGHT: "CRUZ →"}

func pad_name(action: String) -> String:
	return String(PAD_NAMES.get(int(pad_bindings.get(action, -1)), "—"))

## Whether there is a pad plugged in at all (the menus only offer its rows then).
func pad_present() -> bool:
	return not Input.get_connected_joypads().is_empty()

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
	pad_bindings = PAD_KEYS.duplicate()
	values.pad_look = DEFAULTS.pad_look
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
		InputMap.action_set_deadzone(action, STICK_DEADZONE)
		var key := InputEventKey.new()
		key.physical_keycode = bindings[action]
		InputMap.action_add_event(action, key)
		# And on a pad: moving is the left stick, the rest are buttons.
		if MOVE_AXES.has(action): InputMap.action_add_event(action, stick(MOVE_AXES[action]))
		if pad_bindings.has(action):
			var press := InputEventJoypadButton.new()
			press.button_index = pad_bindings[action]
			InputMap.action_add_event(action, press)
	for action in UI_PAD:
		if not InputMap.has_action(action): continue
		var button: int = UI_PAD[action]
		if not InputMap.action_get_events(action).any(func(event): return event is InputEventJoypadButton and int(event.button_index) == button):
			var press := InputEventJoypadButton.new()
			press.button_index = button
			InputMap.action_add_event(action, press)
		if not UI_STICK.has(action): continue
		var pair: Array = UI_STICK[action]
		if not InputMap.action_get_events(action).any(func(event): return event is InputEventJoypadMotion and int(event.axis) == int(pair[0]) and signf(event.axis_value) == signf(pair[1])):
			InputMap.action_add_event(action, stick(pair))
	# Looking is the right stick and nothing else: it is read as a direction
	# every frame (hotel_player.pad_look), not as a press.
	for action in LOOK_ACTIONS:
		if not InputMap.has_action(action): InputMap.add_action(action)
		InputMap.action_erase_events(action)
		InputMap.action_set_deadzone(action, STICK_DEADZONE)
		InputMap.action_add_event(action, stick(LOOK_ACTIONS[action]))

static func stick(pair: Array) -> InputEventJoypadMotion:
	var motion := InputEventJoypadMotion.new()
	motion.axis = int(pair[0])
	motion.axis_value = float(pair[1])
	return motion

## Actions bound to a modifier key -- running on Shift, crouching on Ctrl --
## could stay held after the key was let go: the key-up never reached the game
## (Windows swallows it on some combinations, such as Ctrl+Shift, its own
## keyboard-layout shortcut, or Alt+Shift), and every survivor and the hunter
## went on running with nothing pressed. Every key press and every movement of
## the mouse carries the system's own word on which modifiers are down, so
## whenever one says the key is up, the action is let go.
const MODIFIER_FLAGS := {KEY_SHIFT: "shift_pressed", KEY_CTRL: "ctrl_pressed", KEY_ALT: "alt_pressed", KEY_META: "meta_pressed"}

func _input(event: InputEvent) -> void:
	if not event is InputEventWithModifiers: return
	for action in bindings:
		var key: int = bindings[action]
		if not MODIFIER_FLAGS.has(key) or not Input.is_action_pressed(action): continue
		# The modifier's own key event may or may not count itself as held,
		# depending on the system: it is not asked.
		if event is InputEventKey and (event as InputEventKey).physical_keycode == key: continue
		if not bool(event.get(MODIFIER_FLAGS[key])): Input.action_release(action)

func apply() -> void:
	apply_bindings()
	Engine.max_fps = values.fps
	# Whether the window is one of the two that cover the screen.
	fullscreen = values.window_mode != WINDOWED
	# Window mode and size are only touched by display settings (apply_display),
	# so changing quality or shadows never resizes a maximised window.
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values.vsync else DisplayServer.VSYNC_DISABLED)
	get_viewport().scaling_3d_scale = values.scale
	# Which upscaler, and how hard it sharpens (graphics_presets.scaling_mode).
	# Godot's own number is backwards -- 0 is sharpest, 2 is softest -- and a
	# slider that goes the other way reads wrong, so the setting is "sharpness".
	get_viewport().scaling_3d_mode = PRESETS.scaling_mode(values)
	get_viewport().fsr_sharpness = lerpf(2.0, 0.0, values.sharpness)
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

## Whether the window covers the screen (either fullscreen mode). Kept as a
## plain flag because it is read every frame by the menus and by F11.
var fullscreen := true

## Fullscreen (exclusive or borderless) on the current screen, or a window of
## the chosen size that fits the usable area (never under the taskbar) and is
## centred on it.
func apply_display() -> void:
	if DisplayServer.get_name() == "headless": return
	if not manages_window():
		if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		return
	if values.window_mode != WINDOWED:
		var wanted := DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN if values.window_mode == FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN
		if DisplayServer.window_get_mode() != wanted: DisplayServer.window_set_mode(wanted)
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
	if values.window_mode != WINDOWED or DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED: return
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
	if file: file.store_string(JSON.stringify({"values": values, "bindings": bindings, "pad_bindings": pad_bindings, "audio_curve": AUDIO_CURVE, "display_rev": DISPLAY_REVISION, "subtitle_rev": SUBTITLE_REVISION}))

func _process(delta: float) -> void:
	if countdown > 0:
		var before := int(ceil(countdown))
		countdown -= delta
		if countdown <= 0: revert_display()
		elif int(ceil(countdown)) != before: display_pending.emit(int(ceil(countdown)))
