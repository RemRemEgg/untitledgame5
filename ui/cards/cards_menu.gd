class_name CardsMenu
extends Control

var selection: Array[Card]
var picked_card: int
var animation_state: int = -1
var animation_timer: float = 0.0
var flip_animations: Array[float]
var local_mouse: Vector3


func card_selection_time() -> void:
	if Console.AUTO_CARD_SELECT:
		card_selected()
		return
	
	visible = true
	animation_state = 0
	animation_timer = 0.0
	
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Game.mouse_fallback = Input.MOUSE_MODE_VISIBLE
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	selection = []
	while selection.size() < mini(Card.ALL_CARDS.size(), 5): #TODO shitassery
		var random_card: Card = Card.ALL_CARDS.pick_random() as Card
		if !selection.has(random_card): selection.append(random_card)
	flip_animations.resize(selection.size())
	flip_animations.fill(-1.0)
	for card in selection:
		card.display.set_face_up(false)
	
	reset_card_displays()
	update_card_animations(0.0)


func _process(delta: float) -> void:
	#TODO custom flip anims based on rarity? at least more stylization based on rarity
	#TODO better hitboxing, sometimes mouse isnt correct
	var g_mouse := (get_global_mouse_position() / size) * 2.0 - Vector2.ONE
	local_mouse = Vector3(g_mouse.x, -g_mouse.y * (size.y/size.x), 0.0) * 0.933 # why 0.933 idfk
	
	animation_timer += delta
	update_card_animations(delta)
	match animation_state:
		-1: return
		0: # cards moving into position
			tick_animation_timer(1.0, 1)
		1: # cards in position, waiting for choice
			animation_timer = 1.0
		2: # card selected, pick animation
			if tick_animation_timer(1.5, -1):
				Game.player.add_card(selection[picked_card])
				
				card_selected()
				selection = []
				reset_card_displays()


func _input(event: InputEvent) -> void: # TODO cleanup
	if event is InputEventMouseButton:
		var iemb := event as InputEventMouseButton
		if animation_state == 1 && iemb.button_index == MOUSE_BUTTON_LEFT && iemb.pressed:
			for i in selection.size():
				if get_card_hover_pos(i):
					animation_state = 2
					animation_timer = 0.0
					picked_card = i
					Console.print(&"picked card %s" % selection[picked_card])
	if Input.is_key_pressed(KEY_L): # skip without updating net state
		visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		Game.mouse_fallback = Input.MOUSE_MODE_CAPTURED
		process_mode = Node.PROCESS_MODE_DISABLED
		selection = []
		reset_card_displays()


func card_selected() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Game.mouse_fallback = Input.MOUSE_MODE_CAPTURED
	process_mode = Node.PROCESS_MODE_DISABLED
	Network.change_to_state(Network.NS_IDLE)


func reset_card_displays() -> void:
	for chld in get_children(): remove_child(chld)
	for i in selection.size():
		var display := selection[i].wrapper_3d
		add_child(display)


func tick_animation_timer(max_time: float, next_state: int) -> bool:
	if animation_timer >= max_time:
		animation_state = next_state
		animation_timer = 0.0
		return true
	return false


func update_card_animations(delta: float) -> void:
	for i in selection.size():
		var display := selection[i].wrapper_3d
		var place := get_card_position(i, selection.size())
		match animation_state:
			0: # moving up
				display.position = Vector3(0.0, -5.0, 0.0).lerp(place, animation_timer ** 0.125)
				display.position.z = 0.0
				display.rotation = Vector3(0.0, 0.0, place.z)
				display.scale = Vector3.ONE
			1: # waiting
				display.position = place
				display.position.z = 0.0
				display.rotation = Vector3(0.0, 0.0, place.z)
				display.scale = Vector3.ONE
				var c_mouse := get_card_hover_pos(i)
				# look towards mouse, start card flip
				if c_mouse:
					if flip_animations[i] == -1.0: flip_animations[i] = 0.0
					display.position += Vector3(0.0, 0.02, 0.01)
					display.scale *= 1.1
					display.position += Vector3(display.position.x*-0.055, 0.02, 0.1)
					display.look_at(Vector3(-c_mouse.x, -c_mouse.y, -1.0) + display.position)
				# update card flip
				if flip_animations[i] >= 0.0 && flip_animations[i] < 2.0:
					flip_animations[i] += delta * 8.0
					if flip_animations[i] > 2.0: flip_animations[i] = 2.0
					display.rotate_object_local(Vector3.UP, flip_animations[i] * PI/2.0 + PI)
					selection[i].display.set_face_up(display.rotation.y >= -PI*1.0/2.0)
			_: # card picked
				if i == picked_card: # move to "gun"
					display.position = place.lerp(Vector3(2.0, 0.6, 0.01), (animation_timer/1.5)**8)
					display.position = place.lerp(Vector3(0.0, -2.0, 0.5), (animation_timer/1.5)**8)
					display.rotation = Vector3(0.0, 0.0, place.z)
					display.scale = Vector3.ONE * (1.2-(animation_timer/2.0))**0.5
					display.scale = Vector3.ONE * (1.2+(animation_timer/2.0))**0.5
				else: # hide
					display.position = place.lerp(Vector3(0.0, -3.0, 0.0), (animation_timer/1.5)**8)
					display.position.z = 0.0
					display.rotation = Vector3(0.0, 0.0, place.z)
					display.scale = Vector3.ONE * (1.0-(animation_timer/1.5))**2


func get_card_position(i: int, total: int) -> Vector3:
	var subi := (i-(total/2.0)+0.5) / (total+1.0)
	var x := subi*2.0
	var y := 0.15-(absf(subi)**1.64 * 0.5)
	var r := -subi*0.35
	var res := Vector3(x, y * (size.y/size.x), r)
	return res


func get_card_hover_pos(i: int) -> Vector3:
	var pos := get_card_position(i, selection.size()) + Vector3(0.0, 0.06 + (i * 0.002), 0.0)
	var c_mouse := local_mouse - pos
	if absf(c_mouse.x) < 0.13 && absf(c_mouse.y) < 0.23:
		return c_mouse
	return Vector3.ZERO
