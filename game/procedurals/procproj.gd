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
	for stat in all_stats:
		stat.reset_value()

func calculate_stats() -> void:
	for stat in all_stats:
		stat.calculate_value()

## Duration of the bullet. Default 1.0
var time := Stat.new(&"Bullet Time", 1.0, 0.001, 15.0)
## Size of the bullet. Default 2.0
var scale := Stat.new(&"Bullet Size", 2.0, 0.15)
## Damage of the bullet. Default 20.0
var damage := Stat.new(&"Bullet Damage", 20.0)
## bounces of the bullet. Default 0
var bounces := Stat.new(&"Bullet Bounces", 0)
## Knockback of the bullet. Default 20.0
var knockback := Stat.new(&"Bullet Knockback", 20.0, -9e9)
## All stats
var all_stats: Array[Stat] = [damage, scale, bounces, knockback, time]

## Hook for projectile hitting an object or entity, without bouncing
## [codeblock](ed:EventHook.EventData, pb3d:PhysicsBody3D)[/codeblock]
var collide_hook := EventHook.new()
## TODO seralize de for networking?
## Hook for projectile damaging entity
## [codeblock]func(n:int, bullet:Projectile, hit_player:Player) -> void:[/codeblock]
var damage_hook := EventHook.new()


func _init() -> void:
	shader_mat = StandardMaterial3D.new()
	shader_mat.albedo_color = Color.from_hsv(randf_range(0.0, 1.0), 0.85, 0.85)
	mesh = SphereMesh.new()
	mesh.radial_segments = 4
	mesh.rings = 1
	mesh.radius = 15 / 100.0
	mesh.height = mesh.radius*2
	mesh.material = shader_mat
	shape = SphereShape3D.new()
	shape.radius = mesh.radius
	psqp = PhysicsShapeQueryParameters3D.new()
	psqp.shape = shape
	psqp.collision_mask = 0b0110
	prqp = PhysicsRayQueryParameters3D.new()
	prqp.collision_mask = 0b0001


func create_projectile() -> Projectile:
	var proj := Projectile.new()
	bind(proj)
	count += 1
	return proj


func bind(proj: Projectile) -> void:
	proj.proc = self
	
	proj.time = 0.0
	proj.damage = damage.value
	proj.mesh = mesh
	proj.scale *= scale.value
	proj.bounces = bounces.value_int
	proj.knockback = knockback.value


func destroy_projectile(proj: Projectile) -> void:
	proj.proc = null
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
	
	if s_dist < 1.0: # hit entity before wall
		psqp.transform = proj.transform
		if proj.time == 0.0: psqp.exclude = [proj.ownr.get_rid()]
		var hits := dss.get_rest_info(psqp)
		if proj.time == 0.0: psqp.exclude = []
		if !hits.is_empty():
			var cid := hits[&"collider_id"] as int
			var colc := instance_from_id(cid) as PhysicsBody3D
			if colc is Entity:
				var normal: Vector3 = r_col.get(&"normal", -proj.velocity.normalized()) as Vector3
				hit_entity(proj, colc as Entity, normal)
	elif h_pos: # hit wall
		var colc: Variant = r_col[&"collider"]
		if colc is PhysicsBody3D:
			var pb3d := colc as PhysicsBody3D
			var normal: Vector3 = r_col.get(&"normal", -proj.velocity.normalized()) as Vector3
			bounce(proj, pb3d, normal)
			if pb3d is LevelBody:
				var lvlb: LevelBody = colc as LevelBody
				var pos := r_col.get(&"position", lvlb.global_position) as Vector3
				pos -= lvlb.global_position
				lvlb.take_proj_hit.rpc_id(1, proj.damage, proj.velocity.normalized() * (proj.knockback + 5.0) * proj.strength, pos)
	
	proj.time += dist


func hit_entity(proj: Projectile, ent: Entity, normal: Vector3) -> void:
	if ent is Player:
		var de := DamageEvent.new(proj.damage, proj.velocity.normalized() * proj.knockback * proj.strength, DamageEvent.TYPE_BULLET)
		de.source_entity = proj.ownr
		de.target_entity = ent
		
		var ed := EventHook.EventData.from_player(proj.ownr)
		ed.position = proj.global_position
		ed.proj_inst = proj
		ed.normal = normal
		ed.damage = de
		ed.mult = proj.strength
		damage_hook.execute(ed)
		
		var hit_player := ent as Player
		hit_player.take_damage_seralized.rpc(de.seralize())
		if proj.ownr is Player:
			var from_player := proj.ownr as Player
			from_player.hud.hit_marker_timer = 0.15
			SFXHandler.play_world_local(SFXHandler.HIT, ent.global_position, 0.0, 1.0, true)
	
	proj.time = time.value
	proj.bounces = 0


func bounce(proj: Projectile, pb3d: PhysicsBody3D, normal: Vector3) -> void:
	if proj.bounces > 0:
		proj.bounces -= 1
		proj.velocity = proj.velocity.bounce(normal) * 0.95
		SFXHandler.play_world(SFXHandler.RUBBER, proj.global_position, 0.0)
	else:
		proj.time = time.value
	
	var ed := EventHook.EventData.from_player(proj.ownr)
	ed.position = proj.global_position
	ed.proj_inst = proj
	ed.hit_pb3d = pb3d
	ed.normal = normal
	ed.mult = proj.strength / maxf(bounces.value+1.0, 1.0)
	ed.percent = proj.strength
	collide_hook.execute(ed)
