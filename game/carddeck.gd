class_name CardDeck
extends RefCounted

var deck_name: StringName
var card_art: Texture2D

var cards: Array[Card]


func _init(name: StringName, art: Texture2D) -> void:
	deck_name = name
	card_art = art


static func pick_weighted_cards(deck: Array[Card], player: Player, n: int, allow_duplicates: bool = true) -> Array[Card]:
	var valid_cards: Array[Card] = []
	var total_weight: float = 0.0
	
	for card in deck:
		if card.rarity_eval.can_draw(player):
			var weight := card.get_weight(player)
			if weight <= 0.0: continue
			total_weight += weight
			valid_cards.append(card)
	
	if !allow_duplicates && n >= valid_cards.size():
		valid_cards.shuffle()
		return valid_cards
	
	var random_cards: Array[Card] = []
	for ni in n:
		var rngw := randf_range(0, total_weight)
		for ci in valid_cards.size():
			var weight := valid_cards[ci].get_weight(player)
			rngw -= weight
			if rngw <= 0.0:
				random_cards.append(valid_cards[ci])
				if !allow_duplicates:
					valid_cards.remove_at(ci)
					total_weight -= weight
				break
	
	return random_cards


static func pick_weighted_cards_reduced_dupes(deck: Array[Card], player: Player, n: int, allow_duplicates: bool = true) -> Array[Card]:
	var valid_cards: Array[Card] = []
	var total_weight: float = 0.0
	var weight_storage := player.deck_weights
	
	for card in deck:
		if card.rarity_eval.can_draw(player):
			if card.get_weight(player) <= 0.0: continue
			valid_cards.append(card)
	
	if !allow_duplicates && n >= valid_cards.size():
		valid_cards.shuffle()
		return valid_cards
	
	
	var random_cards: Array[Card] = []
	for ni in n:
		total_weight = 0
		for card in valid_cards:
			total_weight += card.get_weight(player)
		
		var rngw := randf_range(0, total_weight)
		for ci in valid_cards.size():
			var weight := valid_cards[ci].get_weight(player)
			rngw -= weight
			if rngw <= 0.0:
				player.deck_weights[valid_cards[ci].deck] *= 0.6
				random_cards.append(valid_cards[ci])
				if !allow_duplicates:
					valid_cards.remove_at(ci)
					total_weight -= weight
				break
	
	player.deck_weights = weight_storage
	return random_cards
