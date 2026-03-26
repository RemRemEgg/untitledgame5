extends Node

signal players_changed
const PORT := 15973

var peer: ENetMultiplayerPeer
var is_server := false
var uuid := 0
var self_player := PlayerInfo.new()
var players: Dictionary[int, PlayerInfo] = {}

func _ready() -> void:
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected_to_server)
	multiplayer.connection_failed.connect(_connection_failed)
	multiplayer.server_disconnected.connect(_server_disconnected)

#region server #######################################

func start_server() -> Error:
	is_server = true
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT)
	if err:
		print("server start failed: %s" % err)
		return err
	multiplayer.multiplayer_peer = peer
	uuid = multiplayer.get_unique_id()
	self_player.name = "Host"
	self_player.uuid = uuid
	players[uuid] = self_player
	players_changed.emit()
	return OK

#endregion


#region client #######################################

func start_client(ip: String) -> Error:
	is_server = false
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	if err:
		print("client start failed: %s" % err)
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func _peer_connected(id: int) -> void:
	print("[%s] player %s connected, sending seralized data" % [is_server, id])
	register_player.rpc_id(id, uuid, self_player.seralize())
	players_changed.emit()
func _peer_disconnected(id: int) -> void:
	players.erase(id)
	players_changed.emit()

func _connected_to_server() -> void:
	print("[C] connection sucessful")
	uuid = multiplayer.get_unique_id()
	players[uuid] = self_player
	self_player.name = str(uuid)
	self_player.uuid = uuid
	players_changed.emit()

func _connection_failed() -> void:print("[C] connection failed")#TODO

func _server_disconnected() -> void:print("[C] server disconnected")#TODO

@rpc("any_peer", "call_remote", "reliable")
func register_player(id: int, info: Dictionary) -> void:
	players[id] = PlayerInfo.deseralize(info)
	players_changed.emit()

@rpc("any_peer", "call_local", "reliable")
func update_player(id: int, info: Dictionary) -> void:
	(players[id] as PlayerInfo).update(info)

var loaded_players := 0
var synced_players := 0
@rpc("authority", "call_local", "reliable")
func change_scene(target: String) -> void:
	loaded_players = 0
	get_tree().change_scene_to_file(target)
@rpc("any_peer", "call_local", "reliable")
func loaded_scene() -> void:
	print("player loaded")
	if is_server:
		loaded_players += 1
		if loaded_players == players.size():
			loaded_players = 0
			print("all players loaded")
			all_players_loaded.rpc()
			Game.world.all_players_loaded()
@rpc("authority", "call_local", "reliable")
func all_players_loaded() -> void:
	var cs := get_tree().current_scene
	cs.process_mode = Node.PROCESS_MODE_INHERIT

@rpc("authority", "call_local", "reliable")
func player_draw_time() -> void:
	loaded_players = 0
	Game.player.cards_menu._card_selection_time()
@rpc("any_peer", "call_local", "reliable")
func selected_card() -> void:
	print("player selected")
	if is_server:
		loaded_players += 1
		if loaded_players == players.size():
			loaded_players = 0
			print("all players selected")
			all_players_selected.rpc()
@rpc("authority", "call_local", "reliable")
func all_players_selected() -> void:
	loaded_players = 0
	synced_players = 0
	# TODO proj sync
	var sps := Game.player.get_seralized_projectiles()
	for sp in sps:
		sync_projectile.rpc(sp)
@rpc("any_peer", "call_remote", "reliable")
func sync_projectile(info: Dictionary) -> void:
	print("syncing projectile")
	var id := info.get("uuid", 0) as int
	if id > 0:
		players[id].linked_player.set_seralized_projectiles(info)
	synced_players += 1
	if synced_players == players.size() - 1:
		projectiles_synced.rpc_id(1)
@rpc("any_peer", "call_local", "reliable")
func projectiles_synced() -> void:
	print("projectiles synced")
	if is_server:
		loaded_players += 1
		if loaded_players == players.size():
			loaded_players = 0
			print("all projectiles synced")
			all_projectiles_synced.rpc()
@rpc("authority", "call_local", "reliable")
func all_projectiles_synced() -> void:
	print("all projectiles synced, starting round")
	
	#calc spawn position
	players.sort()
	var seed_func := func(a: int, k: int) -> int: return (hash(a) ^ hash(k))
	var sseed := int(players.keys().reduce(seed_func, 0xB100D1EDB00B5))
	var angle := (sseed/1000.0)
	angle += (players.keys().find(uuid) * PI*2.0) / players.size()
	print("spawn info %s %s %s %s" % [uuid, sseed, angle, players.keys().find(uuid)])
	var spawn2d := Vector2.from_angle(angle) * 9.0
	var tween := self_player.linked_player.create_tween()
	tween.tween_property(self_player.linked_player, "global_position", Vector3(spawn2d.x, 16.0, spawn2d.y), 0.0).set_trans(Tween.TRANS_QUAD)
	tween.finished.connect(_local_round_start)
func _local_round_start() -> void:
	self_player.linked_player.can_shoot = true
#endregion

class PlayerInfo:
	signal on_update(pi: PlayerInfo)
	
	var uuid: int = 0
	var name: String = "New Player"
	var color: Color = Color.from_hsv(randf_range(0, 1.0), 0.95, 0.95)
	var ready := false
	var linked_player: Player
	
	func seralize() -> Dictionary:
		var d: Dictionary[String, Variant] = {}
		d.uuid = uuid
		d.name = name
		d.color = color
		d.ready = ready
		return d
	
	static func deseralize(info: Dictionary) -> PlayerInfo:
		var pi := PlayerInfo.new()
		pi.uuid = info.uuid
		pi.name = info.name
		pi.color = info.color
		pi.ready = info.ready
		return pi
	
	func update(info: Dictionary) -> void:
		uuid = info.get("uuid", uuid)
		name = info.get("name", name)
		color = info.get("color", color)
		ready = info.get("ready", ready)
		on_update.emit(self)


var out_proj_spawner: MultiplayerSpawner

#pp.global_position = trans.origin
#pp.ownr = ownr
#pp.team = ownr.team
#pp.velocity = trans.basis * vel
#pproj.update(pp, delta)
#Network._send_projectile(pp)
#func _send_projectile(proj: Projectile) -> void:
	#var data: Dictionary = {}
	#data.team = proj.team
	#data.transform = proj.global_position
	#out_proj_spawner.spawn(data)
func _send_projectile(trans: Transform3D, team: int) -> Projectile:
	var node := out_proj_spawner.spawn({"trans":trans, "team":team, "uuid":uuid})
	return node as Projectile

func add_proj_spawner(mps: MultiplayerSpawner, is_out: bool = false) -> void:
	mps.spawn_function = _recieve_projectile
	if is_out: out_proj_spawner = mps

# transform (rotation, position, ) 
func _recieve_projectile(data: Dictionary) -> Projectile:
	var id := data.get("uuid", 0) as int
	if id > 0:
		var proj := Projectile.deseralize(data)
		proj.set_multiplayer_authority(id)
		
		players[id].linked_player.pproj.bind(proj)
		
		return proj
	return null



class ProjInfo:
	var auth_uuid: int
	
	
	
	func seralize() -> Dictionary:
		var d := {}
		d.auth_uuid = auth_uuid
		return d
	
	static func deseralize(info: Dictionary) -> ProjInfo:
		var pi := ProjInfo.new()
		pi.auth_uuid = info.auth_uuid
		return pi
		
