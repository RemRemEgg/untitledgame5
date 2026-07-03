class_name World
extends Node3D

## Player scene
const PLAYER := preload("uid://c2wfggr4eiia1")
## Player script
const P_SCRIPT = preload("uid://dqe5og2n28eku")
## LoboPlayer script
const L_SCRIPT = preload("uid://y4dp2cqltcrw")

## Speed of the sudden death walls
const SD_SPEED := 6.0
## Delay before sudden death starts, in seconds
const SD_DELAY := 45
## Time between sudden death walls, as a proportion(?)
const SD_INTERVAL := 0.95

@onready var levelgeo: Node3D = $levelgeo as Node3D
@onready var players: Node3D = $players as Node3D
@onready var projectiles: Node3D = $projectiles as Node3D
@onready var visuals: Node3D = $visuals as Node3D


func _ready() -> void:
	Game.world = self
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Game.mouse_fallback = Input.MOUSE_MODE_CAPTURED
	process_mode = Node.PROCESS_MODE_DISABLED
	
	for pi in (Network.players.values() as Array[Network.PlayerInfo]): # typesafe
		var p_scn := PLAYER.instantiate()
		
		p_scn.name = str(pi.uuid)
		p_scn.set_multiplayer_authority(pi.uuid, true)
		
		if pi.uuid == Network.uuid:
			p_scn.set_script(P_SCRIPT)
			var player := p_scn as Player
			player.set_data(pi)
			Game.player = player
		else:
			p_scn.set_script(L_SCRIPT)
			var lplayer := p_scn as LoboPlayer
			lplayer.set_data(pi)
		
		pi.linked_player = p_scn as Player
		players.add_child(p_scn)
	
	load_levelgeo(Network.get_synced_rng_seed(false))
	
	Network.change_to_state(Network.NS_IDLE)


func change_level(sseed: int, stasis_pos: Vector3) -> void:
	if Console.AUTO_LEVEL_LOAD:
		Game.player.stasis = stasis_pos
		
		load_levelgeo(sseed)
		levelgeo.process_mode = Node.PROCESS_MODE_DISABLED
		
		await get_tree().create_timer(0.25).timeout
		Network.change_to_state(Network.NS_IDLE)
		return
	
	# move player to spawn pos and wait
	var stasis := Game.player.create_tween()
	stasis.tween_property(Game.player, "position", stasis_pos, 0.5)
	await stasis.finished
	Game.player.stasis = stasis_pos
	await get_tree().create_timer(0.5).timeout
	
	# shrink old level
	var tween := levelgeo.create_tween()
	tween.tween_property(levelgeo, "rotation:y", PI, 1.0).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUINT)
	tween = levelgeo.create_tween()
	tween.tween_property(levelgeo, "scale", Vector3.ONE*0.001, 1.0)
	await tween.finished
	
	# setup new level
	load_levelgeo(sseed)
	#levelgeo.process_mode = Node.PROCESS_MODE_DISABLED
	
	# grow new level
	levelgeo.rotation.y = -PI
	levelgeo.scale = Vector3.ONE*0.001
	tween = levelgeo.create_tween()
	tween.tween_property(levelgeo, "rotation:y", 0.0, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	tween = levelgeo.create_tween()
	tween.tween_property(levelgeo, "scale", Vector3.ONE, 1.0)
	await tween.finished
	
	await get_tree().create_timer(0.25).timeout
	Network.change_to_state(Network.NS_IDLE)


func game_start() -> void:
	levelgeo.process_mode = Node.PROCESS_MODE_INHERIT


func load_levelgeo(sseed: int) -> void:
	Util.remove_and_free_all_children(levelgeo)
	var rng := RandomNumberGenerator.new()
	rng.seed = sseed
	
	var room_lvls: Array[PackedScene] = []
	for i in 10: room_lvls.append(load("res://game/levels/test_level_%d.tscn" % (i+1)) as PackedScene)
	
	for x in 5: for y in 2: for z in 5:
		var room_inst := room_lvls[rng.randi_range(0, room_lvls.size()-1)].instantiate() as Node3D
		levelgeo.add_child(room_inst)
		room_inst.position = Vector3(x-2, (y-0.501)*0.75, z-2) * 64.0
		
		var t := (absf(room_inst.position.x) + absf(room_inst.position.z)) / 64.0 # distance from center
		t = 6 - t # invert
		(room_inst.get_node(^"room_walls") as RoomWalls).ceilingsb.position.y = (SD_DELAY + SD_INTERVAL*SD_SPEED*t) * SD_SPEED
