extends SceneTree
## The Lurker's shell and routes (game/enemies/lurker/lurker_shell.gd and
## lurker_routes.gd, spec_f2_movement 3, 6 and 11.1): the shell's curves
## against the bench's, the transform of every place,
## the seams between ceilings, bands and aisles, how far it keeps from door
## heads and lamps, every room and door covered, the walls of the tall rooms
## and the fronts of the lockers (the author, 24 October 2026), the back
## cue's posture for a victim standing and crouched, and the same build twice;
## her routes on a stub level: by doors, by ducts when one shuts, dearer
## through light, never through an off-limits room. No floor is built and
## nothing of physics runs.
const GEN := preload("res://game/world/generation/office_generator.gd")
const HOTEL_GEN := preload("res://game/world/generation/map_generator.gd")
const SHELL := preload("res://game/enemies/lurker/lurker_shell.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const LAYOUT := preload("res://game/world/generation/office_layout.gd")
const ROUTES := preload("res://game/enemies/lurker/lurker_routes.gd")
const DUCTS := preload("res://game/enemies/lurker/duct_graph.gd")
const FIX := preload("res://tests/office/lurker_fixture.gd")
const Profile := SHELL.Profile
const State := SHELL.State
const SEEDS := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
var checks: Array = []
var failed := 0
var figures := {}
var shells := {}

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool, detail := "") -> void:
	checks.append({"check": title, "passed": passed, "detail": detail if not passed else ""})
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title, ("  (" + detail + ")") if not passed and not detail.is_empty() else "")

func run() -> void:
	var started := Time.get_ticks_msec()
	for seed_value in SEEDS: shells[seed_value] = SHELL.build(GEN.new().generate(int(seed_value), 2))
	figures["build_ms"] = Time.get_ticks_msec() - started
	profiles()
	bench()
	constants()
	transforms()
	seams()
	round_trips()
	continuity()
	clearances()
	coverage()
	walls_and_lockers()
	lamps_and_cue()
	heights()
	fixture_cases()
	determinism()
	plenum()
	await route_cases()
	duct_steps()
	route_seeds()
	text()
	figures["total_ms"] = Time.get_ticks_msec() - started
	var file := FileAccess.open("res://evidence/lurker_shell_test.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"checks": checks, "figures": figures}, "\t"))
	print("LURKER_SHELL_TEST_RESULT ", checks.size() - failed, "/", checks.size())
	quit(1 if failed > 0 else 0)

# --- Helpers -------------------------------------------------------------------

func state(patch: int, u: float, v: float, heading := 0.0, hang := SHELL.DEFAULT_HANG) -> State:
	var s := State.new()
	s.patch = patch
	s.u = u
	s.v = v
	s.heading = heading
	s.hang = hang
	return s

## The largest difference between two bases' columns (about the angle between
## them when small; float32 makes a quaternion's angle too coarse for this).
func basis_gap(a: Basis, b: Basis) -> float:
	return maxf((a.x - b.x).length(), maxf((a.y - b.y).length(), (a.z - b.z).length()))

func same_place(a: Transform3D, b: Transform3D, tolerance := 1e-4) -> bool:
	return a.origin.distance_to(b.origin) <= tolerance and basis_gap(a.basis, b.basis) <= tolerance

func kind_of(shell, kind: int) -> Array:
	var out: Array = []
	for i in shell.patches.size():
		if int(shell.patches[i].kind) == kind: out.append(i)
	return out

func door_bands(shell) -> Array:
	return kind_of(shell, SHELL.Kind.BAND).filter(func(b): return int(shell.patches[b].rooms[1]) >= 0)

func exit_bands(shell) -> Array:
	return kind_of(shell, SHELL.Kind.BAND).filter(func(b): return int(shell.patches[b].exit) >= 0)

# --- A to C: curves and constants ------------------------------------------------

func profiles() -> void:
	var p := Profile.rounded(PackedVector2Array([Vector2(0, 0), Vector2(2, 0), Vector2(2, -2)]), 0.45, -1.0)
	var smooth := true
	var du := 0.001
	var last: Array = p.at(0.0)
	var u := du
	while u <= p.length:
		var now: Array = p.at(u)
		var step: float = (now[0] as Vector2).distance_to(last[0])
		var turn: float = absf((last[1] as Vector2).angle_to(now[1]))
		if step > du * 1.0001 + 2e-6 or absf((now[1] as Vector2).length() - 1.0) > 1e-6 or turn > du / 0.45 + 2e-6: smooth = false
		last = now
		u += du
	check("Perfiles: una esquina redondeada mide lo que debe", absf(p.length - (3.1 + 0.45 * PI / 2.0)) < 1e-6, str(p.length))
	check("Perfiles: a pasos de un milímetro avanza lo justo y gira suave", smooth)
	var tight := Profile.rounded(PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 0.3), Vector2(2, 0.3)]), 0.45, 1.0)
	var tight_c1 := true
	last = tight.at(0.0)
	u = du
	while u <= tight.length:
		var now: Array = tight.at(u)
		if (now[0] as Vector2).distance_to(last[0]) > du * 1.0001 + 2e-6 or absf((last[1] as Vector2).angle_to(now[1])) > du / 0.15 + 2e-6: tight_c1 = false
		last = now
		u += du
	check("Perfiles: un tramo corto entre dos esquinas recorta el radio a la mitad", absf(tight.min_radius - 0.15) < 1e-6 and tight_c1, str(tight.min_radius))
	var section := Profile.section(1.0, 2.95, 0.45)
	var a: Vector2 = section.at(0.3)[0]
	var b: Vector2 = section.at(section.length + 0.3)[0]
	check("Perfiles: la sección de un pasillo de archivo mide lo que debe y se cierra", absf(section.length - (2.0 * 0.1 + 2.0 * 2.05 + TAU * 0.45)) < 1e-6 and a.distance_to(b) < 1e-6)

func bench() -> void:
	var bench_script: GDScript = load("res://tools/workbenches/lurker_test.gd")
	var bench_node = bench_script.new()
	var width: float = bench_script.get_script_constant_map().WIDTH
	var height: float = bench_script.get_script_constant_map().HEIGHT
	var bend: float = bench_script.get_script_constant_map().BEND
	var section := Profile.section(width, height, bend)
	var worst := 0.0
	for i in 200:
		var u: float = bench_node.perimeter() * float(i) / 200.0
		var theirs: Array = bench_node.outline(u)
		var ours: Array = section.at(u)
		worst = maxf(worst, maxf((ours[0] as Vector2).distance_to(theirs[0]), section.normal_at(u).distance_to(theirs[1])))
	var walls := absf(section.length - float(bench_node.perimeter())) < 1e-5
	bench_node.free()
	check("El banco: la sección es el contorno de lurker_test.gd, punto y normal", worst < 1e-5 and walls, str(worst))

