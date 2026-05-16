extends Node

signal players_changed
const PORT := 15973

var peer: ENetMultiplayerPeer
var is_server := false
var uuid := 0
var self_player := PlayerInfo.new()
var players: Dictionary[int, PlayerInfo] = {}

var round_count := 0

func _ready() -> void:
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected_to_server)
	multiplayer.connection_failed.connect(_connection_failed)
	multiplayer.server_disconnected.connect(_server_disconnected)



#region server exclusive #######################################

func start_server() -> Error:
	is_server = true
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT)
	if err:
		Console.print_err(&"server start failed: %s" % err)
		return err
	multiplayer.multiplayer_peer = peer
	uuid = multiplayer.get_unique_id()
	self_player.name = "Host"
	self_player.uuid = uuid
	players[uuid] = self_player
	players_changed.emit()
	return OK

#endregion



#region client exclusive #######################################

func start_client(ip: String) -> Error:
	is_server = false
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	if err:
		Console.print_err(&"client start failed: %s" % err)
		return err
	multiplayer.multiplayer_peer = peer
	return OK

func _connected_to_server() -> void:
	Console.print(&"connection sucessful")
	uuid = multiplayer.get_unique_id()
	players[uuid] = self_player
	self_player.name = str(uuid)
	self_player.uuid = uuid
	players_changed.emit()

func _connection_failed() -> void:Console.print_err(&"connection failed")#TODO

func _server_disconnected() -> void:Console.print(&"server disconnected")#TODO

#endregion



#region all peers ########################################

func _peer_connected(id: int) -> void:
	Console.print(&"player %s connected, sending seralized data" % id)
	register_player.rpc_id(id, self_player.seralize())
	players_changed.emit()

func _peer_disconnected(id: int) -> void:
	players.erase(id)
	players_changed.emit()

@rpc("any_peer", "call_remote", "reliable")
func register_player(info: Dictionary) -> void:
	var id := multiplayer.get_remote_sender_id(); if !id: return
	players[id] = PlayerInfo.deseralize(info)
	players_changed.emit()

@rpc("any_peer", "call_local", "reliable")
func update_player(info: Dictionary) -> void:
	var id := multiplayer.get_remote_sender_id(); if !id: return
	(players[id] as PlayerInfo).update(info)

#endregion



#region state machine #####################################

@rpc("authority", "call_local", "reliable")
func change_to_state(new_state: int) -> void: # peer side
	@warning_ignore("int_as_enum_without_cast")
	self_player.state = new_state
	match new_state:
		NS_UNINIT:
			Console.print(&"change to  NS_UNINIT")
		NS_IDLE:
			Console.print(&"change to  NS_IDLE")
		NS_LOBBY:
			Console.print(&"change to  NS_LOBBY")
			get_tree().change_scene_to_file(&"res://ui/lobby.tscn")
		NS_LOAD_GAME:
			Console.print(&"change to  NS_LOAD_GAME")
			next_state = NS_DRAWING
			get_tree().change_scene_to_file(&"res://game/world.tscn")
		NS_DRAWING:
			Console.print(&"change to  NS_DRAWING")
			next_state = NS_PROJ_SYNC
			get_tree().current_scene.process_mode = Node.PROCESS_MODE_INHERIT
			Game.player.cards_menu.card_selection_time()
		NS_PROJ_SYNC:
			Console.print(&"change to  NS_PROJ_SYNC")
			next_state = NS_LOAD_LEVEL
			for p:PlayerInfo in (players.values() as Array[PlayerInfo]): p.proj_synced = false
			self_player.proj_synced = true
			var sps := Game.player.get_seralized_projectiles()
			for sp in sps: sync_projectile.rpc(sp)
		NS_LOAD_LEVEL:
			Console.print(&"change to  NS_LOAD_LEVEL")
			next_state = NS_BATTLE
			if is_server:
				var sseed := randi()
				load_level.rpc(sseed)
		NS_BATTLE:
			Console.print(&"change to  NS_BATTLE")
			next_state = NS_PROJ_SYNC
			for p:PlayerInfo in (players.values() as Array[PlayerInfo]): p.death_time = -1.0
			start_round()
	peer_state_change.rpc(self_player.state)

@rpc("any_peer", "call_local", "reliable")
func peer_state_change(new_state: int) -> void: # server side, from peer
	var id := multiplayer.get_remote_sender_id(); if !id: return
	@warning_ignore("int_as_enum_without_cast")
	players[id].state = new_state
	if is_server: test_all_players_synced()

var next_state: int = NS_IDLE
func test_all_players_synced() -> void:
	if players.values().all(func(p:PlayerInfo)->bool:return p.state == self_player.state): all_peers_synced()
