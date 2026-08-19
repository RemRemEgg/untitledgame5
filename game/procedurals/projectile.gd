class_name Projectile
extends MeshInstance3D

# TODO trail visuals update

#var next: Projectile # ll # fuck you ll you aint even real

static var PACKED := preload("uid://djlg0ybtmd4im")
@onready var trail: Trail = $trail as Trail

var proc: ProcProj
var ownr: Entity

var velocity: Vector3

var damage: float = 4.0
var time: float = 0.0
var bounces: int = 0
var knockback: float = 0.0
var strength: float = 1.0

func _init() -> void:
	pass

func _process(delta: float) -> void:
	if !is_multiplayer_authority(): return
	if proc: proc.process(self, delta)
	else: kill()

static func deseralize(data: Dictionary) -> Projectile:
	var proj := PACKED.instantiate() as Projectile
	
	var trans := data.get("trans", Transform3D()) as Transform3D
	proj.position = trans.origin
	
	return proj


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		trail.unbind()


func kill() -> void:
	VFXHandler.spawn(VFXHandler.PARTICLE_BURST, global_position, [0.5])
	var p := get_parent(); if p: p.remove_child(self)
	queue_free()
