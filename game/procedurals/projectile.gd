class_name Projectile
extends MeshInstance3D

# TODO trail visuals update

#var next: Projectile # ll # fuck you ll you aint even real

const PROJECTILE := preload("uid://djlg0ybtmd4im")

var proc: ProcProj
var ownr: Entity

#var mesh: MeshInstance3D

var velocity: Vector3
#var left_owner: bool = false

#var depth: float = 0.0
var damage: float = 4.0
var time: float = 0.0
var bounces: int = 0
var knockback: float = 0.0

func _init() -> void:
	pass

func _process(delta: float) -> void:
	if !is_multiplayer_authority(): return
	if proc: proc.process(self, delta)

static func deseralize(data: Dictionary) -> Projectile:
	#var proj := new()
	var proj := PROJECTILE.instantiate() as Projectile
	
	var trans := data.get("trans", Transform3D()) as Transform3D
	proj.position = trans.origin
	
	return proj
