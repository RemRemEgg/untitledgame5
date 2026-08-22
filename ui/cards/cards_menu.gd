class_name CardsMenu
extends Control

var draws: Array[CardDrawData]
var current_draw: CardDrawData
var selection: Array[Card]
var picked_card: int
var animation_state: int = -1
var animation_timer: float = 0.0
var flip_animations: Array[float]
var local_mouse: Vector3

@onready var disp3d: Node3D = $"disp3d" as Node3D

@onready var spell_slot: Control = $spell_slot as Control
@onready var spell_1: Button = $spell_slot/spell_1 as Button
@onready var spell_2: Button = $spell_slot/spell_2 as Button
@onready var c_disp: CardIcon = $spell_slot/c_disp as CardIcon
@onready var s1_disp: FlowContainer = $spell_slot/s1_disp as FlowContainer
@onready var s2_disp: FlowContainer = $spell_slot/s2_disp as FlowContainer


func _ready() -> void:
	spell_1.pressed.connect(_pick_spell_slot.bind(1))
	spell_2.pressed.connect(_pick_spell_slot.bind(2))


func card_selection_time() -> void:
	if Console.AUTO_CARD_SELECT \
			|| (Console.AUTO_INIT_CARD_SELECT && Network.round_count == 0) \
			|| (!Network.is_server && Console.CLIENT_DUMMY):
		_draws_finished()
		return
	
	Game.player.deck_weights[Card.DECK_INIT] = 0.0
	if Network.round_count == 0: # first card draw
		new_draw().set_weights({Card.DECK_INIT:1.0}).set_exclusive(true).set_max_cards(2)
		new_draw().set_weights({Card.DECK_SPELL:1.0}).set_exclusive(true)
	else:
		# artifact draws
		if Network.self_player.losses in [4, 8, 16, 32, 64, 128]:
			new_draw().set_max_cards(3).add_forced_card(Card.ARTIFACT_DRAW_CARD)
		else: new_draw()
	
	visible = true
	spell_slot.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Game.mouse_fallback = Input.MOUSE_MODE_VISIBLE
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_next_card_draw()


func _next_card_draw() -> void:
	spell_slot.visible = false
	animation_state = 0
	animation_timer = 0.0
	
	if draws.is_empty():
		_draws_finished()
	else:
		current_draw = draws[0]
		draws.pop_front()
		var player := Game.player
		var weights_pre := player.deck_weights.duplicate()
		
		if current_draw.is_exclusive:
			for deck in player.deck_weights:
				player.deck_weights[deck] = 0.0
			for deck in current_draw.deck_weights:
				player.deck_weights[deck] = current_draw.deck_weights[deck]
		else:
			for deck in current_draw.deck_weights:
				player.deck_weights[deck] *= current_draw.deck_weights[deck]
		
		var max_cards: int = Console.MAX_CARD_OPTIONS if (Console.DEBUG) else (current_draw.max_cards + player.card_draw_mod)
		max_cards -= current_draw.forced_cards.size()
		selection = CardDeck.pick_weighted_cards_reduced_dupes(Card.ALL_CARDS, player, max_cards, false)
		for i in current_draw.forced_cards.size():
			selection.insert(floori(selection.size()/2.0), current_draw.forced_cards[i])
		player.deck_weights = weights_pre
		
		flip_animations.resize(selection.size())
		flip_animations.fill(-1.0)
		for card in selection:
			card.display.set_face_up(false)
		
		reset_card_displays()
		update_card_animations(0.0)


func card_selected() -> void:
	picked_card = -1
	selection = []
	reset_card_displays()
	_next_card_draw()


func _draws_finished() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Game.mouse_fallback = Input.MOUSE_MODE_CAPTURED
	process_mode = Node.PROCESS_MODE_DISABLED
	selection = []
	reset_card_displays()
	Network.change_to_state(Network.NS_IDLE)


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
				var picked := selection[picked_card]
				if picked.use_spell_selection:
					_setup_spell_slot()
				else:
					if picked.card_take_effect:
						picked.card_take_effect.call(Game.player)
					if !picked.is_fake:
						Game.player.add_card(picked)
					card_selected()


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
	if Input.is_action_pressed(&"dbg_button"):
		if Input.is_key_pressed(KEY_L): # hide without updating net state
			visible = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			Game.mouse_fallback = Input.MOUSE_MODE_CAPTURED
			process_mode = Node.PROCESS_MODE_DISABLED
			selection = []
			reset_card_displays()
		if Input.is_key_pressed(KEY_S): # skip
			_draws_finished()
		if Input.is_key_pressed(KEY_R): # reroll
			draws.push_front(current_draw)
			_next_card_draw()


func reset_card_displays() -> void:
	for c in disp3d.get_children(): disp3d.remove_child(c)
	for i in selection.size():
		var display := selection[i].wrapper_3d
		disp3d.add_child(display)


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
			-1: # waiting
				pass
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


func _setup_spell_slot() -> void:
	spell_slot.visible = true
	Util.remove_and_free_all_children(s1_disp)
	Util.remove_and_free_all_children(s2_disp)
	
	var card := selection[picked_card]
	c_disp.set_data_from_card(card)
	
	for s1card in Game.player.spell_1.cards:
		if !s1card.use_spell_selection: continue
		s1_disp.add_child(CardIcon.from_card(s1card, Game.player.spell_1.cards[s1card]))
	for s2card in Game.player.spell_2.cards:
		if !s2card.use_spell_selection: continue
		s2_disp.add_child(CardIcon.from_card(s2card, Game.player.spell_2.cards[s2card]))


func _pick_spell_slot(id: int) -> void:
	if !(picked_card+1): return
	var card := selection[picked_card]
	var spell: Spell
	if id == 1: spell = Game.player.spell_1
	if id == 2: spell = Game.player.spell_2
	
	Game.player.add_spell_card(card, spell)
	card_selected()


func new_draw() -> CardDrawData:
	var cdd := CardDrawData.new()
	draws.append(cdd)
	return cdd


class CardDrawData:
	var max_cards: int = 5
	var deck_weights: Dictionary[CardDeck, float]
	var is_exclusive: bool = false
	var forced_cards: Array[Card]
	
	
	func _init() -> void:
		deck_weights = {Card.DECK_INIT:0.0, Card.DECK_ARTIFACT:0.0}
	
	
	func set_max_cards(max_: int) -> CardDrawData:
		max_cards = max_
		return self
	
	
	func set_weights(weights: Dictionary[CardDeck, float]) -> CardDrawData:
		deck_weights.merge(weights, true)
		return self
	
	
	func set_exclusive(ex: bool = true) -> CardDrawData:
		is_exclusive = ex
		return self
	
	
	func add_forced_card(card: Card) -> CardDrawData:
		forced_cards.append(card)
		return self
