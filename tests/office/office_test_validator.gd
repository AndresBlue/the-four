extends "res://tests/office/office_test.gd"
## office_test's second part, on its own (verify.ps1 runs its three parts side
## by side): the validator's mutations of seed 7's floor.

func _initialize() -> void:
	part = "validator"
	super()
