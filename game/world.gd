class_name World
extends Node3D

const MASK_PLAYER: int = 0b0010_0010
const MASK_WORLD: int = 0b0001_0001
const MASK_ALL: int = 0b0011_0011


## Player scene
const PLAYER := preload("uid://c2wfggr4eiia1") as PackedScene
## Player script
const P_SCRIPT = preload("uid://dqe5og2n28eku")
## LoboPlayer script
const L_SCRIPT = preload("uid://y4dp2cqltcrw")
## World box scene
const WB_SCN := preload("uid://bwm04bfxnae5") as PackedScene
## SD box scene
const SDB_SCN := preload("uid://bl448vwrgqvmy") as PackedScene

static var full_rooms: Array[PackedScene]
static var half_rooms: Array[PackedScene]


var is_sudden_death: bool = false
@onready var sd_walls: Node3D = $sd_walls as Node3D
@onready var levelgeo: Node3D = $levelgeo as Node3D
@onready var bounds: Node3D = $bounds as Node3D
@onready var players: Node3D = $players as Node3D
@onready var projectiles: Node3D = $projectiles as Node3D
@onready var visuals: Node3D = $visuals as Node3D
@onready var sounds: Node3D = $sounds as Node3D

signal reset_sd()


static func _static_init() -> void:
	for file_name in DirAccess.get_files_at(&"res://rooms/full"):
		if file_name.get_extension() == &"tscn":
			full_rooms.append(load(&"res://rooms/full/%s" % file_name) as PackedScene)
			print(&"Load room %s" % full_rooms.back())
	for file_name in DirAccess.get_files_at(&"res://rooms/half"):
		if file_name.get_extension() == &"tscn":
			half_rooms.append(load(&"res://rooms/half/%s" % file_name) as PackedScene)
			print(&"Load room %s" % half_rooms.back())


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
	
	is_sudden_death = false
	Network.game_won.connect(_game_end)
	for x in 12: for y in 12: for z in 12:
		var dir := Vector3(x, y, z) - Vector3.ONE*5.5
		if is_equal_approx(absf(dir.x)+absf(dir.y)+absf(dir.z), 5.5):#roundi(dir.length()) == 5:#
			var sdb := SDB_SCN.instantiate() as SDBox
			sd_walls.add_child(sdb)
			sdb.setup(dir)
	reset_sd.emit()
	
	Network.change_to_state(Network.NS_IDLE)


