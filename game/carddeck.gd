class_name CardDeck
extends RefCounted

var deck_name: StringName
var card_art: Texture2D

var cards: Array[Card]

func _init(name: StringName, art: Texture2D) -> void:
	deck_name = name
	card_art = art


func get_random_card() -> Card:
	return cards[randi_range(0, cards.size()-1)] if !cards.is_empty() else null


func get_random_cards(n: int, allow_duplicates: bool = true) -> Array[Card]:
	var m := mini(n, cards.size())
	if m == 0: return []
	if m == 1: return [get_random_card()]
	
	if allow_duplicates:
		var arr: Array[Card] = []
		arr.resize(n)
		for i:int in n: arr[i] = get_random_card()
		return arr
	
	else:
		var arr: Array[Card] = cards.duplicate(false) as Array[Card]
		arr.shuffle()
		return arr.slice(0, m)
