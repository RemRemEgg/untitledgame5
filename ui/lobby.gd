extends MarginContainer

@onready var playereditor: VBoxContainer = $split/playereditor as VBoxContainer
@onready var p_name: LineEdit = $split/playereditor/name as LineEdit
@onready var p_color: ColorPicker = $split/playereditor/color as ColorPicker
@onready var p_ready: Button = $split/playereditor/ready as Button
@onready var start: Button = $split/playereditor/start as Button
@onready var fullscreen: Button = $split/playereditor/fullscreen as Button

@onready var volume_slider: HSlider = $split/playereditor/volume/slider as HSlider
@onready var test_sound: Button = $split/playereditor/volume/test_sound as Button

@onready var playerlist: VFlowContainer = $split/playerlist as VFlowContainer

func _ready() -> void:
	p_name.text_changed.connect(_on_player_name_edit)
	p_color.color_changed.connect(_on_player_color_edit)
	p_ready.toggled.connect(_on_player_ready_edit)
	start.pressed.connect(Network.start_game)
	fullscreen.pressed.connect(DisplayServer.window_set_mode.bind(DisplayServer.WINDOW_MODE_FULLSCREEN))
	
	volume_slider.drag_ended.connect(_update_volume)
	test_sound.pressed.connect(_test_sound)
	
	p_color.color = Network.self_player.color
	
	Network.players_changed.connect(load_players)
	load_players()
	
	if Console.AUTO_FULLSCREEN && !(!Network.is_server && Console.CLIENT_DUMMY): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	if Console.AUTO_FULLSCREEN && (!Network.is_server && Console.CLIENT_DUMMY):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
		Engine.max_fps = 15
		AudioServer.set_bus_mute(0, true)
	if Network.is_server:
		start.visible = true
		if Console.AUTO_START_GAME: get_tree().create_timer(0.25).timeout.connect(Network.start_game)


func _process(_delta: float) -> void:
	start.disabled = !Network.players.values().all(func(p: Network.PlayerInfo)->bool: return p.ready)


func load_players() -> void:
	for c in playerlist.get_children():
		playerlist.remove_child(c)
		c.queue_free()
	Network.players.sort()
	for p in Network.players:
		var pi := (Network.players[p] as Network.PlayerInfo)
		var pcard := Util.PLAYER_ICON_SCN.instantiate() as PlayerIcon
		pi.on_update.connect(pcard._on_player_update)
		playerlist.add_child(pcard)
		pcard.dispname.text = pi.name
		pcard.disppfp.modulate = pi.color


func _on_player_name_edit(new_name: String) -> void:
	if new_name.ends_with("Player") && !new_name.begins_with("Player"):
		new_name = new_name.trim_suffix("Player")
		p_name.text = new_name
		p_name.caret_column = 1
	if new_name.is_empty():
		new_name = "Player"
		p_name.text = new_name
	Network.update_player.rpc({&"name":new_name})


func _on_player_color_edit(new_color: Color) -> void:
	Network.update_player.rpc({&"color":new_color})


func _on_player_ready_edit(is_ready: bool) -> void:
	Network.update_player.rpc({&"ready":is_ready})
	playereditor.process_mode = PROCESS_MODE_DISABLED if is_ready else PROCESS_MODE_INHERIT


func _update_volume(__:bool) -> void:
	AudioServer.set_bus_volume_linear(0, volume_slider.value / 100.0)
	_test_sound()


func _test_sound() -> void:
	SFXHandler.play_user(SFXHandler.EXPLOSION, 0.0)
