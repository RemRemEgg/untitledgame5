extends MarginContainer
const PLAYER_ICON = preload("uid://caqvxbw61lbnt")

@onready var playereditor: VBoxContainer = $split/playereditor as VBoxContainer
@onready var p_name: LineEdit = $split/playereditor/name as LineEdit
@onready var p_color: ColorPicker = $split/playereditor/color as ColorPicker
@onready var p_ready: Button = $split/playereditor/ready as Button
@onready var start: Button = $split/playereditor/start as Button

@onready var playerlist: VFlowContainer = $split/playerlist as VFlowContainer

func _ready() -> void:
	p_name.text_changed.connect(_on_player_name_edit)
	p_color.color_changed.connect(_on_player_color_edit)
	p_ready.toggled.connect(_on_player_ready_edit)
	start.pressed.connect(_start_game)
	
	p_color.color = Network.self_player.color
	#p_name.text = str(Network.uuid)
	
	Network.players_changed.connect(load_players)
	load_players()
	
	if Network.is_server:
		start.visible = true
		get_tree().create_timer(0.15).timeout.connect(_start_game)


func _process(_delta: float) -> void:
	#start.disabled = !Network.players.values().all(func(p: Network.PlayerInfo): return p.ready)
	pass

func load_players() -> void:
	for c in playerlist.get_children():
		playerlist.remove_child(c) # memory leak lmao
		c.queue_free()
	Network.players.sort()
	for p in Network.players:
		var pi := (Network.players[p] as Network.PlayerInfo)
		var pcard := PLAYER_ICON.instantiate() as PlayerIcon
		pi.on_update.connect(pcard._on_player_update)
		playerlist.add_child(pcard)
		pcard.dispname.text = pi.name
		pcard.dispcolor.color = pi.color

func _on_player_name_edit(new_name: String) -> void:
	if new_name.ends_with("Player") && !new_name.begins_with("Player"):
		new_name = new_name.trim_suffix("Player")
		p_name.text = new_name
		p_name.caret_column = 1
	if new_name.is_empty():
		new_name = "Player"
		p_name.text = new_name
	Network.update_player.rpc(Network.uuid, {"name":new_name})

func _on_player_color_edit(new_color: Color) -> void:
	Network.update_player.rpc(Network.uuid, {"color":new_color})

func _on_player_ready_edit(is_ready: bool) -> void:
	Network.update_player.rpc(Network.uuid, {"ready":is_ready})
	playereditor.process_mode = PROCESS_MODE_DISABLED if is_ready else PROCESS_MODE_INHERIT

func _start_game() -> void:
	Network.change_scene.rpc("res://game/world.tscn")
