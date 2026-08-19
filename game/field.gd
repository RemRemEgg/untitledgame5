class_name Field
extends Area3D

var id: int
var effect: Callable
var strength: float = 1.0
var time: float
var radius: float = 1.0
var visuals: Array[Node3D]

func _process(delta: float) -> void:
	var bodies := get_overlapping_bodies()
	for body in bodies:
		effect.call(self, body as PhysicsBody3D, delta)
	
	time -= delta
	if time <= 0.0:
		for v in visuals: if v: Util.remove_and_free(v)
		Util.remove_and_free(self)
