class_name PlayerModel
extends Node3D

var player: Player
var time: float = 0.0
@export var material: Material

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
	set_color_recur(material, self)
	player = get_parent() as Player
	if !player: process_mode = Node.PROCESS_MODE_DISABLED
	
	if player.uuid == Network.uuid:
		head.transparency = 1.0
	
	var gun_scn := load("res://game/gun_model.tscn") as PackedScene
	gun = gun_scn.instantiate() as Node3D
	wristr.add_child(gun)
	gun.position = Vector3(-0.15, -0.3, 0.2)
	
	var magic_scn := load("res://game/magic_ball.tscn") as PackedScene
	magic = magic_scn.instantiate() as Node3D
	wristl.add_child(magic)
	magic.position = Vector3(0, -0.55, 0.35)


func _process(delta: float) -> void:
	if !player: return
	time += delta
	
	# walking
	var ang := sin(time*14.0)
	var amo := player.animation_data[Player.ANIM_VELOCITY]
	amo = amo / (amo + 60.0)
	hipr.rotation = Vector3(ang * amo * 1.25, 0.0, 0.0)
	hipl.rotation.x = -hipr.rotation.x
	shoulderl.rotation.x = hipr.rotation.x * 0.5 + head.rotation.x*0.75 - 0.55
	shoulderr.rotation.x = -hipr.rotation.x * 0.5 + head.rotation.x - 0.9
	
	# air / ground
	if !player.animation_data[Player.ANIM_STATE]:
		# in air
		hipr.rotation.x = hipr.rotation.x*0.2-0.7
		hipl.rotation.x = hipl.rotation.x*0.2-0.7
		kneer.rotation.x = 1.5
		kneel.rotation.x = 1.5
	else:
		# on ground
		kneer.rotation.x = 0.0
		kneel.rotation.x = 0.0
	
	# gun aiming
	if player.is_use_alt:
		shoulderr.rotation.x =-hipr.rotation.x * 0.1 + head.rotation.x - 0.75
		bicepr.rotation = Vector3(-0.25, 1.3, -0.55)
		wristr.rotation = Vector3(-0.18, -0.5, -0.18)
		gun.rotation = Vector3(0.89, 0.1, 0.81)
		gun.rotation.y -= 0.7*player.animation_data[Player.ANIM_RELOAD]
	else:
		bicepr.rotation = Vector3.ZERO
		wristr.rotation = Vector3.ZERO
		gun.rotation = Vector3.ZERO
	# reload / fire delay
	gun.rotation.x += 0.75 - (player.animation_data[Player.ANIM_RELOAD])
	
	# looking
	head.rotation = -player.camera.rotation
	
	# meleeing
	if player.animation_data[Player.ANIM_MELEE] <= 1.0:
		# player.animation_data[Player.ANIM_MELEE] [0.0, 1.0]
		var d := player.animation_data[Player.ANIM_MELEE] - 0.5 # [-0.5, 0.5]
		d = 1.0 - (absf(d*2.0)**2.0) # [0.0, 1.0, 0.0] exp
		hipr.rotation = Vector3(
			(-0.7-d*2.0) + head.rotation.x*0.5,
			d*1.2-0.5,
			0.0
		)
		kneer.rotation.x = 0.0
	
	# magicing
	var anim_mult := 2.0
	magic.scale = Vector3.ONE
	#if player.is_prep_cast: shoulderl.rotation.x = head.rotation.x - 1.4 + (shoulderl.rotation.x * 0.2)
	if player.animation_data[Player.ANIM_MAGIC] >= 0.0: # during cast
		magic.scale = Vector3.ONE * 2.5
		shoulderl.rotation.x = head.rotation.x - 1.4 + (shoulderl.rotation.x * 0.2)
		anim_mult = 8.0
	magic.position.y = (sin(time*2.0)*0.5 + 0.35)
	magic.rotation.y += delta * anim_mult
	magic.rotation.z = magic.rotation.y * -5.0
	magic.rotation.z = magic.rotation.y * 0.5
	
	# health & damage
	var pc := player.animation_data[Player.ANIM_HEALTH]
	var ht := player.animation_data[Player.ANIM_HURT]
	player.health_gradient.offsets = [0.0, pc - 0.0001, max(ht, pc) + 0.0001]
	player.health_gradient.colors = [Color.FIREBRICK, Color.GOLD, Color.DIM_GRAY] as PackedColorArray
	player.armor_gradient.offsets = [0.0, player.animation_data[Player.ANIM_ARMOR]]
