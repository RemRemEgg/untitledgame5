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

@rpc("any_peer", "reliable")
func register_player(id: int, info: Dictionary) -> void:
	players[id] = PlayerInfo.deseralize(info)
	players_changed.emit()

@rpc("any_peer", "call_local", "reliable")
func update_player(id: int, info: Dictionary) -> void:
	(players[id] as PlayerInfo).update(info)

var loaded_players := 0
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
			#TODO
@rpc("authority", "call_local", "reliable")
func all_players_loaded() -> void:
	var cs := get_tree().current_scene
	cs.process_mode = Node.PROCESS_MODE_INHERIT

#endregion

class PlayerInfo:
	signal on_update(pi: PlayerInfo)
	
	var uuid: int = 0
	var name: String = "New Player"
	var color: Color = Color.from_hsv(randf_range(0, 1.0), 0.95, 0.95)
	var ready := false
	
	func seralize() -> Dictionary:
		var d: Dictionary = {}
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