func all_peers_synced() -> void: # server side
	await get_tree().create_timer(2.0).timeout
	match self_player.state:
		NS_IDLE:
			if next_state != NS_IDLE:
				change_to_state.rpc(next_state)
		_: pass

func start_game() -> void: # called from host pressing start button
	change_to_state.rpc(NS_LOAD_GAME)

@rpc("any_peer", "call_remote", "reliable")
func sync_projectile(info: Dictionary) -> void: # peer side, from peers
	var id := multiplayer.get_remote_sender_id(); if !id: return
	Console.print(&"sync projectile from %s" % id)
	if !players.has(id): return
	players[id].linked_player.set_seralized_projectiles(info)
	players[id].proj_synced = true
	if players.values().all(func(p:PlayerInfo)->bool:return p.proj_synced):
		change_to_state(NS_IDLE)

@rpc("authority", "call_local", "reliable")
func load_level(sseed: int) -> void:# peer side, from server
	var angle := (sseed/2048.0)
	angle += (players.keys().find(uuid) * PI*2.0) / players.size()
	Console.print(&"spawn info %s %s %s %s" % [uuid, sseed, angle, players.keys().find(uuid)])
	var spawn2d := Vector2.from_angle(angle) * 32.0
	Game.world.change_level("", Vector3(spawn2d.x, 16.0, spawn2d.y))

func start_round() -> void: # peer side
	Console.print(&"starting round")
	Game.player.game_start()
	round_count += 1

@rpc("any_peer", "call_local", "reliable")
func player_died(time: float) -> void: # server side, from peers
	var id := multiplayer.get_remote_sender_id(); if !id: return
	Console.print(&"player [%s] died at %+010.1f" % [id, time])
	if !players.has(id): return
	players[id].death_time = time
	
	var players_left := players.values().filter(func(p:PlayerInfo)->bool:return p.death_time < 0.0).size()
	if players_left == 1:
		get_tree().create_timer(1.0).timeout.connect(determine_winner)

func determine_winner() -> void: # server side
	var win_id := -1
	var win_time := 0.0
	for player in (players.values() as Array[PlayerInfo]):
		if player.death_time < 0.0: # still alive
			win_id = player.uuid
			break
		if player.death_time > win_time:
			win_time = player.death_time
			win_id = player.uuid
	if win_id == -1: assert(false, "No winner found")
	Console.print(&"winner is [%s]" % win_id)
	player_won_game.rpc(win_id)

@rpc("authority", "call_local", "reliable")
func player_won_game(id: int) -> void:
	Console.print(&"recieved [%s] won" % id)
	self_player.linked_player.respawn()
	if id == uuid: # won
		Console.print(&"i won, moving to idle")
		change_to_state(NS_IDLE)
	else:
		Console.print(&"i lost, drawing cards")
		change_to_state(NS_DRAWING)

#endregion



#region world sync #######################################
const NS_NAME: PackedStringArray = ["NS_UNINIT", "NS_IDLE", "NS_LOBBY", "NS_LOAD_GAME", "NS_DRAWING", "NS_PROJ_SYNC", "NS_LOAD_LEVEL", "NS_BATTLE"]
enum {NS_UNINIT, NS_IDLE, NS_LOBBY, NS_LOAD_GAME, NS_DRAWING, NS_PROJ_SYNC, NS_LOAD_LEVEL, NS_BATTLE}
class PlayerInfo:
	signal on_update(pi: PlayerInfo)
	
	var linked_player: Player
	var uuid: int = 0
	
	var name: String = "New Player"
	var color: Color = Color.from_hsv(randf_range(0, 1.0), 0.95, 0.95)
	var state := NS_UNINIT
	var ready := false
	var death_time := -1.0
	var proj_synced := false
	
	func seralize() -> Dictionary:
		var d: Dictionary[String, Variant] = {}
		d.uuid = uuid
		d.name = name
		d.color = color
		d.ready = ready
		d.state = state
		return d
	
	static func deseralize(info: Dictionary) -> PlayerInfo:
		var pi := PlayerInfo.new()
		pi.uuid = info.uuid
		pi.name = info.name
		pi.color = info.color
		pi.ready = info.ready
		pi.state = info.state
		return pi
	
	func update(info: Dictionary) -> void:
		uuid = info.get("uuid", uuid)
		name = info.get("name", name)
		color = info.get("color", color)
		ready = info.get("ready", ready)
		state = info.get("state", state)
		on_update.emit(self)


var out_proj_spawner: MultiplayerSpawner

func _send_projectile(trans: Transform3D) -> Projectile:
	var node := out_proj_spawner.spawn({"trans":trans, "uuid":uuid})
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

#endregion