func constants() -> void:
	var hotel_geometry: Dictionary = load("res://game/world/hotel/hotel_geometry.gd").get_script_constant_map()
	var bench_bend: float = load("res://tools/workbenches/lurker_test.gd").get_script_constant_map().BEND
	check("Constantes: el dintel, el ancho de puerta y la curva son los del juego", is_equal_approx(SHELL.OPEN, float(hotel_geometry.OPENING_HIGH)) and is_equal_approx(SHELL.PORTAL_WIDTH, FLOOR.PORTAL) and is_equal_approx(SHELL.BEND, bench_bend))

# --- D to H ------------------------------------------------------------------

func transforms() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var bad: Array = []
	for i in 500:
		var shell = shells[SEEDS[rng.randi_range(0, 4)]]
		var patch := rng.randi_range(0, shell.patches.size() - 1)
		var record: Dictionary = shell.patches[patch]
		var s := state(patch, 0.0, 0.0, rng.randf_range(-PI, PI), rng.randf_range(0.0, 1.0))
		match int(record.kind):
			SHELL.Kind.TRAY:
				var rect: Rect2 = record.rect
				s.u = rng.randf_range(rect.position.x, rect.end.x)
				s.v = rng.randf_range(rect.position.y, rect.end.y)
			SHELL.Kind.BAND:
				s.u = rng.randf_range(0.0, (record.profile as Profile).length)
				s.v = rng.randf_range(-float(record.width) / 2.0, float(record.width) / 2.0)
			_:
				s.u = rng.randf_range(0.0, (record.profile as Profile).length)
				s.v = rng.randf_range(0.0, float(record.length))
		shell.clamp_state(s)
		var t: Transform3D = shell.transform_of(s)
		var basis := t.basis
		var orthonormal := absf(basis.x.length() - 1.0) < 1e-5 and absf(basis.y.length() - 1.0) < 1e-5 and absf(basis.z.length() - 1.0) < 1e-5 and absf(basis.x.dot(basis.y)) < 1e-5 and absf(basis.y.dot(basis.z)) < 1e-5 and absf(basis.x.dot(basis.z)) < 1e-5
		var frame: Array = shell.frame_of(s)
		if not orthonormal or absf(basis.determinant() - 1.0) > 1e-5 or basis.y.distance_to(frame[0]) > 1e-5 or basis.z.distance_to(shell.heading_vector(s)) > 1e-5 or absf(basis.y.dot(basis.z)) > 1e-6:
			bad.append([patch, int(record.kind)])
	check("Transformación: 500 sitios al azar dan una base ortonormal con +Y la normal y +Z el rumbo", bad.is_empty(), str(bad.slice(0, 5)))
	var shell = shells[1]
	var tray: int = shell.tray_of.values()[0]
	var t2: Transform3D = shell.transform_of(state(tray, shell.patches[tray].rect.get_center().x, shell.patches[tray].rect.get_center().y, PI / 2.0))
	check("Transformación: en un techo +Y mira abajo y el rumbo PI / 2 es +Z", t2.basis.y.distance_to(Vector3.DOWN) < 1e-6 and t2.basis.z.distance_to(Vector3.BACK) < 1e-6)

func seams() -> void:
	var bad_doors: Array = []
	var skipped := 0
	var bad_walls: Array = []
	var bad_channels: Array = []
	for seed_value in SEEDS:
		var shell = shells[seed_value]
		for band in door_bands(shell):
			var record: Dictionary = shell.patches[band]
			var length: float = (record.profile as Profile).length
			for v: float in [-0.6, 0.0, 0.6]:
				for end in 2:
					var u: float = 0.0 if end == 0 else length
					var on_band := state(band, u, v, 0.0 if end == 0 else PI)
					var at: Vector3 = shell.anchor_of(on_band)
					var room := int(record.rooms[end])
					var rect: Rect2 = shell.patches[int(shell.tray_of[room])].rect
					if not rect.grow(1e-6).has_point(Vector2(at.x, at.z)):
						if v == 0.0: bad_doors.append([seed_value, band, "fuera", end])
						skipped += 1
						continue
					var on_tray: State = shell.tray_state(room, at.x, at.z, SHELL.BAND_CLEAR)
					shell.set_heading(on_tray, shell.heading_vector(on_band))
					var switched: State = shell.switch_to(on_tray, band)
					if not same_place(shell.transform_of(on_tray), shell.transform_of(on_band)) or switched == null or not same_place(shell.transform_of(switched), shell.transform_of(on_band)):
						bad_doors.append([seed_value, band, v, end])
		for band in exit_bands(shell):
			var on_band := state(band, 0.0, 0.0, PI)
			var at: Vector3 = shell.anchor_of(on_band)
			var on_tray: State = shell.tray_state(int(shell.patches[band].rooms[0]), at.x, at.z, SHELL.BAND_CLEAR)
			shell.set_heading(on_tray, shell.heading_vector(on_band))
			if not same_place(shell.transform_of(on_tray), shell.transform_of(on_band)) or shell.switch_to(on_tray, band) == null: bad_walls.append([seed_value, band])
		for channel in kind_of(shell, SHELL.Kind.CHANNEL):
			var record: Dictionary = shell.patches[channel]
			var length := float(record.length)
			var probe := state(channel, 0.0, 0.0)
			var top: float = shell.max_hang(probe)
			for v: float in [0.0, length / 2.0, length]:
				for hang: float in [0.1, 0.25]:
					var point: Vector3 = (record.origin as Vector3) + (record.axis as Vector3) * v
					var on_tray: State = shell.state_at(point + Vector3.UP * 1.0, hang)
					shell.set_heading(on_tray, record.axis)
					var switched: State = shell.switch_to(on_tray, channel)
					if hang > top + 1e-9:
						if switched != null: bad_channels.append([seed_value, channel, "hondo", hang])
						continue
					if switched == null or not same_place(shell.transform_of(switched), shell.transform_of(on_tray)):
						bad_channels.append([seed_value, channel, v, hang])
						continue
					var widest: float = shell.channel_seam(record, hang)
					for side: float in [-1.0, 1.0]:
						var edge: State = shell.state_at(point + (record.across as Vector3) * side * widest + Vector3.UP, hang)
						var past: State = shell.state_at(point + (record.across as Vector3) * side * (widest + 0.005) + Vector3.UP, hang)
						var at_edge: State = shell.switch_to(edge, channel)
						if at_edge == null or shell.anchor_of(at_edge).distance_to(shell.anchor_of(edge)) > SHELL.SEAM_TOL + 1e-4 or shell.switch_to(past, channel) != null:
							bad_channels.append([seed_value, channel, "borde", side])
	figures["door_band_ends_off_their_tray"] = skipped
	check("Costuras: en cada puerta, techo y franja coinciden a ambos lados", bad_doors.is_empty(), str(bad_doors.slice(0, 6)))
	check("Costuras: cada bajada a una rejilla empieza donde acaba el techo", bad_walls.is_empty(), str(bad_walls.slice(0, 6)))
	check("Costuras: el techo y el pasillo de archivo coinciden sobre su eje y hasta el borde que se acepta", bad_channels.is_empty(), str(bad_channels.slice(0, 6)))

