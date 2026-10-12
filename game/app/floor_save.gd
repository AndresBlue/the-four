extends RefCounted
## A floor played alone, as it stood when it was left: Continuar gives it back
## from that point and not from its beginning. The floor itself is not kept
## -- the seed builds the same hotel again (the checkpoint,
## game_session.gd) -- only what had changed in it: where the survivor stood
## and how they were, the sector, the doors, the sets lit, the furniture gone
## through and the code, the lifts, where the creature was, the sheet, the
## plan as far as it had been seen, and what the tape had counted.
##
## take() reads it off the level and give() puts it back into the same floor
## freshly built; the session writes it beside the checkpoint
## (game_session.write_state(), binary: it holds vectors and tables keyed by
## seat). hotel_main decides when: on pausing, on closing the window, and
## every so often while playing (keep_floor()).
##
## What is not kept comes back fresh: the director's mood, the hallucinations'
## timers, a ride half taken (the survivor is put where it was taking them)
## and a chase -- the creature is where it was, but it has to find them again.

## Seconds the creature leaves whoever has just come back alone: the time to
## see where they are standing.
const GRACE := 8.0

static func take(level) -> Dictionary:
	var player = level.player
	var session = level.session
	# Half way down in a car: where it was taking them.
	var riding: Dictionary = level.lifts.boarding
	var at: Vector3 = riding.point if riding.has("point") else player.global_position
	var arrived: Array = level.lifts.arrived.keys()
	if riding.has("car") and int(riding.car) >= 0 and not arrived.has(int(riding.car)): arrived.append(int(riding.car))
	var searched: Array = []
	for index in level.containers.size():
		var piece = level.containers[index]
		if is_instance_valid(piece) and piece.searched: searched.append([index, int(level.found_by.get(piece.slot, player.slot))])
	var creature := {}
	if is_instance_valid(level.locust): creature = {"at": level.locust.global_position, "yaw": level.locust.rotation.y}
	return {
		"stage": session.stage,
		"elapsed": session.elapsed,
		"restarts": session.restarts,
		"goal": session.goal.duplicate(true),
		"player": {
			"at": at,
			"yaw": player.rotation.y,
			"pitch": player.camera.rotation.x,
			"sanity": player.sanity,
			"stamina": player.stamina,
			"exhausted": player.exhausted,
			"crouched": player.crouched,
			"torch": player.torch.visible,
			"zoom": player.zoom_wanted,
			"hide": level.hotel.hides.find(player.hiding_place) if player.hidden and not riding.has("point") else -1,
		},
		"doors": level.hotel.doors.map(func(door): return door.opened),
		"sets": level.televisions.map(func(set): return is_instance_valid(set) and set.on),
		"searched": searched,
		"code": level.code_entered,
		"lifts": {"away": level.lifts.lift_away.duplicate(), "hold": level.lifts.creature_hold.duplicate(), "lobby": level.lifts.lobby_time.duplicate(), "arrived": arrived},
		"creature": creature,
		"dark": level.hotel.dark,
		"sheet": level.sheet_snapshot(),
		"plan": level.floor_map.pack(),
		"ledger": level.ledger.pack(),
		"tape": [level.tape_rewound, level.stage_tape],
	}

## Into the floor just built from the same seed (hotel_main.continue_floor()).
static func give(level, state: Dictionary) -> void:
	var player = level.player
	var session = level.session
	var stage := clampi(int(state.get("stage", 1)), 1, session.STAGES)
	# Told, not heard: every door and every set would sound at once.
	level.world_audio.hush = true
	session.elapsed = float(state.get("elapsed", 0.0))
	session.restarts = int(state.get("restarts", 0))
	if state.get("goal") is Dictionary: session.goal = state.goal.duplicate(true)
	# What had been done.
	var doors: Array = state.get("doors", [])
	for index in mini(doors.size(), level.hotel.doors.size()): level.hotel.doors[index].set_state(bool(doors[index]))
	var sets: Array = state.get("sets", [])
	for index in mini(sets.size(), level.televisions.size()):
		if bool(sets[index]): level.apply_television(index, true, true)
	# With the sector it had reached, and that sector's card over the arrival
	# (catch_up_progress); reached, not just arrived at: the creature is not
	# sent after a lift nobody has just taken.
	level.catch_up_progress({"searched": state.get("searched", []), "code": state.get("code", false), "lift_away": state.get("lifts", {}).get("away", {}), "stage": stage})
	level.last_stage = session.stage
	var lifts: Dictionary = state.get("lifts", {})
	level.lifts.creature_hold = lifts.get("hold", {}).duplicate()
	level.lifts.lobby_time = lifts.get("lobby", {}).duplicate()
	# The cars that had let somebody out stand open, as they were left.
	for car in lifts.get("arrived", []): level.lifts.arrived[int(car)] = 0.0
	# The power that had gone is gone, without the board being thrown again.
	if bool(state.get("dark", false)) and not level.hotel.dark: level.hotel.blackout(true)
	# The survivor.
	var own: Dictionary = state.get("player", {})
	player.velocity = Vector3.ZERO
	player.global_position = own.get("at", player.global_position)
	player.rotation.y = float(own.get("yaw", player.rotation.y))
	player.camera.rotation.x = float(own.get("pitch", 0.0))
	player.sanity = float(own.get("sanity", 100.0))
	player.stamina = float(own.get("stamina", 100.0))
	player.exhausted = bool(own.get("exhausted", false))
	player.crouched = bool(own.get("crouched", false))
	player.zoom_wanted = float(own.get("zoom", 1.0))
	player.zoom = player.zoom_wanted
	var hide := int(own.get("hide", -1))
	if hide >= 0 and hide < level.hotel.hides.size(): player.enter_hide(level.hotel.hides[hide])
	else: player.torch.visible = bool(own.get("torch", player.torch.visible))
	player.snap_torch()
	# The creature where it was, with a moment before it looks about: what it
	# was doing is not kept. A wing behind, it makes for its car by itself
	# (lifts.creature_crossing).
	var creature: Dictionary = state.get("creature", {})
	if not creature.is_empty() and is_instance_valid(level.locust) and level.locust.control == "ai":
		level.locust.relocate(creature.at, GRACE)
		level.locust.rotation.y = float(creature.get("yaw", 0.0))
	# What the tape and the page held. Last: the wardrobe above counted a
	# hiding, and this puts the count back as it was.
	level.restore_sheet(state.get("sheet", []))
	level.floor_map.unpack(state.get("plan", {}))
	level.ledger.unpack(state.get("ledger", {}))
	# How far the tape's clock is behind the floor's (stages given back).
	var kept_tape = state.get("tape", [])
	if kept_tape is Array and kept_tape.size() == 2:
		level.tape_rewound = clampf(float(kept_tape[0]), 0.0, session.elapsed)
		level.stage_tape = clampf(float(kept_tape[1]), 0.0, session.elapsed)
	level.world_audio.hush = false
	# The doors of the sector, and whoever listens to the session.
	session.changed.emit()
	level.hotel.update_visibility(player.global_position, true)
