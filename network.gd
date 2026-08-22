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
			game_won.emit.call_deferred(-1)
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
	await get_tree().create_timer(0.25).timeout
	match self_player.state:
		NS_IDLE:
			if next_state != NS_IDLE:
				change_to_state.rpc(next_state)
		NS_BATTLE:
			system_message.rpc(&"[b]Round start![/b]")
		_: pass

#endregion



#region helper functions #################################

func player_from_uuid(id: int) -> Player:
	if id <= 0: return null
	if !players.has(id):
		Console.print_err(&"Could not get player from id '%s'" % id)
		return null
	return players[id].linked_player



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
	var spawn2d := Vector2.from_angle(angle) * 48.0
	#Game.world.change_level("res://game/levels/level_base.tscn", Vector3(spawn2d.x, 0.0, spawn2d.y))
	Game.world.change_level(sseed, Vector3(spawn2d.x, 0.0, spawn2d.y))


func start_round() -> void: # peer side
	Console.print(&"starting round")
	Game.world.game_start()
	Game.player.game_start()


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
	system_message.rpc(&"[b]%s won![/b]" % players[win_id].get_name_fancy())
	player_won_game.rpc(win_id)

signal game_won(id: int)
@rpc("authority", "call_local", "reliable")
func player_won_game(id: int) -> void:
	Console.print(&"recieved [%s] won" % id)
	round_count += 1
	self_player.linked_player.respawn()
	self_player.linked_player.on_round_end(id == uuid)
	for player: PlayerInfo in players.values():
		if player.uuid == id: player.wins += 1
		else: player.losses += 1
	
	if id == uuid: # won
		Console.print(&"i won, skip card draw")
		change_to_state(NS_IDLE)
	else:
		Console.print(&"i lost, drawing cards")
		change_to_state(NS_DRAWING)
	game_won.emit(id)


@rpc("authority", "call_local", "reliable")
func system_message(msg: String) -> void:
	Game.player.hud.add_chat_message(msg)

