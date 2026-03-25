extends MarginContainer


func _ready() -> void:
	$vbox/host.pressed.connect(_host_game)
	$vbox/join.pressed.connect(_join_game)
	dbg_auto_join()

func dbg_auto_join() -> void:
	var error := Network.start_server()
	if error:
		print("error detected, moving right")
		get_window().position.x += 480
		await get_tree().create_timer(0.5).timeout
		Network.start_client("127.0.0.1")
	else:
		print("no error detected, moving left")
		get_window().position.x -= 480
	get_tree().change_scene_to_file(&"res://ui/lobby.tscn")



func _host_game() -> void:
	print("host game")
	var e := Network.start_server()
	if !e: get_tree().change_scene_to_file(&"res://ui/lobby.tscn")

func _join_game() -> void:
	print("join game %s" % $vbox/join_ip.text)
	var e := Network.start_client($vbox/join_ip.text)
	if !e: get_tree().change_scene_to_file(&"res://ui/lobby.tscn")