func round_trips() -> void:
	var shell = shells[1]
	var bad: Array = []
	for band in door_bands(shell).slice(0, 40):
		var record: Dictionary = shell.patches[band]
		var at: Vector3 = shell.anchor_of(state(band, 0.0, 0.0))
		var start: State = shell.tray_state(int(record.rooms[0]), at.x, at.z, SHELL.BAND_CLEAR)
		start.heading = atan2((record.across as Vector3).z, (record.across as Vector3).x) + 0.3
		var world: Vector3 = shell.heading_vector(start)
		var there: State = shell.switch_to(start, band)
		var back: State = shell.switch_to(there, int(shell.tray_of[int(record.rooms[0])])) if there != null else null
		if back == null or absf(back.u - start.u) > 2e-5 or absf(back.v - start.v) > 2e-5 or absf(back.hang - start.hang) > 2e-5 or shell.heading_vector(back).distance_to(world) > 1e-5:
			bad.append(band)
	for channel in kind_of(shell, SHELL.Kind.CHANNEL).slice(0, 20):
		var record: Dictionary = shell.patches[channel]
		var point: Vector3 = (record.origin as Vector3) + (record.axis as Vector3) * float(record.length) / 2.0
		var start: State = shell.state_at(point + Vector3.UP, 0.1)
		start.heading = 0.4
		var world: Vector3 = shell.heading_vector(start)
		var there: State = shell.switch_to(start, channel)
		var back: State = shell.switch_to(there, start.patch) if there != null else null
		if back == null or absf(back.u - start.u) > 2e-5 or absf(back.v - start.v) > 2e-5 or absf(back.hang - start.hang) > 2e-5 or shell.heading_vector(back).distance_to(world) > 1e-5:
			bad.append(["pasillo", channel])
	check("Ida y vuelta: techo a franja a techo y techo a pasillo a techo devuelven el mismo sitio", bad.is_empty(), str(bad.slice(0, 6)))
	var tray: int = shell.tray_of.values()[0]
	var middle: State = shell.tray_state(int(shell.patches[tray].room), shell.patches[tray].rect.get_center().x, shell.patches[tray].rect.get_center().y)
	var away := true
	for band in shell.bands_of.get(int(shell.patches[tray].room), []):
		var to_band: State = shell.switch_to(middle, int(band))
		if to_band != null and shell.anchor_of(to_band).distance_to(shell.anchor_of(middle)) > SHELL.SEAM_TOL: away = false
	check("Ida y vuelta: lejos de una costura no se cambia de superficie", away)

func continuity() -> void:
	var bad: Array = []
	var worst_radius := INF
	for seed_value in SEEDS:
		var shell = shells[seed_value]
		worst_radius = minf(worst_radius, shell.min_radius)
		for band in kind_of(shell, SHELL.Kind.BAND):
			var record: Dictionary = shell.patches[band]
			var length: float = (record.profile as Profile).length
			var du := 0.005 if int(seed_value) == 1 else 0.02
			var vs: Array = [-0.5, 0.0, 0.5] if int(seed_value) == 1 else [0.0]
			for v: float in vs:
				var last: Transform3D = shell.transform_of(state(band, 0.0, clampf(v, -float(record.width) / 2.0, float(record.width) / 2.0)))
				var u := du
				while u <= length + 1e-9:
					var now: Transform3D = shell.transform_of(state(band, u, clampf(v, -float(record.width) / 2.0, float(record.width) / 2.0)))
					if now.origin.distance_to(last.origin) > du * 1.001 + 1e-5 or basis_gap(now.basis, last.basis) > du / SHELL.R_MIN + 1e-4:
						bad.append([seed_value, band, snappedf(u, 0.001)])
						break
					last = now
					u += du
		if int(seed_value) > 3: continue
		for channel in kind_of(shell, SHELL.Kind.CHANNEL):
			var record: Dictionary = shell.patches[channel]
			var length: float = (record.profile as Profile).length
			var top: float = shell.max_hang(state(channel, 0.0, 0.0))
			var aisle := Rect2(Vector2((record.origin as Vector3).x, (record.origin as Vector3).z), Vector2.ZERO)
			aisle = aisle.expand(Vector2((record.origin as Vector3).x, (record.origin as Vector3).z) + Vector2((record.axis as Vector3).x, (record.axis as Vector3).z) * float(record.length))
			aisle = aisle.grow(float(record.width) / 2.0 + 1e-4)
			for hang: float in [0.0, SHELL.CH_HANG, top]:
				var h := minf(hang, top)
				var du := 0.01
				var last: Vector3 = shell.anchor_of(state(channel, 0.0, float(record.length) / 2.0, 0.0, h))
				var u := du
				while u <= length + 1e-9:
					var now: Vector3 = shell.anchor_of(state(channel, u, float(record.length) / 2.0, 0.0, h))
					var rel: Vector3 = now - (record.origin as Vector3)
					var lateral: float = absf(rel.dot(record.across))
					var inside := lateral <= float(record.width) / 2.0 + 1e-4 and rel.y >= -1e-4 and rel.y <= float(record.height) + 1e-4
					if h > 0.0: inside = inside and lateral <= float(record.width) / 2.0 - 0.05 + 1e-4 and rel.y >= 0.05 - 1e-4 and rel.y <= float(record.height) - 0.05 + 1e-4
					if now.distance_to(last) > du * 1.001 + 1e-5 or not inside or not aisle.has_point(Vector2(now.x, now.z)):
						bad.append([seed_value, "pasillo", channel, snappedf(u, 0.001), h])
						break
					last = now
					u += du
	figures["min_radius"] = worst_radius
	check("Continuidad: franjas y pasillos sin saltos ni giros bruscos", bad.is_empty(), str(bad.slice(0, 6)))
	check("Continuidad: ninguna curva más cerrada que R_MIN", worst_radius >= SHELL.R_MIN, str(worst_radius))

