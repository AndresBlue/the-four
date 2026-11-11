extends RefCounted
## The theme, and how much of it a frightened ear lets through
## (world_audio.mood; hotel_main sets the theme's volume from gain()).
##
## TENSION, 0 calm to 1 as bad as it gets, is read every frame from what the
## listener is going through (felt()):
##  - the creature by walking, real or imagined: dread_aura.menace, its
##    nearness and its hunt. Not fooled, as the aura is on purpose, by a
##    creature holding itself still beside a wardrobe: whoever waits in there
##    knows it is outside, and the theme coming back is what gave it away;
##  - somebody caught within EXECUTION_REACH, or the listener: all of it;
##  - a grunt aimed at the listener (world_audio.duck_under): GRUNT;
##  - a mind going (sanity under its UNEASY), up to MIND of it at nothing left.
## It rises with what frightens at RISE a second, and falls only once things
## have been quiet for CALM_HOLD -- the longer the worse it got -- and then
## down to whatever is still felt: at once through what cannot be heard (above
## GONE), and from there slowly, the theme taking RETURN seconds to come back
## from nothing. Gently, and not the moment the creature turns a corner.
##
## The theme follows it all the way: as it rises the music is drawn into the
## middle (the Music bus's ThemeWidth, from stereo to mono), muffled as if
## from further and further away (ThemeMuffle, down to MUFFLED_HZ) and faded,
## gone altogether from GONE; as it falls, the same backwards. Calm, both
## effects are off. Presentation only, this machine's own: nothing here
## reaches the creature or the network. The creature's seat keeps the theme
## as it was.
const RISE := 0.6
## Seconds of calm before it falls: after a fright, and after the worst.
const CALM_HOLD := Vector2(5.0, 15.0)
const GONE := 0.5
const RETURN := 10.0
const FALL := GONE / RETURN
const FALL_SILENT := 1.0
const MUFFLED_HZ := 700.0
const OPEN_HZ := 20000.0
const EXECUTION_REACH := 25.0
const GRUNT := 0.8
const MIND := 0.35
## Once she has fled (step()'s release): from all of it to nothing in 2.5 s,
## so a warning saved has the theme back within 6 s.
const RELEASE := 0.4

var tension := 0.0
## The worst since it was last calm, which sets how long the calm must last.
var worst := 0.0
## How long it has been calmer than `tension`.
var calm := 0.0
var muffle: AudioEffectLowPassFilter
var width: AudioEffectStereoEnhance
var bus := -1
var muffle_index := -1
var width_index := -1

## Finds its two effects on the Music bus (default_bus_layout.tres).
func setup() -> void:
	bus = AudioServer.get_bus_index("Music")
	if bus < 0: return
	for index in AudioServer.get_bus_effect_count(bus):
		var effect := AudioServer.get_bus_effect(bus, index)
		if effect is AudioEffectLowPassFilter:
			muffle = effect
			muffle_index = index
		elif effect is AudioEffectStereoEnhance:
			width = effect
			width_index = index
	apply()

func reset() -> void:
	tension = 0.0
	worst = 0.0
	calm = 0.0
	apply()

## How tense it is for the listener right now (0..1).
func felt(level, world_audio) -> float:
	if level.match_net.local_is_locust(): return 0.0
	var now: float = world_audio.aura.menace if world_audio.aura != null else 0.0
	if not level.execution.is_empty():
		var listener: Vector3 = world_audio.listener_position()
		if int(level.execution.seat) == int(level.player.slot) or listener.distance_to(level.execution.point) <= EXECUTION_REACH: now = 1.0
	if world_audio.duck_hold > 0.0: now = maxf(now, GRUNT)
	if level.local_alive():
		var uneasy: float = level.sanity.SANITY_UNEASY
		now = maxf(now, MIND * clampf((uneasy - float(level.player.sanity)) / uneasy, 0.0, 1.0))
	return clampf(now, 0.0, 1.0)

## One frame of it, `now` being felt(). `release`: what frightened has fled
## (dread_aura.release): no calm to wait out, down at RELEASE.
func step(now: float, delta: float, release := false) -> void:
	if now >= tension:
		tension = move_toward(tension, now, delta * RISE)
		calm = 0.0
	elif release:
		tension = maxf(now, tension - delta * RELEASE)
	else:
		calm += delta
		if calm >= lerpf(CALM_HOLD.x, CALM_HOLD.y, worst): tension = maxf(now, tension - delta * (FALL_SILENT if tension > GONE else FALL))
	worst = maxf(worst, tension)
	if tension < 0.02: worst = tension
	apply()

## How much of the theme is left (1 all, 0 none).
func gain() -> float:
	return 1.0 - smoothstep(0.05, GONE, tension)

func apply() -> void:
	if bus < 0: return
	var drawn := smoothstep(0.0, GONE, tension)
	var on := drawn > 0.001
	if muffle != null:
		muffle.cutoff_hz = MUFFLED_HZ * pow(OPEN_HZ / MUFFLED_HZ, 1.0 - drawn)
		AudioServer.set_bus_effect_enabled(bus, muffle_index, on)
	if width != null:
		width.pan_pullout = 1.0 - drawn
		AudioServer.set_bus_effect_enabled(bus, width_index, on)
