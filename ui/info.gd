class_name Info
extends BoxContainer

const CARD_ICON := preload("uid://ba8bixelqjeyx") as PackedScene
const PLAYER_ICON = preload("uid://caqvxbw61lbnt") as PackedScene

@onready var player_list: FlowContainer = $player_list as FlowContainer

@onready var player_name: Label = $info_list/player_name as Label
@onready var team_color: ColorRect = $info_list/team_color as ColorRect
@onready var quick_stats: Label = $info_list/quick_stats as Label
@onready var spider_graph: SpiderGraph = $info_list/spider_graph as SpiderGraph

@onready var card_list: FlowContainer = $card_list as FlowContainer


func _ready() -> void:
	for p in Network.players:
		var pi := (Network.players[p] as Network.PlayerInfo)
		
		var pcard := Util.PLAYER_ICON_SCN.instantiate() as PlayerIcon
		player_list.add_child(pcard)
		pcard.pressed.connect(swap_to_player)
		pcard.dispname.text = pi.name
		pcard.dispcolor.color = pi.color
		pcard.id = p




func _process(_delta: float) -> void:
	var mouse := get_global_mouse_position()
	var margin := 12.0
	for ico:Control in card_list.get_children():
		if (mouse.x > ico.global_position.x + margin && mouse.y > ico.global_position.y + margin &&\
				mouse.x < ico.global_position.x + ico.size.x - margin && mouse.y < ico.global_position.y + ico.size.y - margin):
			ico.modulate = Color.GOLD
		else:
			ico.modulate = Color.WHITE


func swap_to_player(id: int) -> void:
	var pi := (Network.players[id] as Network.PlayerInfo)
	for c in player_list.get_children() as Array[PlayerIcon]:
		c.dispname.modulate = Color.GOLD if c.id == id else Color.WHITE
	
	player_name.text = pi.name
	team_color.color = pi.color
	quick_stats.text = &"%s Wins | %s:%s" % [pi.wins, pi.uuid, Network.NS_NAME[pi.state]]
	
	var spider: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	
	Util.remove_and_free_all_children(card_list)
	for card_uuid in (pi.cards.keys() as Array[StringName]):
		var card := Card.get_card(card_uuid)
		if !card:
			Console.print_err(&"Cannot find card %s" % card_uuid)
			return
		var count := pi.cards[card_uuid]
		
		for i:int in 6: spider[i] += card.spider[i]*count
		
		var ico := CARD_ICON.instantiate()
		var bg := ico.get_node(^"background") as ColorRect
		var abbv := bg.get_node(^"abbv") as Label
		var mult := bg.get_node(^"mult") as Label
		bg.color = Color(Card.RARITY_COLORS[card.rarity])
		abbv.text = card.abbv
		mult.text = StringName("x%s" % count) if count>1 else &""
		card_list.add_child(ico)
	
	var smin := +1000000.0
	var smax := -1000000.0
	for v in spider:
		if v < smin: smin = v
		if v > smax: smax = v
	smin -= 1.0
	smax += 1.0
	spider_graph.data_min = smin
	spider_graph.data_max = smax
	spider_graph.values = spider
	spider_graph.recalculate_graph()
