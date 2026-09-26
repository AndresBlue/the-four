extends RefCounted
## How a pad feels in the hands, for whoever the local player drives (the
## survivor, hotel_player.gd, and the creature, locust_player.gd): the right
## stick turned into a turn of the head, and running and crouching that flip on
## and off with a press instead of being held.
##
## Looking used to be the stick's direction squared times a speed, read at the
## physics rate: it came to the screen in steps whenever the picture ran faster
## than physics, went from stopped to full speed with nothing between, and a
## stick sitting at its rim turned no faster after a second than at first. Now
## it is read every drawn frame, the stick is eased (LOOK_EASE, quicker to let
## go than to push), the middle of its travel is gentle and the rim is not
## (CURVE_LINEAR), and holding it at the rim sideways builds up to RIM_BOOST
## times the speed, so turning round is quick and aiming stays fine. Up and
## down is a little slower than across (PITCH_SHARE), as it is in every game.
const LOOK_EASE := 0.045
const LOOK_RELEASE := 0.025
## Share of the response that is linear; the rest is the square.
const CURVE_LINEAR := 0.2
const PITCH_SHARE := 0.75
## Past RIM across, after RIM_WAIT s, the turn grows to RIM_BOOST times over
## RIM_RAMP s.
const RIM := 0.9
const RIM_WAIT := 0.15
const RIM_RAMP := 0.45
const RIM_BOOST := 1.8
## Toggled running stops by itself when the stick is let go for this long.
const STOP_AFTER := 0.3

var stick := Vector2.ZERO
var rim_time := 0.0
var sprint_latched := false
var crouch_latched := false
var still := 0.0

## The turn of the head for this frame, in the units look_by() takes
## (positive x turns left, positive y looks up), already slowed by the lens.
func look(delta: float, settings, zoom := 1.0) -> Vector2:
	var raw := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	var ease := LOOK_RELEASE if raw.length() < stick.length() else LOOK_EASE
	stick = stick.lerp(raw, 1.0 - exp(-delta / ease))
	var push := minf(stick.length(), 1.0)
	if push < 0.002:
		stick = Vector2.ZERO
		rim_time = 0.0
		return Vector2.ZERO
	rim_time = rim_time + delta if absf(raw.x) >= RIM else 0.0
	var boost := 1.0 + (RIM_BOOST - 1.0) * clampf((rim_time - RIM_WAIT) / RIM_RAMP, 0.0, 1.0)
	var response := push * (CURVE_LINEAR + (1.0 - CURVE_LINEAR) * push)
	var turn := stick.normalized() * response * float(settings.values.pad_look) * delta / zoom
	return Vector2(-turn.x * boost, -turn.y * PITCH_SHARE)

## A pad press, from the body's _unhandled_input: flips running or crouching
## if that one is set to flip. Running stands up and crouching stops running.
func pressed(event: InputEvent, settings) -> void:
	if settings == null or not event is InputEventJoypadButton or not event.pressed: return
	if event.is_action("sprint") and settings.values.pad_sprint_toggle:
		sprint_latched = not sprint_latched
		if sprint_latched: crouch_latched = false
	elif event.is_action("crouch") and settings.values.pad_crouch_toggle:
		crouch_latched = not crouch_latched
		if crouch_latched: sprint_latched = false

## Whether the action is asked for now: held on the keyboard (or on the pad,
## when it is not set to flip), or flipped on.
func wants(action: String, settings) -> bool:
	if settings == null: return Input.is_action_pressed(action)
	var flips: bool = settings.values.get("pad_%s_toggle" % action, false)
	if not flips: return Input.is_action_pressed(action)
	var latched := sprint_latched if action == "sprint" else crouch_latched
	return latched or (Input.is_action_pressed(action) and not pad_holds(action, settings))

## Whether it is a pad's button, and not a key, that holds the action down.
static func pad_holds(action: String, settings) -> bool:
	var button := int(settings.pad_bindings.get(action, -1))
	if button < 0: return false
	for pad in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(pad, button): return true
	return false

## Each frame the body moves: running flipped on stops once the stick has been
## let go a moment, or the breath runs out.
func settle(moving: bool, spent: bool, delta: float) -> void:
	still = 0.0 if moving else still + delta
	if still >= STOP_AFTER or spent: sprint_latched = false

func reset() -> void:
	stick = Vector2.ZERO
	rim_time = 0.0
	sprint_latched = false
	crouch_latched = false
	still = 0.0
