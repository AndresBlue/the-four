extends Control
## How long is left to hold a key, drawn round the aiming dot: a thin ring of
## the OSD's own ink that fills clockwise from the top while something is held
## -- a drawer being gone through, a door being eased open, the opening scene
## being skipped -- and goes as soon as nobody asks for it. It eases towards
## what it is told instead of jumping, comes in and goes out with a fade, and
## gives a small pulse when it fills. Under the tape, like the rest of the HUD:
## the camera films it.
##
## Whoever holds something calls hold() every frame with how far along it is;
## a frame without a call is a ring on its way out.
const STYLE := preload("res://game/ui/osd_style.gd")
const RADIUS := 15.0
const WIDTH := 2.5
## Below this a press is a tap (a door opened at once), not a hold: the ring
## does not flash up for it.
const SHOW_FROM := 0.12
## How quickly it follows what it is told, and how quickly it fades.
const EASE := 18.0
const FADE := 9.0
## Seconds it may go without being told before it goes.
const STALE := 0.08

var wanted := -1.0
var shown := 0.0
var alpha := 0.0
var pulse := 0.0
var told := -INF
var clock := 0.0

## Its size is known from the start, before it is placed: whoever places it
## centres it with custom_minimum_size, before it is in the tree.
func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2.ONE * (RADIUS + WIDTH) * 2.0 + Vector2(8, 8)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH

## How far along the thing held is, 0 to 1; anything below nought, nothing.
func hold(fraction: float) -> void:
	told = clock
	if fraction >= 1.0 and wanted < 1.0 and wanted >= 0.0: pulse = 1.0
	wanted = clampf(fraction, 0.0, 1.0) if fraction >= 0.0 else -1.0

func _process(delta: float) -> void:
	clock += delta
	if clock - told > STALE: wanted = -1.0
	var visible_now := wanted >= SHOW_FROM or (wanted >= 0.0 and alpha > 0.01)
	alpha = move_toward(alpha, 1.0 if visible_now else 0.0, FADE * delta)
	if wanted >= 0.0: shown = lerpf(shown, wanted, 1.0 - exp(-EASE * delta))
	elif alpha <= 0.01: shown = 0.0
	pulse = move_toward(pulse, 0.0, delta * 3.5)
	queue_redraw()

func _draw() -> void:
	if alpha <= 0.01: return
	var centre := size * 0.5
	var radius := RADIUS * (1.0 + 0.18 * ease(pulse, 0.4))
	draw_arc(centre, radius, 0.0, TAU, 48, Color(STYLE.FAINT, STYLE.FAINT.a * alpha), WIDTH, true)
	if shown > 0.005:
		var ink := STYLE.INK.lerp(STYLE.AMBER, pulse)
		draw_arc(centre, radius, -PI * 0.5, -PI * 0.5 + TAU * shown, maxi(8, int(48 * shown)), Color(ink, alpha), WIDTH, true)
		# The end it is filling at, a little brighter: where the eye follows.
		var tip := centre + Vector2.from_angle(-PI * 0.5 + TAU * shown) * radius
		draw_circle(tip, WIDTH * 0.75, Color(ink, alpha))
