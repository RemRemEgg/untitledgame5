class_name CardDisplay
extends TextureRect

const CARD_DISPLAY := preload("uid://b5ava4xusp4lu")
const OUTLINE_COMMON := preload("uid://cr73ecy66f8or") as ShaderMaterial
const OUTLINE_UNUSUAL := preload("uid://b8j6y8svxyb2q") as ShaderMaterial
const OUTLINE_RARE = preload("uid://fif1sx8k4w8f") as ShaderMaterial
const OUTLINE_EPIC = preload("uid://caexkypvp4txu") as ShaderMaterial

var background: ColorRect

var content: MarginContainer
var card_name: Label
var card_image: TextureRect
var card_desc: RichTextLabel

var extras: Control
var outline: Panel
var spider_graph: SpiderGraph
var card_icon: MarginContainer


static func from_card(card: Card, deck: CardDeck) -> CardDisplay:
	var cdisp := CARD_DISPLAY.instantiate() as CardDisplay
	cdisp._node_initilization()
	
	cdisp.texture = deck.card_art
	cdisp.card_name.text = card.name
	cdisp.card_desc.text = card.desc
	
	cdisp.outline.modulate = Color(Card.RARITY_COLORS[card.rarity])
	match card.rarity:
		#Card.RARITY_COMMON: cdisp.outline.material = OUTLINE_COMMON
		#Card.RARITY_UNUSUAL: cdisp.outline.material = OUTLINE_UNUSUAL
		#Card.RARITY_RARE: cdisp.outline.material = OUTLINE_RARE
		#Card.RARITY_EPIC: cdisp.outline.material = OUTLINE_EPIC
		Card.RARITY_COMMON: cdisp.material = OUTLINE_COMMON
		Card.RARITY_UNUSUAL: cdisp.material = OUTLINE_UNUSUAL
		Card.RARITY_RARE: cdisp.material = OUTLINE_RARE
		Card.RARITY_EPIC: cdisp.material = OUTLINE_EPIC
	
	cdisp.spider_graph.values = card.spider
	cdisp.spider_graph.data_outline_color = Card.spider_to_color(card.spider)
	cdisp.spider_graph.recalculate_graph()
	(cdisp.card_icon.get_node(^"background") as ColorRect).color = Color(Card.RARITY_COLORS[card.rarity])
	(cdisp.card_icon.get_node(^"background/abbv") as Label).text = card.abbv
	(cdisp.card_icon.get_node(^"background/mult") as Label).text = &""
	
	return cdisp


func _node_initilization() -> void:
	background = $background as ColorRect
	
	content = $content as MarginContainer
	card_name = $content/vbox/name as Label
	card_image = $content/vbox/card_image as TextureRect
	card_desc = $content/vbox/desc as RichTextLabel
	
	extras = $extras as Control
	outline = $extras/outline as Panel
	spider_graph = $extras/spider_graph as SpiderGraph
	card_icon = $extras/card_mini_icon as MarginContainer



func set_face_up(facing: bool) -> void:
	background.visible = facing
	content.visible = facing
	extras.visible = facing
