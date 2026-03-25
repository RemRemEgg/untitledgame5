class_name ProcProj
extends RefCounted


static var count: int = 0

var psqp: PhysicsShapeQueryParameters3D
var shape: SphereShape3D
var mesh: SphereMesh
var shader_mat: ShaderMaterial

var health: float = 4.0
var scale: float = 1.0
var damage: float = 4.0
var bounces: int = 10


func _init() -> void:
	#pp.shader_mat = SDFBuilder.new().build_shader_2D((Vector3(randf(), randf(), randf()) - Vector3(0.1, 0.1, 0.1)).normalized() * 7./12)
	mesh = SphereMesh.new()
	mesh.radial_segments = 4
	mesh.rings = 1
	mesh.radius = 0.15*scale; mesh.height = mesh.radius*2
	#mesh.material = shader_mat
	shape = SphereShape3D.new()
	shape.radius = mesh.radius
	psqp = PhysicsShapeQueryParameters3D.new()
	psqp.shape = shape
	psqp.collision_mask = 0b0
	
	travel_mod_stack = []
	travel_mod_data = []


func create_projectile() -> Projectile:
	var proj := Projectile.new()
	proj.proc = self
	
	proj.health = health
	proj.damage = damage
	#proj.depth = 0.0
	proj.mesh = mesh
	proj.scale *= scale
	proj.bounces = bounces
	
	Game.world.projectiles.add_child(proj)
	count += 1
	
	return proj
func destroy_projectile(proj: Projectile) -> void:
	var p := proj.get_parent(); if p: p.remove_child(proj)
	proj.queue_free()
	count -= 1


func process(proj: Projectile, delta: float) -> void:
	if !update(proj, delta): return destroy_projectile(proj)
	
	#proj.global_position = Entity.up_dim(proj.trans.origin)
	#proj.rotation.y = -proj.vel.angle()
#
func update(proj: Projectile, delta: float) -> bool:
	var dss: PhysicsDirectSpaceState3D = Game.world.get_world_3d().direct_space_state
	var rem := 1.0
	var i := 0
	psqp.collision_mask = proj.team | (0b0001)
	
	while rem > 0.0 && proj.health > 0.0 && i < 5: ##TODO do-while
		i += 1
		psqp.transform = proj.transform
		psqp.motion = proj.velocity * rem * delta
		var dist := dss.cast_motion(psqp)[1] * rem
		
		proj.transform.origin += proj.velocity * dist * delta
		proj.velocity += Vector3(0.0, -32.0, 0.0) * delta * dist
		#process_modifier(proj, Vector2i.ZERO, delta * dist)
		proj.health -= delta * dist
		rem -= dist
		psqp.transform = proj.transform
		shape.radius += 0.02
		var hits := dss.get_rest_info(psqp)
		shape.radius -= 0.02
		
		if hits:
			var cid := hits[&"collider_id"] as int
			var colc := instance_from_id(cid) as PhysicsBody3D
			if colc is Entity: process_hit(proj, colc as Entity)
			if colc is StaticBody3D:
				process_collision(proj, colc as StaticBody3D, hits.get(&"normal", -proj.velocity) as Vector3)
	
	return proj.health > 0.0


func process_hit(proj: Projectile, ent: Entity) -> void:
	pass
	#if ent.team & proj.team: return
	#
	#ent.proc.take_proj_damage(ent, proj)
	#deal_proj_damage(proj, ent)
	#ent.proc.deal_proj_damage(ent, proj)
#
#func deal_proj_damage(proj: Projectile, _ent: Entity) -> void:
	#proj.health = 0.0


func process_collision(proj: Projectile, _sb3d: StaticBody3D, normal: Vector3) -> void:
	if proj.bounces > 0:
		proj.bounces -= 1
		proj.velocity = proj.velocity.bounce(normal)
	else: proj.health = 0.0


##region MODIFIERS
#
#enum {MOD_DECELERATE, MOD_ACCELERATE, MOD_TIMESCALE, MOD_SIN, MOD_HOME}
var travel_mod_stack: PackedInt32Array
var travel_mod_data: PackedFloat32Array

var coll_mod_stack: PackedInt32Array
var coll_mod_data: PackedFloat32Array
#
#func add_modifier(type: int, data: Array[float]) -> void:
	#mod_stack.append(type)
	#mod_data.append_array(data)
#
#func process_modifier(proj: Projectile, i: Vector2i, delta: float) -> void:
	#if i.x >= mod_stack.size(): return
	#match mod_stack[i.x]:
		#MOD_DECELERATE: # [ strength ]
			#var x := proj.health / health
			#var s_a := x * x
			#x = (proj.health - delta * mod_data[i.y]) / health
			#var s_b := x * x
			#proj.vel *= s_b / s_a
			#process_modifier(proj, i+Vector2i(1, 1), delta)
		#MOD_ACCELERATE: # [ strength ]
			#var x := proj.health / health
			#var s_a := x * x
			#x = (proj.health - delta * mod_data[i.y]) / health
			#var s_b := x * x
			#proj.vel *= s_a / s_b
			#process_modifier(proj, i+Vector2i(1, 1), delta)
		#MOD_TIMESCALE: # [ strength ]
			#process_modifier(proj, i+Vector2i(1, 1), delta * mod_data[i.y])
		#MOD_SIN: # [ sin-rad/sec? ]
			#var s_a := sin((proj.health - health) * mod_data[i.y])
			#var s_b := sin((proj.health - health - delta) * mod_data[i.y])
			##proj.basis = proj.basis.rotated(proj.basis.y, s_b - s_a)
			#proj.vel = proj.vel.rotated(s_b - s_a)
			#process_modifier(proj, i+Vector2i(1, 1), delta)
		#MOD_HOME: # [ strength ]
			#if !proj.ownr || !proj.ownr.target: return process_modifier(proj, i+Vector2i(1, 1), delta)
			#var targ := proj.ownr.target.position - proj.trans.origin
			#var ang := targ.angle_to(proj.vel)
			#proj.vel = proj.vel.rotated(minf(absf(ang), delta * mod_data[i.y]) * -signf(ang))
			#process_modifier(proj, i+Vector2i(1, 1), delta)
#
##endregion