func clearances() -> void:
	var bad: Array = []
	var nearest := INF
	var t := 2.0 * OFFICE.WALL_HALF
	var c := SHELL.BAND_CLEAR
	var bad_grilles: Array = []
	for seed_value in SEEDS:
		var shell = shells[seed_value]
		for band in door_bands(shell):
			var record: Dictionary = shell.patches[band]
			var profile: Profile = record.profile
			var h_a: float = shell.tray_height(int(record.rooms[0]))
			var h_b: float = shell.tray_height(int(record.rooms[1]))
			var lowest := INF
			for p: Vector2 in profile.sample(0.005):
				var edge := minf(p.distance_to(Vector2(-t / 2.0, SHELL.OPEN)), p.distance_to(Vector2(t / 2.0, SHELL.OPEN)))
				nearest = minf(nearest, edge)
				lowest = minf(lowest, p.y)
				var ceiling := h_a if p.x < 0.0 else h_b
				if edge < 0.8 * c or p.y > ceiling - c + 1e-4 or (absf(p.x) <= t / 2.0 and p.y > SHELL.OPEN - c + 1e-4):
					bad.append([seed_value, band, p])
					break
			if lowest < SHELL.OPEN - c - 1e-4: bad.append([seed_value, band, "bajo", lowest])
		var exits: Array = shell.manifest.ducts.exits
		for band in exit_bands(shell):
			var record: Dictionary = shell.patches[band]
			var end: Vector2 = (record.profile as Profile).at((record.profile as Profile).length)[0]
			var grille: float = float(exits[int(record.exit)].point[1]) - float(shell.rooms[int(record.rooms[0])].get("py", 0.0))
			if end.y - grille < 0.45 or end.y - grille > 0.65: bad_grilles.append([seed_value, band, end.y - grille])
	figures["head_edge_nearest"] = nearest
	check("Holguras: bajo un dintel la franja no roza sus aristas ni sube al techo", bad.is_empty(), str(bad.slice(0, 4)))
	check("Holguras: cada bajada a una rejilla acaba de 0,45 a 0,65 m sobre ella", bad_grilles.is_empty(), str(bad_grilles.slice(0, 4)))

# --- I and J: coverage and heights ------------------------------------------------

func coverage() -> void:
	var bad: Array = []
	for seed_value in SEEDS:
		var shell = shells[seed_value]
		var m: Dictionary = shell.manifest
		var off: Array = OFFICE.off_limits_rooms(m)
		for room in m.rooms:
			var wanted := not FLOOR.is_void(room) and not off.has(int(room.id))
			if shell.tray_of.has(int(room.id)) != wanted: bad.append([seed_value, "bandeja", int(room.id)])
		var merged := {}
		for pair in m.get("merged", []): merged[Vector2i(mini(int(pair[0]), int(pair[1])), maxi(int(pair[0]), int(pair[1])))] = true
		for edge in m.edges:
			var key := Vector2i(mini(int(edge[0]), int(edge[1])), maxi(int(edge[0]), int(edge[1])))
			var wanted: bool = not merged.has(key) and shell.tray_of.has(key.x) and shell.tray_of.has(key.y)
			if shell.band_of_pair.has(key) != wanted: bad.append([seed_value, "puerta", key])
		for band in kind_of(shell, SHELL.Kind.BAND):
			for r in shell.patches[band].rooms:
				if int(r) >= 0 and off.has(int(r)): bad.append([seed_value, "prohibida", band])
		var exits: Array = m.ducts.exits
		for i in exits.size():
			if String(exits[i].kind) == "wall" and shell.tray_of.has(int(exits[i].room)) and not shell.wall_band_of_exit.has(i): bad.append([seed_value, "rejilla", i])
		for unit in m.get("archives", []):
			for aisle in unit.aisles:
				var size := Vector2(float(aisle[2]) - float(aisle[0]), float(aisle[3]) - float(aisle[1]))
				var short := minf(size.x, size.y)
				var found := -1
				for channel in kind_of(shell, SHELL.Kind.CHANNEL):
					var record: Dictionary = shell.patches[channel]
					var o: Vector3 = record.origin
					# Its own unit's channel: another planta's aisle may lie over it in plan.
					if record.unit == unit.rooms and absf(float(record.width) - short) < 1e-4 and float(record.length) <= maxf(size.x, size.y) + 1e-4 and float(record.length) > 0.0 and Rect2(Vector2(float(aisle[0]), float(aisle[1])), size).grow(1e-4).has_point(Vector2(o.x, o.z)): found = channel
				var wanted := short < SHELL.CHANNEL_MAX and not bool(unit.get("mobile", false))
				if (found >= 0) != wanted: bad.append([seed_value, "pasillo", aisle])
		for band in kind_of(shell, SHELL.Kind.BAND):
			var record: Dictionary = shell.patches[band]
			for end in 2:
				var room := int(record.rooms[end])
				if room < 0: continue
				var at: Vector3 = shell.anchor_of(state(band, 0.0 if end == 0 else (record.profile as Profile).length, 0.0))
				if not (shell.patches[int(shell.tray_of[room])].rect as Rect2).grow(1e-4).has_point(Vector2(at.x, at.z)): bad.append([seed_value, "extremo", band, end])
		for channel in kind_of(shell, SHELL.Kind.CHANNEL):
			var record: Dictionary = shell.patches[channel]
			for v: float in [0.0, float(record.length) / 2.0, float(record.length)]:
				var p: Vector3 = (record.origin as Vector3) + (record.axis as Vector3) * v
				var inside := false
				for r in record.unit:
					if shell.tray_of.has(int(r)) and (shell.patches[int(shell.tray_of[int(r)])].rect as Rect2).grow(1e-4).has_point(Vector2(p.x, p.z)): inside = true
				if not inside: bad.append([seed_value, "pasillo fuera", channel, v])
	check("Cobertura: cada sala, puerta, rejilla y pasillo estrecho tiene su superficie, y ninguna sala prohibida", bad.is_empty(), str(bad.slice(0, 6)))
	var shell = SHELL.build(FIX.fixture())
	check("Cobertura: en el plano de prueba, tres techos, dos puertas y nada en la sala prohibida", shell.tray_of.size() == 3 and not shell.tray_of.has(3) and shell.band_of_pair.size() == 2 and not shell.band_of_pair.has(Vector2i(2, 3)) and shell.wall_band_of_exit.has(1) and shell.channels_of.get(2, []).size() == 1)

