@warning_ignore("missing_tool")
class_name SDBox
extends LevelBody

var origin: Vector3
var target: Vector3

func _ready() -> void:
	super()
	Game.world.reset_sd.connect(_reset)


func setup(dir: Vector3) -> void:
	var ldir := dir.sign() * 64.0
	origin = (dir * 64.0) + (ldir*4.5)
	target = origin - (ldir * 32.0)


func _reset() -> void:
	position = origin


func _process(delta: float) -> void:
	var diff := target - position
	if !Game.world.is_sudden_death: delta *= -4
	match (diff.abs() / 16.0).floor().max_axis_index():
		0: position.x += delta * signf(diff.x) * 8.0
		1: position.y += delta * signf(diff.y) * 8.0
		2: position.z += delta * signf(diff.z) * 8.0
