class_name PlayerIcon
extends ColorRect

signal pressed(id:int)

@onready var dispname: Label = $name as Label
@onready var disppfp: TextureRect = $pfp as TextureRect
var id: int


func _ready() -> void:
	gui_input.connect(_handle_input)


func _on_player_update(pi: Network.PlayerInfo) -> void:
	dispname.text = pi.name
	dispname.modulate = Color.GOLD if pi.ready else Color.WHITE
	disppfp.modulate = pi.color


func _handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var iemb := event as InputEventMouseButton
		if iemb.pressed && iemb.button_index == MouseButton.MOUSE_BUTTON_LEFT:
			pressed.emit(id)
