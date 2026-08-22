class_name CardDisplay
extends TextureRect

const CARD_DISPLAY := preload("uid://b5ava4xusp4lu")
const OUTLINE_COMMON := preload("uid://cr73ecy66f8or") as ShaderMaterial
const OUTLINE_UNUSUAL := preload("uid://b8j6y8svxyb2q") as ShaderMaterial
const OUTLINE_RARE = preload("uid://fif1sx8k4w8f") as ShaderMaterial
const OUTLINE_EPIC = preload("uid://caexkypvp4txu") as ShaderMaterial
const OUTLINE_ARTIFACT = preload("uid://bwblbnbrntr11") as ShaderMaterial


var background: Panel

var content: MarginContainer
var card_name: Label
var card_image: TextureRect
var card_desc: RichTextLabel

var extras: Control
var outline: Panel
var spider_graph: SpiderGraph
var card_icon: CardIcon


static func from_card(card: Card, deck: CardDeck) -> CardDisplay:
	var cdisp := CARD_DISPLAY.instantiate() as CardDisplay
	cdisp._node_initilization()
	
	var image_path := &"res://textures/cards/%s.png" % card.uuid.to_lower()
	if ResourceLoader.exists(image_path):
		cdisp.card_image.texture = load(image_path) as CompressedTexture2D
	
	cdisp.texture = deck.card_art
	cdisp.card_name.text = card.name
	cdisp.card_desc.text = card.desc
	
	cdisp.outline.modulate = Color(Card.RARITY_COLORS[card.rarity])
	match card.rarity:
		Card.RARITY_COMMON: cdisp.material = OUTLINE_COMMON
		Card.RARITY_UNUSUAL: cdisp.material = OUTLINE_UNUSUAL
		Card.RARITY_RARE: cdisp.material = OUTLINE_RARE
		Card.RARITY_EPIC: cdisp.material = OUTLINE_EPIC
		Card.RARITY_ARTIFACT: cdisp.material = OUTLINE_ARTIFACT
	
	cdisp.spider_graph.values = card.spider as PackedFloat64Array
	cdisp.spider_graph.data_outline_color = Card.spider_to_color(card.spider)
	cdisp.spider_graph.recalculate_graph()
	
	cdisp.card_icon.set_data_from_card(card)
	
	return cdisp


func _node_initilization() -> void:
	background = $background as Panel
	
	content = $content as MarginContainer
	card_name = $content/vbox/name as Label
	card_image = $content/vbox/image as TextureRect
	card_desc = $content/vbox/desc as RichTextLabel
	
	extras = $extras as Control
	outline = $extras/outline as Panel
	spider_graph = $extras/spider_graph as SpiderGraph
	card_icon = $extras/icon_clip/icon as CardIcon



func set_face_up(facing: bool) -> void:
	background.visible = facing
	content.visible = facing
	extras.visible = facing
