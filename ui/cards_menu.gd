class_name CardsMenu
extends Control

var selection: Array[Card]
var picked_card: int
var animation_state: int = -1
var animation_timer: float = 0.0

func get_card_position(i: int, total: int) -> Vector3:
	#var res := Vector3(
		#((i+1) * size.x) / (total + 1.0), # x
		#size.y * 0.12, # y
		#(i - (total - 1.0)/2.0) * 0.05) # r
	#res.x -= card_size.x/2.0
	#res.y += (cos(res.z)-1.0) * -10000.0
	var subi := (i-(total/2.0)+0.5) / (total+1.0)
	var x := subi*2.0
	var y := 0.15-(absf(subi)**1.64 * 0.5)
	var r := -subi*0.35
	var res := Vector3(x, y * (size.y/size.x), r)# * ((size.x-16.0)/size.y)
	return res



func card_selection_time() -> void:
	visible = true
	animation_state = 0
	animation_timer = 0.0
	
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	selection = []
	while selection.size() < 7: #TODO shitassery
		var random_card: Card = Card.ALL_CARDS.pick_random() as Card
		if !selection.has(random_card): selection.append(random_card)
	reset_card_display()
	update_card_display()

func card_selected() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	process_mode = Node.PROCESS_MODE_DISABLED
	Network.change_to_state(Network.NS_IDLE)


func tick_animation_timer(max_time: float, next_state: int) -> bool:
	if animation_timer >= max_time:
		animation_state = next_state
		animation_timer = 0.0
		return true
	return false
func _process(delta: float) -> void:
	Game.player.hud.debug_any.text = "%s" % animation_state
	animation_timer += delta
	update_card_display()
	match animation_state:
		-1: return
		0: # cards moving into position
			tick_animation_timer(1.0, 1)
		1: # cards in position, waiting for choice
			animation_timer = 1.0
			if selection.is_empty(): return # TODO cleanup
			var g_mouse := (get_global_mouse_position() / size) * 2.0 - Vector2.ONE
			var s_mouse := Vector3(g_mouse.x, -g_mouse.y * (size.y/size.x), 0.0) * 0.933 # why 0.933 idfk
			for i in selection.size():
				var pos := get_card_position(i, selection.size()) + Vector3(0.0, 0.06, 0.0)
				var l_mouse := (s_mouse - pos).abs()
				if l_mouse.x < 0.12 && l_mouse.y < 0.23:
					selection[i].display.position += Vector3(0.0, 0.02, 0.01)
					selection[i].display.scale *= 1.1
		2: # card selected, pick animation
			if tick_animation_timer(1.5, -1):
				Game.player.cards.append(selection[picked_card])
				card_selected()


func reset_card_display() -> void:
	for chld in get_children(): remove_child(chld)
	for i in selection.size():
		var display := selection[i].display
		add_child(display)

func upscale(vec: Vector2) -> Vector3: return Vector3(vec.x, vec.y, 0.0)
func update_card_display() -> void:
	for i in selection.size():
		var display := selection[i].display
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
				card_hover(i)
			_:
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

func card_hover(i: int) -> bool:
	var g_mouse := (get_global_mouse_position() / size) * 2.0 - Vector2.ONE
	var s_mouse := Vector3(g_mouse.x, -g_mouse.y * (size.y/size.x), 0.0) * 0.933 # why 0.933 idfk
	var pos := get_card_position(i, selection.size()) + Vector3(0.0, 0.06, 0.0)
	var l_mouse := s_mouse - pos
	if absf(l_mouse.x) < 0.13 && absf(l_mouse.y) < 0.23:
		selection[i].display.position += Vector3(pos.x*-0.055, 0.02, 0.1)
		selection[i].display.look_at(Vector3(-l_mouse.x, -l_mouse.y, -1.0) + selection[i].display.position)
		return true
	return false

func _input(event: InputEvent) -> void: # TODO cleanup
	if event is InputEventMouseButton:
		var iemb := event as InputEventMouseButton
		Console.print("presssed mouse %s" % iemb.button_index)
		if animation_state == 1 && iemb.button_index == MOUSE_BUTTON_LEFT && iemb.pressed:
			for i in selection.size():
				if card_hover(i):
					animation_state = 2
					animation_timer = 0.0
					picked_card = i
					Console.print(&"picked card %s" % selection[picked_card])
