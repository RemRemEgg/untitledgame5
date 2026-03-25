class_name PlayerIcon
extends ColorRect

@onready var dispname: Label = $name as Label
@onready var dispcolor: ColorRect = $color as ColorRect

func _on_player_update(pi: Network.PlayerInfo) -> void:
	dispname.text = pi.name
	dispname.modulate = Color.GOLD if pi.ready else Color.WHITE
	dispcolor.color = pi.color
