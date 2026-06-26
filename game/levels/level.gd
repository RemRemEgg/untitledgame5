class_name Level
extends Node3D

@onready var bounds: StaticBody3D = $bounds as StaticBody3D

const LEVELBODY := preload("res://game/levelbody.tscn") as PackedScene

#TODO more levels

func _ready() -> void:
	bounds.visible = true
	
	var rng := Network.get_synced_rng(true)
	
	var ROOM_PCK_1 := load("res://game/levels/test_level_1.tscn") as PackedScene
	var ROOM_PCK_2 := load("res://game/levels/test_level_2.tscn") as PackedScene
	var ROOM_PCK_3 := load("res://game/levels/test_level_3.tscn") as PackedScene
	var room_lvls: Array[PackedScene] = [ROOM_PCK_1, ROOM_PCK_2, ROOM_PCK_3]
	for x in 5: for z in 5:
		var room_inst := room_lvls[rng.randi_range(0, 2)].instantiate() as Node3D
		add_child(room_inst)
		room_inst.position = Vector3(x-2, 0.0, z-2) * 64.0

func _process(_delta: float) -> void:
	pass
