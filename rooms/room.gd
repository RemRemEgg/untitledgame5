class_name Room
extends Node3D


enum Rotation {
	NONE, ## Will not rotate
	Y, ## Only rotates around Y axis
	XY, ## Only rotates around X and Y axis (like a player camera)
	FULL, ## Rotate around all axies
	FULL_UNSNAPPED, ## Rotate around all axies, in non 90 deg amounts
}
@export var rotation_type: Rotation = Rotation.Y


func _ready() -> void: pass


func _process(_delta: float) -> void: pass


func random_rotate(rng: RandomNumberGenerator) -> void:
	match rotation_type:
		Rotation.Y:
			rotation.y = rng.randi_range(0, 3) * PI/2.0
			# 1/100 chance to be rotated differently
			if rng.randf() <= 0.015:
				rotation.x = rng.randi_range(-1, 1) * PI/2.0
		Rotation.XY:
			rotation.y = rng.randi_range(0, 3) * PI/2.0
			if rng.randf() <= 0.5:
				rotation.x = rng.randi_range(-1, 1) * PI/2.0
		Rotation.FULL:
			rotation.y = rng.randi_range(0, 3) * PI/2.0
			if rng.randf() <= 0.5:
				rotation.x = rng.randi_range(-1, 1) * PI/2.0
			else:
				rotation.z = rng.randi_range(1, 3) * PI/2.0
		Rotation.FULL_UNSNAPPED:
			rotation.y = rng.randf() * PI*2.0
			if rng.randf() <= 0.5:
				rotation.x = rng.randf_range(-PI/2.0, PI/2.0)
			else:
				rotation.z = rng.randf() * PI*2.0
	
