extends RefCounted
## Versus (.claude/specs/lurker_versus.md 6; phase 3): where she lies in wait,
## from what her shell already knows of the floor (lurker_shell.gd): a door's
## band on each room's side, just over its frame (the lintel); the walled
## corners of a tray; the mouth of an archive's aisle, up a shelf; the ceiling
## over a locker. None within LAMP_CLEAR of a lamp of its room in plan (the
## lamp she keeps low there would give her away) and none in an off-limits
## room (the shell has no ceiling for her there). From the manifest alone, in
## the shell's order: the same on every machine.
const SHELL := preload("res://game/enemies/lurker/lurker_shell.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const LAYOUT := preload("res://game/world/generation/office_layout.gd")
## A corner's site this far in from each wall's tray edge.
const CORNER_IN := 0.2
## Up an aisle's shelf at its mouth: this high, this far along.
const AISLE_HOLD := 1.8
const AISLE_IN := 0.3
## A lintel's u is found on its band's profile in steps this long.
const STEP := 0.02

## Every site: {kind ("door", "corner", "aisle", "locker"), room, wing, point
## (her anchor there), patch (the band or the aisle; the tray's otherwise), u,
## v, dir (a band's way from its start in `room`)}.
static func sites(shell) -> Array:
	var out: Array = []
	var t := 2.0 * OFFICE.WALL_HALF
	var c := SHELL.BAND_CLEAR
	for index in shell.patches.size():
		var patch: Dictionary = shell.patches[index]
		match int(patch.kind):
			SHELL.Kind.BAND:
				if (patch.pair as Vector2i).x < 0: continue
				# Each side's corner of the band over the frame (add_door_band()).
				for side in 2:
					var room := int(patch.rooms[side])
					var u := nearest_u(patch.profile, Vector2((t / 2.0 + c) * (1.0 if side == 1 else -1.0), SHELL.OPEN - c))
					add(shell, out, {"kind": "door", "room": room, "patch": index, "u": u, "v": 0.0, "dir": 1 if side == 0 else -1})
			SHELL.Kind.TRAY:
				var rect: Rect2 = patch.rect
				var open: Dictionary = patch.open
				var inner := rect.grow(-CORNER_IN)
				for corner in [["west", "north", inner.position], ["east", "north", Vector2(inner.end.x, inner.position.y)], ["east", "south", inner.end], ["west", "south", Vector2(inner.position.x, inner.end.y)]]:
					if open.has(corner[0]) or open.has(corner[1]): continue
					add(shell, out, {"kind": "corner", "room": int(patch.room), "patch": index, "u": (corner[2] as Vector2).x, "v": (corner[2] as Vector2).y, "dir": 0})
			SHELL.Kind.CHANNEL:
				add(shell, out, {"kind": "aisle", "room": int(patch.room), "patch": index, "u": shell.channel_u_on_wall(index, 1.0, AISLE_HOLD), "v": minf(AISLE_IN, float(patch.length)), "dir": 0})
	for id in shell.tray_of:
		var room: Dictionary = shell.rooms[int(id)]
		for hide in room.get("hides", []):
			var hw := LAYOUT.hide_wall(hide)
			var at: Vector3 = shell.wall_frame(room, String(hw.wall), float(hw.along), LAYOUT.LOCKER.y * 0.5)[0]
			var s = shell.tray_state(int(id), at.x, at.z)
			add(shell, out, {"kind": "locker", "room": int(id), "patch": s.patch, "u": s.u, "v": s.v, "dir": 0})
	return out

## The site with its anchor, unless it falls by a lamp or a column of its room.
static func add(shell, out: Array, site: Dictionary) -> void:
	var s = state_of(shell, site)
	var point: Vector3 = shell.anchor_of(s)
	var near: PackedVector2Array = shell.lamps_of.get(int(site.room), PackedVector2Array()) + shell.columns_of.get(int(site.room), PackedVector2Array())
	for lamp in near:
		if Vector2(point.x, point.z).distance_to(lamp) < SHELL.LAMP_CLEAR: return
	site["point"] = point
	site["wing"] = int(shell.patches[int(site.patch)].wing)
	out.append(site)

## Where on her shell a site is.
static func state_of(shell, site: Dictionary):
	var s = SHELL.State.new()
	s.patch = int(site.patch)
	s.u = float(site.u)
	s.v = float(site.v)
	s.hang = SHELL.DEFAULT_HANG
	shell.clamp_state(s)
	return s

## The u of a profile nearest a point of its plane.
static func nearest_u(profile, point: Vector2) -> float:
	var best := 0.0
	var best_d := INF
	var u := 0.0
	while u <= profile.length:
		var d: float = (profile.at(u)[0] as Vector2).distance_squared_to(point)
		if d < best_d:
			best_d = d
			best = u
		u += STEP
	return best

## The nearest site to `at` on its planta within `reach` (plan metres), -1 none.
static func nearest(list: Array, at: Vector3, wing: int, reach: float) -> int:
	var best := -1
	var best_d := reach
	for i in list.size():
		var site: Dictionary = list[i]
		if int(site.wing) != wing: continue
		var p: Vector3 = site.point
		var d := Vector2(p.x - at.x, p.z - at.z).length()
		if d <= best_d:
			best_d = d
			best = i
	return best
