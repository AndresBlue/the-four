extends RefCounted
## What a tape was worth: the points of each survivor, what the team earned
## together, the mark it gets, who was worth most, the part each one played
## and which of the floor's milestones it reached. All of it is read out of
## the line a floor leaves (game/app/run_ledger.gd writes it), and nothing
## here keeps anything: the same line always gives the same answer, so a tape
## can be read again years later, on any machine.
##
## The line is settled once, by whoever ran the floor (settle()), and what it
## says travels with it: a rule changed later does not rewrite old tapes.

## What each thing a survivor did is worth. Objectives weigh most, because
## they are what gets a team out; staying alive is next; the rest is colour.
const TV := 150
const DIGIT := 200
const CODE := 250
const SEARCH := 10
const ROOM := 5
const ESCAPE := 120
const SECTOR := 150
const OUT := 300
const INTACT := 250
const DEATH := -200
## Past these, more of the same is worth nothing: going through every drawer of
## the floor, or being chased round a table all night, is not a way to win.
const SEARCH_CAP := 30
const ROOM_CAP := 60
const ESCAPE_CAP := 5

## What the team earns together, once the floor is won: a second under PAR is
## TIME_RATE points, up to TIME_CAP.
const TIME_RATE := 1.0
const TIME_CAP := 1500
const CLEAN := 500
const BRAVE := 300
const WHOLE := 300
const COLLAPSE := -300

## The mark: the points of the tape, brought to what one survivor alone would
## make of them (a team shares the objectives, so it scores less per head; each
## one past the first counts SHARE of a whole one), against these floors.
const SHARE := 0.3
const GRADES := [["S", 4800], ["A", 4000], ["B", 3200], ["C", 2400]]
const LOWEST := "D"

## The parts a survivor can have played. In a team each goes to whoever leads
## its count, if the count reaches `least`, and nobody gets two: first the
## parts whose leader is still without one, in this order, and then what is
## left among those still without. Alone, where one survivor does every errand
## there is, the errands say nothing: the part is the one of the others (the
## ones with a `mark`: what would be a lot of it on a whole floor) that was
## done most against its mark. `why` says it in words ("%t" takes the count as
## a time), and `once` says it when the count is one.
const TITLES := [
	{"title": "CERRAJERO", "stat": "code", "least": 1, "why": "marcó el código de la última puerta"},
	{"title": "ELECTRICISTA", "stat": "tvs", "least": 2, "why": "encendió %d televisores"},
	{"title": "SABUESO", "stat": "digits", "least": 2, "why": "encontró %d números del código"},
	{"title": "ESCAPISTA", "stat": "escapes", "least": 2, "mark": 3, "why": "se le escapó %d veces a la criatura"},
	{"title": "CEBO", "stat": "chased", "least": 45, "mark": 90, "why": "%t con la criatura detrás"},
	{"title": "EL DEL ARMARIO", "stat": "hidden", "least": 60, "mark": 120, "why": "%t dentro de un armario"},
	{"title": "MANOS LARGAS", "stat": "searched", "least": 8, "mark": 20, "why": "registró %d muebles"},
	{"title": "EXPLORADOR", "stat": "rooms", "least": 25, "mark": 70, "why": "pisó %d salas"},
	{"title": "MARATONISTA", "stat": "metres", "least": 600, "mark": 2500, "why": "anduvo %d metros"},
	{"title": "AL BORDE", "stat": "burnt", "least": 1, "mark": 1, "why": "se quedó sin cordura %d veces", "once": "se quedó sin cordura"},
	{"title": "CARNE DE CAÑÓN", "stat": "deaths", "least": 2, "mark": 2, "why": "cayó %d veces"},
]

static func count(member: Dictionary, key: String) -> int:
	return int(member.get(key, 0))

