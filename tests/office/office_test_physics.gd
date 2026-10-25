extends "res://tests/office/office_test.gd"
## office_test's third part, on its own (verify.ps1 runs its three parts side
## by side): three floors of offices built in a level, checked by the office
## validator's physics.

func _initialize() -> void:
	part = "physics"
	super()
