extends MarginContainer

func _ready() -> void:
	$vbox/host.pressed.connect(_host_game)
	$vbox/join.pressed.connect(_join_game)
	dbg_auto_join()

func dbg_auto_join() -> void:
	var error := Network.start_server()
	if error:
		Console.print(&"dbg_auto_join: error detected, moving right")
		await get_tree().create_timer(0.1).timeout
		get_window().position.x += 380
		Network.start_client("127.0.0.1")
	else:
		Console.print(&"dbg_auto_join: no error detected, moving left")
		await get_tree().create_timer(0.1).timeout
		get_window().position.x -= 380
	Network.change_to_state(Network.NS_LOBBY)



func _host_game() -> void:
	Console.print(&"hosting game")
	var e := Network.start_server()
	if !e: Network.change_to_state(Network.NS_LOBBY)

func _join_game() -> void:
	Console.print(&"joining game ip:%s" % $vbox/join_ip.text)
	var e := Network.start_client($vbox/join_ip.text)
	if !e: Network.change_to_state(Network.NS_LOBBY) # TODO fix