## What one survivor's points are made of: [what, how many, points], only the
## rows that count for something.
static func breakdown(member: Dictionary) -> Array:
	var rows: Array = []
	add(rows, "Televisores encendidos", count(member, "tvs"), TV)
	add(rows, "Números del código", count(member, "digits"), DIGIT)
	add(rows, "Código marcado", count(member, "code"), CODE)
	add(rows, "Sectores cerrados en pie", count(member, "sectors"), SECTOR)
	add(rows, "Salidas", count(member, "escapes"), ESCAPE, ESCAPE_CAP)
	add(rows, "Muebles registrados", count(member, "searched"), SEARCH, SEARCH_CAP)
	add(rows, "Salas pisadas", count(member, "rooms"), ROOM, ROOM_CAP)
	if bool(member.get("escaped", false)):
		rows.append(["Salió del piso", 1, OUT])
		if count(member, "deaths") == 0: rows.append(["Sin morir ni una vez", 1, INTACT])
	add(rows, "Muertes", count(member, "deaths"), DEATH)
	return rows

static func add(rows: Array, what: String, many: int, each: int, cap := 0) -> void:
	if many != 0: rows.append([what, many, (mini(many, cap) if cap > 0 else many) * each])

static func member_score(member: Dictionary) -> int:
	var total := 0
	for row in breakdown(member): total += int(row[2])
	return maxi(total, 0)

static func won(line: Dictionary) -> bool:
	return String(line.get("result", "won")) == "won"

## What the team earned together: [what, points]. Nothing on a floor that was
## lost: there is no time to beat on a tape that never got out.
static func bonuses(line: Dictionary) -> Array:
	if not won(line): return []
	var rows: Array = []
	var par := float(line.get("par", 0.0))
	var spare := par - float(line.get("time", 0.0))
	if par > 0.0 and spare > 0.0: rows.append(["Tiempo bajo la marca", mini(int(spare * TIME_RATE), TIME_CAP)])
	var players := int(line.get("players", 1))
	if int(line.get("deaths", 0)) == 0 and int(line.get("escaped", 0)) >= players: rows.append(["Sin bajas", CLEAN])
	if int(line.get("hides", 0)) == 0: rows.append(["Sin esconderse", BRAVE])
	if players > 1 and int(line.get("escaped", 0)) >= players: rows.append(["Equipo entero", WHOLE])
	if int(line.get("restarts", 0)) > 0: rows.append(["Derrumbe", COLLAPSE])
	return rows

static func total(line: Dictionary) -> int:
	var sum := 0
	for member in line.get("team", []): sum += member_score(member)
	for row in bonuses(line): sum += int(row[1])
	return maxi(sum, 0)

## The mark of a tape that got out; "" for one that did not.
static func grade(line: Dictionary) -> String:
	if not won(line): return ""
	var heads := 1.0 + SHARE * float(maxi(int(line.get("players", 1)), 1) - 1)
	var level := float(line.get("score", total(line))) / heads
	for step in GRADES:
		if level >= float(step[1]): return String(step[0])
	return LOWEST

## Whether mark `a` is at least as good as `b` ("S" over "A" over ... over "D").
static func grade_at_least(a: String, b: String) -> bool:
	var order := ["S", "A", "B", "C", "D"]
	return order.has(a) and order.has(b) and order.find(a) <= order.find(b)

## The seat that was worth most to a team: the most points, and between equals
## whoever fell less, then whoever sat first. Nobody on a floor played alone.
static func mvp(team: Array) -> int:
	if team.size() < 2: return 0
	var best: Dictionary = {}
	for member in team:
		if best.is_empty() or better(member, best): best = member
	return int(best.get("seat", 0))

static func better(a: Dictionary, b: Dictionary) -> bool:
	var points_a := int(a.get("score", member_score(a)))
	var points_b := int(b.get("score", member_score(b)))
	if points_a != points_b: return points_a > points_b
	if count(a, "deaths") != count(b, "deaths"): return count(a, "deaths") < count(b, "deaths")
	return int(a.get("seat", 0)) < int(b.get("seat", 0))

