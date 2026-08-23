class_name Field
extends Area3D

var id: int
var data: FieldHandler.FieldData
var strength: float = 1.0
var time: float
var radius: float = 1.0
var visuals: Array[Node3D]

func _process(delta: float) -> void:
	visuals.assign(visuals.filter(func(v:Node3D) -> bool: return v && is_instance_valid(v)))
	
	if data.idle_effect:
		data.idle_effect.call(self, delta)
	
	var bodies := get_overlapping_bodies()
	if data.body_effect: for body in bodies:
		data.body_effect.call(self, body as PhysicsBody3D, delta)
	
	time -= delta
	if time <= 0.0:
		if data.end_effect: data.end_effect.call(self)
		
		for v in visuals: if v: Util.remove_and_free(v)
		Util.remove_and_free(self)