@rpc("any_peer", "call_local", "reliable")
func chat_message(msg: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	Game.player.hud.add_chat_message(&"%s: %s" % [players[id].get_name_fancy(), msg])

@rpc("any_peer", "call_local", "reliable")
func death_message(data: Array[Variant]) -> void:
	var de := DamageEvent.deseralize(data)
	var target := players[de.target_uuid].get_name_fancy()
	var death_msg := de.get_death_message(target, (players[de.source_uuid].get_name_fancy() if de.source_uuid else ""))
	Game.player.hud.add_chat_message(&"💀" + death_msg)

@rpc("any_peer", "call_local", "reliable")
func update_card_picked(card_uuid: StringName, count: int) -> void:
	var id := multiplayer.get_remote_sender_id()

	var card := Card.get_card(card_uuid)
	if !card:
		Console.print_err(&"Cannot find card %s" % card_uuid)
		return

	var card_list := players[id].cards
	var diff := int(count - card_list.get(card_uuid, 0))
	card_list[card_uuid] = count
	if count <= 0: card_list.erase(card_uuid)
	Game.player.hud.add_chat_message(&"%s took [color=%s]%s[/color] %s" %\
		[players[id].get_name_fancy(), Card.RARITY_COLORS[card.rarity], card.name, (&"x%s"%diff) if diff > 1 else ("")])

#endregion



#region world sync #######################################

func _round_seed_func(a: int, k: int) -> int: return (hash(a) ^ hash(k))
func get_synced_rng_seed(include_round_count: bool = false) -> int:
	var keys := players.keys().duplicate() as Array[int]
	keys.sort()
	return int(keys.reduce(_round_seed_func, 0xB100D1EDB00B5)) + (round_count**2 if include_round_count else 0)
func get_synced_rng(include_round_count: bool = false) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = get_synced_rng_seed(include_round_count)
	return rng


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
	var wins: int = 0
	var losses: int = 0 # not fully tracked, only used for artifacts

	var cards: Dictionary[StringName, int]

	func seralize() -> Dictionary:
		var d: Dictionary[StringName, Variant] = {}
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
		uuid = info.get(&"uuid", uuid)
		name = info.get(&"name", name)
		color = info.get(&"color", color)
		ready = info.get(&"ready", ready)
		state = info.get(&"state", state)
		on_update.emit(self)

	func get_name_fancy() -> String:
		return "[color=%s]%s[/color]" % [color.to_html(false), name]


var out_proj_spawner: MultiplayerSpawner
func send_projectile(trans: Transform3D) -> Projectile:
	# TODO sometimes returns null
	var payload := [0, {"trans":trans, "uuid":uuid}]
	var node := out_proj_spawner.spawn(payload)
	if !node:
		Console.print_err(&"ops data; tree: %s, has_multiplayer: %s, is_auth: %s" % [out_proj_spawner.is_inside_tree(), multiplayer.has_multiplayer_peer(), out_proj_spawner.is_multiplayer_authority()])
		Game.player.hud.add_chat_message(&"[color=red]Failed to create projectile[/color]")
		return _recieve_projectile(payload)
	return node as Projectile


func send_alt_projectile(trans: Transform3D) -> Projectile:
	# TODO sometimes returns null
	var payload := [1, {"trans":trans, "uuid":uuid}]
	var node := out_proj_spawner.spawn(payload)
	if !node:
		Console.print_err(&"alt ops data; tree: %s, has_multiplayer: %s, is_auth: %s" % [out_proj_spawner.is_inside_tree(), multiplayer.has_multiplayer_peer(), out_proj_spawner.is_multiplayer_authority()])
		Game.player.hud.add_chat_message(&"[color=red]Failed to create alt projectile[/color]")
		return _recieve_projectile(payload)
	return node as Projectile


func add_proj_spawner(mps: MultiplayerSpawner, is_out: bool = false) -> void:
	mps.spawn_function = _recieve_projectile
	if is_out: out_proj_spawner = mps


var dbg_proj: Dictionary
# transform (rotation, position)
func _recieve_projectile(arr: Array) -> Projectile:
	var mode := arr[0] as int
	if mode == 0:
		var data := arr[1] as Dictionary
		ProcGun.dbg_proj = data
		dbg_proj = data
		var id := data.get("uuid", 0) as int
		if id > 0:
			var proj := Projectile.deseralize(data)
			proj.set_multiplayer_authority(id)

			players[id].linked_player.pproj.bind(proj)

			return proj

	elif mode == 1:
		var data := arr[1] as Dictionary
		ProcGun.dbg_proj = data
		dbg_proj = data
		var id := data.get("uuid", 0) as int
		if id > 0:
			var proj := AltProjHandler.spawn_local(data.get(&"trans", Transform3D.IDENTITY))
			proj.set_multiplayer_authority(id)
			return proj

	return null


@rpc("any_peer", "call_local", "reliable")
func sfx_sync(sound_id: int, pos: Vector3, volume: float, pitch_scale: float, disable_falloff: bool) -> void:
	SFXHandler.play_world_local(sound_id, pos, volume, pitch_scale, disable_falloff)


@rpc("any_peer", "call_local", "reliable")
func vfx_sync(effect_id: int, pos: Vector3, data: Array) -> void:
	VFXHandler.spawn_local(effect_id, pos, data)


@rpc("any_peer", "call_local", "reliable")
func field_sync(field_id: int, trans: Transform3D, scale: float, duration: float, strength: float) -> void:
	FieldHandler.spawn_local(field_id, trans, scale, duration, strength)

#endregion



#region rpcs for card effects #################################

@rpc("any_peer", "call_local", "reliable")
func move_object(path: NodePath, pos: Vector3) -> void: # spacial warp
	print("warp %s to %s" % [path, pos])
	var node: Node3D = get_tree().root.get_node(path) as Node3D
	if node: node.global_position = pos


@rpc("any_peer", "call_local", "reliable")
func spawn_levelbody(pos: Vector3, type: LevelBody.Type, is_static: bool = false) -> void:
	var lvlb_scn := load("res://game/levelbody.tscn") as PackedScene
	var lvlb := lvlb_scn.instantiate() as LevelBody
	Game.world.levelgeo.add_child(lvlb)
	lvlb.global_position = pos
	lvlb.bodytype = type
	lvlb.shape = BoxShape3D.new()
	lvlb.is_static = is_static
	lvlb.update_display()
	lvlb.update_bodytype()


@rpc("any_peer", "call_local", "reliable")
func slow_player(amount: float, duration: float, n: float = 1.0) -> void:
	Game.player.speed.mult_temp(amount, duration, n)

#endregion
