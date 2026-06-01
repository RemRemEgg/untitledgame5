class_name ProcProj
extends RefCounted

func seralize() -> Dictionary:
	var d: Dictionary[String, Variant] = {}
	
	d.color = shader_mat.albedo_color
	d.scale = scale.value
	
	return d

static func deseralize(info: Dictionary) -> ProcProj:
	var proc := new()
	
	proc.shader_mat.albedo_color = info.get("color", Color.WHITE)
	proc.scale.value = info.get("scale", 1.0)
	
	return proc



static var count: int = 0

var psqp: PhysicsShapeQueryParameters3D
var prqp: PhysicsRayQueryParameters3D
var shape: SphereShape3D
var mesh: SphereMesh
var shader_mat: StandardMaterial3D

func reset_stats() -> void:
	time.reset_value()
	scale.reset_value()
	damage.reset_value()
	bounces.reset_value()
	knockback.reset_value()
	collide_hooks = []
	damage_hooks = []

func calculate_stats() -> void:
	time.calculate_value()
	scale.calculate_value()
	damage.calculate_value()
	bounces.calculate_value()
	knockback.calculate_value()

#modifiable stats
var time := Stat.new(4.0)
var scale := Stat.new(1.0)
var damage := Stat.new(20.0)
var bounces := Stat.new(0)
var knockback := Stat.new(0.0)
##Hook for projectile hitting an object or entity, without bouncing
##[codeblock]func(bullet:Projectile,collider:CollisionObject3D) -> void:[/codeblock]
var collide_hooks: Array[Callable]
##Hook for projectile damaging entity
##[codeblock]func(bullet:Projectile,hit_player:Player) -> void:[/codeblock]
var damage_hooks: Array[Callable]


func _init() -> void:
	shader_mat = StandardMaterial3D.new()
	shader_mat.albedo_color = Color.from_hsv(randf_range(0.0, 1.0), 0.85, 0.85)
	mesh = SphereMesh.new()
	mesh.radial_segments = 4
	mesh.rings = 1
	mesh.radius = 0.1; mesh.height = mesh.radius*2
	mesh.material = shader_mat
	shape = SphereShape3D.new()
	shape.radius = mesh.radius
	psqp = PhysicsShapeQueryParameters3D.new()
	psqp.shape = shape
	psqp.collision_mask = 0b0110
	prqp = PhysicsRayQueryParameters3D.new()
	prqp.collision_mask = 0b0001
	
	travel_mod_stack = []
	travel_mod_data = []


func create_projectile() -> Projectile:
	var proj := Projectile.new()
	bind(proj)
	count += 1
	return proj
func bind(proj: Projectile) -> void:
	proj.proc = self
	
	proj.time = 0.0
	proj.damage = damage.value
	#proj.depth = 0.0
	proj.mesh = mesh
	proj.scale *= scale.value
	proj.bounces = bounces.value_int
	proj.knockback = knockback.value
func destroy_projectile(proj: Projectile) -> void:
	var p := proj.get_parent(); if p: p.remove_child(proj)
	proj.queue_free()
	count -= 1


func process(proj: Projectile, delta: float) -> void:
	update(proj, delta)
	if proj.time >= time.value: destroy_projectile(proj)

func update(proj: Projectile, delta: float) -> void:
	var dss: PhysicsDirectSpaceState3D = Game.world.get_world_3d().direct_space_state
	#TODO custom collision api?
	#TODO pserver rids over refs? see psqp
	
	
	prqp.from = proj.global_position
	prqp.to = prqp.from + proj.velocity*delta
	var r_col := dss.intersect_ray(prqp)
	var r_dist := 1.0
	var h_pos := Vector3.ZERO
	if !r_col.is_empty():
		h_pos = r_col[&"position"] as Vector3
		r_dist = Util.vec3_inv_lerp(prqp.from, prqp.to, h_pos)
	
	psqp.transform = proj.transform
	psqp.motion = proj.velocity * delta * r_dist
	var s_dist := dss.cast_motion(psqp)[1]
	
	var dist := delta*s_dist*r_dist
	proj.transform.origin += proj.velocity * dist
	proj.velocity += Vector3(0.0, -32.0, 0.0) * dist
	#process_modifier(proj, Vector2i.ZERO, delta * dist) # TODO proj modifiers
	
	if s_dist < 1.0: # hit entity before wall
		psqp.transform = proj.transform
		if proj.time == 0.0: psqp.exclude = [proj.ownr.get_rid()]
		var hits := dss.get_rest_info(psqp)
		if proj.time == 0.0: psqp.exclude = []
		if !hits.is_empty():
			var cid := hits[&"collider_id"] as int
			var colc := instance_from_id(cid) as PhysicsBody3D
			if colc is Entity: hit_entity(proj, colc as Entity)
	elif h_pos: # hit wall TODO collide with bounds
		var colc: Variant = r_col[&"collider"]
		if colc is LevelBody:
			var lvlb: LevelBody = colc as LevelBody
			var normal: Vector3 = r_col.get(&"normal", -proj.velocity.normalized()) as Vector3
			var pos := r_col.get(&"position", lvlb.global_position) as Vector3
			hit_levelbody(proj, lvlb, normal, pos)
	
	proj.time += dist

func hit_entity(proj: Projectile, ent: Entity) -> void:
	proj.time = time.value
	
	if ent is Player:
		var hit_player := ent as Player
		hit_player.take_damage.rpc(proj.damage, proj.velocity.normalized() * proj.knockback)
		for hook: Callable in collide_hooks: hook.call(proj, ent)
		for hook: Callable in damage_hooks: hook.call(proj, ent as Entity)

func hit_levelbody(proj: Projectile, lvlb: LevelBody, normal: Vector3, pos: Vector3) -> void:
	pos -= lvlb.global_position
	lvlb.take_proj_hit.rpc_id(1, proj.damage, proj.velocity.normalized() * (proj.knockback + 5.0), pos)
	if proj.bounces > 0:
		proj.bounces -= 1
		proj.velocity = proj.velocity.bounce(normal)
	else:
		proj.time = time.value
		for hook: Callable in collide_hooks: hook.call(proj, lvlb)


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