## The author's walls (M1) and lockers (M8).
func walls_and_lockers() -> void:
	var bad: Array = []
	var walls := 0
	var exposed := 0
	var lockers := 0
	for seed_value in SEEDS:
		var shell = shells[seed_value]
		for id in shell.tray_of:
			var room: Dictionary = shell.rooms[int(id)]
			if not OFFICE.false_ceiling(room):
				exposed += 1
				var strips: Array = shell.walls_of.get(int(id), [])
				for side in clean_sides(room):
					if not strips.any(func(b): return String(shell.patches[b].get("wall", "")) == side): bad.append([seed_value, "sin pared", int(id), side])
				for band in strips:
					walls += 1
					var record: Dictionary = shell.patches[band]
					var rect: Rect2 = OFFICE.ceiling_rect(room)
					for v: float in [-float(record.width) / 2.0, float(record.width) / 2.0]:
						var low: Vector3 = shell.anchor_of(state(band, (record.profile as Profile).length, v))
						if not rect.grow(-0.3).has_point(Vector2(low.x, low.z)) or absf(low.y - float(room.get("py", 0.0)) - SHELL.WALL_LOW) > 1e-4: bad.append([seed_value, "pared", band, v])
			elif shell.walls_of.has(int(id)): bad.append([seed_value, "pared con falso techo", int(id)])
			var hides: Array = room.get("hides", [])
			var fronts: Array = shell.lockers_of.get(int(id), [])
			if fronts.size() != hides.size(): bad.append([seed_value, "taquillas", int(id)])
			for band in fronts:
				lockers += 1
				var record: Dictionary = shell.patches[band]
				var hw := LAYOUT.hide_wall(hides[int(record.hide)])
				var locker := LAYOUT.wall_rect(room, String(hw.wall), float(hw.along), LAYOUT.LOCKER.x / 2.0, LAYOUT.LOCKER.y)
				var end: Vector3 = shell.anchor_of(state(band, (record.profile as Profile).length, 0.0))
				var local := Vector2(end.x - float(room.px), end.z - float(room.pz))
				var gap := locker.grow(SHELL.BAND_CLEAR + 0.01)
				if locker.has_point(local) or not gap.has_point(local) or absf(end.y - float(room.get("py", 0.0)) - (SHELL.LOCKER_SLOT + SHELL.FACE_OFFSET.z)) > 1e-4: bad.append([seed_value, "frente", band])
	figures["wall_strips"] = walls
	figures["exposed_rooms"] = exposed
	figures["locker_fronts"] = lockers
	check("Paredes y taquillas: las salas sin falso techo tienen paredes; cada taquilla, su frente hasta la rendija", bad.is_empty() and walls > 0 and lockers > 0, str(bad.slice(0, 6)))

## The walled sides of a room with nothing on them (no doorway, locker or
## furniture) and long enough for a strip: each must have one.
func clean_sides(room: Dictionary) -> Array:
	var out: Array = []
	var span := FLOOR.size_of(room)
	for side in ["west", "east", "north", "south"]:
		if room.get("open_sides", []).has(side): continue
		var half: float = span.y / 2.0 if side == "west" or side == "east" else span.x / 2.0
		if 2.0 * (half - OFFICE.WALL_HALF - SHELL.WALL_CORNER) < SHELL.WALL_MIN: continue
		if FLOOR.doorways(room).any(func(w): return String(w.wall) == side): continue
		if room.get("hides", []).any(func(h): return String(LAYOUT.hide_wall(h).wall) == side): continue
		var face := LAYOUT.face(room, side)
		var touched := false
		for item in room.get("furniture", []):
			var foot := LAYOUT.footprint(item)
			var gap: float = foot.position.x - face if side == "west" else face - foot.end.x if side == "east" else foot.position.y - face if side == "north" else face - foot.end.y
			if gap <= SHELL.BAND_CLEAR + 0.3: touched = true
		if not touched: out.append(side)
	return out

func heights() -> void:
	var want := {3: 2.95, 5: 2.95, 12: 3.05, 22: 3.05, 23: 3.05}
	var bad: Array = []
	var seen := {}
	for seed_value in SEEDS:
		var shell = shells[seed_value]
		for id in shell.tray_of:
			var room: Dictionary = shell.rooms[int(id)]
			if not want.has(int(room.type)): continue
			seen[int(room.type)] = true
			if absf(shell.tray_height(int(id)) - float(want[int(room.type)])) > 1e-4: bad.append([seed_value, int(id), int(room.type)])
	check("Alturas: despacho y sala de juntas 2,95, pasillo de servicio, climatización y máquinas 3,05", bad.is_empty() and seen.size() == want.size(), str(bad.slice(0, 4)) + " " + str(seen.keys()))

# --- I2: lamps and the cue ---------------------------------------------------------

