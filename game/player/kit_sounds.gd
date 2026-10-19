extends Node
## What the survivor's own kit sounds like: the torch's switch and the
## camcorder's zoom motor (tools/audio/prepare_camera_sfx.py cuts them from the
## author's two recordings). Presentation only: nothing here is a noise the
## creature hears.
##
## The switch is heard where the torch is, by its owner and by anybody near
## (remote_player plays it when a teammate's torch goes on or off): one of
## three recordings of it going on, or of it going off, never the same one
## twice running, a hair higher or lower each time.
##
## The motor is heard only by its owner and only while the lens is moving: it
## starts with the motor kicking in, runs for as long as the lens travels --
## a notch of the wheel, a fifth of a second; the whole range, about a
## second; the recordings run longer than either -- and stops within
## MOTOR_STOP of the lens getting where it was asked to. The other way round
## is the other recording, from its own start.
const TORCH_ON := ["res://assets/audio/sfx/flashlight/on_1.wav", "res://assets/audio/sfx/flashlight/on_2.wav", "res://assets/audio/sfx/flashlight/on_3.wav"]
const TORCH_OFF := ["res://assets/audio/sfx/flashlight/off_1.wav", "res://assets/audio/sfx/flashlight/off_2.wav", "res://assets/audio/sfx/flashlight/off_3.wav"]
const ZOOM_IN := "res://assets/audio/sfx/camera/zoom_in.wav"
const ZOOM_OUT := "res://assets/audio/sfx/camera/zoom_out.wav"
## The switch, a hand from the ear; the motor, quieter than anything round it.
const CLICK_DB := -17.0
const MOTOR_DB := -15.0
## How fast the motor dies away once the lens has stopped (seconds), and how
## short a stop of the lens is still the same run of the motor.
const MOTOR_STOP := 0.06
const MOTOR_JOIN := 0.06

## The last recording played of each set, so it is not played again next.
static var last_click := {}

## The voice a torch's switch is heard by: on the torch, in the world.
static func switch_voice(torch: Node3D) -> AudioStreamPlayer3D:
	var voice := AudioStreamPlayer3D.new()
	voice.name = "Switch"
	voice.bus = "Effects"
	voice.unit_size = 2.0
	voice.max_distance = 14.0
	voice.area_mask = 512
	torch.add_child(voice)
	return voice

## The switch going on, or off.
static func click(voice: AudioStreamPlayer3D, on: bool) -> void:
	if voice == null or not voice.is_inside_tree(): return
	var key := "on" if on else "off"
	var choices: Array = (TORCH_ON if on else TORCH_OFF).filter(func(path): return path != last_click.get(key, ""))
	var path: String = choices[randi() % choices.size()]
	last_click[key] = path
	voice.stream = load(path)
	voice.pitch_scale = randf_range(0.96, 1.04)
	voice.volume_db = CLICK_DB + randf_range(-1.5, 1.0)
	voice.play()

var switch: AudioStreamPlayer3D
var motor: AudioStreamPlayer
## Which way the motor is running (1 in, -1 out, 0 still), how long the lens
## has been still, and how far the motor has died away (0 running, 1 gone).
var running := 0
var still := 0.0
var dying := 1.0

func setup(torch: Node3D) -> void:
	switch = switch_voice(torch)
	motor = AudioStreamPlayer.new()
	motor.name = "ZoomMotor"
	motor.bus = "Effects"
	add_child(motor)

func torch_switched(on: bool) -> void:
	click(switch, on)

## Every frame: which way the lens is travelling (1 in, -1 out, 0 not at all).
func lens(way: int, delta: float) -> void:
	if motor == null: return
	if way != 0:
		still = 0.0
		if way != running or dying > 0.0:
			running = way
			dying = 0.0
			motor.stream = load(ZOOM_IN if way > 0 else ZOOM_OUT)
			motor.pitch_scale = randf_range(0.98, 1.02)
			motor.volume_db = MOTOR_DB
			motor.play()
	else:
		still += delta
		if running != 0 and still >= MOTOR_JOIN:
			running = 0
			dying = 0.001
	if dying > 0.0 and motor.playing:
		dying = minf(1.0, dying + delta / MOTOR_STOP)
		motor.volume_db = MOTOR_DB + linear_to_db(maxf(0.001, 1.0 - dying))
		if dying >= 1.0: motor.stop()

## Quiet at once (the body put somewhere else, the camera taken).
func hush() -> void:
	if motor != null: motor.stop()
	running = 0
	dying = 1.0
