class_name CardDisplay
extends TextureRect

var background: ColorRect

var content: MarginContainer
var card_name: Label
var card_image: TextureRect
var card_desc: RichTextLabel

var extras: Control
var spider_graph: SpiderGraph
var card_icon: MarginContainer


func _init() -> void:
	background = $background as ColorRect
	
	content = $content as MarginContainer
	card_name = $content/vbox/name as Label
	card_image = $content/vbox/card_image as TextureRect
	card_desc = $content/vbox/desc as RichTextLabel
	
	extras = $extras as Control
	spider_graph = $extras/spider_graph as SpiderGraph
	card_icon = $extras/card_icon as MarginContainer



func set_face_up(facing: bool) -> void:
	background.visible = facing
	content.visible = facing
	extras.visible = facing
