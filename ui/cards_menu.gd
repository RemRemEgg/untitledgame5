class_name CardsMenu
extends CanvasLayer

@onready var temp_skip: Button = $temp_skip as Button


func _ready() -> void:
	temp_skip.pressed.connect(_card_selected)
	get_tree().create_timer(0.2).timeout.connect(_card_selected)


func _card_selection_time() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	process_mode = Node.PROCESS_MODE_ALWAYS


func _card_selected() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	process_mode = Node.PROCESS_MODE_DISABLED
	Network.selected_card.rpc_id(1)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion: get_viewport().set_input_as_handled()
		
