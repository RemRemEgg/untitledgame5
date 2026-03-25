class_name Projectile
extends MeshInstance3D

#var next: Projectile # ll # fuck you ll you aint even real

var proc: ProcProj
var ownr: Entity

#var mesh: MeshInstance3D

var team: int
var velocity: Vector3

#var depth: float = 0.0
var damage: float = 4.0
var health: float = 20.0
var bounces: int = 0

func _init() -> void:
	pass

func _process(delta: float) -> void:
	proc.process(self, delta)
