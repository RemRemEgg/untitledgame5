@tool
class_name RoomWalls
extends Node3D


const WALL_HOLE := preload("res://game/levels/wall_hole.tscn") as PackedScene
const WALL_SOLID := preload("res://game/levels/wall_solid.tscn") as PackedScene


@export_flags("X+", "X-", "Z+", "Z-")
var walls_with_holes: int = 0b1111:
	set(v):
		walls_with_holes = v
		update_wall_holes()

func update_wall_holes() -> void:
	Util.remove_and_free($wall_x)
	Util.remove_and_free($wall_ix)
	Util.remove_and_free($wall_z)
	Util.remove_and_free($wall_iz)
	
	add_wall(walls_with_holes & 0b0001, Vector3(31, 0, 0), &"wall_x")
	add_wall(walls_with_holes & 0b0010, Vector3(-31, 0, 0), &"wall_ix")
	add_wall(walls_with_holes & 0b0100, Vector3(0, 0, 31), &"wall_z")
	add_wall(walls_with_holes & 0b1000, Vector3(0, 0, -31), &"wall_iz")

func add_wall(has_hole: bool, pos: Vector3, n: StringName) -> void:
	var wall: StaticBody3D
	if has_hole: wall = WALL_HOLE.instantiate() as StaticBody3D
	else: wall = WALL_SOLID.instantiate() as StaticBody3D
	
	wall.position = pos
	wall.rotation.y = pos.angle_to(Vector3.RIGHT)
	wall.name = n
	add_child(wall)
	wall.owner = self