func change_level(sseed: int, stasis_pos: Vector3) -> void:
	if Console.AUTO_LEVEL_LOAD:
		Game.player.stasis = stasis_pos
		load_levelgeo(sseed)
		await get_tree().create_timer(0.25).timeout
		Network.change_to_state(Network.NS_IDLE)
		return
	
	# move player to spawn pos and wait
	var stasis := Game.player.create_tween()
	stasis.tween_property(Game.player, "position", stasis_pos, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUINT)
	await stasis.finished
	Game.player.stasis = stasis_pos
	await get_tree().create_timer(0.75).timeout
	
	# shrink old level
	levelgeo.process_mode = Node.PROCESS_MODE_DISABLED
	var tween := create_tween()
	tween.tween_property(levelgeo, "position:y", +192, 2.5)
	await tween.finished
	
	# setup new level
	load_levelgeo(sseed)
	
	# grow new level
	levelgeo.rotation.y = -PI
	levelgeo.position.y = -192
	tween = create_tween()
	tween.tween_property(levelgeo, "position:y", 0.0, 2.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween.finished
	
	await get_tree().create_timer(0.25).timeout
	levelgeo.process_mode = Node.PROCESS_MODE_INHERIT
	Network.change_to_state(Network.NS_IDLE)


func game_start() -> void:
	levelgeo.process_mode = Node.PROCESS_MODE_INHERIT
	reset_sd.emit()
	is_sudden_death = true


func _game_end(__:int) -> void:
	is_sudden_death = false


func load_levelgeo(sseed: int) -> void:
	Console.print(&"loading levelgeo, sseed: %s" % sseed)
	Util.remove_and_free_all_children(levelgeo)
	var rng := RandomNumberGenerator.new()
	rng.seed = sseed
	
	var is_half_filled := false
	for x in 8: for z in 8: for y in 5:
		var i_pos := Vector3i(x, y, z) # room id
		var r_pos := (Vector3(x-3.5, (y-2.25), z-3.5) * 48.0) # world pos
		if _is_room(i_pos):
			if !is_half_filled: # tile is completely open
				if rng.randf() <= 0.25: # place half tile
					place_room(half_rooms, r_pos, rng)
					is_half_filled = true
				else: # place full tile
					place_room(full_rooms, r_pos, rng)
					is_half_filled = false
			
			if is_half_filled: # tile has half full on bottom
				if !_is_room(i_pos + Vector3i(0, 1, 0)) || rng.randf() <= 0.25: # fill remaining area
					place_room(half_rooms, r_pos + Vector3(0.0, 24.0, 0.0), rng)
					is_half_filled = false
				else: # add full room
					place_room(full_rooms, r_pos + Vector3(0.0, 24.0, 0.0), rng)
					is_half_filled = true
			
			if rng.randf() <= 0.1:
				place_random_field(r_pos, rng)
			
		else:
			if Network.round_count == 0:
				place_worldbound(r_pos)
			is_half_filled = false


func place_room(rooms_arr: Array[PackedScene], r_pos: Vector3, rng: RandomNumberGenerator) -> void:
	print(&"wg: placed room")
	var room := rooms_arr[rng.randi_range(0, rooms_arr.size()-1)].instantiate() as Room
	room.name = &"room%d+_%+d_%+d" % [r_pos.x,r_pos.y,r_pos.z]
	room.random_rotate(rng)
	levelgeo.add_child(room)
	room.position = r_pos
	
	print(&"wg: children %s"%room.get_child_count())


func place_worldbound(pos: Vector3) -> void:
	var wb := WB_SCN.instantiate() as Node3D
	wb.name = &"wb%d+_%+d_%+d" % [pos.x,pos.y,pos.z]
	bounds.add_child(wb)
	wb.position = pos


func place_random_field(pos: Vector3, rng: RandomNumberGenerator) -> void:
	var trans := Transform3D.IDENTITY
	trans.origin = pos
	match rng.randi_range(0, 5):
		0: FieldHandler.spawn_local(FieldHandler.REVERSE_GRAV, trans, 23.0, 60.0, 0.5)
		1: FieldHandler.spawn_local(FieldHandler.ACCELERATE, trans, 23.0, 60.0, 2.0)
		2: FieldHandler.spawn_local(FieldHandler.SHRINK, trans, 23.0, 30.0, 1.0)
		3: FieldHandler.spawn_local(FieldHandler.IMPLODE, trans, 23.0, 60.0, 1.0)
		4: FieldHandler.spawn_local(FieldHandler.MINE, trans, 23.0, 60.0, 2.0)
		5: FieldHandler.spawn_local(FieldHandler.HEAL, trans, 23.0, 30.0, 1.0)


func _is_room(pos: Vector3i) -> bool:
	pos = pos.clamp(Vector3i.ZERO, Vector3i(7, 4, 7))
	var i := pos.x + pos.z*8
	match pos.y:
		4: return false
		3: return HLAYER_SMALL[i]
		2: return HLAYER_MEDIUM[i]
		1: return HLAYER_SMALL[i]
		_: return false

const HLAYER_BIG: Array[bool] = [
	0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 1, 1, 0, 0, 0,
	0, 0, 1, 1, 1, 1, 0, 0,
	0, 1, 1, 1, 1, 1, 1, 0,
	0, 1, 1, 1, 1, 1, 1, 0,
	0, 0, 1, 1, 1, 1, 0, 0,
	0, 0, 0, 1, 1, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0,
]
const HLAYER_MEDIUM: Array[bool] = [
	0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 1, 1, 0, 0, 0,
	0, 0, 1, 1, 1, 1, 0, 0,
	0, 0, 1, 1, 1, 1, 0, 0,
	0, 0, 0, 1, 1, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0,
]
const HLAYER_SMALL: Array[bool] = [
	0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 1, 1, 0, 0, 0,
	0, 0, 0, 1, 1, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0,
]


func get_aoe_objects(pos: Vector3, radius: float, ignore_rids: Array[RID] = []) -> Array[PhysicsBody3D]:
	var dss: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	var psqp := PhysicsShapeQueryParameters3D.new()
	psqp.shape = shape
	psqp.transform.origin = pos
	shape.radius = radius
	psqp.collision_mask = 0b0011_0011
	psqp.exclude = ignore_rids
	var hits := dss.intersect_shape(psqp, 64)
	
	var objects: Array[PhysicsBody3D] = []
	for hit in hits:
		var colc := hit[&"collider"] as PhysicsBody3D
		if colc: objects.append(colc)
	return objects


func get_aoe_players(pos: Vector3, radius: float, ignore_players: Array[Player] = []) -> Array[Player]:
	var dss: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	var psqp := PhysicsShapeQueryParameters3D.new()
	psqp.shape = shape
	psqp.transform.origin = pos
	shape.radius = radius
	psqp.collision_mask = 0b0010_0010
	psqp.exclude = ignore_players.map(func(p:Player) -> RID: return p.get_rid()) as Array[RID]
	var hits := dss.intersect_shape(psqp, 64)
	
	var objects: Array[Player] = []
	for hit in hits:
		var colc := hit[&"collider"] as Player
		if colc: objects.append(colc)
	return objects


func create_explosion(pos: Vector3, radius: float, damage: float, knockback: float, ignore_rids: Array[RID] = [], source: Player = null) -> void:
	var objects := get_aoe_objects(pos, radius, ignore_rids)
	VFXHandler.spawn(VFXHandler.EXPLOSION, pos, [radius])
	SFXHandler.play_world(SFXHandler.EXPLOSION, pos, (radius * 16.0) / (radius + 16.0))
	
	for obj in objects:
		var dir := obj.global_position - pos
		var length := dir.length_squared()
		dir = (dir * radius * knockback) / (length + 0.1)
		
		if obj is Player:
			var de := DamageEvent.new(damage, dir, DamageEvent.TYPE_EXPLOSION)
			de.source_entity = source
			(obj as Player).take_damage_seralized.rpc(de.seralize())
			continue
		if obj is RigidBody3D:
			if (obj as RigidBody3D).freeze: continue
			(obj as RigidBody3D).apply_central_impulse.rpc(dir * 2.0)


func has_line(start: Vector3, end: Vector3, mask: int = MASK_WORLD) -> bool:
	var dss: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var prqp := PhysicsRayQueryParameters3D.new()
	prqp.collision_mask = mask
	prqp.from = start
	prqp.to = end
	return dss.intersect_ray(prqp).is_empty()
