class_name PlayerModel
extends Node3D

var player: Player

@onready var torso: MeshInstance3D = $torso as MeshInstance3D
@onready var head: MeshInstance3D = $torso/head as MeshInstance3D

@onready var shoulderl: MeshInstance3D = $torso/shoulderl as MeshInstance3D
@onready var bicepl: MeshInstance3D = $torso/shoulderl/bicepl as MeshInstance3D
@onready var forearml: MeshInstance3D = $torso/shoulderl/bicepl/forearml as MeshInstance3D
@onready var wristl: MeshInstance3D = $torso/shoulderl/bicepl/forearml/wristl as MeshInstance3D
@onready var knuckle_1l: MeshInstance3D = $torso/shoulderl/bicepl/forearml/wristl/knuckle1l as MeshInstance3D
@onready var knuckle_2l: MeshInstance3D = $torso/shoulderl/bicepl/forearml/wristl/knuckle2l as MeshInstance3D
@onready var knuckle_3l: MeshInstance3D = $torso/shoulderl/bicepl/forearml/wristl/knuckle3l as MeshInstance3D
var magic: Node3D

@onready var shoulderr: MeshInstance3D = $torso/shoulderr as MeshInstance3D
@onready var bicepr: MeshInstance3D = $torso/shoulderr/bicepr as MeshInstance3D
@onready var forearmr: MeshInstance3D = $torso/shoulderr/bicepr/forearmr as MeshInstance3D
@onready var wristr: MeshInstance3D = $torso/shoulderr/bicepr/forearmr/wristr as MeshInstance3D
@onready var knuckle_1r: MeshInstance3D = $torso/shoulderr/bicepr/forearmr/wristr/knuckle1r as MeshInstance3D
@onready var knuckle_2r: MeshInstance3D = $torso/shoulderr/bicepr/forearmr/wristr/knuckle2r as MeshInstance3D
@onready var knuckle_3r: MeshInstance3D = $torso/shoulderr/bicepr/forearmr/wristr/knuckle3r as MeshInstance3D
var gun: Node3D

@onready var pelvis: MeshInstance3D = $torso/pelvis as MeshInstance3D

@onready var hipl: MeshInstance3D = $torso/pelvis/hipl as MeshInstance3D
@onready var thighl: MeshInstance3D = $torso/pelvis/hipl/thighl as MeshInstance3D
@onready var kneel: MeshInstance3D = $torso/pelvis/hipl/thighl/kneel as MeshInstance3D
@onready var shinl: MeshInstance3D = $torso/pelvis/hipl/thighl/kneel/shinl as MeshInstance3D

@onready var hipr: MeshInstance3D = $torso/pelvis/hipr as MeshInstance3D
@onready var thighr: MeshInstance3D = $torso/pelvis/hipr/thighr as MeshInstance3D
@onready var kneer: MeshInstance3D = $torso/pelvis/hipr/thighr/kneer as MeshInstance3D
@onready var shinr: MeshInstance3D = $torso/pelvis/hipr/thighr/kneer/shinr as MeshInstance3D



func set_color_recur(mat: StandardMaterial3D, node: Node3D = self) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = mat
	for c in node.get_children():
		set_color_recur(mat, c as Node3D)


func _ready() -> void:
	player = get_parent() as Player
	if !player: process_mode = Node.PROCESS_MODE_DISABLED
	
	if player.uuid == Network.uuid:
		head.visible = false
	
	var gun_scn := load("res://game/gun_model.tscn") as PackedScene
	gun = gun_scn.instantiate() as Node3D
	wristr.add_child(gun)
	gun.position = Vector3(-0.15, -0.3, 0.2)
	
	var magic_scn := load("res://game/magic_ball.tscn") as PackedScene
	magic = magic_scn.instantiate() as Node3D
	wristl.add_child(magic)
	magic.position = Vector3(0, -0.55, 0.35)


func _process(_delta: float) -> void:
	if !player: return
	
	# walking
	var ang := sin(Time.get_ticks_msec()/120.0)
	var amo := player.animation_data[0]
	amo = amo / (amo + 35.0)
	hipr.rotation = Vector3(ang * amo, 0.0, 0.0)
	hipl.rotation.x = -hipr.rotation.x
	shoulderl.rotation.x = hipr.rotation.x * 0.7 + head.rotation.x*0.75 - 0.5
	shoulderr.rotation.x = -hipr.rotation.x * 0.7 + head.rotation.x - 1.0
	
	if !player.animation_data[3]:
		hipr.rotation.x = hipr.rotation.x*0.2-0.7
		hipl.rotation.x = hipl.rotation.x*0.2-0.7
		kneer.rotation.x = 1.5
		kneel.rotation.x = 1.5
	else:
		kneer.rotation.x = 0.0
		kneel.rotation.x = 0.0
	
	# reload / fire delay
	gun.rotation.x = 0.75-player.animation_data[4]
	
	# looking
	head.rotation = -player.camera.rotation
	
	# meleeing
	if player.animation_data[1] <= 1.0:
		# player.animation_data[1] [0.0, 1.0]
		var d := player.animation_data[1] - 0.5 # [-0.5, 0.5]
		d = 1.0 - (absf(d*2.0)**0.5) # [0.0, 1.0, 0.0] exp
		hipr.rotation = Vector3(
			(-0.7-d*2.0) + head.rotation.x*0.75,
			d*1.2-0.5,
			0.0
		)
	
	# magicing
	if player.animation_data[2] >= 0.0: # during cast
		magic.scale = Vector3.ONE * 2.5
	elif player.animation_data[2] >= -1.0: # recharge [0.0, -1.0]
		var d := player.animation_data[2]*-3.02 # [0.0, 3.0]
		magic.scale = (Vector3.ONE*d - Vector3(2.0, 0.0, 1.0)).clampf(0.1, 0.85)
	else: # idle
		magic.scale = Vector3.ONE
