class_name CardIcon
extends MarginContainer

const CARD_ICON := preload("uid://ba8bixelqjeyx") as PackedScene


var card: Card

static func from_card(fcard: Card, m: int = 1) -> CardIcon:
	var ico := CARD_ICON.instantiate() as CardIcon
	ico.set_data_from_card(fcard, m)
	return ico


func set_data_from_card(fcard: Card, m: int = 1) -> void:
	card = fcard
	var bg := get_node(^"background") as ColorRect
	var abbv := bg.get_node(^"abbv") as Label
	var mult := bg.get_node(^"mult") as Label
	var d_once := bg.get_node(^"draw_once") as Panel
	bg.color = Color(Card.RARITY_COLORS[fcard.rarity])
	abbv.text = fcard.uuid
	mult.text = StringName("x%s" % m) if m>1 else &""
	d_once.visible = fcard.is_draw_once
