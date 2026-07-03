@tool
@icon("res://textures/editor/levelbody.svg")
class_name LevelBody
extends RigidBody3D

@export var is_static: bool = true:
	set(value):
		is_static = value
		freeze = is_static
		update_display()
enum Type {
	SOLID, ## Cannot be broken or moved through, solid to everything
	SCAFFOLD, ## Players and projectiles pass through it
	BREAKABLE ## Like solid, but takes damage from projectiles. Set health via [member health]
}
@export var bodytype: Type = Type.SOLID:
	set(value):
		bodytype = value
		material = null
		update_bodytype()
		update_display()
## Health of the body, only used with bodytype.BREAKABLE. Default player health is 100.0
@export var health: float = 50.0 #TODO scaling health
## Fixer cannot run on anything besides [BoxMesh]. You must manually add collisions for other meshes.
##[br]Changing this mesh's data will modify the meshes of all levelbodies with the same mesh.
##[br]Change this body's scale, then level fix to make it unique.
@export var mesh: Mesh:
	set(val):
		mesh = val
		update_display()
@export var is_harmful: bool = false

@export_subgroup("Danger Zone")
## [b]DO NOT[/b] edit existing material, make a new one
@export var material: Material:
	set(val):
		material = val
		update_display()
## Set only if making a custom mesh. Fixer autogenerates for [BoxMesh]
@export var shape: Shape3D:
	set(val):
		shape = val
		if has_node("collider"): ($collider as CollisionShape3D).shape = shape

func _ready() -> void:
	if Engine.is_editor_hint():
		update_display()
	else:
		if material == preload("res://shaders/level/solid_triplanar_fast.res"):
			material = material.duplicate() as Material
			(material as ShaderMaterial).set_shader_parameter(&"modulo", Color.from_hsv(randf(), randf_range(0.55, 1.0), randf_range(0.8, 1.0)))
		
		if is_static:
			var sync := $sync
			remove_child(sync)
			sync.queue_free()

func update_display() -> void:
	if has_node("mesh"):
		var m := $mesh as MeshInstance3D
		
		if !mesh: return
		m.mesh = mesh
		
		if !material: match bodytype:
			Type.SOLID: material = preload("res://shaders/level/solid_triplanar_fast.res")
			Type.SCAFFOLD: material = preload("res://shaders/level/scaffold.res")
			Type.BREAKABLE: material = preload("res://shaders/level/breakable.res")
		m.material_override = material

func update_bodytype() -> void:
	match bodytype:
		Type.SOLID, Type.BREAKABLE:
			collision_layer = 0b0001_0001
			collision_mask = 0b0001_0001
		Type.SCAFFOLD:
			collision_layer = 0b0001_0000
			collision_mask = 0b0001_0000

@rpc("any_peer", "call_local", "reliable")
func take_proj_hit(amount: float, dir: Vector3, pos: Vector3) -> void:
	if bodytype == Type.BREAKABLE:
		health -= amount
		if health <= 0.0:
			get_completely_destroyed_and_explodinated.rpc()
			return
	if !is_static:
		apply_impulse(dir, pos)

@rpc("authority", "call_local", "reliable")
func get_completely_destroyed_and_explodinated() -> void:
	var breakv := (preload("res://game/visuals/break_effect.tscn") as PackedScene).instantiate() as GPUParticles3D
	Game.world.visuals.add_child(breakv)
	if mesh is BoxMesh:
		(breakv.process_material as ParticleProcessMaterial).emission_box_extents = (mesh as BoxMesh).size
		breakv.amount = ceili((mesh as BoxMesh).size.dot(Vector3.ONE)) + 10
	breakv.global_transform = global_transform
	get_parent().remove_child(self)
	queue_free()
@rpc("any_peer", "call_local", "unreliable")
@warning_ignore("native_method_override")
func apply_central_impulse(impulse: Vector3) -> void:
	super(impulse)
