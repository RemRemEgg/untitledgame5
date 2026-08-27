@tool
@icon("res://textures/editor/levelbody.svg")
class_name LevelBody
extends RigidBody3D

@export_tool_button("Snap to Grid", "SnapGrid") var stg_btn: Callable = snap_to_grid
@export_tool_button("Generate Simplified Collider", "CollisionObject3D") var simcol_btn: Callable = generate_simple_collider
@export_tool_button("Generate Trimesh Collider", "CollisionPolygon3D") var tricol_btn: Callable = generate_trimesh_collider
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
@export var health: float = 40.0
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

func snap_to_grid() -> void:
	var udrd := BuildTool.inst.get_undo_redo()
	udrd.create_action(&"Snap LevelBody to grid")
	udrd.add_undo_property(self, &"position", position)
	var offset := Vector3.ZERO
	if mesh is BoxMesh:
		offset = mesh.size * 0.5
		offset -= offset.round()
	position = (position - offset).round() + offset
	udrd.add_do_property(self, &"position", position)
	udrd.commit_action()


func generate_simple_collider() -> void:
	shape = mesh.create_convex_shape(true, false)


func generate_trimesh_collider() -> void:
	shape = mesh.create_trimesh_shape()


func _ready() -> void:
	if Engine.is_editor_hint():
		update_display()
	else:
		if material == preload("res://shaders/world/solid_triplanar_fast.res"):
			material = material.duplicate() as Material
			(material as ShaderMaterial).set_shader_parameter(&"modulo", Color.from_hsv(randf(), randf_range(0.55, 1.0), randf_range(0.8, 1.0)))
		
		if is_static:
			var sync := $sync
			remove_child(sync)
			sync.queue_free()
		
		var mo := $mesh as MeshInstance3D
		mo.position = Vector3(randf(), randf(), randf())*0.003


func update_display() -> void:
	if has_node("mesh"):
		var m := $mesh as MeshInstance3D
		
		if !mesh: return
		m.mesh = mesh
		
		if !material: match bodytype:
			Type.SOLID: material = preload("res://shaders/world/solid_triplanar_fast.res")
			Type.SCAFFOLD: material = preload("res://shaders/world/scaffold.res")
			Type.BREAKABLE: material = preload("res://shaders/world/breakable.res")
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
	var vfx_size := Vector3.ONE
	var vfx_amount := 10
	if mesh is BoxMesh:
		vfx_size = (mesh as BoxMesh).size
		vfx_amount += ceili((mesh as BoxMesh).size.dot(Vector3.ONE))
	VFXHandler.spawn_local(VFXHandler.BLOCK_BREAK, global_position, [global_basis, vfx_size, vfx_amount])
	get_parent().remove_child(self)
	queue_free()


@rpc("any_peer", "call_local", "unreliable")
@warning_ignore("native_method_override")
func apply_central_impulse(impulse: Vector3) -> void:
	super(impulse)


func _process(_delta: float) -> void: pass
