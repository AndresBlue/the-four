extends Area3D
## A thing of the offices worked by hand (spec_f1_systems 1.2): its handler
## (files, power, air) says what the bracket reads and how long it is held;
## using it asks the host (match_net.use_office).
var level
## Its objective.
var handler
## What using it asks: "hatch", "climb", "ladder" and the like.
var action := ""
## Its place in its handler's list: its name on the wire.
var index := 0
## Where the body is put while it is held (INF: where it is), and which way it
## is turned meanwhile (a body's rotation.y; NAN: as it is).
var stand := Vector3.INF
var face_yaw := NAN
## The focus box, in front of the node (+Z out).
var box := Vector3(0.6, 0.6, 0.4)

func _ready() -> void:
	add_to_group("office_usables")
	collision_layer = 16
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var cube := BoxShape3D.new()
	cube.size = box
	shape.shape = cube
	shape.position = Vector3(0, 0, box.z * 0.5)
	add_child(shape)

func word(seat: int) -> String: return handler.word_of(self, seat)

func hold_time(seat: int) -> float: return handler.hold_of(self, seat)

## The local seat starts holding it: the body is put to `stand`, if it has one.
func begin(seat: int) -> void:
	var body = level.body_of_seat(seat)
	if body == level.player and stand != Vector3.INF and level.player.transit.is_empty():
		level.player.transit = {"from": level.player.global_position, "to": stand, "yaw_from": level.player.rotation.y, "yaw_to": face_yaw if not is_nan(face_yaw) else level.player.rotation.y, "time": 0.0, "length": 0.3}
	handler.begin_use(self, seat)

func holding(seat: int, fraction: float) -> void: handler.holding(self, seat, fraction)

func cancel(seat: int) -> void: handler.cancel_use(self, seat)

func use(seat: int) -> void:
	# A paper on the wall is read on this machine only: nothing changes.
	if action == "read":
		level.interaction.read_paper(handler.paper_of(index))
		return
	level.match_net.use_office(handler.ID, action, index, seat)

## For the bots' reach check.
func aim_point() -> Vector3: return global_transform * Vector3(0, 0, box.z * 0.5)
