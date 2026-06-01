@tool
@icon("res://textures/editor/spidergraph.svg")
class_name SpiderGraph
extends Control

@export_group("Graph")

@export_range(1, 2048) var radius: float = 128.0
@export var anti_alias: bool = true
@export_range(3, 100) var axis_count: int = 6
@export_range(-1, 100) var outline_width: float = 5.0
@export_range(-1, 100) var axis_width: float = 1.0
@export var axis_color: Color = Color(1.0, 1.0, 1.0, 0.5)
@export var axis_labels: PackedStringArray
@export var axis_label_size: int = 24
@export_range(0, 100) var inline_count: int = 3
@export_range(-1, 100) var inline_width: float = 1.0
@export var inline_color: Color = Color(1.0, 1.0, 1.0, 0.25)

@export_group("Data")
@export var values: Array[float]
@export var data_min: float = 0.0
@export var data_max: float = 1.0
@export_range(0.001, 1) var data_scale: float = 0.9
@export_range(-1, 100) var data_outline_width: float = 2.0
@export var data_outline_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var data_fill_color: Color = Color(1.0, 1.0, 1.0, 0.5)

var outline: PackedVector2Array
var inlines: Array[PackedVector2Array]
var data_points: PackedVector2Array
var data_fill_points: PackedVector2Array
var colors: PackedColorArray

func get_vec(i:float) -> Vector2: return Vector2.UP.rotated((i*PI) / axis_count)

func _ready() -> void: recalculate_graph()

func _process(_delta: float) -> void: if Engine.is_editor_hint(): recalculate_graph()

func recalculate_graph() -> void:
	queue_redraw()
	outline.resize(axis_count*2+2)
	colors.resize(axis_count*2+2)
	inlines.resize(inline_count)
	for i in inlines.size():
		inlines[i] = PackedVector2Array()
		inlines[i].resize(axis_count+1)
	
	for i in axis_count*2+1:
		colors[i] = Color.from_hsv((i-0.35) / (axis_count*2), 1.0, 1.0)
		if i % 2 == 0:
			outline[i] = get_vec(i) * radius
			for j:int in inline_count: inlines[j][floori(i/2.0)] = get_vec(i) * radius * (j+1.0)/(inline_count+1.0)
		else: outline[i] = get_vec(i-1).lerp(get_vec(i+1), 0.5) * radius
	outline[-1] = outline[1] # fix seam issue
	colors[-1] = colors[1] # ^
	
	axis_labels.resize(axis_count)
	values.resize(axis_count)
	data_points.resize(axis_count+1)
	data_fill_points.resize(axis_count)
	for i in data_points.size():
		var dist := clampf((values[i%axis_count] - data_min) / (data_max - data_min), 0.0, 1.0)
		data_points[i] = get_vec(i*2) * radius * (0.5 + data_scale*(dist-0.5))
		if i < data_fill_points.size(): data_fill_points[i] = data_points[i]


func _draw() -> void:
	for i:int in inline_count: draw_polyline(inlines[i], inline_color, inline_width, anti_alias)
	for i:int in axis_count: draw_line(Vector2.ZERO, outline[i*2], axis_color, axis_width, anti_alias)
	
	draw_colored_polygon(data_fill_points, data_fill_color)
	draw_polyline(data_points, data_outline_color, data_outline_width, anti_alias)
	
	draw_polyline_colors(outline, colors, outline_width, anti_alias)
	
	var font := ThemeDB.get_default_theme().default_font
	
	for i in axis_count:
		var pos := get_vec(i*2) * (radius + axis_label_size*0.75)
		
		var t_size := font.get_string_size(axis_labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, axis_label_size)
		var h_offset := -0.5 if absf(pos.x)<0.1 else (-1.0 if pos.x < 0.0 else 0.0)
		pos += Vector2(t_size.x*h_offset, t_size.y*0.25)
		
		draw_string_outline(font, pos, axis_labels[i], HORIZONTAL_ALIGNMENT_CENTER, -1, axis_label_size, 8, Color.BLACK)
		draw_string(font, pos, axis_labels[i], HORIZONTAL_ALIGNMENT_CENTER, -1, axis_label_size, colors[i*2])
