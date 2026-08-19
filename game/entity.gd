class_name Entity
extends CharacterBody3D

static func movement_update_flat(ent: Entity, dir: Vector2, delta: float) -> void:
	var vel := Vector2(ent.velocity.x, ent.velocity.z)
	var target := (dir * maxf(ent.speed.value, vel.dot(dir))) - vel # this is where the magic happens
	target = target.limit_length(delta * ent.accel.value) # prevent jittering
	ent.velocity += Vector3(target.x, 0.0, target.y)
static func movement_update(ent: Entity, dir: Vector3, delta: float) -> void:
	var target := (dir * maxf(ent.speed.value, ent.velocity.dot(dir))) - ent.velocity # this is where the magic happens (again)
	target = target.limit_length(delta * ent.accel.value) # prevent jittering
	ent.velocity += target


var health: float = 100.0
## Default 100.0
var max_health: Stat = Stat.new(&"Max Health", 100.0, 1.0)
## Default 10.0
var speed := Stat.new(&"Speed", 10.0, 0.5)
## Default 32.0
var accel := Stat.new(&"Acceleration", 32.0, 0.5)
