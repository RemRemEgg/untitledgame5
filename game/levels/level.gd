class_name LevelDepricated
extends Node3D

## Speed of the sudden death walls
const SD_SPEED := 8.0
## Delay before sudden death starts, in seconds
const SD_DELAY := 45
## Time between sudden death walls, in seconds
const SD_INTERVAL := 4.2

#const LEVELBODY := preload("res://game/levelbody.tscn") as PackedScene

#TODO more levels

func _ready() -> void:
	var rng := Network.get_synced_rng(true)
	
	var ROOM_PCK_1 := load("res://game/levels/test_level_1.tscn") as PackedScene
	var ROOM_PCK_2 := load("res://game/levels/test_level_2.tscn") as PackedScene
	var ROOM_PCK_3 := load("res://game/levels/test_level_3.tscn") as PackedScene
	var ROOM_PCK_4 := load("res://game/levels/test_level_4.tscn") as PackedScene
	var ROOM_PCK_5 := load("res://game/levels/test_level_5.tscn") as PackedScene
	var room_lvls: Array[PackedScene] = [ROOM_PCK_1, ROOM_PCK_2, ROOM_PCK_3, ROOM_PCK_4, ROOM_PCK_5]
	for x in 5: for z in 5:
		var room_inst := room_lvls[rng.randi_range(0, room_lvls.size()-1)].instantiate() as Node3D
		add_child(room_inst)
		room_inst.position = Vector3(x-2, 0.0, z-2) * 64.0
		var t := (absf(room_inst.position.x) + absf(room_inst.position.z)) / 64.0 # distance from center
		t = 6 - t # invert
		(room_inst.get_node(^"room_walls") as RoomWalls).ceilingsb.position.y = (SD_DELAY*SD_SPEED) + (SD_INTERVAL*t*SD_SPEED)

func _process(_delta: float) -> void:
	pass