## The part each one played: seat -> [title, why]. One each, and no part twice.
static func titles(line: Dictionary) -> Dictionary:
	var team: Array = line.get("team", [])
	var given := {}
	if team.size() == 1:
		var alone: Dictionary = team[0]
		var most: Dictionary = {}
		var reach := 0.0
		for part in TITLES:
			if not part.has("mark") or count(alone, part.stat) < int(part.least): continue
			var against := float(count(alone, part.stat)) / float(part.mark)
			if against > reach:
				reach = against
				most = part
		if not most.is_empty(): given[int(alone.get("seat", 0))] = [String(most.title), said(most, count(alone, most.stat))]
	else:
		var taken := {}
		for turn in 2:
			for part in TITLES:
				if taken.has(part.title): continue
				var leader: Dictionary = {}
				for member in team:
					if count(member, part.stat) < int(part.least) or (turn == 1 and given.has(int(member.get("seat", 0)))): continue
					if leader.is_empty() or count(member, part.stat) > count(leader, part.stat) or (count(member, part.stat) == count(leader, part.stat) and better(member, leader)): leader = member
				if leader.is_empty() or given.has(int(leader.get("seat", 0))): continue
				given[int(leader.get("seat", 0))] = [String(part.title), said(part, count(leader, part.stat))]
				taken[part.title] = true
	# Whoever did nothing that has a name: what became of them.
	for member in team:
		var seat := int(member.get("seat", 0))
		if given.has(seat): continue
		if not bool(member.get("escaped", false)): given[seat] = ["SE QUEDÓ ATRÁS", "no salió del piso"]
		elif String(line.get("mode", "")) != "versus" and member.has("chases") and count(member, "chases") == 0: given[seat] = ["FANTASMA", "la criatura no llegó a perseguirle"]
		else: given[seat] = ["SUPERVIVIENTE", "salió del piso"]
	return given

## Why a part is somebody's, with the count it was given for.
static func said(part: Dictionary, amount: int) -> String:
	var why := String(part.get("once", part.why) if amount == 1 else part.why).replace("%t", clock(amount))
	return why % amount if why.contains("%d") else why

## Minutes and seconds, for the parts that are counted in time.
static func clock(seconds: int) -> String:
	return "%d:%02d" % [seconds / 60, seconds % 60]

## The line as it will be kept: every survivor's points and part, the tape's
## points and mark, and who was worth most. Done by whoever ran the floor.
static func settle(line: Dictionary) -> Dictionary:
	var parts := titles(line)
	for member in line.get("team", []):
		member["score"] = member_score(member)
		var part: Array = parts.get(int(member.get("seat", 0)), ["", ""])
		member["title"] = part[0]
		member["why"] = part[1]
	line["score"] = total(line)
	line["grade"] = grade(line)
	line["mvp"] = mvp(line.get("team", [])) if won(line) else 0
	return line

## The member of a line sitting in a seat, or nothing.
static func member_of(line: Dictionary, seat: int) -> Dictionary:
	for member in line.get("team", []):
		if int(member.get("seat", -1)) == seat: return member
	return {}

## The milestones of a floor (its kind's MILESTONES) this tape reached, for
## whoever sat in `seat`: the ids, in the floor's own order.
static func earned(milestones: Array, line: Dictionary, seat: int) -> Array:
	var ids: Array = []
	for milestone in milestones:
		if meets(milestone.get("rule", []), line, seat): ids.append(String(milestone.id))
	return ids

## One rule of a milestone against a tape. Everything but the hunter's own asks
## for a floor that was won; what is said of "me" asks that I got out of it.
static func meets(rule: Array, line: Dictionary, seat: int) -> bool:
	if rule.is_empty(): return false
	var kind := String(rule[0])
	var versus := String(line.get("mode", "")) == "versus"
	if kind == "hunter_won": return versus and not won(line) and int(line.get("hunter", {}).get("seat", 0)) == seat and seat != 0
	if not won(line): return false
	var players := int(line.get("players", 1))
	var everyone := int(line.get("escaped", 0)) >= players
	var me := member_of(line, seat)
	var out := not me.is_empty() and bool(me.get("escaped", false))
	match kind:
		"won": return true
		"solo": return players == 1 and not versus
		"clean": return players > 1 and everyone and int(line.get("deaths", 0)) == 0
		"brave": return int(line.get("hides", 0)) == 0
		"time_under": return float(line.get("time", 0.0)) < float(rule[1])
		"team_out": return players >= int(rule[1]) and everyone
		"restarted": return int(line.get("restarts", 0)) > 0
		"mine": return out and count(me, String(rule[1])) >= int(rule[2])
		"unseen": return out and not versus and me.has("chases") and count(me, "chases") == 0 and count(me, "deaths") == 0
		"mvp": return players > 1 and int(line.get("mvp", 0)) == seat and seat != 0
		"grade": return grade_at_least(String(line.get("grade", "")), String(rule[1]))
		"versus_out": return versus and out
	return false