func lamps_and_cue() -> void:
	var bad: Array = []
	var none_clear := 0
	for seed_value in SEEDS:
		var shell = shells[seed_value]
		for id in shell.tray_of:
			var room: Dictionary = shell.rooms[int(id)]
			var p: Vector2 = shell.clear_point(int(id), float(room.px), float(room.pz))
			var lamps: PackedVector2Array = shell.lamps_of[int(id)]
			var rect: Rect2 = shell.patches[int(shell.tray_of[int(id)])].rect
			if shell.clear_of(p, lamps, rect): continue
			none_clear += 1
			# Nowhere clear: nothing on a grid is farther from its nearest lamp.
			var mine := INF
			for lamp in lamps: mine = minf(mine, p.distance_to(lamp))
			var x := rect.position.x
			while x <= rect.end.x:
				var z := rect.position.y
				while z <= rect.end.y:
					var d := INF
					for lamp in lamps: d = minf(d, Vector2(x, z).distance_to(lamp))
					if d >= SHELL.LAMP_CLEAR - 1e-6 or d > mine + 0.08: bad.append([seed_value, int(id)])
					z += 0.1
				x += 0.1
	figures["rooms_with_no_clear_point"] = none_clear
	check("Lámparas: cada parada por defecto queda a un metro de las lámparas, o lo más lejos posible", bad.is_empty(), str(bad.slice(0, 4)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var shares := {}
	var short_rooms := {}
	var bad_poses: Array = []
	for eye_height: float in [1.64, 0.9]:
		var tried := 0
		var posed := 0
		var lowered := 0
		for seed_value in [1, 2, 3]:
			var shell = shells[seed_value]
			for id in shell.tray_of:
				var room: Dictionary = shell.rooms[int(id)]
				var rect: Rect2 = OFFICE.ceiling_rect(room)
				var room_posed := 0
				var room_tried := 0
				for i in 20:
					var eye := Vector3(rng.randf_range(rect.position.x, rect.end.x), float(room.get("py", 0.0)) + eye_height, rng.randf_range(rect.position.y, rect.end.y))
					var yaw := rng.randf_range(-PI, PI)
					var view := Vector3(sin(yaw), 0, cos(yaw))
					for d: float in [1.6, 2.4, 3.2]:
						tried += 1
						room_tried += 1
						var s: State = shell.cue_pose(eye, view, d)
						if s == null: continue
						posed += 1
						room_posed += 1
						if s.lowered: lowered += 1
						var face: Vector3 = shell.face_of(s)
						var plan := Vector2(face.x - eye.x, face.z - eye.z).length()
						if atan2(face.y - eye.y, plan) > SHELL.CUE_ANGLE + 1e-5 or s.hang > shell.max_hang(s) + 1e-6: bad_poses.append([seed_value, int(id), eye_height, d])
				if eye_height > 1.0 and room_posed < room_tried: short_rooms["%d:%d" % [int(seed_value), int(id)]] = snappedf(float(room_posed) / float(room_tried), 0.01)
		shares["%0.2f" % eye_height] = {"tried": tried, "posed": snappedf(float(posed) / float(maxi(tried, 1)), 0.001), "lowered": snappedf(float(lowered) / float(maxi(tried, 1)), 0.001)}
	figures["cue"] = shares
	figures["cue_rooms_under_full"] = short_rooms
	check("El aviso: cada postura deja la cara a 15 grados como mucho sobre los ojos", bad_poses.is_empty(), str(bad_poses.slice(0, 4)))
	check("El aviso: a una víctima agachada también se le pone delante, bajando", float(shares["0.90"].posed) > 0.5 and float(shares["0.90"].lowered) > 0.0, str(shares))

# --- K, L and M: the fixture, points and determinism ------------------------------------

func fixture_cases() -> void:
	var shell = SHELL.build(FIX.fixture())
	var s: State = shell.tray_state(0, 0.0, 0.0)
	var before: Vector3 = shell.anchor_of(s)
	var moved: float = shell.advance(s, 1.0)
	check("Avanzar: un metro por un techo mueve el ancla un metro", absf(moved - 1.0) < 1e-6 and absf(shell.anchor_of(s).distance_to(before) - 1.0) < 1e-6)
	var wall: State = shell.tray_state(0, -3.0, 0.0)
	wall.heading = PI
	var short: float = shell.advance(wall, 1.0)
	check("Avanzar: contra una pared se para dentro de su techo", short < 1.0 and (shell.patches[int(shell.tray_of[0])].rect as Rect2).grow(1e-6).has_point(Vector2(wall.u, wall.v)), str(short))
	var open = SHELL.build(FIX.fixture(true))
	var across: State = open.tray_state(0, 3.0, 0.0)
	var start: Vector3 = open.anchor_of(across)
	var went: float = open.advance(across, 2.0)
	check("Avanzar: por un lado abierto pasa al techo vecino en el mismo punto", across.patch == int(open.tray_of[1]) and absf(went - 2.0) < 1e-6 and open.anchor_of(across).distance_to(start + Vector3(2, 0, 0)) < 1e-6, "%d %f" % [across.patch, went])
	var band: int = shell.band_of_pair[Vector2i(0, 1)]
	var on_band: State = shell.band_start(band, 0)
	var sum := 0.0
	var last: Vector3 = shell.anchor_of(on_band)
	for i in 1000:
		shell.advance(on_band, 0.001)
		var now: Vector3 = shell.anchor_of(on_band)
		sum += now.distance_to(last)
		last = now
	check("Avanzar: un metro por una franja es un metro de su curva", absf(sum - 1.0) < 1e-3, str(sum))
	var rng := RandomNumberGenerator.new()
	rng.seed = 200
	var seeded = shells[1]
	var ids: Array = seeded.tray_of.keys()
	ids.sort()
	var bad: Array = []
	for i in 200:
		var id: int = ids[rng.randi_range(0, ids.size() - 1)]
		var room: Dictionary = seeded.rooms[id]
		var cell := Rect2(Vector2(float(room.px), float(room.pz)) - FLOOR.size_of(room) * 0.45, FLOOR.size_of(room) * 0.9)
		var p := Vector3(rng.randf_range(cell.position.x, cell.end.x), float(room.get("py", 0.0)) + 1.5, rng.randf_range(cell.position.y, cell.end.y))
		var found := int(FLOOR.room_at(seeded.rooms, p).get("id", -1))
		var at: State = seeded.state_at(p)
		if not seeded.tray_of.has(found): continue
		var rect: Rect2 = seeded.patches[int(seeded.tray_of[found])].rect
		if at == null or at.patch != int(seeded.tray_of[found]) or absf(at.u - clampf(p.x, rect.position.x, rect.end.x)) > 1e-6 or absf(at.v - clampf(p.z, rect.position.y, rect.end.y)) > 1e-6 or absf(at.hang - 0.35) > 1e-9: bad.append([id, p])
	var in_off: State = shell.state_at(Vector3(20.4, 1.0, 0.0))
	check("Estado en un punto: el techo de la sala donde está, y desde una sala prohibida, el más cercano", bad.is_empty() and in_off != null and in_off.patch == int(shell.tray_of[2]), str(bad.slice(0, 3)))
	var mouth: State = shell.channel_mouth(int(shell.channels_of[2][0]))
	var mouth_at: Vector3 = shell.anchor_of(mouth)
	check("El pasillo de archivo: se entra por el lado del lomo, hacia dentro y a media altura del techo", absf(mouth_at.z - 0.8) < 1e-4 and absf(mouth_at.x - 8.5) < 1e-4 and shell.heading_vector(mouth).distance_to(Vector3.BACK) < 1e-6 and absf(mouth.hang - 0.3) < 1e-6, str(mouth_at))

func determinism() -> void:
	var a = SHELL.build(GEN.new().generate(7, 2))
	var b = SHELL.build(GEN.new().generate(7, 2))
	check("Determinismo: la misma semilla da la misma cáscara", JSON.stringify(a.dump()) == JSON.stringify(b.dump()))
	check("Determinismo: en el hotel no hay cáscara", SHELL.build(HOTEL_GEN.new().generate(7)) == null)

## The author's plenum (M7): her sound out of the tile under her.
func plenum() -> void:
	var shell = SHELL.build(FIX.fixture())
	var mouth: Vector3 = shell.plenum_mouth(Vector3(1.0, 3.7, 1.0))
	check("El plénum: se la oye por la placa que tiene debajo", absf(mouth.y - 2.95) < 1e-6 and absf(mouth.x - 0.9) < 1e-6 and absf(mouth.z - 0.9) < 1e-6, str(mouth))
	var seeded = shells[1]
	var exposed := -1
	for id in seeded.tray_of:
		if not OFFICE.false_ceiling(seeded.rooms[int(id)]):
			exposed = int(id)
			break
	var room: Dictionary = seeded.rooms[exposed]
	var point := Vector3(float(room.px), float(room.get("py", 0.0)) + 3.7, float(room.pz))
	check("El plénum: donde no hay falso techo, el sonido sale de donde está", seeded.plenum_mouth(point) == point)

func text() -> void:
	var bad: Array = []
	for path in ["res://game/enemies/lurker/lurker_shell.gd", "res://game/enemies/lurker/lurker_routes.gd", "res://game/enemies/lurker/lurker_motion.gd", "res://game/enemies/lurker/lurker.gd", "res://tools/dev/lurker_route_probe.gd", "res://tests/office/lurker_fixture.gd", "res://game/enemies/lurker/duct_graph.gd", "res://game/world/generation/conduit_graph.gd"]:
		var body := FileAccess.get_file_as_string(path)
		if body.contains(char(0xB7)) or body.contains(char(0x2014)): bad.append(path)
	check("Texto: ni punto medio ni guion largo en los guiones nuevos", bad.is_empty(), str(bad))

# --- O: routes, on a stub level ---------------------------------------------------------

func kinds_of(legs: Array) -> Array:
	return legs.map(func(leg): return String(leg.kind))

## The 6.2 cost of a door edge from the shell's lengths, by hand.
func door_cost(routes, a: int, b: int, factor_a := 1.0, factor_b := 1.0) -> float:
	var shell = routes.shell
	var band: int = shell.band_of_pair[ROUTES.key_of(a, b)]
	var half: float = shell.patches[band].profile.length / 2.0
	var near: Vector3 = shell.anchor_of(shell.band_start(band, a))
	var far: Vector3 = shell.anchor_of(shell.band_start(band, b))
	var ma: float = routes.plan_point(a).distance_to(Vector2(near.x, near.z)) + half
	var mb: float = half + Vector2(far.x, far.z).distance_to(routes.plan_point(b))
	return (ma * factor_a + mb * factor_b) / ROUTES.CRAWL_SPEED + ROUTES.PORTAL_COST

func door_metres(routes, a: int, b: int) -> Array:
	var shell = routes.shell
	var band: int = shell.band_of_pair[ROUTES.key_of(a, b)]
	var half: float = shell.patches[band].profile.length / 2.0
	var near: Vector3 = shell.anchor_of(shell.band_start(band, a))
	var far: Vector3 = shell.anchor_of(shell.band_start(band, b))
	return [routes.plan_point(a).distance_to(Vector2(near.x, near.z)) + half, half + Vector2(far.x, far.z).distance_to(routes.plan_point(b))]

## The doors, the grilles and the ducts, without the plenum over the false
## ceilings (any tile a way in and out: lurker_tiles_test.gd).
func route_cases() -> void:
	var m := FIX.fixture()
	var lvl := FIX.stub_level(m)
	var routes = FIX.routes_on(m, lvl, false)
	var shell = routes.shell
	var open_plan: Dictionary = routes.plan({"room": 0}, {"room": 2})
	var v_ok := true
	for leg in open_plan.legs:
		if String(leg.kind) == "band" and absf(absf(float(leg.v)) - ROUTES.DOOR_SIDE) > 1e-9: v_ok = false
		if String(leg.kind) == "band" and float(leg.v) < 0.0: v_ok = false
	var by_hand: float = door_cost(routes, 0, 1) + door_cost(routes, 1, 2)
	check("Rutas: con todo abierto y a oscuras va de puerta en puerta", bool(open_plan.ok) and kinds_of(open_plan.legs) == ["tray", "band", "tray", "band", "tray"] and open_plan.pairs == [Vector2i(0, 1), Vector2i(1, 2)], str(kinds_of(open_plan.legs)) + " " + str(open_plan.pairs))
	check("Rutas: por cada puerta pasa a un palmo del centro, lejos de la bisagra", v_ok)
	check("Rutas: lo que cuesta es la cuenta de 6.2", absf(float(open_plan.cost) - by_hand) < 1e-4, "%f %f" % [float(open_plan.cost), by_hand])
	# Door 1-2 shut: by the ducts.
	var door_12: FIX.StubDoor = lvl.hotel.doors["Door_1_2"]
	door_12.opened = false
	var shut_plan: Dictionary = routes.plan({"room": 0}, {"room": 2})
	var kinds := kinds_of(shut_plan.legs)
	check("Rutas: con la puerta cerrada entra por la rejilla del techo y sale por la de la pared", bool(shut_plan.ok) and kinds.has("squeeze") and kinds.has("duct") and kinds.count("squeeze") == 2 and kinds.has("band") and not shut_plan.pairs.has(Vector2i(1, 2)), str(kinds))
	var duct_metres := 0.0
	for leg in shut_plan.legs:
		if String(leg.kind) == "duct":
			for k in range(1, (leg.nodes as PackedInt32Array).size()): duct_metres += float(routes.ducts.edges[routes.ducts.edge_between(leg.nodes[k - 1], leg.nodes[k])][2])
	var timed := true
	var base := -1.0
	for speed: float in [1.2, 1.6, 2.0, 2.4]:
		routes.duct_speed = speed
		var c: float = float(routes.plan({"room": 0}, {"room": 2}).cost) - duct_metres / speed
		if base < 0.0: base = c
		elif absf(c - base) > 1e-6: timed = false
	routes.duct_speed = 1.6
	check("Rutas: por los ductos tarda sus metros entre la velocidad de su dificultad", timed and duct_metres > 0.0, str(duct_metres))
	var duct_cost: float = float(routes.plan({"room": 0}, {"room": 2}).cost)
	door_12.opened = true
	lvl.hotel.lit_rooms[1] = true
	var metres := door_metres(routes, 0, 1)
	var metres_b := door_metres(routes, 1, 2)
	var lit_door: float = by_hand + (ROUTES.LIT_FACTOR - 1.0) * (float(metres[1]) + float(metres_b[0])) / ROUTES.CRAWL_SPEED
	var lit_plan: Dictionary = routes.plan({"room": 0}, {"room": 2})
	check("Rutas: una sala con luz encarece el paso y elige el camino más barato", absf(float(lit_plan.cost) - minf(lit_door, duct_cost)) < 1e-4, "%f %f %f" % [float(lit_plan.cost), lit_door, duct_cost])
	var replanned: float = routes.path_cost({"room": 0}, open_plan.nodes)
	check("Rutas: recalculado con la luz, el plan viejo cuesta lo que dice la cuenta", absf(replanned - lit_door) < 1e-4, "%f %f" % [replanned, lit_door])
	lvl.hotel.lit_rooms.erase(1)
	var never := true
	for goal in [0, 1, 2]:
		for from in [0, 1, 2]:
			if (routes.plan({"room": from}, {"room": goal}).nodes as PackedInt32Array).has(3): never = false
	check("Rutas: nunca pasa por la sala prohibida ni llega a ella", never and not bool(routes.plan({"room": 0}, {"room": 3}).ok) and not routes.travel_metres(0).has(3))
	var hand_1: float = door_metres(routes, 0, 1)[0] + door_metres(routes, 0, 1)[1]
	var hand_2: float = hand_1 + door_metres(routes, 1, 2)[0] + door_metres(routes, 1, 2)[1]
	var travel: Dictionary = routes.travel_metres(0)
	check("Rutas: los metros a cada sala, con todo abierto, son los de las puertas", absf(float(travel.get(1, INF)) - hand_1) < 1e-4 and absf(float(travel.get(2, INF)) - hand_2) < 1e-4, str(travel))
	var door_01: FIX.StubDoor = lvl.hotel.doors["Door_0_1"]
	door_01.swung.emit(false, false, false)
	door_01.opened = false
	check("Rutas: una puerta que se cierra queda apuntada con su fotograma", routes.last_shut == Vector2i(0, 1) and routes.shut_frame >= 0)
	var shut_travel: Dictionary = routes.travel_metres(0)
	check("Rutas: con la puerta cerrada, los metros van por los ductos", float(shut_travel.get(2, 0.0)) > hand_2 and float(shut_travel.get(1, 0.0)) > hand_1, str(shut_travel))
	await physics_frame
	var signature: int = routes.door_signature(0)
	var epoch: int = routes.door_epoch
	door_01.opened = true
	await physics_frame
	var after: int = routes.door_signature(0)
	check("Rutas: una puerta que cambia sin señal se nota igual", after != signature and routes.door_epoch > epoch and absf(float(routes.travel_metres(0).get(1, INF)) - hand_1) < 1e-4)
	var p := Vector3(1.0, 3.7, 0.0)
	var duct_plan: Dictionary = routes.plan({"duct": [0, 1], "metres": [1.0, 4.2], "point": p}, {"room": 0})
	var first_duct: Dictionary = {}
	for leg in duct_plan.legs:
		if String(leg.kind) == "duct" and first_duct.is_empty(): first_duct = leg
	check("Rutas: desde dentro de un ducto vuelve por donde es más corto, desde su punto", bool(duct_plan.ok) and duct_plan.nodes[0] == routes.room_count + 0 and not first_duct.is_empty() and (first_duct.points as PackedVector3Array)[0] == p, str(duct_plan.nodes))
	var merged_m := FIX.fixture(true)
	var merged_routes = FIX.routes_on(merged_m, FIX.stub_level(merged_m))
	merged_routes.door_nodes[Vector2i(1, 2)] = null
	merged_routes.report_missing = false
	check("Rutas: un lado abierto está abierto sin puerta; una puerta que no se encuentra, cerrada", merged_routes.door_open(Vector2i(0, 1)) and not merged_routes.door_open(Vector2i(1, 2)) and merged_routes.missing_reported.has(Vector2i(1, 2)))
	var merged_plan: Dictionary = merged_routes.plan({"room": 0}, {"room": 1})
	check("Rutas: por un lado abierto va de un techo al otro sin franja", bool(merged_plan.ok) and not kinds_of(merged_plan.legs).has("band") and merged_plan.pairs.is_empty(), str(kinds_of(merged_plan.legs)))
	for door in lvl.hotel.doors.values(): door.opened = true
	routes.teardown()
	var connected := false
	for door in lvl.hotel.doors.values():
		if door.swung.get_connections().size() > 0: connected = true
	check("Rutas: al desmontarlas sueltan cada puerta", not connected)

## Rule 5: where the main or a cross meets the network, a vertical step.
func duct_steps() -> void:
	var m: Dictionary = shells[7].manifest
	var lvl := FIX.stub_level(m)
	var routes = FIX.routes_on(m, lvl)
	var ducts = routes.ducts
	var found := []
	for n in ducts.nodes.size():
		var low := -1
		var high := -1
		for link in ducts.adjacency[n]:
			var kind: String = ducts.edges[int(link[2])][3]
			if ducts.visible_kinds.has(kind): low = int(link[0])
			elif kind != "drop": high = int(link[0])
		if low >= 0 and high >= 0:
			found = [high, n, low]
			break
	if found.is_empty():
		check("Rutas: un paso vertical donde el conducto principal se junta con la red", false, "sin nudo")
		return
	var leg: Dictionary = routes.duct_leg(PackedInt32Array(found), Vector3.INF)
	var points: PackedVector3Array = leg.points
	var vertical := false
	var short := true
	for i in range(1, points.size()):
		var step := points[i] - points[i - 1]
		if Vector2(step.x, step.z).length() < 1e-4 and absf(step.y) > 0.1: vertical = true
		if step.length() > float(ducts.edges[ducts.edge_between(found[0], found[1])][2]) + float(ducts.edges[ducts.edge_between(found[1], found[2])][2]) + 1e-4: short = false
	check("Rutas: un paso vertical donde el conducto principal se junta con la red", vertical and short and (leg.kinds as PackedStringArray).size() == points.size() - 1, str(points))

func route_seeds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var bad: Array = []
	var plans := 0
	for seed_value in [1, 2, 3, 4, 5]:
		var m: Dictionary = shells[seed_value].manifest
		var lvl := FIX.stub_level(m)
		var routes = FIX.routes_on(m, lvl)
		var off: Array = OFFICE.off_limits_rooms(m)
		var with_exit := {}
		for e in routes.ducts.exits: with_exit[int(e.room)] = true
		for wing in 3:
			var ids: Array = routes.shell.tray_of.keys().filter(func(r): return int(m.rooms[int(r)].get("wing", -1)) == wing)
			ids.sort()
			if ids.size() < 2: continue
			for i in 20:
				var a: int = ids[rng.randi_range(0, ids.size() - 1)]
				var b: int = ids[rng.randi_range(0, ids.size() - 1)]
				for door in lvl.hotel.doors.values(): door.opened = true
				var open_plan: Dictionary = routes.plan({"room": a}, {"room": b})
				plans += 1
				if not bool(open_plan.ok): bad.append([seed_value, a, b, "abierto", open_plan.why])
				for door in lvl.hotel.doors.values(): door.opened = false
				var shut_plan: Dictionary = routes.plan({"room": a}, {"room": b})
				plans += 1
				if with_exit.has(a) and with_exit.has(b) and (not bool(shut_plan.ok) or not shut_plan.pairs.is_empty()): bad.append([seed_value, a, b, "cerrado", shut_plan.why])
				for plan in [open_plan, shut_plan]:
					for n in plan.nodes:
						if int(n) < routes.room_count and off.has(int(n)): bad.append([seed_value, a, b, "prohibida"])
		routes.teardown()
	figures["route_plans"] = plans
	check("Rutas: en cinco semillas, con puertas abiertas o cerradas, llega y nunca por una sala prohibida", bad.is_empty(), str(bad.slice(0, 5)))
	var m7: Dictionary = shells[7].manifest
	var routes7 = FIX.routes_on(m7, FIX.stub_level(m7))
	var draws: Array = []
	var shares_ok := true
	var walk := FLOOR.route_metres(m7, FLOOR.entry_of(m7, 1))
	var top := 0.0
	for r in walk:
		if routes7.shell.tray_of.has(int(r)) and int(m7.rooms[int(r)].get("wing", -1)) == 1: top = maxf(top, float(walk[r]))
	var rng3 := RandomNumberGenerator.new()
	rng3.seed = 3
	for i in 50:
		var e: int = routes7.arrival_exit(1, rng3)
		draws.append(e)
		if e < 0: shares_ok = false
		else:
			var share := float(walk.get(int(routes7.ducts.exits[e].room), 0.0)) / top
			if share < ROUTES.ARRIVE_BAND.x - 1e-9 or share > ROUTES.ARRIVE_BAND.y + 1e-9: shares_ok = false
	var again := RandomNumberGenerator.new()
	again.seed = 3
	var same := true
	for i in 50:
		if routes7.arrival_exit(1, again) != draws[i]: same = false
	check("Rutas: sale lejos del vestíbulo, entre la mitad y nueve décimos del camino, y siempre igual", shares_ok and same)
	routes7.teardown()
