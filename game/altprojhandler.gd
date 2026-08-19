class_name AltProjHandler

static var projs: Array[ProcProj]
enum {
	FIREBALL,
	CACTUS,
	_MAX_COUNT }


static func load_all_projs() -> void:
	projs.resize(_MAX_COUNT)
	for i in _MAX_COUNT:
		match i:
			FIREBALL:
				var pproj := load_altproj(&"fireball", i)
				pproj.damage.multiplier = 0
				pproj.time.adder += 5.0
				pproj.knockback.multiplier = 0
				pproj.collide_hook.add_effect(1, func effect(ed:EventHook.EventData)-> void:
					var rt := ed.mult ** 0.333
					Game.world.create_explosion(ed.position, rt * 12.0, rt * 12.0, rt * 4.0, [], ed.player)
				)
				pproj.shader_mat.albedo_color = Color.ORANGE_RED
				pproj.calculate_stats()
			
			CACTUS:
				var pproj := load_altproj(&"cactus", i)
				pproj.scale.multiplier = 0.5
				pproj.time.adder += 5.0
				pproj.damage.multiplier *= 2.0
				pproj.shader_mat.albedo_color = Color.DARK_SEA_GREEN
				pproj.calculate_stats()


static func load_altproj(proj_id: StringName, i: int) -> ProcProj:
	Console.print(&"Loading altproj '%s'" % proj_id)
	projs[i] = ProcProj.new()
	return projs[i]


static func spawn(proj_id: int, trans: Transform3D, vel: Vector3 = Vector3(0, 0, -100), ownr: Entity = null) -> void:
	var proc := projs[proj_id]
	var proj := Network.send_alt_projectile(trans)
	proc.bind(proj)
	proj.ownr = ownr
	proj.velocity = trans.basis * vel


static func spawn_local(trans: Transform3D) -> Projectile:
	var pck := Projectile.PACKED
	var inst := pck.instantiate()
	var proj := inst as Projectile
	proj.position = trans.origin
	return proj
